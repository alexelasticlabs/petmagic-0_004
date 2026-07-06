# Gallery Release Branch Prep - 2026-07-03

Branch: `codex/release-blockers-hardening`

Status: `YELLOW`

Reason: release checks were previously reported GREEN, and local compose config checks pass, but the current working tree is not a clean gallery-only release scope. It contains gallery/release changes mixed with Economy, Identity, SupportChat, Gamification, admin-user, monitoring, and docs changes. Do not create a release commit until the scope is split or explicitly approved as one release train.

## Dirty Scope

Current dirty inventory after refreshed validation:

- tracked dirty entries: `367`
- untracked files: `26`
- earlier rough gallery/release tracked-file classification: `51`
- earlier rough unrelated/separate-release tracked-file classification: `71`
- ignored local files confirmed: `.env`, `.env.local`, `.env.staging.local`, `artifacts/`

### Release / Gallery Scope Candidates

These files look directly related to gallery, templates, runtime config, Docker, or release docs:

- `.dockerignore`
- `.env.example`
- `README.md`
- `docker-compose.yml`
- `docs/API_CONTRACTS.md`
- `docs/OBSERVABILITY.md`
- `docs/template-feed-stability-qa-2026-06-14.md`
- `apps/admin-web/src/components/templates/template-form-mappers.test.ts`
- `apps/admin-web/src/components/templates/template-form-mappers.ts`
- `apps/admin-web/src/lib/api-client.templates.ts`
- `apps/admin-web/src/lib/api-client.types.templates.ts`
- `apps/petmagic-mobile/integration_test/gallery_cross_flow_test.dart`
- `apps/petmagic-mobile/lib/features/templates/data/template_generation_repository_cache.part.dart`
- `apps/petmagic-mobile/lib/features/templates/data/templates_cache_data_source.dart`
- `apps/petmagic-mobile/lib/features/templates/presentation/template_generation_controller.dart`
- `apps/petmagic-mobile/test/template_generation_controller_test.dart`
- `apps/petmagic-mobile/test/template_generation_repository_cache_test.dart`
- `apps/petmagic-mobile/test/templates_controller_test.dart`
- `apps/petmagic-mobile/test/templates_repository_test.dart`
- `src/Modules/Templates/**`

### Release-Infrastructure Candidates

These may belong in the release branch, but should be reviewed separately because they are broader than gallery UX:

- `src/Host/PetMagic.Host.Api/Program.cs`
- `src/Host/PetMagic.Host.Api/Security/HostApiProductionConfigurationValidator.cs`
- `src/Host/PetMagic.Host.Api/appsettings.json`
- `src/Host/PetMagic.Host.GenerationWorker/Program.cs`
- `src/Host/PetMagic.Host.GenerationWorker/appsettings.json`
- `src/BuildingBlocks/PetMagic.BuildingBlocks/Observability/SafeLogValues.cs`
- `tests/PetMagic.Modules.Identity.Tests/Host/BackendEnvironmentContractTests.cs`
- `tests/PetMagic.Modules.Identity.Tests/Host/HostApiProductionConfigurationValidatorTests.cs`
- `deploy/monitoring/**`

### Exclude From Gallery Release Commit Unless Explicitly Approved

These are likely separate workstreams and should not be mixed into a gallery-only release commit:

- Economy module/API/tests/docs changes under `src/Modules/Economy/**`, `tests/**/Economy/**`, `docs/economy-*`, and `docs/audit-notifications-tokens-purchases-economy-2026-07-03.md`
- Identity/admin-user/auth/avatar changes under `src/Modules/Identity/**`, `tests/**/Identity/**`, and admin users UI/API files
- SupportChat changes under `src/Modules/SupportChat/**`, `tests/**/SupportChat/**`, and admin support UI files
- Gamification endpoint hardening under `src/Modules/Gamification/**` and `tests/**/Gamification/**`
- `docs/admin-web-production-followups.md` and `docs/security-audit-2026-06-17.md` unless they are intentionally part of the release branch cleanup
- Deleted `docs/md/STATUS.md` is release cleanup, not gallery functionality: it was a stale implementation status snapshot dated 2026-05-16 and has no active Markdown links.

### Mixed-Hunk Risk

Review these before staging because they can contain both release config and unrelated edits:

- `.env.example`
- `README.md`
- `docker-compose.yml`
- `docs/API_CONTRACTS.md`
- `docs/OBSERVABILITY.md`
- `src/Host/PetMagic.Host.Api/Program.cs`
- `src/Host/PetMagic.Host.Api/Security/HostApiProductionConfigurationValidator.cs`
- `apps/admin-web/src/lib/api-client.templates.ts`
- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplatesInfrastructureServiceCollectionExtensions.cs`

## Production Config And Secrets

Hard-required deployment values:

- `POSTGRES_PASSWORD`: secret store, non-placeholder
- `JWT_SIGNING_KEY`: secret store, non-placeholder, at least 64 characters
- `BACKEND_PUBLIC_BASE_URL`: real HTTPS public API/media base URL
- `BACKEND_ALLOWED_HOSTS`: real public backend host names, for example `api.petmagic.app`
- `BACKEND_HEALTHCHECK_HOST`: one host from `BACKEND_ALLOWED_HOSTS` for Docker healthchecks
- `TEMPLATES_STORAGE_PROVIDER`: production value must be `R2`
- `TEMPLATES_AI_PROVIDER`: production value must be `Fal`
- `PETMAGIC_LOCAL_SMOKE_FAST_FAKE_COMPLETION`: production value must be `false`
- `NEXT_PUBLIC_API_BASE_URL`: real HTTPS public API URL used by admin-web browser bundle
- `INTERNAL_API_BASE_URL`: real internal or HTTPS API URL used by admin-web server runtime
- `ALERTMANAGER_WEBHOOK_URL`: real webhook URL, or monitoring/alertmanager profile intentionally disabled
- `GRAFANA_ADMIN_PASSWORD`: secret store, non-placeholder

Additional production values required by the selected providers:

- `FAL_AI_API_KEY`
- `FAL_WEBHOOK_URL`
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY`
- `R2_SECRET_KEY`
- `R2_BUCKET_NAME`
- `R2_PUBLIC_URL`
- payment/store secrets if production billing is enabled

Confirmed local safety:

- `.env`, `.env.local`, `.env.staging.local`, and `artifacts/` are ignored by `.gitignore`.
- `.env.example` is a local template with placeholders and local defaults. It is safe as an example file, but it is not a production env file.
- `docker compose config` reads the local ignored `.env` when present. Therefore production deploy must use deployment secret store or an explicit production env source, never the local `.env`.
- `docker compose --env-file .env.example config --quiet` passes, proving the example file is syntactically complete for compose validation.

Production validators already reject:

- placeholder connection strings and JWT keys outside Development;
- unsafe public base URLs outside Development;
- `Local` template storage in Production;
- `Fake` template AI provider in Production;
- template seed/QA fixtures in Production;
- missing R2 config when `R2` is selected;
- missing FAL key when `Fal` is selected;
- noop generation billing in Production.

## Checks Run In This Prep Pass

- `git status --short`: dirty tree is broad; release scope is not clean.
- `git diff --shortstat`: 366 files changed, 11559 insertions, 2407 deletions.
- `git status --short`: 367 tracked dirty entries and 26 untracked files.
- `git check-ignore -v .env .env.local .env.staging.local artifacts/...`: ignored as expected.
- `dotnet restore PetMagic.slnx`: passed.
- `dotnet build PetMagic.slnx --no-restore`: passed, 0 warnings, 0 errors.
- `dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-build`: passed, 1573/1573.
- EF pending model checks for Identity, Economy, Gamification, SupportChat, and Templates: passed, no pending model changes.
- EF `database update` on existing isolated `petmagic_goal_probe` DB for all five contexts: passed, database already up to date.
- EF clean apply on temporary `petmagic_clean_goal_202607031826` for all five contexts: passed, 73 migration history entries; temporary DB removed.
- `docker compose --env-file .env.example config --quiet`: passed.
- `docker compose --env-file .env.local-smoke.example config --quiet`: passed.
- `docker compose --env-file .env.example --profile monitoring config --quiet`: passed.
- `npm run lint`, `npm run typecheck`, `npm test`, `npm run build` in `apps/admin-web`: passed; admin tests passed 616/616.
- `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --profile --dart-define=API_BASE_URL=https://api.petmagic.app`: passed; Flutter tests passed 1176/1176 and profile APK built.
- `adb devices`: `R5CR126590A` connected.
- `adb reverse --list`: `UsbFfs tcp:5000 tcp:5000`.
- `flutter test integration_test\gallery_cross_flow_test.dart -d R5CR126590A --reporter expanded --dart-define=API_BASE_URL=http://127.0.0.1:5000`: passed, 1/1 on real Android device.
- `adb logcat -d -b crash -t 200`: no crash-buffer output.
- `node scripts\qa\check-markdown-local-links.mjs`: passed, 45 files checked.
- `node --check` across `scripts/**/*.js` and `scripts/**/*.mjs`: passed.
- `git diff --check`: passed, with CRLF normalization warnings only.

Not rerun in this prep pass:

- `dotnet build PetMagic.slnx -c Release --no-restore --no-incremental -m:1`
- `flutter gen-l10n`
- Docker image rebuilds and `ffmpeg -version` inside freshly rebuilt images in this refreshed pass.
- Staging/prod smoke with real provider secrets.

Reason: current dirty tree is still not isolated to a clean release/gallery scope. The refreshed local gates validate the mixed branch state, not a controlled release commit.

## Release Notes

- Gallery save/share/copy flows now use fresh backend endpoints instead of relying on stale signed media URLs.
- Copy link uses a durable public share URL.
- Gallery list supports cursor pagination and load-more.
- `GalleryMediaState` models explicit gallery media readiness.
- User-facing states cover preparing, expired, unavailable, preview-only, watermark-preparing, failed, and hidden media.
- Background gallery media sync is bounded to avoid unbounded traffic and storage growth.
- Video result thumbnails are generated with `ffmpeg`.
- Realtime gallery updates use authenticated per-user SSE.
- Ownership and security tests were added around gallery access, public share behavior, storage URL exposure, and admin/template boundaries.
- Docker/runtime checks include `ffmpeg` in API and generation-worker images.
- Real-device gallery smoke was rerun and passed on `R5CR126590A` with `API_BASE_URL=http://127.0.0.1:5000` and `adb reverse tcp:5000 tcp:5000`.

## Operational Notes

- Production secrets must come from the deployment secret store, not local `.env`.
- Do not use `.env.example` as a production env file without replacing local placeholders and fake/local providers.
- API and generation-worker images must include `ffmpeg` wherever video thumbnail or media processing can run.
- Reverse proxy must preserve SSE streaming behavior: no response buffering, no forced compression buffering, no short idle timeout.
- Public share responses must not expose signed private media URLs.
- `PETMAGIC_LOCAL_SMOKE_FAST_FAKE_COMPLETION=false` is mandatory outside local smoke.

## Staging Deploy Checklist

Before production, deploy to staging and verify:

- backend `/health` reports the expected build;
- database migrations apply cleanly;
- API auth works for fresh login/session;
- gallery list loads;
- cursor pagination works beyond 50 items;
- completed generation appears in gallery through realtime/polling;
- image result card renders;
- video result card renders with thumbnail;
- save/download works;
- native share works;
- copy link returns durable public share URL;
- public share URL opens without private signed URL leakage;
- expired media state renders correctly;
- watermark preparing state renders correctly;
- delete works and updates gallery;
- unread badge updates correctly;
- authenticated SSE reconnect works after network/app interruption;
- logout/login as another user does not leak prior user's gallery;
- storage access works through configured R2/public media path;
- `ffmpeg` thumbnail generation works in deployed API/worker runtime;
- logs do not contain sensitive data, secrets, signed URLs, bearer tokens, or raw provider payloads;
- gallery works on a real Android device.

## Rollback Plan

Migrations observed in current release scope:

- `20260702234729_AddGenerationBillingReconciliationIndexes`
  - Adds indexes on `templates_generation_jobs`: `ChargedAtUtc`, `RefundedAtUtc`, `(CreatedAtUtc, Id)`, `(UpdatedAtUtc, Id)`.
  - Down migration drops those indexes.
  - No destructive data changes observed in this migration.

Rollback actions:

- If app deployment fails before migrations: roll back API/admin/mobile artifacts to the previous release image/build; do not apply migrations.
- If this index migration has been applied and rollback is required: deploy previous app image first if compatible, then run EF downgrade only if the database load allows index drops. Index drops are operationally safer than data rewrites but can still take locks on large tables.
- If `ffmpeg` or video thumbnail path fails: keep generation result delivery active, disable or bypass thumbnail generation if a config switch exists; otherwise roll back API/worker image to the previous known-good build.
- If public share URL route fails: disable the copy durable link entrypoint in UI if feature-gated; otherwise roll back API/admin/mobile package together to avoid clients generating broken links.
- If authenticated SSE is unstable: reduce reliance on realtime by using existing polling/refresh paths; if a realtime feature flag/config exists, disable SSE while keeping gallery list/status endpoints active.
- If storage access fails: switch traffic back to previous storage config/image, verify R2 credentials and public URL, then replay failed media sync/reconciliation jobs if available.
- Do not manually edit production DB rows for emergency rollback unless a targeted migration or runbook has been prepared and reviewed.

## Final Decision

Current branch is not ready for a production deploy commit as-is.

Production deploy can be prepared after:

- release/gallery scope is split from unrelated dirty files or explicitly approved as a combined release train;
- full backend/mobile/docker gate is rerun against the final scope;
- production env is supplied by secret store with real non-placeholder values;
- staging deploy checklist is completed;
- rollback owner and migration window are confirmed.
