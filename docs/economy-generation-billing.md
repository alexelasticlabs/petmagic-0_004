# Economy generation billing

This document describes how template generation spends PawSpark tokens, how the current reconciliation safety net works, and how operators should recover inconsistent states.

## Main flow

1. Templates creates a `TemplateGenerationJob`.
2. Templates creates a `TemplateGenerationBillingCommand` in the same Templates DB save.
3. Templates persists the job and billing command together.
4. Templates settles the billing command by calling Economy billing through `ITemplateGenerationBilling.ChargeAsync`.
5. Economy records a wallet debit:
   - source: `generation_spend`
   - reason: `template_generation:{generationId:N}`
6. Templates marks the billing command `succeeded` and sets `ChargedAtUtc` in the same Templates DB save.
7. If the API process crashes after the Economy debit but before the marker save, the generation worker retries the pending/processing billing command. Economy uses the same generation reason, so the debit remains idempotent and the retry restores `ChargedAtUtc`.
8. The generation worker only processes paid user jobs.
9. If a charged job fails or is cancelled, Templates calls `RefundAsync`.
10. Economy records a wallet credit:
   - source: `generation_refund`
   - reason: `generation_refund:{generationId:N}`
   - idempotency key: `generation_refund:{generationId:N}`
11. Templates sets `RefundedAtUtc`.

## Consistency model

The write path is still cross-module: Templates and Economy use separate DbContexts. Primary reliability is handled by the durable Templates billing command:

- the job and billing command are created atomically in Templates DB;
- command processing is retryable after API/worker crashes;
- Economy charge uses the stable generation id/reason so command retries do not double debit;
- `ChargedAtUtc` is written only after the charge succeeds.

Generation billing reconciliation remains the production safety net:

- Economy owns wallet ledger truth.
- Templates owns generation job billing markers.
- `IGenerationBillingReconciliationService` lets Economy read generation billing snapshots and request marker recovery without referencing `TemplatesDbContext` directly.
- `TemplateGenerationBillingReconciliationService` implements that port in Templates infrastructure.

## Reconciliation checks

`RunEconomyReconciliationAsync` now checks:

- generation spend ledger exists, but `ChargedAtUtc` is missing;
- generation is charged, but matching spend ledger is missing;
- failed/cancelled charged generation has no refund ledger;
- refund ledger exists, but `RefundedAtUtc` is missing;
- generation is marked refunded, but refund ledger is missing;
- refund ledger exists without matching spend;
- multiple spend/refund ledger entries exist for one generation;
- active unpaid generation is older than the pending threshold.

## Incident types

| Type | Severity | Meaning | Typical action |
| --- | --- | --- | --- |
| `GenerationChargeMarkerMissing` | Critical | Wallet spend exists but Templates did not store `ChargedAtUtc`. | `restore_generation_charge_marker` or `refund_generation_spend` |
| `GenerationLedgerSpendMissing` | Critical | Templates says charged but Economy has no spend ledger. | Manual review; usually resolve marker or compensate |
| `GenerationRefundMissing` | Critical | Failed/cancelled charged generation has no refund ledger. | `refund_generation_spend` |
| `GenerationRefundMarkerMissing` | Warning | Refund ledger exists but Templates marker is missing. | `refund_generation_spend` to restore marker idempotently |
| `GenerationRefundLedgerMissing` | Critical | Templates says refunded but Economy has no refund ledger. | Manual review, then refund or fix marker |
| `GenerationRefundWithoutSpend` | Critical | Refund ledger exists without original spend. | Manual review |
| `GenerationDuplicateLedgerMutation` | Critical | More than one spend/refund ledger entry for the same generation. | Manual review |
| `GenerationBillingPendingStale` | Warning | Active generation stayed unpaid beyond threshold. | Retry reconciliation or investigate Templates worker |
| `GenerationBillingJobMissing` | Critical | Economy ledger references a missing Templates job. | Manual review and possible refund |

## Admin recovery actions

| Action | Behavior |
| --- | --- |
| `restore_generation_charge_marker` | Finds `generation_spend` ledger and sets Templates `ChargedAtUtc` to the spend timestamp. |
| `refund_generation_spend` | Credits `generation_refund:{generationId:N}` idempotently and asks Templates to mark `RefundedAtUtc`. |
| `resolve_incident` | Closes incident after operator review. |
| `reopen_incident` | Reopens a resolved incident. |

Every recovery action writes `EconomyIncidentAuditEntry` and admin audit when admin audit logging is configured.

## Operator rule

Use `restore_generation_charge_marker` when the generation job exists and should continue or be processed as paid. Use `refund_generation_spend` when the job cannot be safely recovered or the user should be compensated.

## Remaining design work

Provider sandbox validation and deployed reconciliation evidence are still required before production release. The durable command removes the known charge-marker crash window from the primary path, while reconciliation remains the audit and operator recovery layer.
