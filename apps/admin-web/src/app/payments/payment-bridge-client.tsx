"use client";

import { useEffect } from "react";

import styles from "./payment-bridge.module.css";

type PaymentBridgeClientProps = {
  appLink: string;
  body: string;
  title: string;
};

export function PaymentBridgeClient({ appLink, body, title }: PaymentBridgeClientProps) {
  useEffect(() => {
    window.location.assign(appLink);
  }, [appLink]);

  return (
    <main className={styles.page}>
      <section className={styles.card} aria-labelledby="payment-bridge-title">
        <div className={styles.brand}>PetMagic</div>
        <h1 id="payment-bridge-title">{title}</h1>
        <p>{body}</p>
        <a className={styles.primaryAction} href={appLink}>
          Open PetMagic
        </a>
        <p className={styles.hint}>If the app does not open automatically, use the button above.</p>
      </section>
    </main>
  );
}
