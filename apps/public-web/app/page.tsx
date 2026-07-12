import Link from "next/link";
import { LegalShell } from "./site-components";

const cards = [
  ["Privacy", "How PetMagic handles account, media, and service data.", "/privacy"],
  ["Terms", "Rules for accounts, user content, and paid features.", "/terms"],
  ["Support", "Get help with PetMagic, billing, or generation results.", "/support"],
  ["Account deletion", "How to permanently delete a PetMagic account.", "/account-deletion"],
] as const;

export default function Home() {
  return (
    <LegalShell locale="en">
      <section className="hero" aria-labelledby="home-title">
        <p className="eyebrow">PetMagic information center</p>
        <h1 id="home-title">Clear answers for you and your pet.</h1>
        <p className="hero-copy">
          Privacy, terms, support, and account controls in one quiet, accessible place.
        </p>
      </section>
      <nav className="card-grid" aria-label="Information pages">
        {cards.map(([title, description, href]) => (
          <Link className="nav-card" href={href} key={href}>
            <span>{title}</span>
            <small>{description}</small>
            <b aria-hidden="true">→</b>
          </Link>
        ))}
      </nav>
    </LegalShell>
  );
}
