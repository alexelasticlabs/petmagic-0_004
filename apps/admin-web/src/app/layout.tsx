import type { Metadata } from "next";
import { Inter, Manrope } from "next/font/google";
import "./globals.css";

const bodyFont = Inter({
  variable: "--font-manrope",
  subsets: ["latin", "cyrillic"],
  display: "swap",
  weight: ["400", "500", "600", "700"],
});

const headingFont = Manrope({
  variable: "--font-space-grotesk",
  subsets: ["latin", "cyrillic"],
  display: "swap",
  weight: ["500", "600", "700", "800"],
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
