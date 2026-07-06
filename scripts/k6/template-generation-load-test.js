import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import encoding from 'k6/encoding';
import { Counter, Rate, Trend } from 'k6/metrics';

const profile = (__ENV.PROFILE || 'generation').toLowerCase();
const sourcePngBytes = encoding.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=');

const createLatency = new Trend('generation_create_latency', true);
const pollLatency = new Trend('generation_poll_latency', true);
const acceptedRate = new Rate('generation_create_accepted');
const duplicateRate = new Rate('generation_duplicate_matched');
const overloadRate = new Rate('generation_queue_overloaded');
const activeLimitRate = new Rate('generation_active_limit_reached');
const createFailures = new Counter('generation_create_failures');
const pollFailures = new Counter('generation_poll_failures');

export const options = {
    scenarios: buildScenarios(profile),
    thresholds: {
        http_req_failed: ['rate<0.10'],
        http_req_duration: ['p(95)<1500', 'p(99)<3000'],
        generation_create_latency: ['p(95)<1500', 'p(99)<3000'],
        generation_poll_latency: ['p(95)<750', 'p(99)<1500']
    }
};

export function setup() {
    const baseUrl = (__ENV.BASE_URL || 'http://localhost:5001').replace(/\/$/, '');
    const templateId = __ENV.TEMPLATE_ID;
    if (!templateId) {
        fail('TEMPLATE_ID is required.');
    }

    let tokens = parseTokens(__ENV.AUTH_TOKENS || __ENV.AUTH_TOKEN);
    if (tokens.length === 0) {
        tokens = [login(baseUrl)];
    }

    return {
        baseUrl,
        templateId,
        tokens,
        mode: (__ENV.MODE || 'user').toLowerCase(),
        pollAttempts: intEnv('POLL_ATTEMPTS', 10),
        pollSleepSeconds: numberEnv('POLL_SLEEP_SECONDS', 1),
        generationId: __ENV.GENERATION_ID || ''
    };
}

export function createGeneration(data) {
    const response = submitGeneration(data, uniqueIdempotencyKey());
    recordCreateResult(response);
}

export function createAndPoll(data) {
    const response = submitGeneration(data, uniqueIdempotencyKey());
    recordCreateResult(response);
    if (response.status !== 202) {
        return;
    }

    const generationId = response.json('generationId') || response.json('jobId');
    if (!generationId) {
        createFailures.add(1);
        return;
    }

    pollGeneration(data, generationId);
}

export function statusPolling(data) {
    if (data.generationId) {
        pollGeneration(data, data.generationId);
        return;
    }

    createAndPoll(data);
}

export function duplicateIdempotency(data) {
    const idempotencyKey = `duplicate-${__VU}-${__ITER}`;
    const first = submitGeneration(data, idempotencyKey);
    const second = submitGeneration(data, idempotencyKey);

    recordCreateResult(first);
    recordCreateResult(second);

    const firstId = first.status === 202 ? first.json('generationId') : null;
    const secondId = second.status === 202 ? second.json('generationId') : null;
    const matched = Boolean(firstId && secondId && firstId === secondId);
    duplicateRate.add(matched);
    check(null, {
        'duplicate idempotency returned same generation': () => matched
    });
}

function submitGeneration(data, idempotencyKey) {
    const url = data.mode === 'admin-test'
        ? `${data.baseUrl}/api/admin/templates/${data.templateId}/test`
        : `${data.baseUrl}/api/templates/${data.templateId}/generations`;
    const token = tokenForVu(data.tokens);
    const response = http.post(
        url,
        {
            sourceImage: http.file(sourceImageFor(idempotencyKey), `source-${idempotencyKey}.png`, 'image/png')
        },
        {
            headers: {
                Authorization: `Bearer ${token}`,
                'Idempotency-Key': idempotencyKey
            },
            tags: {
                name: data.mode === 'admin-test'
                    ? 'POST /api/admin/templates/{templateId}/test'
                    : 'POST /api/templates/{templateId}/generations'
            }
        });

    createLatency.add(response.timings.duration);
    return response;
}

function sourceImageFor(idempotencyKey) {
    const suffix = `\npetmagic-load-test-source-${idempotencyKey}`;
    const source = new Uint8Array(sourcePngBytes.byteLength + suffix.length);
    source.set(new Uint8Array(sourcePngBytes), 0);
    for (let i = 0; i < suffix.length; i += 1) {
        source[sourcePngBytes.byteLength + i] = suffix.charCodeAt(i) & 0xff;
    }

    return source.buffer;
}

function pollGeneration(data, generationId) {
    const token = tokenForVu(data.tokens);
    const url = data.mode === 'admin-test'
        ? `${data.baseUrl}/api/admin/templates/tests/${generationId}`
        : `${data.baseUrl}/api/templates/generations/${generationId}`;

    for (let attempt = 0; attempt < data.pollAttempts; attempt += 1) {
        const response = http.get(url, {
            headers: { Authorization: `Bearer ${token}` },
            tags: {
                name: data.mode === 'admin-test'
                    ? 'GET /api/admin/templates/tests/{generationId}'
                    : 'GET /api/templates/generations/{generationId}'
            }
        });

        pollLatency.add(response.timings.duration);
        const ok = check(response, {
            'poll returned 200': r => r.status === 200
        });
        if (!ok) {
            pollFailures.add(1);
            return;
        }

        const status = String(response.json('status') || '').toLowerCase();
        if (status === 'completed' || status === 'succeeded' || status === 'failed') {
            return;
        }

        sleep(data.pollSleepSeconds);
    }
}

function recordCreateResult(response) {
    const accepted = response.status === 202;
    acceptedRate.add(accepted);

    const contentType = response.headers['Content-Type'] || '';
    const title = contentType.indexOf('json') >= 0
        ? String(response.json('title') || response.json('code') || '')
        : '';
    const overloaded = response.status === 503 && title === 'GENERATION_QUEUE_OVERLOADED';
    const activeLimited = response.status === 429 && title === 'ACTIVE_GENERATION_LIMIT_REACHED';
    overloadRate.add(overloaded);
    activeLimitRate.add(activeLimited);

    const allowedFailure = profile === 'overload' && (overloaded || activeLimited || response.status === 429);
    const ok = check(response, {
        'create accepted or expected throttle/overload': r => accepted || allowedFailure
    });
    if (!ok) {
        createFailures.add(1);
    }
}

function login(baseUrl) {
    const email = __ENV.LOGIN_EMAIL;
    const password = __ENV.LOGIN_PASSWORD;
    if (!email || !password) {
        fail('AUTH_TOKEN/AUTH_TOKENS or LOGIN_EMAIL + LOGIN_PASSWORD is required.');
    }

    const response = http.post(
        `${baseUrl}/api/auth/login`,
        JSON.stringify({ email, password }),
        {
            headers: { 'Content-Type': 'application/json' },
            tags: { name: 'POST /api/auth/login' }
        });

    if (response.status !== 200) {
        fail(`Login failed with HTTP ${response.status}: ${response.body}`);
    }

    const token = response.json('accessToken');
    if (!token) {
        fail('Login response did not contain accessToken.');
    }

    return token;
}

function buildScenarios(selectedProfile) {
    const vus = intEnv('VUS', 50);
    const iterations = intEnv('ITERATIONS', 100);
    const duration = __ENV.DURATION || '2m';

    if (selectedProfile === 'polling') {
        if (__ENV.POLLING_EXECUTOR === 'constant-vus') {
            return {
                status_polling: {
                    executor: 'constant-vus',
                    vus,
                    duration,
                    exec: 'statusPolling'
                }
            };
        }

        return {
            status_polling: {
                executor: 'shared-iterations',
                vus,
                iterations,
                exec: 'statusPolling'
            }
        };
    }

    if (selectedProfile === 'duplicates') {
        return {
            duplicate_idempotency: {
                executor: 'shared-iterations',
                vus,
                iterations,
                exec: 'duplicateIdempotency'
            }
        };
    }

    if (selectedProfile === 'overload') {
        return {
            queue_overload: {
                executor: 'constant-arrival-rate',
                rate: intEnv('RATE', 100),
                timeUnit: '1s',
                duration,
                preAllocatedVUs: vus,
                maxVUs: intEnv('MAX_VUS', Math.max(vus * 2, 100)),
                exec: 'createGeneration'
            }
        };
    }

    if (selectedProfile === 'create-and-poll') {
        return {
            generation_create_and_poll: {
                executor: 'shared-iterations',
                vus,
                iterations,
                exec: 'createAndPoll'
            }
        };
    }

    return {
        generation_requests: {
            executor: 'shared-iterations',
            vus,
            iterations,
            exec: 'createGeneration'
        }
    };
}

function parseTokens(raw) {
    if (!raw) {
        return [];
    }

    return raw
        .split(',')
        .map(token => token.trim())
        .filter(token => token.length > 0);
}

function tokenForVu(tokens) {
    return tokens[(__VU - 1) % tokens.length];
}

function uniqueIdempotencyKey() {
    return `${profile}-${__VU}-${__ITER}-${Date.now()}`;
}

function intEnv(name, fallback) {
    const raw = __ENV[name];
    if (!raw) {
        return fallback;
    }

    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
}

function numberEnv(name, fallback) {
    const raw = __ENV[name];
    if (!raw) {
        return fallback;
    }

    const parsed = Number.parseFloat(raw);
    return Number.isFinite(parsed) ? parsed : fallback;
}

export function handleSummary(data) {
    const summary = renderSummary(data);
    const jsonPath = __ENV.SUMMARY_JSON || 'artifacts/load/k6-template-generation-summary.json';
    const mdPath = __ENV.SUMMARY_MD || 'artifacts/load/k6-template-generation-summary.md';

    return {
        stdout: summary,
        [jsonPath]: JSON.stringify(sanitizeSummary(data), null, 2),
        [mdPath]: summary
    };
}

function sanitizeSummary(data) {
    const sanitized = Object.assign({}, data);
    delete sanitized.setup_data;
    return sanitized;
}

function renderSummary(data) {
    const metric = name => (data.metrics[name] && data.metrics[name].values) || {};
    const httpReqDuration = metric('http_req_duration');
    const httpReqs = metric('http_reqs');
    const checks = metric('checks');
    const failures = metric('http_req_failed');
    const createAccepted = metric('generation_create_accepted');
    const overloaded = metric('generation_queue_overloaded');
    const activeLimited = metric('generation_active_limit_reached');

    return [
        '# PetMagic Template Generation Load Test',
        '',
        `Profile: ${profile}`,
        `Timestamp: ${new Date().toISOString()}`,
        `Git commit: ${__ENV.GIT_COMMIT || 'unknown'}`,
        `Workers: ${__ENV.WORKER_COUNT || 'unknown'}`,
        `VUs: ${__ENV.VUS || 'default'}`,
        `Iterations: ${__ENV.ITERATIONS || 'default'}`,
        `Duration: ${__ENV.DURATION || 'default'}`,
        '',
        '| Metric | Value |',
        '| --- | ---: |',
        `| HTTP RPS | ${formatNumber(httpReqs.rate)} |`,
        `| HTTP p95 | ${formatMs(httpReqDuration['p(95)'])} |`,
        `| HTTP p99 | ${formatMs(httpReqDuration['p(99)'])} |`,
        `| HTTP failure rate | ${formatRate(failures.rate)} |`,
        `| Check pass rate | ${formatRate(checks.rate)} |`,
        `| Generation accepted rate | ${formatRate(createAccepted.rate)} |`,
        `| Queue overloaded rate | ${formatRate(overloaded.rate)} |`,
        `| Active limit rate | ${formatRate(activeLimited.rate)} |`,
        '',
        'Capture host baseline next to this file:',
        '',
        '```sql',
        'select "Status", count(*) from templates_generation_jobs group by "Status" order by "Status";',
        "select count(*) from pg_stat_activity where datname = 'petmagic_db';",
        '```',
        '',
        '```bash',
        'docker stats --no-stream',
        '```',
        ''
    ].join('\n');
}

function formatMs(value) {
    return value === undefined ? 'n/a' : `${Number(value).toFixed(0)} ms`;
}

function formatRate(value) {
    return value === undefined ? 'n/a' : `${(Number(value) * 100).toFixed(2)}%`;
}

function formatNumber(value) {
    return value === undefined ? 'n/a' : Number(value).toFixed(2);
}
