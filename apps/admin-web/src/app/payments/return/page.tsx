import { buildPaymentAppLink } from "@/lib/payment-bridge";

import { PaymentBridgeClient } from "../payment-bridge-client";

import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Subscription settings · PetMagic",
  robots: { index: false, follow: false },
};

export default function PaymentReturnPage() {
  return (
    <PaymentBridgeClient
      appLink={buildPaymentAppLink("manage")}
      title="Subscription settings saved"
      body="Return to PetMagic to refresh your subscription status."
    />
  );
}
