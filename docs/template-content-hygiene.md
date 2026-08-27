# Template Content Hygiene

## Visibility Rules

Production-visible templates are templates where:

- `DeletedAtUtc IS NULL`;
- `Status = Active`;
- `IsQaOnly = false`;
- the required public media exists:
  - every active production-visible template has a preview asset with a non-empty URL;
  - every active production-visible video template has a reference motion asset with a non-empty URL;
  - preview and reference URLs are reachable and do not return 404/5xx;
  - video preview assets include duration metadata.

`Status = Active` is the publish flag. `Draft` and `Archived` templates are not public. `IsQaOnly`
is the environment/content hygiene flag for local smoke, failing provider, staging overload, and QA
templates that must never appear in normal production-visible public surfaces.

## Draft Authoring Contract

Use `Draft` for unfinished templates that an administrator intends to return to. A draft requires
only a non-empty title and remains available in the regular admin catalog; it is never shown to
users. Empty optional fields must not create empty template categories.

`Archived` is a separate lifecycle state for removing a template from routine work. Do not use it
as a substitute for an unfinished draft.

Before a template can move to `Active`, the API requires a title, short description, category,
positive PawSpark cost, pet photo requirements, valid model configuration, and the public media
required for its template type. This check is enforced server-side, including status-only API
requests, rather than relying only on the admin form.

Public endpoints exclude `IsQaOnly=true` by default:

- `GET /api/templates`
- `GET /api/templates/feed`
- `GET /api/templates/random`
- `GET /api/templates/{templateId}`
- `GET /api/templates/changes`
- `GET /api/templates/template-of-the-day`

Development/Staging QA can opt in only through `includeQa=true` on public catalog/feed/random/detail
endpoints, and only for authenticated `Admin` or `Moderator` callers. Production ignores this opt-in.
Admin catalog/detail endpoints still show QA-only templates so operators can edit or clean them.

## Problem Template Query

Use this query on local/staging/prod before releases. It identifies the same classes of rows that
caused local feed noise such as `впавпав`, `Тест`, `Local Smoke Failing Image`, unavailable previews,
and ExoPlayer 404s.

```sql
SELECT t."Id",
       t."Title",
       t."Status",
       t."IsQaOnly",
       t."TemplateType",
       preview."Url" AS "PreviewUrl",
       preview."ContentType" AS "PreviewContentType",
       preview."DurationSeconds" AS "PreviewDurationSeconds",
       reference."Url" AS "ReferenceUrl"
FROM templates_items t
LEFT JOIN templates_assets preview
  ON preview."TemplateId" = t."Id"
 AND preview."AssetKind" = 0
LEFT JOIN templates_assets reference
  ON reference."TemplateId" = t."Id"
 AND reference."AssetKind" = 1
WHERE t."DeletedAtUtc" IS NULL
  AND t."Status" = 1
  AND (
    t."IsQaOnly" = true
    OR t."Title" ILIKE ANY (ARRAY['%test%', '%тест%', '%smoke%', '%failing%', '%впавпав%'])
    OR preview."Url" IS NULL
    OR btrim(preview."Url") = ''
    OR (preview."ContentType" ILIKE 'video/%' AND preview."DurationSeconds" IS NULL)
    OR (t."TemplateType" = 1 AND (reference."Url" IS NULL OR btrim(reference."Url") = ''))
  )
ORDER BY t."UpdatedAtUtc" DESC;
```

## Health Check

`/health` includes `templates_content`. It checks active production-visible templates only
(`IsQaOnly=false`) and reports unhealthy when preview/reference media is missing or unreachable.
The public anonymous response is sanitized: it keeps health status and safe counters such as
`checkedTemplates` and `problemCount`, but it does not expose raw template ids/titles from the
`problems` list. Full diagnostics require an authenticated admin request.

Run:

```powershell
curl -sS "$env:STAGING_API_BASE_URL/health"
```

Expected healthy evidence:

- `templates_content` is healthy;
- `problemCount = 0`;
- no preview/reference 404s in API logs or CDN logs.

## Production Cleanup Checklist

Before production release:

- Run the problem template query against production.
- For any QA/local/failing/smoke template, set `IsQaOnly=true` or move it to `Draft`/`Archived`.
- For garbage titles such as `впавпав` or `Тест`, either rename to production copy or archive.
- For active production templates, verify preview URL opens from a clean browser session.
- For video templates, verify reference motion URL exists and preview video has duration metadata.
- Verify `/api/templates/feed?take=50` does not include QA/local/failing/smoke titles.
- Verify `/api/templates/feed?includeQa=true` does not expose QA rows in Production.
- Verify `/health` reports `templates_content` healthy.
