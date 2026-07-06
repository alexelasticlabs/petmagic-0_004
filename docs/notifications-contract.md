# Notifications contract

This document defines the current push notification payloads and mobile routing behavior.

## General rules

- Backend sends FCM data payloads.
- Mobile accepts only internal safe routes from `NotificationCoordinator`.
- External schemes, query strings and fragments are rejected.
- `dedupe_key` is used to suppress duplicate foreground UI messages.
- Template generation has persistent unread state through generation history.
- Wallet, premium and support notifications are currently transient-only; state is recovered by opening the target screen.

## Payloads

| Type | Sender | Required data | Route | Persistence |
| --- | --- | --- | --- | --- |
| `template_generation` | `FcmTemplateGenerationPushNotificationSender` | `type`, `generationId`, `status`, `route`, `dedupe_key` | `/generations/{generationId}` | Generation history unread/read |
| `wallet` | `FcmEconomyPushNotificationSender` | `type`, `status`, `route`, `dedupe_key` | `/profile/wallet` | Transient-only |
| `premium` | `FcmEconomyPushNotificationSender` | `type`, `status`, `route`, `dedupe_key`, optional `provider`, `planId` | `/profile` | Transient-only |
| `support_chat` | `FcmSupportChatPushNotificationSender` | `type`, `conversationId`, `route`, `dedupe_key` | `/profile/support` | Transient-only |

## Route allowlist

Mobile allows app routes such as:

- `/templates`
- `/creations`
- `/generations/{generationId}`
- `/profile/wallet`
- `/rewards`
- `/profile`
- `/profile/support`
- premium/subscription management routes

The route parser must keep rejecting:

- absolute external URLs;
- unknown schemes;
- query/fragment injection;
- malformed generation ids.

## Localization

Backend senders own title/body selection for their module:

- template generation terminal status;
- economy wallet/premium status;
- support chat message status.

Mobile should treat payload data as routing/state hints and not as a source of business truth.

## Fallback behavior

- If FCM is not configured, backend sender returns without failing the business operation.
- If token is invalid, backend disables that token.
- If mobile cannot route immediately, bootstrap stores pending route until auth/legal state is ready.
- If a transient notification is missed, user-visible state must be fetched from `/api/economy/wallet`, `/api/economy/premium/status`, generation history or support conversation.

## Inbox decision

There is no persistent unified notification inbox for wallet, premium or support. This is intentional for the current release gate, but it must remain documented as a product limitation. If product requires notification history, add a dedicated notification entity/API/read-state instead of overloading FCM token tables.

## Test checklist

- Each sender emits stable `type`, `route` and `dedupe_key`.
- Each mobile handler accepts the intended route.
- Unsafe routes are rejected.
- Foreground duplicate messages do not produce duplicate UI.
- Missed wallet/premium/support push can be recovered by opening the target screen.
