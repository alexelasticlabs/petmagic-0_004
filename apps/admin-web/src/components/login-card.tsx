"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

import { getAdminChromeCopy } from "@/components/admin/admin-chrome.content";
import { EyeIcon, EyeOffIcon, LockIcon, MailIcon } from "@/components/admin/admin-icons";
import styles from "@/components/login-card.module.css";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { getDefaultAdminPath, hasAdminPanelAccess } from "@/lib/admin-rbac";
import {
  acceptCurrentLegalDocuments,
  fetchCurrentLegalDocuments,
  isAuthSessionExpired,
  login,
  logout,
  restoreSession,
  useAuthSession,
  type AuthSession,
  type LegalAcceptanceStatus,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { type Locale, getDictionary } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

/* ── Component ────────────────────────────────────────────────────── */
type LoginCardProps = { locale: Locale };

function hasAcceptanceVersions(legalAcceptance: LegalAcceptanceStatus | undefined): boolean {
  return Boolean(
    legalAcceptance?.currentTermsOfUseVersion && legalAcceptance.currentPrivacyPolicyVersion
  );
}

function resolveLoginErrorMessage(error: unknown, fallback: string): string {
  const status =
    error && typeof error === "object" ? (error as { status?: number }).status : undefined;
  if (status === 400 || status === 401) {
    return fallback;
  }

  return getAdminErrorMessage(error, fallback);
}

function getLoginClientErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

async function ensureLegalAcceptance(locale: Locale, session: AuthSession): Promise<void> {
  const legalAcceptance = session.user.legalAcceptance;
  if (!legalAcceptance?.requiresAcceptance) {
    return;
  }

  if (hasAcceptanceVersions(legalAcceptance)) {
    try {
      await acceptCurrentLegalDocuments({
        termsOfUseVersion: legalAcceptance.currentTermsOfUseVersion,
        privacyPolicyVersion: legalAcceptance.currentPrivacyPolicyVersion,
      });
      return;
    } catch (error) {
      clientLogger.warn("auth.legal_acceptance_with_session_versions_failed", {
        locale,
        ...getLoginClientErrorDetails(error),
      });
    }
  }

  const legalDocuments = await fetchCurrentLegalDocuments(locale);
  await acceptCurrentLegalDocuments({
    termsOfUseVersion: legalDocuments.termsOfUse.version,
    privacyPolicyVersion: legalDocuments.privacyPolicy.version,
  });
}

export function LoginCard({ locale }: LoginCardProps) {
  const text = getDictionary(locale);
  const authText = getAdminChromeCopy(locale).loginCard;
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const isRestoringSessionRef = useRef(false);
  const emailInputRef = useRef<HTMLInputElement | null>(null);
  const existingSession = useAuthSession();
  const isCheckingSession = existingSession === undefined;
  const needsSessionRestore =
    Boolean(existingSession) &&
    (!existingSession?.accessToken || isAuthSessionExpired(existingSession));
  const hasValidExistingSession =
    Boolean(existingSession?.accessToken) && !isAuthSessionExpired(existingSession);
  const isRedirecting = hasValidExistingSession;

  useEffect(() => {
    if (!needsSessionRestore || isRestoringSessionRef.current) {
      return;
    }

    isRestoringSessionRef.current = true;
    void restoreSession()
      .then((restored) => {
        if (!restored) {
          void logout();
        }
      })
      .catch(() => {
        void logout();
      })
      .finally(() => {
        isRestoringSessionRef.current = false;
      });
  }, [needsSessionRestore]);

  useEffect(() => {
    if (hasValidExistingSession) {
      if (!hasAdminPanelAccess(existingSession?.user.roles)) {
        void logout();
        return;
      }

      router.replace(getDefaultAdminPath(locale, existingSession?.user.roles));
    }
  }, [existingSession?.user.roles, hasValidExistingSession, locale, router]);

  useEffect(() => {
    if (!hasAdminPanelAccess(existingSession?.user.roles)) {
      return;
    }

    router.prefetch(getDefaultAdminPath(locale, existingSession?.user.roles));
  }, [existingSession?.user.roles, locale, router]);

  useEffect(() => {
    if (existingSession === null) emailInputRef.current?.focus();
  }, [existingSession]);

  const normalizedEmail = email.trim();
  const isEmailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail);
  const submittedPassword = password;
  const isPasswordValid = submittedPassword.length >= 1;
  const canSubmit = isEmailValid && isPasswordValid && !isSubmitting;

  /* Dark skeleton while checking session */
  if (isCheckingSession || needsSessionRestore || isRedirecting) {
    return (
      <div className={styles.formArea}>
        <div className={styles.skeleton}>
          <div className={`${styles.skeletonLine} ${styles.skeletonTitle}`} />
          <div className={`${styles.skeletonLine} ${styles.skeletonSubtitle}`} />
          <div className={`${styles.skeletonLine} ${styles.skeletonInput}`} />
          <div className={`${styles.skeletonLine} ${styles.skeletonInput}`} />
          <div className={`${styles.skeletonLine} ${styles.skeletonButton}`} />
        </div>
      </div>
    );
  }

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (isSubmitting) {
      return;
    }

    if (!isEmailValid || !isPasswordValid) {
      setError(authText.validationError);
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const session = await login(normalizedEmail, submittedPassword);

      if (!hasAdminPanelAccess(session.user.roles)) {
        await logout();
        setError(authText.noAccess);
        return;
      }

      await ensureLegalAcceptance(locale, session);
      router.replace(getDefaultAdminPath(locale, session.user.roles));
    } catch (error) {
      clientLogger.warn("auth.login_failed", {
        locale,
        maskedEmail: maskEmail(normalizedEmail),
        ...getLoginClientErrorDetails(error),
      });
      setError(resolveLoginErrorMessage(error, text.loginFailed));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className={styles.formArea}>
      <h2 className={styles.title}>{text.loginTitle}</h2>
      <p className={styles.subtitle}>{text.loginHint}</p>

      {error ? (
        <p className={styles.error} role="alert" aria-live="polite">
          {error}
        </p>
      ) : null}

      <form className={styles.form} onSubmit={onSubmit} noValidate aria-busy={isSubmitting}>
        {/* Email */}
        <div className={styles.field}>
          <label className={styles.fieldLabel} htmlFor="login-email">
            {text.emailLabel}
          </label>
          <div className={styles.inputWrap}>
            <MailIcon className={styles.inputIcon} />
            <input
              ref={emailInputRef}
              id="login-email"
              className={styles.input}
              type="email"
              name="email"
              value={email}
              onChange={(event) => {
                setEmail(event.target.value.slice(0, 254));
                if (error) {
                  setError(null);
                }
              }}
              placeholder={authText.emailPlaceholder}
              required
              maxLength={254}
              disabled={isSubmitting}
              aria-invalid={email.length > 0 && !isEmailValid}
              autoComplete="email"
            />
          </div>
        </div>

        {/* Password */}
        <div className={styles.field}>
          <label className={styles.fieldLabel} htmlFor="login-password">
            {text.passwordLabel}
          </label>
          <div className={styles.inputWrap}>
            <LockIcon className={styles.inputIcon} />
            <input
              id="login-password"
              className={`${styles.input} ${styles.inputPaddedRight}`}
              type={showPassword ? "text" : "password"}
              name="password"
              value={password}
              onChange={(event) => {
                setPassword(event.target.value.slice(0, 128));
                if (error) {
                  setError(null);
                }
              }}
              placeholder={authText.passwordPlaceholder}
              required
              maxLength={128}
              disabled={isSubmitting}
              aria-invalid={password.length > 0 && !isPasswordValid}
              autoComplete="current-password"
            />
            <button
              type="button"
              className={styles.eyeButton}
              aria-label={showPassword ? authText.hidePassword : authText.showPassword}
              disabled={isSubmitting}
              onClick={() => setShowPassword((c) => !c)}
            >
              {showPassword ? <EyeOffIcon /> : <EyeIcon />}
            </button>
          </div>
        </div>

        {/* Submit */}
        <button type="submit" className={styles.submit} disabled={!canSubmit}>
          {isSubmitting ? <span className={styles.spinner} aria-hidden="true" /> : null}
          {text.signIn}
        </button>
      </form>

      <div className={styles.divider}>
        <span>{authText.orText}</span>
      </div>

      <p className={styles.contact}>
        {authText.contactText}
        <a href="mailto:admin@petgpt.app" className={styles.contactLink}>
          {authText.contactLinkText}
        </a>
      </p>
    </div>
  );
}
