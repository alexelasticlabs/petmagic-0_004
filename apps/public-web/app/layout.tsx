import type { Metadata } from "next";
import { Comfortaa } from "next/font/google";
import "./globals.css";

const comfortaa = Comfortaa({
  variable: "--font-comfortaa",
  subsets: ["latin", "cyrillic"],
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://petmagic.app"),
  title: {
    default: "PetMagic — Legal & Support",
    template: "%s · PetMagic",
  },
  description:
    "PetMagic privacy, terms, support, and account deletion information.",
  alternates: { canonical: "/" },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={comfortaa.variable}>{children}</body>
    </html>
  );
}
