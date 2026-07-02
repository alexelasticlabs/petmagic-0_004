# API Contracts

This file records client-facing contract invariants that must stay compatible with the mobile app and admin panel.

## Error Responses

Consumers:

- Flutter mobile app.
- Next.js admin panel.

Compatibility rules:

- Client-visible API errors must use `application/problem+json` where the endpoint can return structured failures.
- ProblemDetails responses must include a stable machine-readable `title`/`code` value where available, a safe `detail` message, and diagnostic `correlationId` plus `traceId` fields for support/debugging.
- HTTP 429 rate-limit responses use title/code `RATE_LIMIT_EXCEEDED`, include `Retry-After` when the limiter provides it, and must include `correlationId` and `traceId`.
- Production 5xx responses must not expose exception messages, stack traces, secrets, provider payloads, tokens, or raw request bodies.

## Legacy Stripe Compatibility Routes

Current compatibility routes:

- `POST /api/payments/stripe/token-purchase`
- `POST /api/payments/stripe/subscription`
- `POST /api/payments/stripe/customer-portal`
- `GET /api/payments/stripe/diagnostics`
- `GET /api/economy/premium/stripe-diagnostics`

Compatibility rules:

- New mobile/admin code must use `/api/economy/purchases/create`, `/api/economy/purchases/{orderId}/verify-stripe`, premium plan/status endpoints, and admin economy endpoints instead of adding new calls to the legacy route group.
- Legacy diagnostics routes must remain `AdminOnly`; they must never expose Stripe secrets, webhook secrets, raw provider payloads, or unrestricted user data.
- These routes are kept only for migration compatibility while startup smoke tests still assert their presence. Removal requires a usage search across mobile/admin/backend tests, updating startup smoke tests, and documenting the migration window in this file.

## Public Templates Feed

Endpoint: `GET /api/templates/feed`

Consumers:

- Flutter mobile templates feed.

Query parameters:

- `type`: optional `Image`, `Video`, or `all`. `all` is equivalent to omitting the type filter.
- `category`: optional trimmed category name, backend-bounded to the public category filter limit.
- `tags`: optional repeated or comma-separated tag query parameter.
- `premiumOnly`: optional boolean.
- `search`: optional trimmed search string.
- `take`: optional page size, backend bounded.
- `cursor`: optional opaque `nextCursor` value from the previous response.
- `locale`: optional localization code.

Response shape:

- `items`: array of lightweight template feed items.
- `nextCursor`: nullable cursor string. Clients must treat it as opaque.
- `hasMore`: boolean.
- `generatedAtUtc`: UTC timestamp.

Item fields required by mobile:

- `id`: GUID string.
- `type`: `Image` or `Video`.
- `title`, `shortDescription`.
- `category`: object with nullable `id`, stable `slug`, and display `title`.
- `tags`: string array.
- `isPremium`: boolean.
- `access`: `free` or `premium`.
- `thumbnailUrl`: nullable static image URL for immediate card paint.
- `media`: lightweight feed media object:
  - `thumbnailUrl`: static image for placeholders and first paint.
  - `animatedPreviewUrl`: cheap animated image/loop for many visible cards.
  - `feedLoopLowUrl`: low-bitrate muted loop for feed playback.
  - `feedLoopMediumUrl`: medium-bitrate muted loop reserved for adaptive playback.
  - `mediaKind`: `image` or `video`.
  - `aspectRatio`, `durationMs`, `sizeBytes`, `dominantColor`, `blurHash`: nullable rendering/cache hints.
  - `mediaVersion`: integer cache invalidation stamp.
- `mediaKind`, `aspectRatio`, `durationMs`, `sizeBytes`: top-level card hints mirroring the selected feed media.
- `version`: integer catalog version for the item.
- `mediaVersion`: integer media cache invalidation stamp.

Compatibility rules:

- Do not rename or remove any listed field without updating `apps/petmagic-mobile` DTOs/tests.
- Feed items must stay bounded for card rendering. They must not expose prompts, generation parameters, pet photo requirements, admin/audit fields, detail media, original/source media, reference motion assets, status/promo internals, provider cost estimates, raw assets collections, deleted timestamps, create timestamps, or `updatedAtUtc`. Fetch `GET /api/templates/{id}` for `TemplateDetailDto` when preview/detail data is needed.
- `TemplateDetailDto` may include `detailPreviewUrl` inside its `media` object; this field must not appear in `/api/templates/feed`.
- `AdminTemplateDto` is a separate admin contract and may include all media variants plus source/reference assets for moderation and CRUD.
- Invalid non-empty `type` values must return HTTP 400 problem details with `templates.invalid_type`; unknown or numeric values must not fall back to the full feed. `type=all` must remain accepted.
- Invalid non-empty cursors must return HTTP 400 problem details with `templates.invalid_cursor`.
- Backend-emitted cursors include `PublishedAtUtc` ticks plus template id. Legacy timestamp/version/template-id cursors remain accepted as opaque compatibility input, but clients must not parse either format.
- Public feed ordering is stable public ranking, not technical edit time: `PublishedAtUtc DESC, Id DESC`. `PublishedAtUtc` is set once on first public activation and is not rewritten by title, description, media, prompt, or metadata edits. Existing active templates are backfilled once from `CreatedAtUtc`; inactive/draft templates keep it null until first activation.
- Search/category filters are backend-bounded to public field limits. Tag filters must stay within the public tag count and length bounds; out-of-bounds tag filters must not broaden the feed. Archived categories are hidden from `/api/templates/categories` and explicit category filters, but active templates assigned to an archived category remain available in unfiltered public feed, catalog/search, random, detail, template-of-the-day, and user-started generation flows.
- Normal public feed responses must include only production-visible templates: active, non-deleted, and `IsQaOnly=false`. QA/local/failing/smoke templates must stay hidden unless a non-production admin QA request explicitly opts in.
- Feed queries must stay bounded and must not require authentication.

### Template Visibility Policy Bypass Allowlist

Direct checks of template active/deleted state outside `TemplateVisibilityPolicy` are allowed only for non-public operational/admin contexts that are documented here and marked in source with `TemplateVisibilityPolicy direct-check allowlist`.

- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateCategoryAdminService.cs`: admin category diagnostics inspect active, non-deleted rows to report noncanonical category data; this is not a public feed/detail/generation visibility decision.
- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateGenerationQaFixtureService.cs`: non-production QA fixture generation selects active, non-deleted seed candidates outside public traffic.
- `src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateContentHealthCheck.cs`: operational content health probes active, non-deleted production templates without request/user visibility context.

Any new direct `Status == Active` or `DeletedAtUtc == null` check in templates public/generation code must either move into `TemplateVisibilityPolicy` or be added to this allowlist with a source comment and a source-contract test update.

### Admin Template Bulk Operations

The current admin template API exposes single-template status/media/content mutations only. There is no bulk template status/update endpoint, so SSE batching for bulk template operations is not applicable yet. If a bulk endpoint is introduced, it must include a batching test proving that N affected templates do not emit N independent full-feed reload signals.

## Generation Media URLs

Consumers:

- Flutter mobile generation status, gallery/history, download/share/remove-watermark flows.
- Next.js admin generation list and user analytics.

Compatibility rules:

- Template preview/reference assets are stable public catalog media.
- User uploads, normalized images, generated results, watermarked results, input previews, and result previews are private generation media.
- Client/admin generation media fields must be produced through storage read-url signing and treated as short-lived.
- If read-url signing fails, APIs must return `null` for that media field instead of exposing raw storage keys, provider URLs, or stale public URLs.
- Completed generation responses must use imported managed storage for `outputUrl`/`mediaUrl`; provider result URLs are not a final user-facing contract.

## Public Random Template

Endpoint: `GET /api/templates/random`

Consumers:

- Flutter mobile random template action.

Query parameters:

- `type`: optional `Image`, `Video`, or `all`. `all` is equivalent to omitting the type filter.
- `category`: optional trimmed category name, backend-bounded to the public category filter limit.
- `includePremium`: optional boolean. When `false`, premium templates must be excluded.
- `locale`: optional localization code.

Response shape:

- `template`: nullable public template list item. Unlike the feed item, this includes generation-flow fields needed to open a template directly.

Compatibility rules:

- Random selection must be evaluated on the backend from active, non-deleted templates with usable preview media; mobile must not need a synced local catalog to choose a random template.
- Category, type, premium availability, and active/deleted status filters must be applied before random selection.
- Category filter normalization must stay aligned with public feed/catalog semantics.
- Empty result sets must return HTTP 200 with `template: null`.
- Invalid non-empty `type` values must return HTTP 400 problem details with `templates.invalid_type`; `type=all` must remain accepted.

## Public Templates Catalog

Endpoint: `GET /api/templates?page={page}&pageSize={pageSize}`

Consumers:

- Flutter mobile catalog bootstrap and legacy paged clients.

Query parameters:

- `page`: optional one-based page number, backend bounded to at least `1`.
- `pageSize`: optional page size, backend bounded.
- `type`: optional `Image`, `Video`, or `all`. `all` is equivalent to omitting the type filter.
- `category`: optional trimmed category name.
- `tags`: optional repeated or comma-separated tag query parameter. Paged catalog must apply the same tag semantics as the unpaged public list/feed.
- `premiumOnly`: optional boolean. When `true`, only premium templates are returned.
- `locale`: optional localization code.

Response shape:

- `items`: array of versioned template catalog metadata.
- `page`: normalized one-based page number.
- `pageSize`: normalized page size.
- `hasMore`: boolean.
- `totalCount`: total count after filters.
- `generatedAtUtc`: UTC timestamp.

Compatibility rules:

- Paged catalog filters must stay aligned with accepted HTTP query parameters; do not accept a query parameter and silently ignore it.
- Invalid non-empty `type` values must return HTTP 400 problem details with `templates.invalid_type`; unknown or numeric values must not fall back to the full catalog. `type=all` must remain accepted.
- Search/category/tag normalization must match public feed semantics; out-of-bounds tag filters must not broaden catalog results.
- Metadata items must keep `id`, `title`, `category`, `type`, `thumbnailUrl`, `previewUrl`, `priceTokens`, `isPremium`, `tags`, `version`, and `updatedAtUtc` stable unless mobile DTOs/tests are updated.
- Mobile full-catalog bootstrap/resync must use this paged catalog endpoint, not `/api/templates/feed`, because paged catalog remains the complete versioned metadata source even though feed also carries item version stamps for visible cards.
- Paged catalog queries must stay bounded and must not require authentication.

## Public Template of the Day

Endpoint: `GET /api/templates/template-of-the-day`

Consumers:

- Flutter mobile templates page featured slot.

Query parameters:

- `date`: optional `yyyy-MM-dd` business date. Missing date resolves on the backend using the configured Template of the Day timezone.
- `locale`: optional localization code.

Response shape:

- `template`: nullable featured template object.

Template fields required by mobile:

- `templateId`: GUID string.
- `title`, `subtitle`, `badgeText`.
- `type`: `Image` or `Video`.
- `thumbnailUrl`: nullable string.
- `previewMediaUrl`: nullable string.
- `isPremium`: boolean.
- `requiredPlan`: string, currently `free` or `premium`.
- `date`: `yyyy-MM-dd` date string.
- `source`: `manual` or `auto`.

Compatibility rules:

- Empty schedules must return HTTP 200 with `template: null`.
- The response must stay lightweight; mobile loads full template detail separately before opening the generation flow when needed.
- `date` must remain a date-only value. Do not switch it to a timestamp without updating mobile parsing/tests.

## Admin Templates

Endpoint family: `/api/admin/templates`

Consumers:

- Next.js admin panel.

Compatibility rules:

- Admin list endpoints must support backend pagination with `skip`, `take`, `totalCount`, and `hasMore`.
- Invalid non-empty catalog filters must fail fast with HTTP 400 ProblemDetails: `templates.invalid_type`, `templates.invalid_status`, `templates.invalid_access`, or `templates.invalid_sort`. Numeric enum values must not fall back to the full catalog.
- Recent generation history defaults must stay bounded when `take` is omitted.
- Template status, type, promo badge, asset, and analytics field names must stay aligned with `apps/admin-web/src/lib/api-client.types.ts`.
- Admin endpoints must keep `ModeratorOrAdmin` or stricter authorization policies according to route intent.
- `GET /api/admin/templates/categories/diagnostics` is `AdminOnly` and reports active templates whose string category no longer maps to a non-archived canonical category.

## Template Generation History

Endpoint family:

- `GET /api/templates/generations`
- `GET /api/templates/generations/{generationId}`
- `GET /api/generations/{generationId}`

Consumers:

- Flutter mobile generation history, generation status, gallery, and before/after compare flows.

Compatibility rules:

- History query parameters `status`, `skip`, and `take` must remain optional and backend-bounded. `take` must never allow unbounded history loads.
- List ordering must stay stable by `createdAtUtc desc, generationId desc`.
- Response items must keep `generationId`, `userId`, `templateId`, `status`, `tokenCost`, `sourceImageAsset`, `outputUrl`, `mediaUrl`, `templateTitle`, `templateType`, `stage`, `progressPercent`, `queuePosition`, `estimatedWaitSeconds`, `hasWatermark`, `canRemoveWatermark`, `isWatermarkRemoved`, `supportsGenerateSimilar`, `inputSourceType`, `inputMediaAssetId`, `resultMediaAssetId`, `inputPreviewUrl`, `resultPreviewUrl`, and `canCompareBeforeAfter`.
- Response `status` is a public string contract, not a numeric enum. Current wire values include `Queued`, `ProviderQueued`, `ProviderProcessing`, `ImportingMedia`, `Completed`, `Failed`, and `Cancelled`; clients must never receive numeric enum values such as `"8"`, `"9"`, or `"10"` for provider queue/import stages.
- Completed image generations with available input and result previews must return `canCompareBeforeAfter=true` plus both preview URLs. Mobile treats these fields as optional but uses them when present.
- Compare preview lookup for history must stay batched; do not add per-generation database queries for `TemplateMediaRecords` or `PetPhotos`.
- Legacy `/api/generations/{generationId}` aliases must remain compatible until the mobile app fully migrates to `/api/templates/generations/{generationId}`.

## Feedback

Endpoint: `POST /api/feedback`

Consumers:

- Flutter mobile generation result, bug report, feature request, payment issue, and general feedback flows.

Request body:

- `type`: required string. Supported values are `GenerationResult`, `GenerationFailure`, `BugReport`, `FeatureRequest`, `PaymentIssue`, and `General`; unsupported values are normalized to `General`.
- `category`: required non-empty string, backend-bounded.
- `rating`: optional integer normalized to `-1..1`.
- `message`: optional string, backend-bounded.
- `generationId`, `templateId`, `petId`: optional GUID strings. When `generationId` or `petId` is provided, backend must verify ownership for the authenticated user.
- `sourceScreen`, `appVersion`, `platform`, `deviceModel`, `locale`: optional client diagnostics strings, backend-bounded.

Response shape:

- `feedbackId`: GUID string.
- `status`: feedback workflow status, initially `New`.

Compatibility rules:

- Mobile sends JSON field names in camelCase; backend must keep accepting the current field names.
- Validation/ownership failures must return ProblemDetails, not successful no-op responses.
- Known failure titles include `templates.invalid_subject`, `GENERATION_JOB_NOT_FOUND`, `feedback.forbidden`, and `feedback.rate_limited`.
- Mobile feedback submission is non-idempotent and clients must not retry transient failures automatically unless a future idempotency key is introduced.

## Admin Feedback

Endpoint family:

- `GET /api/admin/feedback`
- `GET /api/admin/feedback/{feedbackId}`
- `PUT /api/admin/feedback/{feedbackId}`
- `POST /api/admin/feedback/{feedbackId}/refund`
- `GET /api/admin/templates/{templateId}/feedback-summary`

Consumers:

- Next.js admin feedback page and template analytics surfaces.

Compatibility rules:

- Admin feedback endpoints must require `ModeratorOrAdmin`; credit refunds must require `AdminOnly`.
- List responses keep `items`, `totalCount`, `skip`, `take`, `hasMore`, and `generatedAtUtc`.
- Status values are `New`, `InReview`, `Resolved`, and `Dismissed`.
- Priority values are `Low`, `Medium`, `High`, and `Critical`.
- Invalid admin `status`, `priority`, or `type` filter/update values must return HTTP 400 ProblemDetails with `feedback.invalid_status`, `feedback.invalid_priority`, or `feedback.invalid_type`; they must not silently fall back to another filter value.
- List and summary queries must stay backend-bounded and use database-side filtering/aggregation rather than unbounded row materialization.
- Template feedback summary keeps `positiveCount`, `neutralCount`, `negativeCount`, `positiveRate`, `neutralRate`, `negativeRate`, `topIssues`, and `hasNegativeWarning`.

## Pets

Endpoint family: `/api/pets`

Consumers:

- Flutter mobile pet profiles, pet photos, and pet-based generation flows.

Compatibility rules:

- `GET /api/pets` returns the existing array contract. Items must keep `id`, `userId`, `name`, `type`, `breed`, `avatarMediaAssetId`, `avatarUrl`, `photosCount`, `generationsCount`, `status`, `createdAtUtc`, `updatedAtUtc`, and `isDeleted`.
- `POST /api/pets` and `PUT /api/pets/{petId}` require `name` and `type`; missing, null, or unsupported `type` must return HTTP 400 validation problem instead of HTTP 500.
- Pet photo and pet generation list endpoints must stay bounded and must not expose deleted user media to non-admin mobile clients.
- `POST /api/generations/from-pet` accepts `petId`, optional `petPhotoId`, and `templateId`. Mobile sends `Idempotency-Key`; backend must trim it, reject values over 256 characters with HTTP 400 validation problem, and must not silently truncate overlong keys.

## Admin Users

Endpoint family: `/api/admin/users`

Consumers:

- Next.js admin users page and user detail page.

Compatibility rules:

- List endpoints must support backend pagination with `skip`, `take`, `items`, `totalCount`, and `hasMore`; `take` must remain backend-bounded.
- Role filters accept `Admin`, `Moderator`, and `User`; backend and admin-web canonicalize casing before querying.
- Status filters accept `active`, `blocked`, and `unconfirmed`; backend and admin-web canonicalize casing before querying.
- Role mutation payloads keep the `{ "role": "Admin" | "Moderator" }` shape for admin panel actions. Clients may trim/canonicalize before sending, and backend must protect direct API calls by canonicalizing supported role casing before validation/service execution.
- Active-status mutations use `PUT /api/admin/users/{userId}/active` with `{ "isActive": boolean }`, return 204 on success, and must keep last-admin protection instead of allowing an admin lockout.
- Admin user mutations return 404 ProblemDetails for missing users and 409 ProblemDetails with `users.cannot_remove_last_admin` when a role revoke, block, or delete would remove the last active admin.
- Dashboard metrics must use database-side aggregation and must not materialize all users or all user-role rows just to compute counters.
- Admin user endpoints must require `ModeratorOrAdmin`; wallet, role, premium, active-status, delete, and bulk-email mutations must require `AdminOnly`.

## Admin User Pets

Endpoint family: `/api/admin/users/{userId}/pets`

Consumers:

- Next.js admin user detail page.

Compatibility rules:

- Admin pet endpoints must require `ModeratorOrAdmin`.
- `GET /api/admin/users/{userId}/pets` keeps the current array response for client compatibility, but backend service failures must return ProblemDetails instead of a successful empty array.
- Admin pet/photo status values are `active`, `hidden`, `flagged`, or `deleted`; invalid values must return ProblemDetails with the backend error code.

## Admin Economy

Endpoint family:

- `/api/admin/economy/ledger`
- `/api/admin/economy/purchases`
- `/api/admin/economy/subscriptions`
- `/api/admin/economy/subscription-events`

Consumers:

- Next.js admin economy page.

Compatibility rules:

- List endpoints must support backend pagination with `skip`, `take`, `items`, and `hasMore`; `take` must remain backend-bounded.
- Admin-web sends purchase status filters in lowercase: `pending`, `succeeded`, `failed`, and `refunded`.
- Admin-web sends subscription and subscription-event status filters in lowercase/snake-case: `active`, `trialing`, `past_due`, `canceled`, `expired`, `processed`, and `failed`.
- Backend may store subscription status values in canonical PascalCase such as `Active`, `Trialing`, `GracePeriod`, `PastDue`, `Canceled`, `Expired`, `Processed`, and `Failed`; read filters must normalize the client value to the stored value before querying.
- Provider filters must stay aligned with `stripe`, `app_store`, and `google_play`.
- Invalid non-empty purchase status filters must fail fast with HTTP 400 ProblemDetails title `economy.purchase_status_invalid`; accepted values are `pending`, `succeeded`, `failed`, and `refunded`.
- Invalid non-empty subscription status filters must fail fast with HTTP 400 ProblemDetails title `economy.subscription_status_invalid`; accepted admin values include `active`, `trialing`, `past_due`, `canceled`, and `expired`.
- Invalid non-empty subscription-event status filters must fail fast with HTTP 400 ProblemDetails title `economy.subscription_event_status_invalid`; accepted admin values include `active`, `canceled`, `expired`, `processed`, and `failed`.
- Invalid non-empty provider filters must fail fast with HTTP 400 ProblemDetails title `economy.payment_provider_invalid`; accepted values are `stripe`, `app_store`, and `google_play`.
- Read responses must not expose provider secrets, customer secrets, webhook payload JSON, or full external transaction tokens.

## Admin Promo Codes

Endpoint family: `/api/admin/economy/redeem-codes`

Consumers:

- Next.js admin promo codes page.

Compatibility rules:

- List and metrics endpoints must apply search, reward kind, status, sorting, and pagination on the backend.
- Status filters must be SQL-prefiltered before materialization and then validated with shared status semantics.
- Invalid non-empty filters must fail fast with HTTP 400 ProblemDetails: `economy.redeem_code_status_invalid`, `economy.redeem_code_reward_kind_invalid`, or `economy.redeem_code_sort_invalid`.
- Accepted status filters are `all`, `draft`, `scheduled`, `active`, `paused`, `exhausted`, `expired`, and `archived`; accepted reward filters are `all` and `spark`; accepted sort modes are `updated`, `usage`, `reward`, `code`, and `expiry`.
- Activation history must stay paged independently from the list response.

## Admin Support Inbox

Endpoint: `GET /api/admin/support/tickets`

Consumers:

- Next.js admin support workspace.

Query parameters:

- `status`: optional, repeatable. Single-status clients may keep sending one `status`; multi-status clients may send `status=New&status=WaitingForUser`.
- `assignment`: optional `all`, `mine`, or `unassigned`.
- `assignedTo`: optional admin user GUID for direct assignment filtering.
- `source`: optional `MobileChat` or `MobileAssistant`.
- `priority`: optional `Low`, `Normal`, or `High`.
- `search`: optional trimmed text, backend-bounded by the admin client.
- `sort`: optional `default`, `priority`, `waiting`, `updated`, or `created`.
- `page`: optional one-based page number.
- `pageSize`: optional page size. Missing or non-positive values normalize to `50`; positive values are backend-bounded to `1..100`.

Response shape:

- `items`: array of support conversation summaries.
- `page`: normalized one-based page number.
- `pageSize`: normalized page size.
- `totalCount`: total count after filters.
- `hasMore`: boolean.

Compatibility rules:

- Preserve the current paged response object so admin pagination and queue counters stay authoritative.
- Repeatable `status` support must remain backward compatible with single `status`.
- Invalid filter values must return problem details with field-specific titles: `support.status_invalid`, `support.assignment_invalid`, `support.source_invalid`, `support.priority_invalid`, or `support.sort_invalid`.
- Numeric enum values such as `status=1`, `source=1`, or `priority=1` must not be accepted; clients must send named values and receive HTTP 400 ProblemDetails for numeric values.
- Extremely large but syntactically valid `page` values must not overflow backend offset calculation; return an empty page with the normalized `page`, `pageSize`, `totalCount`, and `hasMore=false`.
- Admin support endpoints must require `ModeratorOrAdmin`.

## Support Conversation Messages

Endpoint family:

- `GET /api/support/conversation`
- `GET /api/admin/support/tickets/{conversationId}`

Consumers:

- Flutter mobile support chat.
- Next.js admin support workspace.

Query parameters:

- `take`: optional message page size, backend bounded.
- `beforeMessageCreatedAtUtc`: optional UTC timestamp cursor from `oldestLoadedMessageCreatedAtUtc`.
- `beforeMessageId`: optional GUID tie-break cursor from the oldest loaded message id. New clients should send it with `beforeMessageCreatedAtUtc`; old clients that send only the timestamp remain supported.

Response shape:

- Existing `SupportConversationDetailResponse` fields must remain stable.
- `messages`: bounded array ordered oldest-to-newest for display.
- `hasOlderMessages`: boolean.
- `oldestLoadedMessageCreatedAtUtc`: nullable UTC timestamp for the oldest returned message.

Compatibility rules:

- Do not remove timestamp-only pagination support without updating mobile and admin clients.
- `beforeMessageId` is additive and optional; adding it must not change responses for clients that omit it.
- Message pagination must remain stable by `createdAtUtc` plus message id tie-break and must avoid unbounded message loads.

## Support Attachment Messages

Endpoint family:

- `POST /api/support/conversation/{conversationId}/attachments`
- `POST /api/admin/support/tickets/{conversationId}/attachments`
- `POST /api/support/conversation/{conversationId}/messages/attachments`
- `POST /api/admin/support/tickets/{conversationId}/messages/attachments`

Consumers:

- Flutter mobile support chat.
- Next.js admin support workspace.

Compatibility rules:

- Legacy single-file endpoints use multipart field `file`; batch endpoints use multipart field `files`.
- Multipart field `files` is required and bounded to 1..5 files per message.
- Multipart field `body` is optional but must be at most 4000 characters.
- Multipart field `replyToMessageId` is optional, but non-empty values must be valid GUIDs.
- Invalid cheap form fields must return HTTP 400 validation problem before backend creates attachment messages or stores uploaded files.
- Successful responses keep the existing `SupportMessageResponse` shape with `attachments`, `attachmentUploadStatus`, and legacy first-attachment fields.

## Secrets And Configuration

Rules:

- Real Stripe, FAL, Cloudflare R2, JWT, SMTP, Apple, Google, Firebase, database, and signing credentials must stay out of tracked frontend/mobile/admin files.
- Client Firebase config files in this repository are placeholders only.
- Tracked mobile client config must use placeholders for Google OAuth client ids and reversed iOS URL schemes; real per-environment values are injected outside the repository.
- Server-only secrets belong in backend/server-side environment variables, CI/CD secrets, platform configuration, or a managed secret store.
- Production startup must reject unsafe placeholder/default backend secrets.
- Non-development startup must reject `NEXT_PUBLIC_*` variables whose suffix matches a server-only secret name such as Stripe secret/webhook keys, FAL API keys, R2 access/secret keys, JWT signing keys, bootstrap admin passwords, OAuth client secrets, store private keys, Firebase service account payloads, or App Store shared secrets.
- Public admin/mobile configuration may expose only client-safe values such as API base URLs; never mirror backend secret names with a `NEXT_PUBLIC_` prefix.
- Non-development media base URLs returned in API responses for avatars, support attachments, template media, and R2/CDN assets must be configured as HTTPS public URLs and must not point to localhost, loopback, or unspecified hosts, and must not contain credentials, query strings, or fragments.
