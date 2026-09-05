# Resumable payments and push QA

Run from the repository root on Windows with Python 3.10+ and .NET 10:

```powershell
./scripts/qa/run-payments-push-qa.ps1 run --api-base-url https://api.petgpt.app --android-device R5GL64DMT6X --contract-tests --run-dir artifacts/payments-push/run-001
```

Supply the intended API origin and device serial explicitly. On Linux/macOS,
use `python3 scripts/qa/payments_push_qa.py` with the same arguments. `--adb`
overrides platform-tools discovery. The default package is the store application;
use `--package com.petmagic.app.staging` only when that is the intended target.
The runner does not install builds or change the application's API environment.
Confirm the app target and license tester account before purchasing. A Play
installer alone does not prove that purchases are sandbox transactions.

The command checks `/health`, device authorization/unlock, installed build and
installer, and runs existing backend tests for store verification, binding,
receipt replay and push outboxes. It writes `report.json`, `report.md` and contract
TRX under the selected directory. These artifacts are gitignored. Tokens, receipts,
raw notification/UI dumps and API response bodies are not written to reports.
The runner locks its report directory against concurrent writers. If a process
was killed abruptly, confirm it has exited before removing the stale `.qa.lock`.
Resume with the same directory and API origin;
use a new directory when changing the build, account or environment.

Exit 0 means the requested action completed, **not** that the full release gate
passed. Exit 2 means blocked/failed. Manual device steps remain visible, and
`strictBindingSwitchAllowed` stays false: this tool never changes production
configuration or certifies the entire store lifecycle from partial observations.

## Store purchase and replay

Use a dedicated test user. Set `PETMAGIC_QA_ACCESS_TOKEN` in the process environment
to that user's short-lived API access token, obtained through normal login. Do
not place tokens on the command line or in committed files. Use the same user
in the app. Complete a sandbox token-pack purchase in the app, including any
required system confirmation; identify its order UUID in Admin purchase history.

```powershell
./scripts/qa/run-payments-push-qa.ps1 purchase --run-dir artifacts/payments-push/run-001 --order-id ORDER_UUID
```

The command reads the owned order and all ledger pages (bounded at 10,000 entries),
requires `succeeded`, the store provider, matching ownership, and exactly one
`pack_purchase` credit equal to `sparkToGrant`. Duplicate credits, inconsistent
pagination and incomplete evidence fail closed. Other wallet activity does not
produce a false balance-delta failure.

After using the app's restore flow, run the same command with `--phase restore`.
It verifies that the original ledger entry and amount are unchanged. This proves
the backend observation, not that the native restore UI was actually exercised.

For an actual backend receipt replay, provide the original
`VerifyPackStorePurchaseRequest` JSON in a private, gitignored file:

```powershell
./scripts/qa/run-payments-push-qa.ps1 purchase --run-dir artifacts/payments-push/run-001 --order-id ORDER_UUID --phase replay --receipt-file PRIVATE_RECEIPT_JSON
```

The request fields are `paymentProvider`, `productId`, `serverVerificationData`,
`localVerificationData`, `purchaseId`, `transactionDate` (the existing API DTO).
The tool first requires an already-settled owned order, POSTs to its existing
`verify-store` endpoint, then verifies the same single credit. It cannot create
a checkout or initiate a charge. Receipts are sent only to the run's HTTPS API
origin; HTTP redirects are rejected. Delete the private receipt file after QA.
If the original receipt is unavailable, leave replay unverified; do not invent one.

## Android physical push and tap routing

Leave the selected phone unlocked and free of other users/automation. Use a
unique marker in a fresh **self-addressed test event**, such as a support test
reply whose notification includes that marker. Arrange the event through the
normal application/API flow only after the runner prints `ARMED`. The runner
does not send messages to users or re-send historical dead letters.

```powershell
./scripts/qa/run-payments-push-qa.ps1 push --run-dir artifacts/payments-push/run-001 --device-ready --lifecycle background --marker qa-push-20260905-001 --route-marker "EXPECTED DESTINATION TEXT"
```

The runner rejects an existing marker, sends the app to the background, polls
the notification shade, taps the unique matching XML node and requires the
expected destination text inside the PetMagic package. It stores only the outcome
and a marker hash. The shade is collapsed on exit. `--timeout` is 15–600 seconds.
Repeat with a new marker and `--lifecycle terminated`: it uses `am kill` after
backgrounding and checks that the process exited. It never uses `force-stop`,
which changes Android push behavior. If killing is refused, the check is blocked.
The displayed version must match the readiness report.

Foreground deduplication, locked-screen behavior, all notification kinds and iOS
delivery still need separate device acceptance. This observer does not claim them.

## Apple and remaining store gates

Use a physical iPhone with the intended TestFlight build and Sandbox Apple
Account for purchase, restore and push. The same `purchase` command verifies
App Store token-pack ledger and receipt replay from any host. Windows cannot
automate the native iOS prompts. Existing `mobile-store-status` workflow checks
catalog/build availability; it does not prove device acceptance.

The source contract suite exercises binding and replay with fixtures. Real-store
mismatch/new-unbound rejection, purchase sandbox identity, native consume/finish,
restore UI, subscription lifecycle and physical iOS push remain release evidence
requirements in [payments-sandbox-checklist.md](payments-sandbox-checklist.md).
Review both platforms' evidence before enabling strict binding. A health warning
must not be hidden to make a report green.

## Runner regression checks

```powershell
& $env:PETMAGIC_QA_PYTHON -m unittest discover -s scripts/qa -p test_payments_push_qa.py
```

These tests require no credentials, network or connected devices. The manual
`payments-push-qa` GitHub workflow runs these checks and the backend contracts;
physical scenarios remain local and resumable.
