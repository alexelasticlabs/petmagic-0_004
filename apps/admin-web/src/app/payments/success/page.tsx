import { buildPaymentAppLink } from "@/lib/payment-bridge";

import { PaymentBridgeClient } from "../payment-bridge-client";

import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Payment complete · PetMagic",
  robots: { index: false, follow: false },
};

type PaymentSuccessPageProps = {
  searchParams: Promise<{ session_id?: string | string[] }>;
};

export default async function PaymentSuccessPage({ searchParams }: PaymentSuccessPageProps) {
  const { session_id: sessionId } = await searchParams;
  return (
    <PaymentBridgeClient
      appLink={buildPaymentAppLink("success", sessionId)}
      title="Payment complete"
      body="Return to PetMagic while we verify your purchase and update your balance."
    />
  );
}
