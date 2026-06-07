# Admin Web Production Follow-ups

This file tracks admin-panel production gaps that cannot be fully closed in the
frontend without a backend contract change.

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

## Support queue priority, sort, and waiting filters

Current frontend state:

- Support inbox calls pass backend-supported `status`, `assignment`, `search`,
  `page`, and `pageSize` query params.
- Exact status, archive, and unassigned filters are wired through those backend
  params.
- The UI no longer exposes priority or alternate sort controls as global queue
  filters because the current support inbox endpoint does not accept `priority`
  or `sort`.
- The UI no longer exposes the composite "waiting" quick filter because it would
  require `New OR WaitingForUser`, while the current backend contract accepts
  only one `status` value.

Production risk:

- Reintroducing priority/sort as browser-only filters would make operators see
  a filtered current page rather than an authoritative filtered queue.
- Reintroducing the waiting quick filter before backend multi-status support
  would make operators see a filtered current page rather than the authoritative
  queue.

Required backend contract:

- Add `priority`, `sort`, and multi-status support to
  `GET /api/admin/support/tickets`, for example:
  `?status=New&status=WaitingForUser&priority=High&sort=priority&page=&pageSize=`.
- Preserve existing `assignment`, `search`, `page`, and `pageSize` semantics.
- Continue returning the current paged response object (`items`, `page`,
  `pageSize`, `totalCount`, `hasMore`) so filter totals and page controls remain
  authoritative.

Frontend completion after backend change:

- Re-enable priority and sort controls by passing backend query params through
  `fetchSupportInbox` and React Query keys.
- Re-enable the waiting quick filter only as a multi-status backend query.
