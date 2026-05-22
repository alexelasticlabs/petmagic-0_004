import { IBM_Plex_Sans, Manrope } from "next/font/google";

import type { Metadata } from "next";
import "./globals.css";

const bodyFont = IBM_Plex_Sans({
  variable: "--font-admin-body",
  subsets: ["latin", "cyrillic"],
  display: "swap",
  weight: ["400", "500", "600", "700"],
});

const headingFont = Manrope({
  variable: "--font-admin-heading",
  subsets: ["latin", "cyrillic"],
  display: "swap",
  weight: ["500", "600", "700"],
});

export const metadata: Metadata = {
  title: "PetMagic Admin",
  description: "Admin panel for authentication and user management",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${bodyFont.variable} ${headingFont.variable}`}>
      <body>{children}</body>
    </html>
  );
}
