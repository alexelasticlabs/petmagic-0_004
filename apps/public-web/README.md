# PetMagic Public Web

Public PetMagic pages for privacy, terms, support, and account deletion. The
site runs on [vinext](https://github.com/cloudflare/vinext) and is deployed as a
Cloudflare Worker through Sites.

## Prerequisites

- Node.js `>=22.13.0`

## Quick Start

```bash
npm install
npm run dev
npm run build
```

This starter does not use `wrangler.jsonc`.

## Project Shape

- Site code lives under `app/`.
- Approved legal text is loaded from
  `../../shared/legal/legal-documents.v2026-07-09.json`.
- `.openai/hosting.json` keeps Sites bindings explicit; this static legal site
  does not require D1 or R2.
- `vite.config.ts` produces the Cloudflare Worker-compatible build.

## Useful Commands

- `npm run dev`: start local development
- `npm run build`: verify the vinext build output
- `npm test`: build the site and verify its rendered legal routes
- `npm run validate:legal`: verify that every required legal translation exists
- `npm run lint`: validate TypeScript and React source hygiene

## Learn More

- [vinext Documentation](https://github.com/cloudflare/vinext)
