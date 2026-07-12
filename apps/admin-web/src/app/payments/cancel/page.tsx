import { buildPaymentAppLink } from "@/lib/payment-bridge";

import { PaymentBridgeClient } from "../payment-bridge-client";

import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Payment cancelled · PetMagic",
  robots: { index: false, follow: false },
};

export default function PaymentCancelPage() {
  return (
    <PaymentBridgeClient
      appLink={buildPaymentAppLink("cancel")}
      title="Payment cancelled"
      body="No new charge was confirmed. Return to PetMagic to choose another payment method."
    />
  );
}
