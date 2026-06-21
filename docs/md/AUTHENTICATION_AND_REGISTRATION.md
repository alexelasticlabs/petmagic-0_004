# Authentication and Registration

This document describes how authentication and registration currently work in PetMagic.

## Overview

Auth is handled by the Identity module in the backend. The public entry points live under /api/auth, and both the mobile app and the admin web app call the same backend endpoints.

The core flow is:

1. Register a user with email, password, legal acceptance, and optional display name.
2. Send an email verification code.
3. Confirm the email address.
4. Log in and receive an access token plus a refresh token.
5. Refresh the session or log out as needed.

## Registration

Registration uses POST /api/auth/register.

The backend validates:

1. Email must be present and valid.
2. Password must satisfy the password policy.
3. Terms of Use and Privacy Policy must be accepted.
4. The submitted legal versions must match the current versions, or the backend falls back to the current versions when the client leaves them empty.

On success, the backend:

1. Creates a new user if the email is new.
2. Reissues the pending-registration flow if the email already exists but the account is still pending.
3. Sets the account status to pending email verification.
4. Saves the terms/privacy acceptance state and marketing opt-in.
5. Assigns the default User role.
6. Queues an email verification code.

If the email already belongs to an active or confirmed account, registration is rejected.

The mobile app sends the register request from ProfileRepository.register, and includes email, password, display name, terms/privacy flags, legal versions, and the marketing opt-in flag.

## Login

Login uses POST /api/auth/login.

The backend checks:

1. The user exists.
2. The account is active.
3. The password is correct.
4. The email is confirmed.
5. The account is not locked out.

If the password is wrong, failed-attempt counters are increased and lockout can kick in after repeated failures. If the email is still unconfirmed, login is denied with a dedicated auth error.

On success, the backend returns a token pair response containing:

1. Access token.
2. Refresh token.
3. Access token expiry time.
4. User profile data.

The backend also writes the refresh token cookie for browser-based flows.

The mobile app stores the returned session in secure storage. The admin web app stores the session in session storage and restores it on startup.

## Email verification

Registration starts in a pending email verification state.

The backend supports these endpoints:

1. POST /api/auth/email-confirmation/request
2. POST /api/auth/email-confirmation/confirm
3. POST /api/auth/resend-email-verification-code
4. POST /api/auth/verify-email-code

The verification code is a six-digit code. The code request is rate-limited so repeated requests cannot be spammed.

Until email confirmation is completed, login stays blocked.

## Password reset

Password reset uses email codes as well.

The public endpoints are:

1. POST /api/auth/request-password-reset
2. POST /api/auth/verify-password-reset-code
3. POST /api/auth/reset-password
4. POST /api/auth/password-reset/request
5. POST /api/auth/password-reset/confirm

The reset flow sends a six-digit code to the user email, verifies the code, and then sets a new password. Confirming a password reset revokes existing refresh token sessions.

Authenticated users can also request and confirm a password change from the signed-in session using the /api/auth/me/password-change/\* endpoints.

## Refresh and logout

The session lifecycle is completed with:

1. POST /api/auth/refresh
2. POST /api/auth/logout

Refresh accepts the current refresh token and returns a new token pair. Logout revokes the current refresh token session and clears the browser cookie.

## External sign-in

PetMagic also supports external sign-in providers.

Current endpoints include:

1. GET /api/auth/external/{provider}
2. GET /api/auth/external/callback
3. POST /api/auth/external/exchange
4. POST /api/auth/google
5. POST /api/auth/apple
6. POST /api/auth/external/google/native

External login can create a new account when the provider returns a verified email and no local account exists yet. If the user already exists, the provider is linked to that account and the user is signed in.

## Client behavior

Mobile and web use the same backend auth API, but they persist sessions differently.

Mobile stores the session in Flutter secure storage under petmagic_mobile_auth_session.

Admin web stores the session in browser session storage under petmagic_admin_auth.

Both clients rely on the backend token pair response from login, refresh, and external sign-in.

## Related files

1. [Auth endpoints](../../src/Modules/Identity/PetMagic.Modules.Identity.Api/Endpoints/AuthEndpoints.cs)
2. [Auth validation rules](../../src/Modules/Identity/PetMagic.Modules.Identity.Application/Validation/AuthValidators.cs)
3. [Identity service auth flows](../../src/Modules/Identity/PetMagic.Modules.Identity.Infrastructure/IdentityService.AuthFlows.cs)
4. [Mobile profile repository](../../apps/petmagic-mobile/lib/features/profile/data/profile_repository.dart)
5. [Mobile auth session storage](../../apps/petmagic-mobile/lib/features/profile/data/auth_session_storage.dart)
6. [Admin web auth client](../../apps/admin-web/src/lib/api-client.core.ts)
