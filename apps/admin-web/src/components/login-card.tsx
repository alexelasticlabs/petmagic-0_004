"use client";

import styles from "@/components/login-card.module.css";
import { login, useAuthSession } from "@/lib/api-client";
import { type Locale, getDictionary } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

/* ── SVG icons ────────────────────────────────────────────────────── */
function IconEmail() {
  return (
    <svg className={styles.inputIcon} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="2" y="4" width="20" height="16" rx="2.5" stroke="currentColor" strokeWidth="1.6" />
      <path d="M22 6.5L12 13.5L2 6.5" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}

function IconLock() {
  return (
    <svg className={styles.inputIcon} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="3" y="11" width="18" height="11" rx="2.5" stroke="currentColor" strokeWidth="1.6" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}

function IconEyeOn() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"
        stroke="currentColor"
        strokeWidth="1.6"
      />
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}

function IconEyeOff() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M14.12 14.12A3 3 0 019.88 9.88"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <line x1="1" y1="1" x2="23" y2="23" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

/* ── Component ────────────────────────────────────────────────────── */
type LoginCardProps = { locale: Locale };

export function LoginCard({ locale }: LoginCardProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const emailInputRef = useRef<HTMLInputElement | null>(null);
  const existingSession = useAuthSession();
  const isCheckingSession = existingSession === undefined;
  const isRedirecting = Boolean(existingSession?.accessToken);

  useEffect(() => {
    if (existingSession?.accessToken) {
      router.replace(`/${locale}/dashboard`);
    }
  }, [existingSession?.accessToken, locale, router]);

  useEffect(() => {
    router.prefetch(`/${locale}/dashboard`);
  }, [locale, router]);

  useEffect(() => {
    if (existingSession === null) emailInputRef.current?.focus();
  }, [existingSession]);

  /* Dark skeleton while checking session */
  if (isCheckingSession || isRedirecting) {
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
    setIsSubmitting(true);
    setError(null);
    const formData = new FormData(event.currentTarget);
    const email = String(formData.get("email") ?? "");
    const password = String(formData.get("password") ?? "");
    try {
      await login(email, password);
      router.replace(`/${locale}/dashboard`);
    } catch {
      setError(text.loginFailed);
    } finally {
      setIsSubmitting(false);
    }
  }

  const isRu = locale === "ru";
  const contactText = isRu ? "Проблемы с доступом? " : "Access issues? ";
  const contactLinkText = isRu ? "Свяжитесь с администратором" : "Contact administrator";
  const orText = isRu ? "или" : "or";

  return (
    <div className={styles.formArea}>
      <h2 className={styles.title}>{text.loginTitle}</h2>
      <p className={styles.subtitle}>{text.loginHint}</p>

      {error ? (
        <p className={styles.error} role="alert" aria-live="polite">
          {error}
        </p>
      ) : null}

      <form className={styles.form} onSubmit={onSubmit} noValidate>
        {/* Email */}
        <div className={styles.field}>
          <label className={styles.fieldLabel} htmlFor="login-email">
            {text.emailLabel}
          </label>
          <div className={styles.inputWrap}>
            <IconEmail />
            <input
              ref={emailInputRef}
              id="login-email"
              className={styles.input}
              type="email"
              name="email"
              placeholder={isRu ? "Введите email" : "Enter email"}
              required
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
            <IconLock />
            <input
              id="login-password"
              className={`${styles.input} ${styles.inputPaddedRight}`}
              type={showPassword ? "text" : "password"}
              name="password"
              placeholder={isRu ? "Введите пароль" : "Enter password"}
              required
              autoComplete="current-password"
            />
            <button
              type="button"
              className={styles.eyeButton}
              aria-label={
                showPassword
                  ? isRu ? "Скрыть пароль" : "Hide password"
                  : isRu ? "Показать пароль" : "Show password"
              }
              onClick={() => setShowPassword((c) => !c)}
            >
              {showPassword ? <IconEyeOff /> : <IconEyeOn />}
            </button>
          </div>
        </div>

        {/* Submit */}
        <button type="submit" className={styles.submit} disabled={isSubmitting}>
          {isSubmitting ? <span className={styles.spinner} aria-hidden="true" /> : null}
          {text.signIn}
        </button>
      </form>

      <div className={styles.divider}>
        <span>{orText}</span>
      </div>

      <p className={styles.contact}>
        {contactText}
        <a href="mailto:admin@petmagic.app" className={styles.contactLink}>
          {contactLinkText}
        </a>
      </p>
    </div>
  );
}
