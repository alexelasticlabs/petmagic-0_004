# Release Readiness

Status: **not approved for production release**

This file is the single current release-readiness summary. Keep detailed
contracts and operating procedures in their canonical documents instead of
adding dated audit snapshots to the repository.

## Automated Gates

Run these gates against the exact release commit:

```powershell
dotnet restore PetMagic.slnx
dotnet build PetMagic.slnx --no-restore
dotnet test PetMagic.slnx --no-build
dotnet list PetMagic.slnx package --vulnerable --include-transitive

npm ci --prefix apps/admin-web
npm audit --prefix apps/admin-web --audit-level=moderate
npm run lint --prefix apps/admin-web
npm run typecheck --prefix apps/admin-web
npm test --prefix apps/admin-web
npm run build --prefix apps/admin-web

npm ci --prefix apps/public-web
npm audit --prefix apps/public-web --audit-level=moderate
npm run validate:legal --prefix apps/public-web
npm run lint --prefix apps/public-web
npm test --prefix apps/public-web

Push-Location apps/petmagic-mobile
flutter pub get
flutter analyze --fatal-infos
flutter test
Pop-Location

docker compose --env-file .env.example config --quiet
node scripts/qa/test-markdown-local-links.mjs
node scripts/qa/check-markdown-local-links.mjs
node scripts/qa/run-render-predeploy-gate.mjs
```

Local passes are pre-release evidence only. Record failures in the release PR;
do not append command transcripts to this file.

## Production Evidence Still Required

- Approved legal translations for every locale exposed by the public site. The
  current catalog is missing `de`, `es`, `fr`, `it`, and `pl`, so publication is
  intentionally blocked by `npm run validate:legal`.
- Privacy/legal approval for release Crashlytics collection, including the
  intended Firebase processor disclosure and retention basis.
- A signed Android AAB built with protected production signing material.
- An iOS archive and store validation from a supported macOS/Xcode environment.
- FAL generation and callback proof with production-like R2 upload/read paths.
- Stripe, Google Play, and App Store sandbox purchase, replay, refund, restore,
  and subscription lifecycle proof.
- FCM and APNs delivery proof on real devices for generation, economy, and
  support notifications.
- Clean and existing-database migration proof against the release commit,
  including backup and rollback evidence.
- Staging smoke for API, generation worker, admin web, public legal routes,
  observability, rate limits, and provider callbacks.

## Release Rules

- Release from a reviewed commit with a clean worktree.
- Keep secrets in platform secret storage; never package local `.env`, Firebase
  active configs, signing keys, database dumps, or test artifacts.
- Keep `Templates__GenerationWorkerEnabled=false` on the API and `true` on the
  generation worker.
- Preserve `/api/economy/...` as the billing contract; do not reintroduce the
  removed `/api/payments/stripe/*` surface.
- A green local build does not waive provider, device, migration, backup, or
  rollback evidence.

## Canonical References

- `docs/API_CONTRACTS.md`
- `docs/SECURITY.md`
- `docs/payments-sandbox-checklist.md`
- `docs/notifications-contract.md`
- `docs/economy-generation-billing.md`
- `docs/OBSERVABILITY.md`
- `docs/render-staging-deployment.md`
- `docs/render-staging-secrets-checklist.md`
