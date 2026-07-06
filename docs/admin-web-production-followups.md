# Admin Web Production Follow-ups

This file tracks admin-panel production gaps that cannot be fully closed in the
frontend without a backend contract change.

## Running-job cancellation action

Current frontend state:

- The admin generation history page uses server-side pagination and filters via
  `GET /api/admin/templates/generations?status=&provider=&user=&search=&skip=&take=`.
- Job ids, user ids, provider/model labels, and failure codes are sanitized
  before display.
- Queued generation cancellation is wired through
  `POST /api/admin/templates/generations/{generationId}/cancel` and is shown
  only when the backend row returns `canCancel=true`.
- Safe full generation retry is wired through
  `POST /api/admin/templates/generations/{generationId}/retry` and is shown only
  when the backend row returns `canRetry=true`. The backend only requeues
  failed/cancelled jobs when the original charge has not been refunded, and it
  rejects refunded, active, completed, or otherwise unsafe jobs.
- Refund retry is wired through the backend refund-only action
  `POST /api/admin/templates/generations/{generationId}/retry-refund`.
- Running/provider cancellation remains hidden because the worker/provider layer
  does not yet expose a safe provider-aware cancellation contract.

Production risk:

- Showing frontend-only running-cancel controls would create false operator
  affordances and could encourage unsafe state changes.
- Running cancellation needs provider-aware cancellation, idempotency
  protection, state-transition validation, refund handling, and audit logging.

Required backend contract:

- Extend cancellation only if the worker can safely stop running/provider jobs.
- Return the updated generation row or a small action result with the final job
  status.
- Enforce valid transitions server-side: cancel only running/retrying jobs that
  the worker/provider can stop safely.
- Write audit log entries with actor, target generation id, old/new status,
  correlation id, IP address, and user agent.

Frontend completion after backend change:

- Add Admin-only running-cancel controls with confirmation modals, disabled
  loading state, double-submit protection, and success/error notifications.
- Invalidate only the affected generation page and dashboard metrics after a
  successful action.
- Keep Moderator access denied and continue hiding signed URLs, provider
  payloads, API keys, and raw worker/provider responses.
