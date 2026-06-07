# Admin Web Production Follow-ups

This file tracks admin-panel production gaps that cannot be fully closed in the
frontend without a backend contract change.

## Promo code registry pagination

Current frontend state:

- `apps/admin-web` calls `GET /api/admin/economy/redeem-codes`.
- The endpoint returns the full promo-code registry as an array.
- The UI applies search, status filters, sorting, CSV scope, and page slicing in
  the browser.
- Promo-code activations already use backend pagination through
  `GET /api/admin/economy/redeem-codes/{id}/activations?skip=&take=`.

Production risk:

- A large promo-code registry can increase payload size, slow down first render,
  and make browser-side filtering inconsistent with the rest of admin tables.

Required backend contract:

- Add server-side search, filter, sort, and pagination to the promo-code registry:
  `GET /api/admin/economy/redeem-codes?search=&status=&rewardKind=&skip=&take=&sort=`.
- Return `items`, `totalCount`, `skip`, `take`, and `hasMore`.
- Keep CSV export behavior explicit: either export the current filtered page from
  the UI or provide a backend export endpoint for the full filtered result set.

Frontend completion after backend change:

- Replace the browser-side `filteredCodes.slice(...)` paging in
  `PromoCodesView` with backend query params and React Query cache keys.
- Keep debounce and `AbortSignal` behavior consistent with users, generations,
  moderation, and economy purchases/subscriptions.

## Template catalog pagination

Current frontend state:

- Template catalog screens call `GET /api/admin/templates?templateType=...` and
  receive the full template list as an array.
- Search, archive/category/access/status filters, and sorting are applied in the
  browser.
- Catalog analytics rows are hydrated from
  `GET /api/admin/templates/analytics?templateType=...&sort=updated&take=500`.

Production risk:

- Large template catalogs can make the catalog route expensive to load and can
  leave analytics rows incomplete after the first 500 templates.
- Browser-side filtering can diverge from backend semantics when archived
  templates, categories, or access rules change.

Required backend contract:

- Add server-side search, filter, sort, and pagination to template catalog:
  `GET /api/admin/templates?templateType=&search=&category=&status=&access=&archive=&skip=&take=&sort=`.
- Return `items`, `totalCount`, `skip`, `take`, and `hasMore`.
- Add matching pagination or a keyed map endpoint for catalog analytics rows so
  the UI can request analytics for the currently visible template ids.

Frontend completion after backend change:

- Replace browser-side catalog filtering/paging with backend query params.
- Keep the current secure blob-media rendering and action confirmations.
- Invalidate only the affected catalog page/template analytics rows after
  status/archive/delete actions.

## Template media update keep semantics

Current frontend state:

- Template editor screens fetch existing `previewAsset.url` and
  `referenceMotionAsset.url` from `GET /api/admin/templates/{id}`.
- The UI does not render those backend media URLs directly in `<img>`, `<video>`,
  `<a>`, or editable input values; media is fetched through `TemplateSecureMedia`
  and rendered as a blob URL.
- Existing asset URLs still have to remain in the internal form payload on `PUT`
  because the current backend update command treats `PreviewAsset = null` or
  `ReferenceMotionAsset = null` as an explicit asset removal.

Production risk:

- Presigned or otherwise sensitive asset URLs make an unnecessary round-trip back
  to the backend when an Admin saves unrelated template metadata without changing
  media.

Required backend contract:

- Add patch/keep semantics for template media updates, for example asset ids or
  explicit `keepPreviewAsset` / `keepReferenceMotionAsset` flags.
- Alternatively split media replacement/removal into dedicated Admin endpoints
  and make template metadata updates leave existing assets untouched.

Frontend completion after backend change:

- Keep existing media readiness and preview behavior, but remove persisted media
  URLs from editable form state and from template metadata update payloads unless
  a newly uploaded asset is being attached.
- Keep clear/remove media actions explicit and confirmation-backed for active
  templates.

## Generation retry and cancellation actions

Current frontend state:

- The admin generation history page uses server-side pagination and filters via
  `GET /api/admin/templates/generations?status=&provider=&user=&search=&skip=&take=`.
- Job ids, user ids, provider/model labels, and failure codes are sanitized
  before display.
- Retry/cancel actions are intentionally hidden because the backend currently
  does not expose admin retry/cancel endpoints for generation jobs.

Production risk:

- Showing frontend-only retry/cancel controls would create false operator
  affordances and could encourage unsafe duplicate-job behavior.
- Retry and cancellation need backend authorization, idempotency protection,
  state-transition validation, and audit logging.

Required backend contract:

- Add Admin-only endpoints such as
  `POST /api/admin/templates/generations/{generationId}/retry` and
  `POST /api/admin/templates/generations/{generationId}/cancel`.
- Return the updated generation row or a small action result with the final job
  status.
- Enforce valid transitions server-side: retry only failed/cancelled/exhausted
  jobs as supported by the worker, cancel only pending/running/retrying jobs
  that the worker can stop safely.
- Make retry idempotent for repeated admin clicks and reject duplicate active
  jobs.
- Write audit log entries with actor, target generation id, old/new status,
  correlation id, IP address, and user agent.

Frontend completion after backend change:

- Add Admin-only retry/cancel controls with confirmation modals, disabled
  loading state, double-submit protection, and success/error notifications.
- Invalidate only the affected generation page and dashboard metrics after a
  successful action.
- Keep Moderator access denied and continue hiding signed URLs, provider
  payloads, API keys, and raw worker/provider responses.

## Users table server-side sorting

Current frontend state:

- Users list search, role/status/premium filters, and pagination are sent to
  `GET /api/admin/users`.
- The UI no longer exposes browser-only sort controls because sorting only the
  current backend page is misleading for operators.
- Row-level last activity and subscription data are still fetched for the
  visible page to populate table cells and side panels.

Production risk:

- Reintroducing client-side sorting for `createdAt` or `lastActivity` would sort
  only the currently loaded page, not the full filtered user set.
- Last-activity sorting cannot be authoritative without a backend users query
  that joins or materializes the relevant activity timestamp.

Required backend contract:

- Add `sort` to `GET /api/admin/users`, for example:
  `?search=&role=&status=&isPremium=&skip=&take=&sort=created_desc|created_asc|last_activity_desc|last_activity_asc`.
- Return the same paged response shape with `items`, `totalCount`, `skip`,
  `take`, and `hasMore`.
- Include `lastActivityAtUtc` in each user row or sort by a backend-maintained
  activity column so the frontend does not need per-row analytics just to order
  the list.

Frontend completion after backend change:

- Re-enable sort controls by passing `sort` through `fetchUsers` and React Query
  keys.
- Keep row analytics requests only for metrics that are actually displayed, not
  for list ordering.

## Support queue total counts

Current frontend state:

- Support inbox calls pass `page` and `pageSize` to backend search/filter
  endpoints.
- The routed conversation workspace exposes previous/next queue controls and
  sends the selected page through the backend query params.
- The UI infers `hasMore` from a full page because the inbox endpoint currently
  returns an array rather than a paged response object.

Production risk:

- Operators can browse pages, but the UI cannot display an authoritative total
  count or know that a partial page is the last page unless the backend contract
  exposes it.

Required backend contract:

- Return `items`, `page`, `pageSize`, `totalCount`, and `hasMore` for support
  inbox responses.
- Keep the current `status`, `assignment`, `search`, `page`, and `pageSize`
  query params.

Frontend completion after backend change:

- Replace the current full-page-size `hasMore` inference with backend `hasMore`.
- Display exact total counts in the support queue footer.

## Support queue priority, sort, and waiting filters

Current frontend state:

- Support inbox calls pass backend-supported `status`, `assignment`, `search`,
  `page`, and `pageSize` query params.
- Exact status, archive, and unassigned filters are wired through those backend
  params.
- The UI no longer exposes priority or alternate sort controls as global queue
  filters because the current support inbox endpoint does not accept `priority`
  or `sort`.
- The "waiting" quick filter remains a current-page convenience because it is a
  composite of `New` and `WaitingForUser`, while the current backend contract
  accepts only one `status` value.

Production risk:

- Reintroducing priority/sort as browser-only filters would make operators see
  a filtered current page rather than an authoritative filtered queue.
- The waiting quick filter can miss matching conversations that are on another
  backend page until the support inbox contract supports multi-status filtering.

Required backend contract:

- Add `priority`, `sort`, and multi-status support to
  `GET /api/admin/support/tickets`, for example:
  `?status=New&status=WaitingForUser&priority=High&sort=priority&page=&pageSize=`.
- Preserve existing `assignment`, `search`, `page`, and `pageSize` semantics.
- Return the paged response object described in "Support queue total counts" so
  filter totals and page controls remain authoritative.

Frontend completion after backend change:

- Re-enable priority and sort controls by passing backend query params through
  `fetchSupportInbox` and React Query keys.
- Replace the current waiting quick filter with a multi-status backend query.
