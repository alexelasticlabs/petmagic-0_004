# Suppress optional Stripe Issuing push-provisioning classes. PetMagic uses
# PaymentSheet, while this separate restricted dependency is intentionally not
# packaged and its internal class suffixes change between Stripe SDK versions.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn kotlinx.parcelize.Parceler$DefaultImpls
-dontwarn kotlinx.parcelize.Parceler
-dontwarn kotlinx.parcelize.Parcelize

# PaymentSheet uses reflection for parts of the native Stripe SDK.
-keep class com.stripe.** { *; }
