# API Contracts

This file records client-facing contract invariants that must stay compatible with the mobile app and admin panel.

## Public Templates Feed

Endpoint: `GET /api/templates/feed`

Consumers:
- Flutter mobile templates feed.

Query parameters:
- `type`: optional `Image` or `Video`.
- `category`: optional trimmed category name.
- `tags`: optional comma-separated tag list.
- `premiumOnly`: optional boolean.
- `search`: optional trimmed search string.
- `take`: optional page size, backend bounded.
- `cursor`: optional opaque `nextCursor` value from the previous response.
- `locale`: optional localization code.

Response shape:
- `items`: array of template list items.
- `nextCursor`: nullable cursor string. Clients must treat it as opaque.
- `hasMore`: boolean.
- `generatedAtUtc`: UTC timestamp.

Item fields required by mobile:
- `templateId`: GUID string.
- `templateType`: `Image` or `Video`.
- `title`, `shortDescription`, `category`.
- `effectivePromoBadge`: nullable string.
- `tags`: string array.
- `isPremium`: boolean.
- `tokenCost`: integer.
- `previewAsset`: nullable object with `url`, `fileName`, `contentType`, optional `fileSizeBytes`, optional `durationSeconds`.
- `musicDescription`: nullable string.
- `referenceVideoDurationSeconds`: nullable number.
- `petPhotoRequirements`: nullable string array.

Compatibility rules:
- Do not rename or remove any listed field without updating `apps/petmagic-mobile` DTOs/tests.
- Invalid non-empty `type` values must return HTTP 400 problem details with `templates.invalid_type`; unknown or numeric values must not fall back to the full feed.
- Invalid non-empty cursors must return HTTP 400 problem details with `templates.invalid_cursor`.
- Feed queries must stay bounded and must not require authentication.

## Public Templates Catalog

Endpoint: `GET /api/templates?page={page}&pageSize={pageSize}`

Consumers:
- Flutter mobile catalog bootstrap and legacy paged clients.

Query parameters:
- `page`: optional one-based page number, backend bounded to at least `1`.
- `pageSize`: optional page size, backend bounded.
- `type`: optional `Image` or `Video`.
- `category`: optional trimmed category name.
- `tags`: optional repeated tag query parameter. Paged catalog must apply the same tag semantics as the unpaged public list/feed.
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
- Invalid non-empty `type` values must return HTTP 400 problem details with `templates.invalid_type`; unknown or numeric values must not fall back to the full catalog.
- Metadata items must keep `id`, `title`, `category`, `type`, `thumbnailUrl`, `previewUrl`, `priceTokens`, `isPremium`, `tags`, `version`, and `updatedAtUtc` stable unless mobile DTOs/tests are updated.
- Paged catalog queries must stay bounded and must not require authentication.

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

## Admin User Pets

Endpoint family: `/api/admin/users/{userId}/pets`

Consumers:
- Next.js admin user detail page.

Compatibility rules:
- Admin pet endpoints must require `ModeratorOrAdmin`.
- `GET /api/admin/users/{userId}/pets` keeps the current array response for client compatibility, but backend service failures must return ProblemDetails instead of a successful empty array.
- Admin pet/photo status values are `active`, `hidden`, `flagged`, or `deleted`; invalid values must return ProblemDetails with the backend error code.

## Admin Promo Codes

Endpoint family: `/api/admin/economy/redeem-codes`

Consumers:
- Next.js admin promo codes page.

Compatibility rules:
- List and metrics endpoints must apply search, reward kind, status, sorting, and pagination on the backend.
- Status filters must be SQL-prefiltered before materialization and then validated with shared status semantics.
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
- `pageSize`: optional page size, backend bounded to `1..100`.

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
- Server-only secrets belong in backend/server-side environment variables, CI/CD secrets, platform configuration, or a managed secret store.
- Production startup must reject unsafe placeholder/default backend secrets.
