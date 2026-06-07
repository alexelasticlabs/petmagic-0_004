"use client";

import { useEffect } from "react";

import { clientLogger } from "@/lib/client-logger";

import type { CSSProperties } from "react";

type GlobalErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

const pageStyle: CSSProperties = {
  minHeight: "100vh",
  margin: 0,
  background: "#f7f8fb",
  color: "#172033",
  fontFamily:
    'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
};

const mainStyle: CSSProperties = {
  minHeight: "100vh",
  display: "grid",
  placeItems: "center",
  padding: "2rem",
};

const panelStyle: CSSProperties = {
  width: "min(100%, 34rem)",
  border: "1px solid #d8deea",
  borderRadius: "8px",
  background: "#ffffff",
  boxShadow: "0 18px 50px rgba(23, 32, 51, 0.12)",
  padding: "2rem",
};

const eyebrowStyle: CSSProperties = {
  margin: "0 0 0.75rem",
  color: "#6f7a8f",
  fontSize: "0.78rem",
  fontWeight: 700,
  letterSpacing: "0.08em",
  textTransform: "uppercase",
};

const titleStyle: CSSProperties = {
  margin: 0,
  fontSize: "clamp(1.6rem, 4vw, 2.25rem)",
  lineHeight: 1.1,
};

const descriptionStyle: CSSProperties = {
  margin: "1rem 0 0",
  color: "#4d5b70",
  fontSize: "1rem",
  lineHeight: 1.55,
};

const actionsStyle: CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: "0.75rem",
  marginTop: "1.5rem",
};

const buttonStyle: CSSProperties = {
  minHeight: "2.75rem",
  border: 0,
  borderRadius: "8px",
  background: "#1d5fd7",
  color: "#ffffff",
  cursor: "pointer",
  fontSize: "0.95rem",
  fontWeight: 700,
  padding: "0.7rem 1rem",
};

const linkStyle: CSSProperties = {
  minHeight: "2.75rem",
  display: "inline-flex",
  alignItems: "center",
  border: "1px solid #c4ccda",
  borderRadius: "8px",
  color: "#172033",
  fontSize: "0.95rem",
  fontWeight: 700,
  padding: "0.7rem 1rem",
  textDecoration: "none",
};

function isRussianPath(): boolean {
  if (typeof window === "undefined") {
    return false;
  }

  return window.location.pathname.split("/").filter(Boolean)[0] === "ru";
}

export default function GlobalError({ error, reset }: GlobalErrorProps) {
  const isRu = isRussianPath();

  useEffect(() => {
    clientLogger.error("admin.global_error_boundary_triggered", {
      name: error.name,
      digest: error.digest,
      scope: "root",
    });
  }, [error]);

  return (
    <html lang={isRu ? "ru" : "en"}>
      <body style={pageStyle}>
        <main style={mainStyle}>
          <section style={panelStyle} aria-labelledby="global-error-title">
            <p style={eyebrowStyle}>PetMagic Admin</p>
            <h1 id="global-error-title" style={titleStyle}>
              {isRu ? "Не удалось открыть админ-панель" : "Unable to open the admin panel"}
            </h1>
            <p style={descriptionStyle}>
              {isRu
                ? "Произошла критическая ошибка интерфейса. Повторите попытку или вернитесь на страницу входа."
                : "A critical interface error occurred. Try again or return to the sign-in page."}
            </p>
            <div style={actionsStyle}>
              <button type="button" style={buttonStyle} onClick={reset}>
                {isRu ? "Повторить" : "Retry"}
              </button>
              <a href={isRu ? "/ru" : "/en"} style={linkStyle}>
                {isRu ? "К входу" : "Go to sign in"}
              </a>
            </div>
          </section>
        </main>
      </body>
    </html>
  );
}
