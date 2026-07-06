# AI Agent Rules

This document is mandatory context for Codex, Claude, MiMo, and any other AI
agent working on PetMagic.

PetMagic is a production-oriented system. Every agent task must preserve clean
architecture, explicit contracts, small diffs, testability, and predictable
release behavior.

## Required Work Cycle

Every agent task must follow this cycle:

1. Create or switch to a dedicated task branch.
2. Inspect the current dirty worktree before editing.
3. Make the smallest production-quality diff that solves the requested issue.
4. Remove replaced or obsolete code instead of leaving legacy paths behind.
5. Run the relevant checks listed below.
6. Report changed files, executed checks, skipped checks with reasons, and
   remaining risks.

Do not bundle unrelated cleanup, refactors, or speculative features into the
task branch. If the task exposes a larger problem, report it as a risk or a
follow-up unless it blocks the requested fix.

## Branch And Diff Rules

- Branches must be isolated per task and named with a clear purpose, using the
  `codex/` prefix unless the user requests another prefix.
- Keep diffs minimal and reviewable. Prefer targeted changes over broad
  rewrites.
- Never revert user changes or unrelated dirty files.
- Do not keep commented-out code, abandoned experiments, unused toggles, or
  duplicate implementations.
- Any replacement must fully remove the superseded path after migration.
- New dependencies require a direct product or engineering reason and must be
  called out in the final report.

## Verification Commands

Run the smallest sufficient command set for the touched area. If a command is
not run, the final report must say why.

### ASP.NET Backend

From the repository root:

```bash
dotnet restore PetMagic.slnx
dotnet build PetMagic.slnx
dotnet test PetMagic.slnx
dotnet test PetMagic.slnx --no-restore
```

For local API runtime checks:

```bash
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.local-smoke.example config --quiet
docker compose --env-file .env.staging.local.example config --quiet
docker compose ps
docker compose logs backend
dotnet run --project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj
```

Expected health endpoint:

```bash
curl http://localhost:5001/health
```

If `.env` overrides `BACKEND_HOST_PORT` to `5000`, use
`http://localhost:5000/health`.

### Flutter Mobile

From `apps/petmagic-mobile`:

```bash
flutter pub get
flutter gen-l10n
dart format --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

For a physical Android device using the local backend:

```bash
adb reverse tcp:5000 tcp:5000
adb reverse --list
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

If the backend is running through the default Compose host port, mirror and pass
`5001` instead:

```bash
adb reverse tcp:5001 tcp:5001
adb reverse --list
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

For release hardening:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.petmagic.app
```

Release app bundles require real `apps/petmagic-mobile/android/key.properties`
signing material. For local packaging/R8 checks without production signing, run
the documented direct Gradle bypass from `apps/petmagic-mobile/android`.

### Admin Web

From `apps/admin-web`:

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

Use plain `npm test`; do not add unsupported Jest flags such as `--runInBand`.

### Markdown And Repo Hygiene

From the repository root:

```bash
rg --files -g "*.md" -g "!apps/petmagic-mobile/third_party/**" -g "!**/Assets.xcassets/**"
node scripts/qa/check-markdown-local-links.mjs
git diff --check
git status --short
```

## API And DTO Rules

- API and Admin must communicate through explicit HTTP/API contracts only.
  Admin must never use EF Core `DbContext`, repositories, or direct database
  access.
- Public and admin APIs must use typed request and response DTOs. Do not expose
  persistence entities directly.
- Client-visible changes must update backend DTOs, validators, endpoint tests,
  Flutter DTOs/repositories, Admin API clients, and `docs/API_CONTRACTS.md`
  when applicable.
- Do not rename, remove, or repurpose existing response fields without a planned
  version-aware migration.
- No hidden breaking changes. Any breaking contract change must be explicit in
  the task report with affected consumers, migration path, and tests.
- Error responses must stay safe and stable: no stack traces, secrets, provider
  payloads, tokens, or raw request bodies in production-facing details.
- Use stable machine-readable error codes/titles and include diagnostic
  correlation identifiers where the endpoint supports structured failures.
- Validate all inputs at the API boundary and keep business rules in application
  or infrastructure services, not UI clients.

## EF Core Migration Rules

Each module owns its own `DbContext` and migration history. Add migrations only
in the infrastructure project that owns the changed model.

Design-time migration connection strings:

- `PETMAGIC_IDENTITY_MIGRATIONS_CONNECTION_STRING`
- `PETMAGIC_ECONOMY_MIGRATIONS_CONNECTION_STRING`
- `PETMAGIC_GAMIFICATION_MIGRATIONS_CONNECTION_STRING`
- `PETMAGIC_SUPPORTCHAT_MIGRATIONS_CONNECTION_STRING`
- `PETMAGIC_TEMPLATES_MIGRATIONS_CONNECTION_STRING`

Migration command pattern:

```bash
dotnet ef migrations add <MigrationName> \
  --project <module-infrastructure-csproj> \
  --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj \
  --context <DbContextName>
```

Pending-model-change check pattern:

```bash
dotnet ef migrations has-pending-model-changes \
  --project <module-infrastructure-csproj> \
  --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj \
  --context <DbContextName>
```

Module examples:

```bash
dotnet ef migrations has-pending-model-changes --project src/Modules/Identity/PetMagic.Modules.Identity.Infrastructure/PetMagic.Modules.Identity.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context IdentityDbContext
dotnet ef migrations has-pending-model-changes --project src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/PetMagic.Modules.Economy.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context EconomyDbContext
dotnet ef migrations has-pending-model-changes --project src/Modules/Gamification/PetMagic.Modules.Gamification.Infrastructure/PetMagic.Modules.Gamification.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context GamificationDbContext
dotnet ef migrations has-pending-model-changes --project src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/PetMagic.Modules.SupportChat.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context SupportChatDbContext
dotnet ef migrations has-pending-model-changes --project src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/PetMagic.Modules.Templates.Infrastructure.csproj --startup-project src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj --context TemplatesDbContext
```

Migration requirements:

- Migrations must match model changes and include the updated snapshot.
- Avoid destructive migrations unless the task explicitly requires them and the
  report names the data impact.
- Do not hand-edit snapshots to hide model drift.
- If a migration affects client behavior, update the API contract and tests in
  the same task.

## UI Size And Composition Rules

Keep files and components small enough to review and maintain:

- Flutter widgets/pages: split before they become hard to scan; keep business
  logic out of widgets and move API/state logic into feature data/state layers.
- Admin pages/components: target less than 250-300 lines per component; extract
  reusable controls into shared UI modules.
- Razor pages, if introduced, must stay orchestration-only and must not contain
  direct database or business logic.
- Backend endpoints/controllers must stay thin. Move use cases, validation,
  persistence, and integration logic into the proper module layer.
- Avoid god services. Split large services by real domain responsibility.

UI must include real loading, empty, error, retry, and unavailable states where
the flow can fail. Text must not clip or overlap on mobile or desktop sizes.

## Safe Area And Navbar Blur Rules

Flutter screens must respect system insets and the existing navigation shell:

- Wrap edge-to-edge screen bodies, modal sheets, sticky actions, and bottom bars
  in `SafeArea` or an equivalent sliver-safe layout.
- Do not place primary actions under gesture navigation, keyboard insets, or
  device cutouts.
- Any `BackdropFilter` or `ImageFilter.blur` must be clipped with `ClipRect` or
  an equivalent bounded widget.
- Heavy blur must go through existing performance guard patterns where
  available, especially on Android and startup/root screens.
- Keep navbar blur visually consistent with the shared shell navigation. Do not
  duplicate one-off blur stacks when a shared component already exists.
- Verify changed screens on small mobile width and at least one normal desktop
  or tablet width when the surface is responsive.

## Security And Logging Rules

- Secrets stay on the backend or in managed environment configuration. Never
  expose server-only secret names or values through browser/mobile config.
- Enforce authentication and role checks at the backend boundary.
- Validate file uploads, media URLs, IDs, ownership, and pagination cursors.
- Keep user-facing errors safe. Keep diagnostic detail in structured logs with
  correlation IDs.
- Do not add temporary console spam or unstructured debug logging.
- New security-sensitive flows must include tests or a manual verification note.

## Agent Report Format

Every final agent report must use this structure:

```text
Branch:
- <branch name or "not changed">

Changed:
- <short list of files/areas changed>

Checks:
- <command>: passed
- <command>: failed, with short reason
- <command>: not run, with reason

Contract impact:
- <none or API/DTO/migration/UI contract details>

Risks:
- <remaining risk, follow-up, or "none known">
```

If runtime verification was requested, include the exact device, URL, port,
health endpoint, and any `adb reverse --list` evidence used.
