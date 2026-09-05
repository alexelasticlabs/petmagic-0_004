#!/usr/bin/env python3
"""Resumable payments/push QA. No credentials, receipts or device dumps in reports."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_FILTER = '|'.join('FullyQualifiedName~' + name for name in (
    'VerifyPackStorePurchaseAsync', 'VerifyPremiumStorePurchaseAsync',
    'StoreSubscriptionVerifierCorrelationTests', 'StoreAccountBindingModeHealthCheckTests',
    'FcmPushPayloadContractTests', 'EconomyPushOutboxProcessorTests',
    'SupportChatPushOutboxProcessorTests', 'TemplateGenerationPushOutboxTopologyTests'))


class QaError(Exception):
    pass


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def require(condition, message):
    if not condition:
        raise QaError(message)


def api_origin(value):
    url = urllib.parse.urlsplit(value)
    require(url.scheme == 'https' and url.hostname and not url.username and not url.password
            and not url.query and not url.fragment and url.path in ('', '/'),
            'Use an explicit HTTPS API origin without credentials, path or query.')
    return value.rstrip('/')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class Api:
    def __init__(self, origin):
        self.origin = api_origin(origin)

    def request(self, path, body=None, authenticated=True):
        token = os.environ.get('PETMAGIC_QA_ACCESS_TOKEN', '')
        require(not authenticated or token, 'Set PETMAGIC_QA_ACCESS_TOKEN for the test user; never pass it as an argument.')
        headers = {'Accept': 'application/json'}
        if authenticated:
            headers['Authorization'] = 'Bearer ' + token
        data = None
        if body is not None:
            headers['Content-Type'] = 'application/json'
            data = json.dumps(body).encode()
        request = urllib.request.Request(self.origin + path, data=data, headers=headers)
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=25) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            # Never print server error bodies, headers, credentials or receipt data.
            raise QaError(f'API returned HTTP {error.code}; check access and target environment.') from None
        except (OSError, ValueError):
            raise QaError('API unavailable or returned invalid JSON.') from None


def command(args, timeout=30):
    try:
        result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8',
                                errors='replace', timeout=timeout, cwd=ROOT)
    except (OSError, subprocess.TimeoutExpired):
        raise QaError('Required tool unavailable or timed out: ' + Path(args[0]).name) from None
    require(result.returncode == 0, 'Tool failed: ' + Path(args[0]).name)
    return result.stdout


class Report:
    def __init__(self, directory, origin=None):
        self.directory = Path(directory).resolve()
        self.path = self.directory / 'report.json'
        if self.path.exists():
            self.data = json.loads(self.path.read_text(encoding='utf-8'))
            require(origin is None or self.data['apiOrigin'] == api_origin(origin), 'Cannot change the API target of an existing run.')
        else:
            require(origin is not None, 'Start with the run command first.')
            self.directory.mkdir(parents=True, exist_ok=True)
            self.data = {'schemaVersion': 1, 'startedAt': utc(), 'apiOrigin': api_origin(origin),
                         'checks': {}, 'purchaseObservations': {}, 'storeAcceptance': 'needs_verification'}

    def add(self, name, status, detail):
        self.data['checks'][name] = {'status': status, 'detail': detail, 'at': utc()}
        self.save()
        print(f'{status.upper()}: {name}: {detail}', flush=True)

    def save(self):
        self.data['updatedAt'] = utc()
        # Source tests and observations alone never certify both store lifecycles.
        self.data['strictBindingSwitchAllowed'] = False
        temp = self.path.with_suffix('.tmp')
        temp.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding='utf-8')
        temp.replace(self.path)
        lines = ['# Payments and push QA', '', 'API: ' + self.data['apiOrigin'],
                 '', 'Store acceptance: **needs verification**. No production configuration was changed.', '']
        for name, check in self.data['checks'].items():
            lines.append(f"- {name}: **{check['status']}** — {check['detail']}")
        lines += ['', 'Remaining release evidence: real Apple and Google sandbox purchase, restore, replay,',
                  'mismatched/new-unbound account rejection, and physical push lifecycle/tap routing.',
                  'A passing source test or ledger observation does not prove the store UI action occurred.']
        (self.directory / 'report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def adb_path(explicit=None):
    result = explicit or shutil.which('adb')
    if not result:
        candidate = Path(os.environ.get('LOCALAPPDATA', '')) / 'Android/Sdk/platform-tools/adb.exe'
        result = str(candidate) if candidate.is_file() else None
    require(result, 'adb is missing; supply --adb or install Android platform-tools.')
    return result


class Android:
    def __init__(self, serial, package, adb=None):
        require(serial and re.fullmatch(r'[A-Za-z0-9_.:-]+', serial), 'An explicit Android serial is required.')
        require(package in ('com.petmagic.app', 'com.petmagic.app.staging'), 'Unsupported PetMagic package.')
        self.adb, self.serial, self.package = adb_path(adb), serial, package

    def run(self, *args):
        return command([self.adb, '-s', self.serial, *args])

    def ready(self):
        require(self.run('get-state').strip() == 'device', 'Device is not authorized/connected.')
        policy = self.run('shell', 'dumpsys', 'window', 'policy')
        require(re.search(r'\bshowing=false\b|\bmIsShowing=false\b', policy), 'Unlock the device manually.')
        package = self.run('shell', 'dumpsys', 'package', self.package)
        version = re.search(r'\bversionCode=(\d+)', package)
        require(version, 'Requested app is not installed.')
        installer = re.search(r'installerPackageName=([^\s]+)', package)
        return {'versionCode': version.group(1), 'installer': installer.group(1) if installer else 'unknown'}

    def ui(self):
        raw = self.run('exec-out', 'uiautomator', 'dump', '/dev/tty')
        start, end = raw.find('<?xml'), raw.rfind('</hierarchy>')
        require(start >= 0 and end >= start, 'UI hierarchy unavailable; retry when device is idle.')
        return ET.fromstring(raw[start:end + len('</hierarchy>')])


def marker_nodes(tree, marker, package=None):
    return [n for n in tree.iter('node') if (not package or n.get('package') == package)
            and marker in (n.get('text', '') + ' ' + n.get('content-desc', ''))]


def center(node):
    match = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
    require(match, 'Notification has no usable bounds.')
    x1, y1, x2, y2 = map(int, match.groups())
    require(x2 > x1 and y2 > y1, 'Notification is outside the visible area.')
    return str((x1+x2)//2), str((y1+y2)//2)


def ledger(api):
    entries, seen = [], set()
    for page in range(100):
        data = api.request(f'/api/economy/wallet/ledger?skip={page*100}&take=100')
        items = data['items']
        require(isinstance(items, list), 'Unexpected ledger contract.')
        for item in items:
            require(item['entryId'] not in seen, 'Ledger changed during pagination; retry on an idle test account.')
            seen.add(item['entryId'])
        entries.extend(items)
        if not data['hasMore']:
            return entries
        require(len(items) == 100, 'Incomplete ledger page; refusing partial evidence.')
    raise QaError('Ledger exceeds the bounded scan; use a dedicated QA account.')


def purchase_evidence(order, entries, order_id):
    require(order['orderId'] == order_id, 'API returned a different order.')
    require(order['paymentProvider'] in ('google_play', 'app_store'), 'This scenario requires a store purchase.')
    require(order['status'].lower() == 'succeeded', 'Purchase has not succeeded yet.')
    matching = [x for x in entries if x['reason'] == 'purchase:' + order_id and x['source'] == 'pack_purchase']
    require(len(matching) == 1, 'Expected exactly one pack_purchase ledger credit.')
    item = matching[0]
    require(item['userId'] == order['userId'] and item['delta'] == order['sparkToGrant'] > 0,
            'Ledger ownership or credited amount does not match the order.')
    return {'entryId': item['entryId'], 'delta': item['delta'], 'provider': order['paymentProvider']}


def passing_tests(trx):
    counters = ET.parse(trx).find('.//{*}Counters')
    require(counters is not None and int(counters.get('total', 0)) > 0
            and int(counters.get('passed', 0)) == int(counters.get('total', 0)),
            'Contract run contains failures/skips or no tests.')
    return int(counters.get('passed'))


def run_checks(args, report):
    try:
        health = Api(report.data['apiOrigin']).request('/health', authenticated=False)
        status = health.get('status', 'Unknown')
        require(status in ('Healthy', 'Degraded', 'Unhealthy'), 'Unknown health response contract.')
        report.add('api.health', {'Healthy': 'passed', 'Degraded': 'attention', 'Unhealthy': 'failed'}[status], status)
    except QaError as error:
        report.add('api.health', 'blocked', str(error))
    if args.android_device:
        try:
            device = Android(args.android_device, args.package, args.adb)
            info = device.ready()
            report.data['android'] = {'serial': args.android_device, 'package': args.package, **info}
            report.add('android.ready', 'passed', f"Build {info['versionCode']}; installer {info['installer']}. API target and license-tester identity still require in-app confirmation.")
        except QaError as error:
            report.add('android.ready', 'blocked', str(error))
    else:
        report.add('android.ready', 'blocked', 'Supply --android-device; no automatic device selection.')
    report.add('ios.store', 'manual', 'Use an unlocked iPhone with TestFlight and a Sandbox Apple Account. Windows cannot perform StoreKit UI acceptance.')
    if args.contract_tests:
        report.add('backend.contracts', 'running', 'Running store binding, replay and notification contracts.')
        trx = report.directory / 'contracts.trx'
        trx.unlink(missing_ok=True)
        try:
            command(['dotnet', 'test', str(ROOT / 'tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj'),
                     '--filter', CONTRACT_FILTER, '--logger', 'trx;LogFileName=contracts.trx',
                     '--results-directory', str(report.directory), '--verbosity', 'quiet'], timeout=900)
            report.add('backend.contracts', 'passed', str(passing_tests(trx)) + ' tests passed; source evidence only.')
        except (QaError, OSError, ET.ParseError) as error:
            report.add('backend.contracts', 'failed', str(error) if isinstance(error, QaError) else 'Missing or invalid TRX results.')
    elif 'backend.contracts' not in report.data['checks']:
        report.add('backend.contracts', 'manual', 'Rerun with --contract-tests to execute server contracts.')


def check_purchase(args, report):
    order_id = str(uuid.UUID(args.order_id))
    api = Api(report.data['apiOrigin'])
    path = '/api/economy/purchases/' + order_id
    before = purchase_evidence(api.request(path), ledger(api), order_id)
    key = order_id + '.' + args.phase
    observations = report.data['purchaseObservations']
    if args.phase == 'replay':
        require(args.receipt_file, '--receipt-file is required for an actual server replay.')
        receipt = json.loads(Path(args.receipt_file).read_text(encoding='utf-8'))
        require(receipt.get('paymentProvider') == before['provider'], 'Receipt provider differs from the settled order.')
        require(receipt.get('serverVerificationData') and receipt.get('productId'), 'Receipt contract is incomplete.')
        # Already-settled, owned order only: cannot create a purchase or initiate a charge.
        api.request(path + '/verify-store', receipt)
    elif args.phase == 'restore':
        require(order_id + '.purchase' in observations, 'Record the purchase before performing restore in the app.')
        require(observations[order_id + '.purchase'] == before, 'Credit changed since original purchase.')
    after = purchase_evidence(api.request(path), ledger(api), order_id)
    require(before == after, 'Ledger credit changed across the verification.')
    observations[key] = after
    report.add('store.' + key, 'passed', 'Exactly one matching credit. ' +
               ('Actual verify-store replay did not create another credit.' if args.phase == 'replay' else
                'Backend observation; store UI completion and sandbox identity need separate evidence.'))


def observe_push(args, report):
    require(args.device_ready, 'Supply --device-ready only when the selected phone is free for QA.')
    require(len(args.marker) >= 12 and len(args.route_marker) >= 4, 'Use a unique notification marker (12+ chars) and a specific destination marker.')
    saved = report.data.get('android', {})
    require(saved.get('serial'), 'Run Android readiness first.')
    device = Android(saved['serial'], saved['package'], args.adb)
    require(device.ready()['versionCode'] == saved['versionCode'], 'Installed app changed; start a fresh report.')
    try:
        device.run('shell', 'cmd', 'statusbar', 'expand-notifications')
        require(not marker_nodes(device.ui(), args.marker), 'Marker already exists. Use a fresh event marker.')
        device.run('shell', 'cmd', 'statusbar', 'collapse')
        device.run('shell', 'input', 'keyevent', 'KEYCODE_HOME')
        if args.lifecycle == 'terminated':
            device.run('shell', 'am', 'kill', device.package)
            processes = device.run('shell', 'ps', '-A')
            require(not re.search(r'\b' + re.escape(device.package) + r'(?::\S+)?\s*$', processes, re.M),
                    'App process is still alive. Close the app normally and retry; force-stop is not a push acceptance test.')
        print('ARMED: trigger a fresh test notification containing the marker. No message is sent by this tool.', flush=True)
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            device.ready()
            device.run('shell', 'cmd', 'statusbar', 'expand-notifications')
            matches = marker_nodes(device.ui(), args.marker)
            if matches:
                # Only tap one uniquely identified visible node; never guess coordinates.
                require(len(matches) == 1, 'Notification marker is ambiguous; inspect the device.')
                device.run('shell', 'input', 'tap', *center(matches[0]))
                route_deadline = time.monotonic() + 25
                while time.monotonic() < route_deadline:
                    if marker_nodes(device.ui(), args.route_marker, device.package):
                        report.add('android.push.' + args.lifecycle, 'passed',
                                   'Fresh notification observed and tap opened the expected app content. Marker SHA256: ' +
                                   hashlib.sha256(args.marker.encode()).hexdigest()[:16])
                        return
                    time.sleep(1)
                raise QaError('Notification arrived but expected destination was not observed.')
            device.run('shell', 'cmd', 'statusbar', 'collapse')
            time.sleep(3)
        raise QaError('No matching notification before timeout. Trigger/device/provider evidence is incomplete.')
    finally:
        device.run('shell', 'cmd', 'statusbar', 'collapse')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    run = sub.add_parser('run', help='Read-only readiness and optional server contract tests')
    run.add_argument('--api-base-url', required=True)
    run.add_argument('--android-device')
    run.add_argument('--package', default='com.petmagic.app', choices=['com.petmagic.app', 'com.petmagic.app.staging'])
    run.add_argument('--contract-tests', action='store_true')
    purchase = sub.add_parser('purchase', help='Verify owned store order and exactly-once credit')
    purchase.add_argument('--order-id', required=True)
    purchase.add_argument('--phase', choices=['purchase', 'restore', 'replay'], default='purchase')
    purchase.add_argument('--receipt-file', help='Exact VerifyPackStorePurchaseRequest JSON; kept out of reports')
    push = sub.add_parser('push', help='Observe a fresh Android background/terminated push and tap route')
    push.add_argument('--marker', required=True)
    push.add_argument('--route-marker', required=True)
    push.add_argument('--lifecycle', required=True, choices=['background', 'terminated'])
    push.add_argument('--timeout', type=int, default=180, choices=range(15, 601), metavar='15..600')
    push.add_argument('--device-ready', action='store_true')
    for child in (run, purchase, push):
        child.add_argument('--run-dir', required=True)
        child.add_argument('--adb')
    args = parser.parse_args(argv)
    report = None
    lock = Path(args.run_dir).resolve() / '.qa.lock'
    try:
        lock.parent.mkdir(parents=True, exist_ok=True)
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(str(os.getpid()))
    except OSError:
        print('Run directory is locked or not writable. Do not run two checks against the same report.', file=sys.stderr)
        return 2
    try:
        report = Report(args.run_dir, getattr(args, 'api_base_url', None))
        if args.action == 'run':
            run_checks(args, report)
        elif args.action == 'purchase':
            check_purchase(args, report)
        else:
            observe_push(args, report)
        report.data['checks'].pop(args.action + '.last_attempt', None)
        report.save()
        print('Report: ' + str(report.directory / 'report.md'))
        return 2 if args.action == 'run' and any(c['status'] in ('failed', 'blocked') for c in report.data['checks'].values()) else 0
    except (QaError, ValueError, KeyError, OSError, ET.ParseError, TypeError) as error:
        message = str(error) if isinstance(error, QaError) else 'Invalid input, report or API contract; no acceptance recorded.'
        if report:
            if args.action == 'purchase':
                name = 'store.' + args.order_id + '.' + args.phase
                report.data['checks'].pop(name, None)
            elif args.action == 'push':
                report.data['checks'].pop('android.push.' + args.lifecycle, None)
            report.add(args.action + '.last_attempt', 'blocked', message)
        else:
            print(message, file=sys.stderr)
        return 2
    finally:
        lock.unlink(missing_ok=True)


if __name__ == '__main__':
    sys.exit(main())
