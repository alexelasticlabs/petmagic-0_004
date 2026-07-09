import type { Metadata } from "next";
import { connection } from "next/server";
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

  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
