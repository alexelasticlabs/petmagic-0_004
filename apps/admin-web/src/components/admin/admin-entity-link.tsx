import Link from "next/link";
import { type ReactNode } from "react";

import styles from "./admin-entity-link.module.css";

type AdminEntityLinkProps = {
  href: string;
  label: string;
  secondaryLabel?: string;
  ariaLabel?: string;
  leading?: ReactNode;
  className?: string;
};

export function AdminEntityLink({
  href,
  label,
  secondaryLabel,
  ariaLabel,
  leading,
  className,
}: AdminEntityLinkProps) {
  const linkClassName = className ? `${styles.entityLink} ${className}` : styles.entityLink;

  return (
    <Link href={href} className={linkClassName} aria-label={ariaLabel}>
      {leading ? <span className={styles.leading}>{leading}</span> : null}
      <span className={styles.copy}>
        <span className={styles.label}>{label}</span>
        {secondaryLabel ? <span className={styles.secondary}>{secondaryLabel}</span> : null}
      </span>
      <svg className={styles.arrow} viewBox="0 0 16 16" aria-hidden="true">
        <path d="M5.5 3.5 10 8l-4.5 4.5" />
      </svg>
    </Link>
  );
}
