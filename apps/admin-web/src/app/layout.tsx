import { headers } from "next/headers";
import { connection } from "next/server";

import { ADMIN_THEME_INIT_SCRIPT } from "@/lib/theme";

import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "PetMagic Admin",
  description: "PetMagic Admin",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  await connection();
  const nonce = (await headers()).get("x-nonce");

  // The CSP nonce is regenerated per server response and stripped from the
  // client-side script representation during hydration.
  return (
    <html lang="en" data-theme="dark" style={{ colorScheme: "dark" }} suppressHydrationWarning>
      <head>
        <script
          nonce={nonce ?? undefined}
          suppressHydrationWarning
          dangerouslySetInnerHTML={{ __html: ADMIN_THEME_INIT_SCRIPT }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
