# PetMagic Mobile UX Check After Frontend Animation Optimization

Date: 2026-06-13

## Devices Checked

- iOS Simulator: iPhone 16, iOS 18.0.
- iOS Simulator: iPhone SE (3rd generation), iOS 18.0.
- Android emulator: attempted `petmagic_api35`, but it did not become an `adb`/Flutter connected device in this environment.
- Real Android device: not available.
- Real iPhone: not available.

## Screens / Flows Checked

- First-run welcome screen and `Continue as guest`.
- Sign in screen, sign-in error toast, focus state, password visibility toggle.
- Sign up screen, legal/consent unavailable state, submit error state.
- Reset password screen and reset error toast.
- Templates guest route with shared error/retry state.
- Rewards/Profile guest auth-required states.
- Light and dark appearances on auth/welcome/templates states.
- iPhone SE compact layout.

## Findings

1. iPhone 16 auth transitions are generally healthy.
   - Sign in to Sign up and Sign in to Reset Password used the new fade/slide transition without visible blank frames or double animation.
   - Password visibility icon switched without a layout jump.
   - Focus state on inputs is visible and not too aggressive.

2. Shared error/retry state is stable.
   - Templates feed failed to load because the backend/feed was unavailable locally, but the shared error state was readable.
   - Retry button stayed the same size and did not cause a visual jump.
   - Because data did not load, live template image/video skeleton behavior could not be fully verified from this run.

3. Dark theme is mostly healthy.
   - Reset Password, Welcome, Templates error, Rewards/Profile auth-required states had readable text and coherent surfaces.
   - Skeleton colors for real media content were not verified because templates did not load.

4. Production issue: iPhone SE Sign In has a layout overflow.
   - Screenshot: `ios-se-02-signin-bottom-overflow.png`.
   - Flutter shows `BOTTOM OVERFLOWED BY 11 PIXELS`.
   - This should be fixed before production, likely by using compact auth layout on short screens, reducing vertical spacing, or ensuring the overflowing child is scroll-contained.

5. Production issue: compact first-run Welcome hides CTAs too low.
   - Screenshot: `ios-se-01-welcome-cta-low.png`.
   - The top content is polished, but primary/secondary CTAs are partially below the first viewport on iPhone SE.
   - It is probably scrollable, but the first actionable controls should be more clearly visible on compact screens.

6. Production issue: Sign Up error state pushes CTA too low.
   - Screenshot: `ios-06-signup-top-error-cta-low.png`.
   - After legal/consent error appears, the Sign Up CTA is partly pushed below the visible bottom area on iPhone 16.
   - Consider scrolling to the new error, reducing error duplication, or trimming vertical spacing in compact sign-up mode.

7. Minor UX risk: top toast can cover auth headings.
   - Screenshot: `ios-08-reset-error-toast.png`.
   - Reset Password error toast did not shift layout, but it temporarily overlaps the title area.
   - This is acceptable for transient feedback, but less ideal than placing error context closer to the form for auth flows.

## Blockers / Limits

- Android emulator did not boot/connect successfully: `flutter devices` did not list `emulator-5554`, and `adb devices` was empty.
- Real devices were not connected, so physical-device scroll/keyboard performance was not verified.
- On-screen keyboard overlap was not fully verified because Simulator used hardware keyboard behavior during this run.
- Google/Apple auth was not completed to avoid external login/account side effects.
- Live media skeleton/video lifecycle could not be fully checked because templates did not load from the local backend/feed.

## Evidence Screenshots

- `ios-01-current.png`
- `ios-02-signin-error-toast.png`
- `ios-03-email-focus.png`
- `ios-04-password-focus-eye.png`
- `ios-05-signup-consent-unavailable.png`
- `ios-06-signup-top-error-cta-low.png`
- `ios-07-reset-password.png`
- `ios-08-reset-error-toast.png`
- `ios-09-reset-dark.png`
- `ios-10-welcome-dark.png`
- `ios-11-templates-error-dark.png`
- `ios-12-rewards-auth-required-dark.png`
- `ios-se-01-welcome-cta-low.png`
- `ios-se-02-signin-bottom-overflow.png`

## Recommendation

Do not treat this as production-ready yet. The animation layer is generally smooth on checked iOS flows, but the compact-screen auth/welcome layout issues should be fixed and rechecked before release. Android and real-device checks still need to be completed once a device/emulator is available.
