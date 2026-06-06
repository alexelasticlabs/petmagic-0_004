# Security

This repository must not contain real production secrets. Use local `.env` files for development only, and CI/CD secrets, platform environment variables, or a managed secret store for deployed environments.

## Secret Handling

Never commit real values for:

- Stripe secret, publishable, and webhook keys;
- FAL API keys;
- Cloudflare R2 credentials;
- JWT signing keys;
- SMTP credentials;
- Apple, Google Play, Firebase, and OAuth credentials;
- database usernames and passwords.

`.env` is ignored by Git. `.env.example` must contain placeholders only. Production deployments should inject values at runtime through the deployment platform or secret manager.

If a real credential is committed or logged:

1. Revoke or rotate the credential immediately.
2. Remove it from the repository history where required by policy.
3. Rerun the Gitleaks workflow and the deployment pipeline.
4. Check backend and worker logs for accidental exposure.

## CI Gates

`.github/workflows/backend-security.yml` runs:

- Gitleaks on repository history;
- GitHub dependency review for pull requests;
- `dotnet list PetMagic.slnx package --vulnerable --include-transitive`.

These checks must stay required for backend changes.

## Production Startup Requirements

Production must fail fast when unsafe defaults are present:

- non-placeholder `Jwt:SigningKey`;
- configured `Cors:AllowedOrigins`;
- no `BootstrapAdmin:Password`;
- production Stripe, App Store, Google Play, and provider secrets;
- production-safe template storage, AI provider, and billing provider;
- backend with `Templates__GenerationWorkerEnabled=false`;
- generation worker with `Templates__GenerationWorkerEnabled=true`.

Swagger/OpenAPI is mapped only in Development.

## Error Responses And Logs

Production problem responses must not include exception messages, stack traces, or secrets. Responses include `traceId` and `correlationId` for support/debugging.

When adding logs:

- do not log authorization headers, cookies, tokens, payment payload secrets, webhook signing secrets, private keys, or full connection strings;
- prefer structured fields such as `GenerationId`, `UserId`, `Status`, and `CorrelationId`;
- log external provider failures with provider name, stage, model, and safe error code only.

## Access Control Invariants

- User-specific queries must filter by `UserId`.
- Foreign user resources return `404`, not resource details.
- Admin and moderator endpoints require explicit role authorization.
- Webhooks must validate provider signatures before mutating state.
- API requests enqueue generation jobs only; generation execution belongs to `generation-worker`.
