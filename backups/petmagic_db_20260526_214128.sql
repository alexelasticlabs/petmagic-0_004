--
-- PostgreSQL database dump
--

\restrict pienfmtHhgPrJKla11wDhNHcaMtilQQBIv2WiYugAnErjJkurA87mhRem5s52vu

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: __EFMigrationsHistory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    "Id" uuid NOT NULL,
    "SubjectUserId" uuid,
    "Action" character varying(120) NOT NULL,
    "Details" character varying(2000) NOT NULL,
    "OccurredAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_currency_packs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_currency_packs (
    "Id" uuid NOT NULL,
    "Code" character varying(40) NOT NULL,
    "DisplayName" character varying(120) NOT NULL,
    "CurrencyCode" character varying(3) NOT NULL,
    "PriceAmount" numeric(12,2) NOT NULL,
    "GrantedSpark" integer NOT NULL,
    "BonusSpark" integer NOT NULL,
    "IsActive" boolean NOT NULL,
    "SortOrder" integer NOT NULL
);


--
-- Name: economy_payment_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_payment_customers (
    "UserId" uuid NOT NULL,
    "Provider" character varying(24) NOT NULL,
    "ExternalCustomerId" character varying(120) NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_payment_provider_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_payment_provider_configs (
    "Id" uuid NOT NULL,
    "Provider" character varying(32) NOT NULL,
    "Platform" character varying(24) NOT NULL,
    "Region" character varying(16) NOT NULL,
    "IsEnabled" boolean NOT NULL,
    "IsRecommended" boolean NOT NULL,
    "IsSelectedByDefault" boolean NOT NULL,
    "RequiresExternalWarning" boolean NOT NULL,
    "RequiresStoreDisclosure" boolean NOT NULL,
    "AllowedFromAppVersion" character varying(32) NOT NULL,
    "ExternalCheckoutAllowed" boolean NOT NULL,
    "BonusTokensPercent" integer NOT NULL,
    "DisplayLabel" character varying(80),
    "DisplaySubtitle" character varying(160),
    "WarningTitle" character varying(120),
    "WarningMessage" character varying(800),
    "Mode" character varying(16) NOT NULL,
    "Notes" character varying(400),
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_processed_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_processed_webhook_events (
    "Id" uuid NOT NULL,
    "Provider" character varying(24) NOT NULL,
    "EventId" character varying(120) NOT NULL,
    "EventType" character varying(120) NOT NULL,
    "ProcessedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_purchase_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_purchase_orders (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "PackId" uuid NOT NULL,
    "SavedPaymentMethodId" uuid,
    "PaymentProvider" character varying(24) NOT NULL,
    "Status" character varying(24) NOT NULL,
    "PriceAmount" numeric(12,2) NOT NULL,
    "CurrencyCode" character varying(3) NOT NULL,
    "SparkToGrant" integer NOT NULL,
    "ExternalPaymentId" character varying(120),
    "CheckoutUrl" character varying(500),
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "ConfirmedAtUtc" timestamp with time zone
);


--
-- Name: economy_redeem_code_redemptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_redeem_code_redemptions (
    "Id" uuid NOT NULL,
    "RedeemCodeId" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "RewardKind" character varying(32) NOT NULL,
    "RewardValue" integer NOT NULL,
    "WalletLedgerEntryId" uuid,
    "PremiumExpiresAtUtc" timestamp with time zone,
    "RedeemedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_redeem_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_redeem_codes (
    "Id" uuid NOT NULL,
    "Code" character varying(64) NOT NULL,
    "CodeHash" character varying(96) NOT NULL,
    "CodePrefix" character varying(16) NOT NULL,
    "Description" character varying(160) NOT NULL,
    "CampaignName" character varying(120),
    "CampaignChannel" character varying(64),
    "MinimumSuccessfulPurchases" integer NOT NULL,
    "CreatedBy" character varying(120),
    "RewardKind" character varying(32) NOT NULL,
    "RewardValue" integer NOT NULL,
    "MaxRedemptions" integer NOT NULL,
    "MaxRedemptionsPerUser" integer NOT NULL,
    "RedeemedCount" integer NOT NULL,
    "IsActive" boolean NOT NULL,
    "StartsAtUtc" timestamp with time zone,
    "ExpiresAtUtc" timestamp with time zone,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_referral_attributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_referral_attributions (
    "Id" uuid NOT NULL,
    "ReferrerUserId" uuid NOT NULL,
    "RefereeUserId" uuid NOT NULL,
    "ReferrerCode" character varying(32) NOT NULL,
    "Status" character varying(24) NOT NULL,
    "RewardSpark" integer NOT NULL,
    "ReferrerLedgerEntryId" uuid,
    "RefereeLedgerEntryId" uuid,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL,
    "QualifiedAtUtc" timestamp with time zone
);


--
-- Name: economy_referral_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_referral_profiles (
    "UserId" uuid NOT NULL,
    "Code" character varying(32) NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_saved_payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_saved_payment_methods (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Provider" character varying(24) NOT NULL,
    "ExternalPaymentMethodId" character varying(120) NOT NULL,
    "Brand" character varying(40) NOT NULL,
    "Last4" character varying(8) NOT NULL,
    "ExpMonth" bigint,
    "ExpYear" bigint,
    "IsDefault" boolean NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_subscription_event_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_subscription_event_logs (
    "Id" uuid NOT NULL,
    "UserId" uuid,
    "UserSubscriptionId" uuid,
    "Provider" character varying(32) NOT NULL,
    "EventType" character varying(64) NOT NULL,
    "Status" character varying(32) NOT NULL,
    "ExternalEventId" character varying(160),
    "ExternalSubscriptionId" character varying(160),
    "PayloadJson" character varying(32000),
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "ProcessedAtUtc" timestamp with time zone
);


--
-- Name: economy_subscription_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_subscription_plans (
    "Id" character varying(64) NOT NULL,
    "Name" character varying(160) NOT NULL,
    "BillingPeriod" character varying(24) NOT NULL,
    "PriceAmount" numeric(12,2) NOT NULL,
    "CurrencyCode" character varying(3) NOT NULL,
    "MonthlyTokenLimit" integer NOT NULL,
    "IsRecommended" boolean NOT NULL,
    "IsActive" boolean NOT NULL,
    "AppleProductId" character varying(160),
    "GoogleProductId" character varying(160),
    "StripePriceId" character varying(160),
    "DisplayOrder" integer NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_user_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_user_subscriptions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Provider" character varying(32) NOT NULL,
    "PurchaseChannel" character varying(32) NOT NULL,
    "Region" character varying(16) NOT NULL,
    "PlanId" character varying(64) NOT NULL,
    "Status" character varying(32) NOT NULL,
    "ExternalCustomerId" character varying(160),
    "ExternalSubscriptionId" character varying(160),
    "ExternalTransactionId" character varying(160),
    "CurrentPeriodStartUtc" timestamp with time zone,
    "CurrentPeriodEndUtc" timestamp with time zone,
    "CancelAtPeriodEnd" boolean NOT NULL,
    "MonthlyTokenLimit" integer NOT NULL,
    "MonthlyTokensGranted" integer NOT NULL,
    "LastTokenGrantAtUtc" timestamp with time zone,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_wallet_ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_wallet_ledger (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Delta" integer NOT NULL,
    "BalanceAfter" integer NOT NULL,
    "Source" character varying(80) NOT NULL,
    "Reason" character varying(120) NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: economy_wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economy_wallets (
    "UserId" uuid NOT NULL,
    "Balance" integer NOT NULL,
    "LastWeeklyGrantAtUtc" timestamp with time zone,
    "AdRewardWindowStartedAtUtc" timestamp with time zone,
    "AdRewardsClaimedInWindow" integer NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: email_dispatch_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_dispatch_jobs (
    "Id" uuid NOT NULL,
    "UserId" uuid,
    "RecipientEmail" character varying(320) NOT NULL,
    "Kind" integer NOT NULL,
    "Status" integer NOT NULL,
    "Subject" character varying(200) NOT NULL,
    "HtmlBody" character varying(20000) NOT NULL,
    "TextBody" character varying(20000) NOT NULL,
    "AttemptCount" integer NOT NULL,
    "QueuedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL,
    "LastAttemptAtUtc" timestamp with time zone,
    "NextAttemptAtUtc" timestamp with time zone,
    "SentAtUtc" timestamp with time zone,
    "FailureCode" character varying(120),
    "FailureMessage" character varying(2000)
);


--
-- Name: external_logins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_logins (
    "LoginProvider" text NOT NULL,
    "ProviderKey" text NOT NULL,
    "ProviderDisplayName" text,
    "UserId" uuid NOT NULL
);


--
-- Name: refresh_token_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_token_sessions (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TokenHash" character varying(200) NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "ExpiresAtUtc" timestamp with time zone NOT NULL,
    "RevokedAtUtc" timestamp with time zone
);


--
-- Name: role_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_claims (
    "Id" integer NOT NULL,
    "RoleId" uuid NOT NULL,
    "ClaimType" text,
    "ClaimValue" text
);


--
-- Name: role_claims_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.role_claims ALTER COLUMN "Id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."role_claims_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    "Id" uuid NOT NULL,
    "Name" character varying(256),
    "NormalizedName" character varying(256),
    "ConcurrencyStamp" text
);


--
-- Name: support_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_conversations (
    "Id" uuid NOT NULL,
    "InitiatorUserId" uuid NOT NULL,
    "AssignedAdminId" uuid,
    "Status" integer NOT NULL,
    "Priority" integer NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL,
    "LastMessageAtUtc" timestamp with time zone,
    "ResolvedAtUtc" timestamp with time zone
);


--
-- Name: support_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_messages (
    "Id" uuid NOT NULL,
    "ConversationId" uuid NOT NULL,
    "SenderUserId" uuid NOT NULL,
    "IsFromAdmin" boolean NOT NULL,
    "Body" character varying(4000) NOT NULL,
    "AttachmentUrl" character varying(2048),
    "AttachmentFileName" character varying(256),
    "AttachmentContentType" character varying(128),
    "AttachmentFileSizeBytes" bigint,
    "AttachmentUploadStatus" integer,
    "AttachmentUploadErrorCode" character varying(128),
    "ReadAtUtc" timestamp with time zone,
    "CreatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: support_reply_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_reply_templates (
    "Id" uuid NOT NULL,
    "Title" character varying(120) NOT NULL,
    "Body" character varying(4000) NOT NULL,
    "IsEnabled" boolean NOT NULL,
    "SortOrder" integer NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: templates_analytics_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_analytics_events (
    "Id" uuid NOT NULL,
    "TemplateId" uuid NOT NULL,
    "UserId" uuid,
    "GenerationId" uuid,
    "EventType" character varying(64) NOT NULL,
    "Source" character varying(64) NOT NULL,
    "DeviceClass" character varying(32) NOT NULL,
    "CountryCode" character varying(8) NOT NULL,
    "FeedbackMessage" character varying(2000),
    "CreatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: templates_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_assets (
    "Id" uuid NOT NULL,
    "TemplateId" uuid NOT NULL,
    "AssetKind" integer NOT NULL,
    "Url" character varying(2048) NOT NULL,
    "FileName" character varying(256) NOT NULL,
    "ContentType" character varying(128) NOT NULL,
    "FileSizeBytes" bigint,
    "DurationSeconds" double precision
);


--
-- Name: templates_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_categories (
    "Id" uuid NOT NULL,
    "Name" character varying(64) NOT NULL,
    "NormalizedName" character varying(64) NOT NULL,
    "IsArchived" boolean NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: templates_generation_feedback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_generation_feedback (
    "Id" uuid NOT NULL,
    "GenerationId" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TemplateId" uuid NOT NULL,
    "Rating" integer NOT NULL,
    "SelectedReasons" character varying(1000) NOT NULL,
    "Comment" character varying(2000),
    "InputPhotoQualityScore" double precision,
    "ModelUsed" character varying(256),
    "GenerationDurationSeconds" double precision,
    "ProviderRequestId" character varying(128),
    "CreatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: templates_generation_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_generation_jobs (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "TemplateId" uuid NOT NULL,
    "Status" integer NOT NULL,
    "TokenCost" integer NOT NULL,
    "SourceImageUrl" character varying(2048) NOT NULL,
    "SourceImageFileName" character varying(256) NOT NULL,
    "SourceImageContentType" character varying(128) NOT NULL,
    "SourceImageFileSizeBytes" bigint,
    "NormalizedImageUrl" character varying(2048),
    "ReferenceMotionUrl" character varying(2048),
    "OutputUrl" character varying(2048),
    "UsedPreprocessingModel" character varying(256),
    "UsedKlingModel" character varying(256),
    "PreprocessingProviderRequestId" character varying(128),
    "PreprocessingInferenceTimeSeconds" double precision,
    "MotionProviderRequestId" character varying(128),
    "MotionInferenceTimeSeconds" double precision,
    "OutputVideoDurationSeconds" double precision,
    "MotionProviderCostUsd" numeric(12,4),
    "PreprocessingCompletedAtUtc" timestamp with time zone,
    "MotionGenerationCompletedAtUtc" timestamp with time zone,
    "MediaImportCompletedAtUtc" timestamp with time zone,
    "AttemptCount" integer NOT NULL,
    "FailureCode" character varying(128),
    "FailureMessage" character varying(1000),
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "QueuedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL,
    "LastAttemptAtUtc" timestamp with time zone,
    "ChargedAtUtc" timestamp with time zone,
    "RefundedAtUtc" timestamp with time zone,
    "RefundAttemptCount" integer NOT NULL,
    "RefundLastErrorCode" character varying(128),
    "RefundLastAttemptedAtUtc" timestamp with time zone,
    "StartedAtUtc" timestamp with time zone,
    "CompletedAtUtc" timestamp with time zone,
    "ResultViewedAtUtc" timestamp with time zone,
    "UserMediaDeletedAtUtc" timestamp with time zone,
    "LastUserMediaCleanupAttemptAtUtc" timestamp with time zone,
    "UserMediaCleanupFailureCode" character varying(128)
);


--
-- Name: templates_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_items (
    "Id" uuid NOT NULL,
    "TemplateType" integer NOT NULL,
    "Title" character varying(120) NOT NULL,
    "ShortDescription" character varying(240) NOT NULL,
    "PetPhotoRequirements" character varying(1000),
    "Category" character varying(64) NOT NULL,
    "Tags" character varying(1000) NOT NULL,
    "IsPremium" boolean NOT NULL,
    "TokenCost" integer NOT NULL,
    "Status" integer NOT NULL,
    "PromoBadgeMode" integer NOT NULL,
    "MusicDescription" character varying(240),
    "ReferenceVideoDurationSeconds" double precision,
    "CharacterOrientation" integer,
    "ImageModel" character varying(128),
    "ImagePrompt" character varying(1000),
    "PreprocessingModel" character varying(128),
    "PreprocessingPrompt" character varying(1000),
    "KlingModel" character varying(128),
    "KlingPrompt" character varying(1000),
    "KeepOriginalSound" boolean,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL
);


--
-- Name: templates_media_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_media_records (
    "Id" uuid NOT NULL,
    "Url" character varying(2048) NOT NULL,
    "FileName" character varying(256) NOT NULL,
    "ContentType" character varying(128) NOT NULL,
    "FileSizeBytes" bigint,
    "Role" integer NOT NULL,
    "LifecycleState" integer NOT NULL,
    "TemplateId" uuid,
    "GenerationJobId" uuid,
    "UploadedAtUtc" timestamp with time zone NOT NULL,
    "ExpiresAtUtc" timestamp with time zone,
    "AttachedAtUtc" timestamp with time zone,
    "DeletedAtUtc" timestamp with time zone,
    "LastCleanupAttemptAtUtc" timestamp with time zone,
    "FailureCode" character varying(128),
    "FailureMessage" character varying(1000)
);


--
-- Name: templates_push_device_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.templates_push_device_tokens (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Token" character varying(4096) NOT NULL,
    "Platform" character varying(32) NOT NULL,
    "DeviceId" character varying(128),
    "AppVersion" character varying(64),
    "Locale" character varying(16),
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UpdatedAtUtc" timestamp with time zone NOT NULL,
    "LastSeenAtUtc" timestamp with time zone NOT NULL,
    "DisabledAtUtc" timestamp with time zone
);


--
-- Name: user_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_claims (
    "Id" integer NOT NULL,
    "UserId" uuid NOT NULL,
    "ClaimType" text,
    "ClaimValue" text
);


--
-- Name: user_claims_Id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.user_claims ALTER COLUMN "Id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."user_claims_Id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_email_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_email_codes (
    "Id" uuid NOT NULL,
    "UserId" uuid NOT NULL,
    "Email" character varying(320) NOT NULL,
    "Purpose" integer NOT NULL,
    "CodeHash" character varying(128) NOT NULL,
    "RequestedAtUtc" timestamp with time zone NOT NULL,
    "ExpiresAtUtc" timestamp with time zone NOT NULL,
    "ConsumedAtUtc" timestamp with time zone,
    "LastSentAtUtc" timestamp with time zone,
    "SendCount" integer NOT NULL
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    "UserId" uuid NOT NULL,
    "RoleId" uuid NOT NULL
);


--
-- Name: user_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_tokens (
    "UserId" uuid NOT NULL,
    "LoginProvider" text NOT NULL,
    "Name" text NOT NULL,
    "Value" text
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    "Id" uuid NOT NULL,
    "DisplayName" character varying(120),
    "TermsOfUseAccepted" boolean DEFAULT false NOT NULL,
    "TermsOfUseAcceptedAtUtc" timestamp with time zone,
    "TermsOfUseAcceptedVersion" character varying(32),
    "PrivacyPolicyAccepted" boolean DEFAULT false NOT NULL,
    "PrivacyPolicyAcceptedAtUtc" timestamp with time zone,
    "PrivacyPolicyAcceptedVersion" character varying(32),
    "MarketingEmailsEnabled" boolean DEFAULT false NOT NULL,
    "MarketingEmailsUpdatedAtUtc" timestamp with time zone,
    "AvatarUrl" character varying(2048),
    "AvatarFileName" character varying(256),
    "AvatarContentType" character varying(128),
    "AvatarFileSizeBytes" bigint,
    "AvatarUpdatedAtUtc" timestamp with time zone,
    "IsPremium" boolean NOT NULL,
    "IsActive" boolean NOT NULL,
    "CreatedAtUtc" timestamp with time zone NOT NULL,
    "UserName" character varying(256),
    "NormalizedUserName" character varying(256),
    "Email" character varying(256),
    "NormalizedEmail" character varying(256),
    "EmailConfirmed" boolean NOT NULL,
    "PasswordHash" text,
    "SecurityStamp" text,
    "ConcurrencyStamp" text,
    "PhoneNumber" text,
    "PhoneNumberConfirmed" boolean NOT NULL,
    "TwoFactorEnabled" boolean NOT NULL,
    "LockoutEnd" timestamp with time zone,
    "LockoutEnabled" boolean NOT NULL,
    "AccessFailedCount" integer NOT NULL
);


--
-- Data for Name: __EFMigrationsHistory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."__EFMigrationsHistory" ("MigrationId", "ProductVersion") FROM stdin;
20260526173332_BaselineEconomy	10.0.8
20260526173403_BaselineIdentity	10.0.8
20260526173424_BaselineSupportChat	10.0.8
20260526173450_BaselineTemplates	10.0.8
\.


--
-- Data for Name: audit_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_events ("Id", "SubjectUserId", "Action", "Details", "OccurredAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_currency_packs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_currency_packs ("Id", "Code", "DisplayName", "CurrencyCode", "PriceAmount", "GrantedSpark", "BonusSpark", "IsActive", "SortOrder") FROM stdin;
035a027c-807c-4757-93d1-a6d311467a86	starter	Tiny Treat	EUR	6.29	20	0	t	1
10e0f1a3-cfdd-45e1-9ca8-0cdd8f28c931	creator	Happy Pack	USD	14.99	45	0	t	2
245bb85f-a15e-4317-ad39-a7d1c437d2f6	creator	Happy Pack	EUR	13.49	45	0	t	2
770aa4b3-538d-4aad-8818-c95170534565	starter	Tiny Treat	USD	6.99	20	0	t	1
7ccc93eb-26b4-4afb-b20f-3addea814620	viral	Magic Boost	USD	29.99	100	0	t	3
fa7172fb-fd9f-4b62-8644-132ec0103bc6	viral	Magic Boost	EUR	26.99	100	0	t	3
\.


--
-- Data for Name: economy_payment_customers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_payment_customers ("UserId", "Provider", "ExternalCustomerId", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_payment_provider_configs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_payment_provider_configs ("Id", "Provider", "Platform", "Region", "IsEnabled", "IsRecommended", "IsSelectedByDefault", "RequiresExternalWarning", "RequiresStoreDisclosure", "AllowedFromAppVersion", "ExternalCheckoutAllowed", "BonusTokensPercent", "DisplayLabel", "DisplaySubtitle", "WarningTitle", "WarningMessage", "Mode", "Notes", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
431845e8-9fcb-4bea-905a-03ecc1eeab03	stripe	web	*	t	t	t	f	f	0.0.0	t	0	Stripe	Recommended · secure card checkout	Payment via Stripe	You will continue to Stripe Checkout to complete payment securely.	test	Primary web checkout and customer portal provider.	2026-05-26 17:38:43.389167+00	2026-05-26 17:38:43.389167+00
4c2113bc-f1b3-452e-ad11-da897c116a2a	google_play	android	*	t	f	f	f	t	0.0.0	f	0	Google Play	Store-native checkout for Android devices.	\N	\N	test	Default Google Play Billing flow.	2026-05-26 17:38:43.389167+00	2026-05-26 17:38:43.389167+00
4c6d1b76-6075-438f-bfe3-7f9d2920b657	stripe	android	EU	t	t	t	t	t	1.0.0	t	10	Stripe	Recommended · secure card payment	Payment via Stripe	You will continue to Stripe Checkout to complete payment securely. PetMagic does not store your card details.	test	EU-only alternative billing path for Android eligible regions.	2026-05-26 17:38:43.389167+00	2026-05-26 17:38:43.389167+00
5071c947-4749-473d-acae-27e5db3d1d4c	app_store	ios	*	t	f	f	f	t	0.0.0	f	0	App Store	Store-native checkout for iPhone and iPad.	\N	\N	test	Default App Store in-app subscription flow.	2026-05-26 17:38:43.389167+00	2026-05-26 17:38:43.389167+00
ebcb6676-4e22-425f-92a6-af49611c3ba2	stripe	ios	EU	t	t	t	t	t	1.0.0	t	10	Stripe	Recommended · secure card payment	Payment via Stripe	You will continue to Stripe Checkout to complete payment securely. PetMagic does not store your card details.	test	EU-only external checkout path for iOS pending legal review.	2026-05-26 17:38:43.389167+00	2026-05-26 17:38:43.389167+00
\.


--
-- Data for Name: economy_processed_webhook_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_processed_webhook_events ("Id", "Provider", "EventId", "EventType", "ProcessedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_purchase_orders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_purchase_orders ("Id", "UserId", "PackId", "SavedPaymentMethodId", "PaymentProvider", "Status", "PriceAmount", "CurrencyCode", "SparkToGrant", "ExternalPaymentId", "CheckoutUrl", "CreatedAtUtc", "ConfirmedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_redeem_code_redemptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_redeem_code_redemptions ("Id", "RedeemCodeId", "UserId", "RewardKind", "RewardValue", "WalletLedgerEntryId", "PremiumExpiresAtUtc", "RedeemedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_redeem_codes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_redeem_codes ("Id", "Code", "CodeHash", "CodePrefix", "Description", "CampaignName", "CampaignChannel", "MinimumSuccessfulPurchases", "CreatedBy", "RewardKind", "RewardValue", "MaxRedemptions", "MaxRedemptionsPerUser", "RedeemedCount", "IsActive", "StartsAtUtc", "ExpiresAtUtc", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_referral_attributions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_referral_attributions ("Id", "ReferrerUserId", "RefereeUserId", "ReferrerCode", "Status", "RewardSpark", "ReferrerLedgerEntryId", "RefereeLedgerEntryId", "CreatedAtUtc", "UpdatedAtUtc", "QualifiedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_referral_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_referral_profiles ("UserId", "Code", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_saved_payment_methods; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_saved_payment_methods ("Id", "UserId", "Provider", "ExternalPaymentMethodId", "Brand", "Last4", "ExpMonth", "ExpYear", "IsDefault", "IsActive", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_subscription_event_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_subscription_event_logs ("Id", "UserId", "UserSubscriptionId", "Provider", "EventType", "Status", "ExternalEventId", "ExternalSubscriptionId", "PayloadJson", "CreatedAtUtc", "ProcessedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_subscription_plans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_subscription_plans ("Id", "Name", "BillingPeriod", "PriceAmount", "CurrencyCode", "MonthlyTokenLimit", "IsRecommended", "IsActive", "AppleProductId", "GoogleProductId", "StripePriceId", "DisplayOrder", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
monthly	PetMagic Premium Monthly	monthly	14.99	USD	500	f	t	com.petmagic.app.premium.monthly	com.petmagic.app.premium.monthly	\N	1	2026-05-26 17:38:43.155371+00	2026-05-26 17:38:43.155371+00
yearly	PetMagic Premium Yearly	yearly	99.99	USD	1000	t	t	com.petmagic.app.premium.yearly	com.petmagic.app.premium.yearly	\N	2	2026-05-26 17:38:43.155371+00	2026-05-26 17:38:43.155371+00
\.


--
-- Data for Name: economy_user_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_user_subscriptions ("Id", "UserId", "Provider", "PurchaseChannel", "Region", "PlanId", "Status", "ExternalCustomerId", "ExternalSubscriptionId", "ExternalTransactionId", "CurrentPeriodStartUtc", "CurrentPeriodEndUtc", "CancelAtPeriodEnd", "MonthlyTokenLimit", "MonthlyTokensGranted", "LastTokenGrantAtUtc", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_wallet_ledger; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_wallet_ledger ("Id", "UserId", "Delta", "BalanceAfter", "Source", "Reason", "CreatedAtUtc") FROM stdin;
\.


--
-- Data for Name: economy_wallets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.economy_wallets ("UserId", "Balance", "LastWeeklyGrantAtUtc", "AdRewardWindowStartedAtUtc", "AdRewardsClaimedInWindow", "UpdatedAtUtc") FROM stdin;
\.


--
-- Data for Name: email_dispatch_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.email_dispatch_jobs ("Id", "UserId", "RecipientEmail", "Kind", "Status", "Subject", "HtmlBody", "TextBody", "AttemptCount", "QueuedAtUtc", "UpdatedAtUtc", "LastAttemptAtUtc", "NextAttemptAtUtc", "SentAtUtc", "FailureCode", "FailureMessage") FROM stdin;
\.


--
-- Data for Name: external_logins; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.external_logins ("LoginProvider", "ProviderKey", "ProviderDisplayName", "UserId") FROM stdin;
\.


--
-- Data for Name: refresh_token_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.refresh_token_sessions ("Id", "UserId", "TokenHash", "CreatedAtUtc", "ExpiresAtUtc", "RevokedAtUtc") FROM stdin;
\.


--
-- Data for Name: role_claims; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.role_claims ("Id", "RoleId", "ClaimType", "ClaimValue") FROM stdin;
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.roles ("Id", "Name", "NormalizedName", "ConcurrencyStamp") FROM stdin;
019e655e-10ab-7e61-a9a9-6b2b3c0ca6e0	User	USER	11595fb7-f965-4f50-803e-7b44fb77abb4
019e655e-10d8-72e7-a32a-78fbcaad72a8	Moderator	MODERATOR	689e94db-43ea-4204-8917-2d7adb37fb3c
019e655e-10dd-7e4e-80e5-40045fd01dab	Admin	ADMIN	7f2871b9-2705-4493-b311-abda82c3373e
\.


--
-- Data for Name: support_conversations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.support_conversations ("Id", "InitiatorUserId", "AssignedAdminId", "Status", "Priority", "CreatedAtUtc", "UpdatedAtUtc", "LastMessageAtUtc", "ResolvedAtUtc") FROM stdin;
\.


--
-- Data for Name: support_messages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.support_messages ("Id", "ConversationId", "SenderUserId", "IsFromAdmin", "Body", "AttachmentUrl", "AttachmentFileName", "AttachmentContentType", "AttachmentFileSizeBytes", "AttachmentUploadStatus", "AttachmentUploadErrorCode", "ReadAtUtc", "CreatedAtUtc") FROM stdin;
\.


--
-- Data for Name: support_reply_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.support_reply_templates ("Id", "Title", "Body", "IsEnabled", "SortOrder", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
2ccf484f-4c97-461b-89b3-244a49df9fb8	Подтвердить получение	Спасибо, мы получили ваше обращение и уже взяли его в работу. Вернемся с обновлением как можно скорее.	t	10	2026-05-26 17:38:44.542844+00	2026-05-26 17:38:44.542844+00
3f4651fa-d99f-41a6-ba35-24fbefbdf412	Запросить детали	Чтобы быстрее разобраться, пришлите, пожалуйста, что именно вы делали перед проблемой и когда это произошло. Если есть скриншот или текст ошибки, тоже поможет.	t	30	2026-05-26 17:38:44.542844+00	2026-05-26 17:38:44.542844+00
92d3bf4c-9249-43ec-8d52-da79c9324ad5	Идет проверка	Мы уже проверяем ситуацию у себя. Как только подтвердим причину или найдем обходное решение, сразу напишем вам.	t	20	2026-05-26 17:38:44.542844+00	2026-05-26 17:38:44.542844+00
\.


--
-- Data for Name: templates_analytics_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_analytics_events ("Id", "TemplateId", "UserId", "GenerationId", "EventType", "Source", "DeviceClass", "CountryCode", "FeedbackMessage", "CreatedAtUtc") FROM stdin;
\.


--
-- Data for Name: templates_assets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_assets ("Id", "TemplateId", "AssetKind", "Url", "FileName", "ContentType", "FileSizeBytes", "DurationSeconds") FROM stdin;
4bc4d241-31ea-434b-a557-61292b8a7bfb	39c5f7a0-74ae-4de6-84f4-82b842d63fa0	1	https://cdn.petmagic.dev/templates/viral-dance-preview.mp4	viral-dance-preview.mp4	video/mp4	\N	7.5
5bd7da22-fed0-4205-8230-752c81d0b415	9ca5be83-5919-491e-95fe-8ab5c3772232	1	https://cdn.petmagic.dev/templates/cozy-portrait-preview.jpg	cozy-portrait-preview.jpg	image/jpeg	\N	\N
7be8fa3a-d5b9-4c9a-a43a-c0c88fbb1ff5	39c5f7a0-74ae-4de6-84f4-82b842d63fa0	2	https://cdn.petmagic.dev/templates/viral-dance-reference.mp4	viral-dance-reference.mp4	video/mp4	\N	7.5
\.


--
-- Data for Name: templates_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_categories ("Id", "Name", "NormalizedName", "IsArchived", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
667d3514-6549-4b18-8427-a0f08503ba91	Portrait	PORTRAIT	f	2026-05-26 17:38:45.04998+00	2026-05-26 17:38:45.04998+00
a5b2b18a-5093-4144-9489-947f1690e998	Dance	DANCE	f	2026-05-26 17:38:45.04998+00	2026-05-26 17:38:45.04998+00
\.


--
-- Data for Name: templates_generation_feedback; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_generation_feedback ("Id", "GenerationId", "UserId", "TemplateId", "Rating", "SelectedReasons", "Comment", "InputPhotoQualityScore", "ModelUsed", "GenerationDurationSeconds", "ProviderRequestId", "CreatedAtUtc") FROM stdin;
\.


--
-- Data for Name: templates_generation_jobs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_generation_jobs ("Id", "UserId", "TemplateId", "Status", "TokenCost", "SourceImageUrl", "SourceImageFileName", "SourceImageContentType", "SourceImageFileSizeBytes", "NormalizedImageUrl", "ReferenceMotionUrl", "OutputUrl", "UsedPreprocessingModel", "UsedKlingModel", "PreprocessingProviderRequestId", "PreprocessingInferenceTimeSeconds", "MotionProviderRequestId", "MotionInferenceTimeSeconds", "OutputVideoDurationSeconds", "MotionProviderCostUsd", "PreprocessingCompletedAtUtc", "MotionGenerationCompletedAtUtc", "MediaImportCompletedAtUtc", "AttemptCount", "FailureCode", "FailureMessage", "CreatedAtUtc", "QueuedAtUtc", "UpdatedAtUtc", "LastAttemptAtUtc", "ChargedAtUtc", "RefundedAtUtc", "RefundAttemptCount", "RefundLastErrorCode", "RefundLastAttemptedAtUtc", "StartedAtUtc", "CompletedAtUtc", "ResultViewedAtUtc", "UserMediaDeletedAtUtc", "LastUserMediaCleanupAttemptAtUtc", "UserMediaCleanupFailureCode") FROM stdin;
\.


--
-- Data for Name: templates_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_items ("Id", "TemplateType", "Title", "ShortDescription", "PetPhotoRequirements", "Category", "Tags", "IsPremium", "TokenCost", "Status", "PromoBadgeMode", "MusicDescription", "ReferenceVideoDurationSeconds", "CharacterOrientation", "ImageModel", "ImagePrompt", "PreprocessingModel", "PreprocessingPrompt", "KlingModel", "KlingPrompt", "KeepOriginalSound", "CreatedAtUtc", "UpdatedAtUtc") FROM stdin;
39c5f7a0-74ae-4de6-84f4-82b842d63fa0	2	Viral Dance	Premium motion-control template stub with calculated orientation.	Full body visible\nPet facing camera\nNo cropped head or legs	Dance	viral,dance	t	60	2	0	Upbeat meme dance track	7.5	1	\N	\N	openai/gpt-image-2/edit	Keep the same pet, same face, same fur, same colors, same background, same lighting and camera angle. Adjust the pet into an upright pose standing on its two hind legs like a human, with the front paws naturally positioned like arms. Make the full body clearly visible and suitable for motion transfer. Do not change the pet’s identity, breed, facial features, background, or image style.	fal-ai/kling-video/v3/pro/motion-control	A cute pet performing a funny viral dance, smooth animation, high quality.	t	2026-05-26 17:38:45.04998+00	2026-05-26 17:38:45.04998+00
9ca5be83-5919-491e-95fe-8ab5c3772232	1	Cozy Portrait	Placeholder image template card for admin and public catalog flows.	One pet in the photo\nClear face\nGood lighting	Portrait	cozy,portrait	f	20	2	0	\N	\N	\N	openai/gpt-image-2/edit	Keep the same pet, same face, same fur, same colors, same eyes, same breed, and the same overall identity. Apply the template style and scene to the uploaded pet photo without replacing the pet with a different animal.	\N	\N	\N	\N	\N	2026-05-26 17:38:45.04998+00	2026-05-26 17:38:45.04998+00
\.


--
-- Data for Name: templates_media_records; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_media_records ("Id", "Url", "FileName", "ContentType", "FileSizeBytes", "Role", "LifecycleState", "TemplateId", "GenerationJobId", "UploadedAtUtc", "ExpiresAtUtc", "AttachedAtUtc", "DeletedAtUtc", "LastCleanupAttemptAtUtc", "FailureCode", "FailureMessage") FROM stdin;
\.


--
-- Data for Name: templates_push_device_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.templates_push_device_tokens ("Id", "UserId", "Token", "Platform", "DeviceId", "AppVersion", "Locale", "CreatedAtUtc", "UpdatedAtUtc", "LastSeenAtUtc", "DisabledAtUtc") FROM stdin;
\.


--
-- Data for Name: user_claims; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_claims ("Id", "UserId", "ClaimType", "ClaimValue") FROM stdin;
\.


--
-- Data for Name: user_email_codes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_email_codes ("Id", "UserId", "Email", "Purpose", "CodeHash", "RequestedAtUtc", "ExpiresAtUtc", "ConsumedAtUtc", "LastSentAtUtc", "SendCount") FROM stdin;
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_roles ("UserId", "RoleId") FROM stdin;
4ac1df4a-eafc-465e-99ad-cefb87de219e	019e655e-10dd-7e4e-80e5-40045fd01dab
\.


--
-- Data for Name: user_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_tokens ("UserId", "LoginProvider", "Name", "Value") FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users ("Id", "DisplayName", "TermsOfUseAccepted", "TermsOfUseAcceptedAtUtc", "TermsOfUseAcceptedVersion", "PrivacyPolicyAccepted", "PrivacyPolicyAcceptedAtUtc", "PrivacyPolicyAcceptedVersion", "MarketingEmailsEnabled", "MarketingEmailsUpdatedAtUtc", "AvatarUrl", "AvatarFileName", "AvatarContentType", "AvatarFileSizeBytes", "AvatarUpdatedAtUtc", "IsPremium", "IsActive", "CreatedAtUtc", "UserName", "NormalizedUserName", "Email", "NormalizedEmail", "EmailConfirmed", "PasswordHash", "SecurityStamp", "ConcurrencyStamp", "PhoneNumber", "PhoneNumberConfirmed", "TwoFactorEnabled", "LockoutEnd", "LockoutEnabled", "AccessFailedCount") FROM stdin;
4ac1df4a-eafc-465e-99ad-cefb87de219e	PetMagic Admin	f	\N	\N	f	\N	\N	f	\N	\N	\N	\N	\N	\N	t	t	2026-05-26 17:38:44.082923+00	admin@petmagic.app	ADMIN@PETMAGIC.APP	admin@petmagic.app	ADMIN@PETMAGIC.APP	t	AQAAAAIAAYagAAAAEFIr1hA3xz1Yqn/JiToyxLrAsR++ZYr1RgRAmy55DphXUskToJBpj/QHX8Zz7EvZ5A==	VELBEPMQEV4RGHU3T4YKXT67P3DU3RJS	b64357a3-4a1a-48db-ba7a-9f505651f01d	\N	f	f	\N	t	0
\.


--
-- Name: role_claims_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."role_claims_Id_seq"', 1, false);


--
-- Name: user_claims_Id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."user_claims_Id_seq"', 1, false);


--
-- Name: __EFMigrationsHistory PK___EFMigrationsHistory; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."__EFMigrationsHistory"
    ADD CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId");


--
-- Name: audit_events PK_audit_events; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT "PK_audit_events" PRIMARY KEY ("Id");


--
-- Name: economy_currency_packs PK_economy_currency_packs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_currency_packs
    ADD CONSTRAINT "PK_economy_currency_packs" PRIMARY KEY ("Id");


--
-- Name: economy_payment_customers PK_economy_payment_customers; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_payment_customers
    ADD CONSTRAINT "PK_economy_payment_customers" PRIMARY KEY ("UserId", "Provider");


--
-- Name: economy_payment_provider_configs PK_economy_payment_provider_configs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_payment_provider_configs
    ADD CONSTRAINT "PK_economy_payment_provider_configs" PRIMARY KEY ("Id");


--
-- Name: economy_processed_webhook_events PK_economy_processed_webhook_events; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_processed_webhook_events
    ADD CONSTRAINT "PK_economy_processed_webhook_events" PRIMARY KEY ("Id");


--
-- Name: economy_purchase_orders PK_economy_purchase_orders; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_purchase_orders
    ADD CONSTRAINT "PK_economy_purchase_orders" PRIMARY KEY ("Id");


--
-- Name: economy_redeem_code_redemptions PK_economy_redeem_code_redemptions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_redeem_code_redemptions
    ADD CONSTRAINT "PK_economy_redeem_code_redemptions" PRIMARY KEY ("Id");


--
-- Name: economy_redeem_codes PK_economy_redeem_codes; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_redeem_codes
    ADD CONSTRAINT "PK_economy_redeem_codes" PRIMARY KEY ("Id");


--
-- Name: economy_referral_attributions PK_economy_referral_attributions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_referral_attributions
    ADD CONSTRAINT "PK_economy_referral_attributions" PRIMARY KEY ("Id");


--
-- Name: economy_referral_profiles PK_economy_referral_profiles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_referral_profiles
    ADD CONSTRAINT "PK_economy_referral_profiles" PRIMARY KEY ("UserId");


--
-- Name: economy_saved_payment_methods PK_economy_saved_payment_methods; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_saved_payment_methods
    ADD CONSTRAINT "PK_economy_saved_payment_methods" PRIMARY KEY ("Id");


--
-- Name: economy_subscription_event_logs PK_economy_subscription_event_logs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_subscription_event_logs
    ADD CONSTRAINT "PK_economy_subscription_event_logs" PRIMARY KEY ("Id");


--
-- Name: economy_subscription_plans PK_economy_subscription_plans; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_subscription_plans
    ADD CONSTRAINT "PK_economy_subscription_plans" PRIMARY KEY ("Id");


--
-- Name: economy_user_subscriptions PK_economy_user_subscriptions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_user_subscriptions
    ADD CONSTRAINT "PK_economy_user_subscriptions" PRIMARY KEY ("Id");


--
-- Name: economy_wallet_ledger PK_economy_wallet_ledger; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_wallet_ledger
    ADD CONSTRAINT "PK_economy_wallet_ledger" PRIMARY KEY ("Id");


--
-- Name: economy_wallets PK_economy_wallets; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economy_wallets
    ADD CONSTRAINT "PK_economy_wallets" PRIMARY KEY ("UserId");


--
-- Name: email_dispatch_jobs PK_email_dispatch_jobs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_dispatch_jobs
    ADD CONSTRAINT "PK_email_dispatch_jobs" PRIMARY KEY ("Id");


--
-- Name: external_logins PK_external_logins; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_logins
    ADD CONSTRAINT "PK_external_logins" PRIMARY KEY ("LoginProvider", "ProviderKey");


--
-- Name: refresh_token_sessions PK_refresh_token_sessions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token_sessions
    ADD CONSTRAINT "PK_refresh_token_sessions" PRIMARY KEY ("Id");


--
-- Name: role_claims PK_role_claims; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_claims
    ADD CONSTRAINT "PK_role_claims" PRIMARY KEY ("Id");


--
-- Name: roles PK_roles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT "PK_roles" PRIMARY KEY ("Id");


--
-- Name: support_conversations PK_support_conversations; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_conversations
    ADD CONSTRAINT "PK_support_conversations" PRIMARY KEY ("Id");


--
-- Name: support_messages PK_support_messages; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_messages
    ADD CONSTRAINT "PK_support_messages" PRIMARY KEY ("Id");


--
-- Name: support_reply_templates PK_support_reply_templates; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_reply_templates
    ADD CONSTRAINT "PK_support_reply_templates" PRIMARY KEY ("Id");


--
-- Name: templates_analytics_events PK_templates_analytics_events; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_analytics_events
    ADD CONSTRAINT "PK_templates_analytics_events" PRIMARY KEY ("Id");


--
-- Name: templates_assets PK_templates_assets; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_assets
    ADD CONSTRAINT "PK_templates_assets" PRIMARY KEY ("Id");


--
-- Name: templates_categories PK_templates_categories; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_categories
    ADD CONSTRAINT "PK_templates_categories" PRIMARY KEY ("Id");


--
-- Name: templates_generation_feedback PK_templates_generation_feedback; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_generation_feedback
    ADD CONSTRAINT "PK_templates_generation_feedback" PRIMARY KEY ("Id");


--
-- Name: templates_generation_jobs PK_templates_generation_jobs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_generation_jobs
    ADD CONSTRAINT "PK_templates_generation_jobs" PRIMARY KEY ("Id");


--
-- Name: templates_items PK_templates_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_items
    ADD CONSTRAINT "PK_templates_items" PRIMARY KEY ("Id");


--
-- Name: templates_media_records PK_templates_media_records; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_media_records
    ADD CONSTRAINT "PK_templates_media_records" PRIMARY KEY ("Id");


--
-- Name: templates_push_device_tokens PK_templates_push_device_tokens; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_push_device_tokens
    ADD CONSTRAINT "PK_templates_push_device_tokens" PRIMARY KEY ("Id");


--
-- Name: user_claims PK_user_claims; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_claims
    ADD CONSTRAINT "PK_user_claims" PRIMARY KEY ("Id");


--
-- Name: user_email_codes PK_user_email_codes; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_email_codes
    ADD CONSTRAINT "PK_user_email_codes" PRIMARY KEY ("Id");


--
-- Name: user_roles PK_user_roles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT "PK_user_roles" PRIMARY KEY ("UserId", "RoleId");


--
-- Name: user_tokens PK_user_tokens; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tokens
    ADD CONSTRAINT "PK_user_tokens" PRIMARY KEY ("UserId", "LoginProvider", "Name");


--
-- Name: users PK_users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT "PK_users" PRIMARY KEY ("Id");


--
-- Name: EmailIndex; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "EmailIndex" ON public.users USING btree ("NormalizedEmail");


--
-- Name: IX_audit_events_OccurredAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_audit_events_OccurredAtUtc" ON public.audit_events USING btree ("OccurredAtUtc");


--
-- Name: IX_economy_currency_packs_Code_CurrencyCode; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_currency_packs_Code_CurrencyCode" ON public.economy_currency_packs USING btree ("Code", "CurrencyCode");


--
-- Name: IX_economy_currency_packs_CurrencyCode_IsActive_SortOrder; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_currency_packs_CurrencyCode_IsActive_SortOrder" ON public.economy_currency_packs USING btree ("CurrencyCode", "IsActive", "SortOrder");


--
-- Name: IX_economy_payment_customers_Provider_ExternalCustomerId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_payment_customers_Provider_ExternalCustomerId" ON public.economy_payment_customers USING btree ("Provider", "ExternalCustomerId");


--
-- Name: IX_economy_payment_provider_configs_Platform_IsEnabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_payment_provider_configs_Platform_IsEnabled" ON public.economy_payment_provider_configs USING btree ("Platform", "IsEnabled");


--
-- Name: IX_economy_payment_provider_configs_Provider_Platform_Region; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_payment_provider_configs_Provider_Platform_Region" ON public.economy_payment_provider_configs USING btree ("Provider", "Platform", "Region");


--
-- Name: IX_economy_processed_webhook_events_ProcessedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_processed_webhook_events_ProcessedAtUtc" ON public.economy_processed_webhook_events USING btree ("ProcessedAtUtc");


--
-- Name: IX_economy_processed_webhook_events_Provider_EventId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_processed_webhook_events_Provider_EventId" ON public.economy_processed_webhook_events USING btree ("Provider", "EventId");


--
-- Name: IX_economy_purchase_orders_PaymentProvider_ExternalPaymentId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_purchase_orders_PaymentProvider_ExternalPaymentId" ON public.economy_purchase_orders USING btree ("PaymentProvider", "ExternalPaymentId");


--
-- Name: IX_economy_purchase_orders_SavedPaymentMethodId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_purchase_orders_SavedPaymentMethodId" ON public.economy_purchase_orders USING btree ("SavedPaymentMethodId");


--
-- Name: IX_economy_purchase_orders_UserId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_purchase_orders_UserId_CreatedAtUtc" ON public.economy_purchase_orders USING btree ("UserId", "CreatedAtUtc");


--
-- Name: IX_economy_redeem_code_redemptions_RedeemCodeId_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_redeem_code_redemptions_RedeemCodeId_UserId" ON public.economy_redeem_code_redemptions USING btree ("RedeemCodeId", "UserId");


--
-- Name: IX_economy_redeem_code_redemptions_UserId_RedeemedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_redeem_code_redemptions_UserId_RedeemedAtUtc" ON public.economy_redeem_code_redemptions USING btree ("UserId", "RedeemedAtUtc");


--
-- Name: IX_economy_redeem_codes_CodeHash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_redeem_codes_CodeHash" ON public.economy_redeem_codes USING btree ("CodeHash");


--
-- Name: IX_economy_redeem_codes_IsActive_ExpiresAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_redeem_codes_IsActive_ExpiresAtUtc" ON public.economy_redeem_codes USING btree ("IsActive", "ExpiresAtUtc");


--
-- Name: IX_economy_referral_attributions_RefereeUserId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_referral_attributions_RefereeUserId" ON public.economy_referral_attributions USING btree ("RefereeUserId");


--
-- Name: IX_economy_referral_attributions_ReferrerUserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_referral_attributions_ReferrerUserId" ON public.economy_referral_attributions USING btree ("ReferrerUserId");


--
-- Name: IX_economy_referral_attributions_ReferrerUserId_Status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_referral_attributions_ReferrerUserId_Status" ON public.economy_referral_attributions USING btree ("ReferrerUserId", "Status");


--
-- Name: IX_economy_referral_profiles_Code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_referral_profiles_Code" ON public.economy_referral_profiles USING btree ("Code");


--
-- Name: IX_economy_saved_payment_methods_Provider_ExternalPaymentMetho~; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_saved_payment_methods_Provider_ExternalPaymentMetho~" ON public.economy_saved_payment_methods USING btree ("Provider", "ExternalPaymentMethodId");


--
-- Name: IX_economy_saved_payment_methods_UserId_IsActive_IsDefault; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_saved_payment_methods_UserId_IsActive_IsDefault" ON public.economy_saved_payment_methods USING btree ("UserId", "IsActive", "IsDefault");


--
-- Name: IX_economy_subscription_event_logs_Provider_ExternalEventId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_subscription_event_logs_Provider_ExternalEventId" ON public.economy_subscription_event_logs USING btree ("Provider", "ExternalEventId");


--
-- Name: IX_economy_subscription_event_logs_Provider_ExternalSubscripti~; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_subscription_event_logs_Provider_ExternalSubscripti~" ON public.economy_subscription_event_logs USING btree ("Provider", "ExternalSubscriptionId");


--
-- Name: IX_economy_subscription_event_logs_UserId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_subscription_event_logs_UserId_CreatedAtUtc" ON public.economy_subscription_event_logs USING btree ("UserId", "CreatedAtUtc");


--
-- Name: IX_economy_subscription_plans_IsActive_DisplayOrder; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_subscription_plans_IsActive_DisplayOrder" ON public.economy_subscription_plans USING btree ("IsActive", "DisplayOrder");


--
-- Name: IX_economy_user_subscriptions_Provider_ExternalSubscriptionId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_economy_user_subscriptions_Provider_ExternalSubscriptionId" ON public.economy_user_subscriptions USING btree ("Provider", "ExternalSubscriptionId");


--
-- Name: IX_economy_user_subscriptions_UserId_Status_CurrentPeriodEndUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_user_subscriptions_UserId_Status_CurrentPeriodEndUtc" ON public.economy_user_subscriptions USING btree ("UserId", "Status", "CurrentPeriodEndUtc");


--
-- Name: IX_economy_user_subscriptions_UserId_UpdatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_user_subscriptions_UserId_UpdatedAtUtc" ON public.economy_user_subscriptions USING btree ("UserId", "UpdatedAtUtc");


--
-- Name: IX_economy_wallet_ledger_UserId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_wallet_ledger_UserId_CreatedAtUtc" ON public.economy_wallet_ledger USING btree ("UserId", "CreatedAtUtc");


--
-- Name: IX_economy_wallets_UpdatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_economy_wallets_UpdatedAtUtc" ON public.economy_wallets USING btree ("UpdatedAtUtc");


--
-- Name: IX_email_dispatch_jobs_NextAttemptAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_email_dispatch_jobs_NextAttemptAtUtc" ON public.email_dispatch_jobs USING btree ("NextAttemptAtUtc");


--
-- Name: IX_email_dispatch_jobs_Status_QueuedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_email_dispatch_jobs_Status_QueuedAtUtc" ON public.email_dispatch_jobs USING btree ("Status", "QueuedAtUtc");


--
-- Name: IX_email_dispatch_jobs_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_email_dispatch_jobs_UserId" ON public.email_dispatch_jobs USING btree ("UserId");


--
-- Name: IX_external_logins_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_external_logins_UserId" ON public.external_logins USING btree ("UserId");


--
-- Name: IX_refresh_token_sessions_TokenHash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_refresh_token_sessions_TokenHash" ON public.refresh_token_sessions USING btree ("TokenHash");


--
-- Name: IX_refresh_token_sessions_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_refresh_token_sessions_UserId" ON public.refresh_token_sessions USING btree ("UserId");


--
-- Name: IX_role_claims_RoleId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_role_claims_RoleId" ON public.role_claims USING btree ("RoleId");


--
-- Name: IX_support_conversations_AssignedAdminId_Status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_support_conversations_AssignedAdminId_Status" ON public.support_conversations USING btree ("AssignedAdminId", "Status");


--
-- Name: IX_support_conversations_InitiatorUserId; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_support_conversations_InitiatorUserId" ON public.support_conversations USING btree ("InitiatorUserId");


--
-- Name: IX_support_conversations_LastMessageAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_support_conversations_LastMessageAtUtc" ON public.support_conversations USING btree ("LastMessageAtUtc");


--
-- Name: IX_support_conversations_Status_UpdatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_support_conversations_Status_UpdatedAtUtc" ON public.support_conversations USING btree ("Status", "UpdatedAtUtc");


--
-- Name: IX_support_messages_ConversationId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_support_messages_ConversationId_CreatedAtUtc" ON public.support_messages USING btree ("ConversationId", "CreatedAtUtc");


--
-- Name: IX_support_messages_ConversationId_IsFromAdmin_ReadAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_support_messages_ConversationId_IsFromAdmin_ReadAtUtc" ON public.support_messages USING btree ("ConversationId", "IsFromAdmin", "ReadAtUtc");


--
-- Name: IX_support_reply_templates_SortOrder_IsEnabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_support_reply_templates_SortOrder_IsEnabled" ON public.support_reply_templates USING btree ("SortOrder", "IsEnabled");


--
-- Name: IX_templates_analytics_events_TemplateId_CountryCode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_analytics_events_TemplateId_CountryCode" ON public.templates_analytics_events USING btree ("TemplateId", "CountryCode");


--
-- Name: IX_templates_analytics_events_TemplateId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_analytics_events_TemplateId_CreatedAtUtc" ON public.templates_analytics_events USING btree ("TemplateId", "CreatedAtUtc");


--
-- Name: IX_templates_analytics_events_TemplateId_DeviceClass; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_analytics_events_TemplateId_DeviceClass" ON public.templates_analytics_events USING btree ("TemplateId", "DeviceClass");


--
-- Name: IX_templates_analytics_events_TemplateId_EventType_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_analytics_events_TemplateId_EventType_CreatedAtUtc" ON public.templates_analytics_events USING btree ("TemplateId", "EventType", "CreatedAtUtc");


--
-- Name: IX_templates_analytics_events_TemplateId_Source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_analytics_events_TemplateId_Source" ON public.templates_analytics_events USING btree ("TemplateId", "Source");


--
-- Name: IX_templates_assets_TemplateId_AssetKind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_templates_assets_TemplateId_AssetKind" ON public.templates_assets USING btree ("TemplateId", "AssetKind");


--
-- Name: IX_templates_categories_IsArchived_Name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_categories_IsArchived_Name" ON public.templates_categories USING btree ("IsArchived", "Name");


--
-- Name: IX_templates_categories_NormalizedName; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_templates_categories_NormalizedName" ON public.templates_categories USING btree ("NormalizedName");


--
-- Name: IX_templates_generation_feedback_GenerationId_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_feedback_GenerationId_UserId" ON public.templates_generation_feedback USING btree ("GenerationId", "UserId");


--
-- Name: IX_templates_generation_feedback_TemplateId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_feedback_TemplateId_CreatedAtUtc" ON public.templates_generation_feedback USING btree ("TemplateId", "CreatedAtUtc");


--
-- Name: IX_templates_generation_feedback_TemplateId_Rating_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_feedback_TemplateId_Rating_CreatedAtUtc" ON public.templates_generation_feedback USING btree ("TemplateId", "Rating", "CreatedAtUtc");


--
-- Name: IX_templates_generation_jobs_LastUserMediaCleanupAttemptAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_LastUserMediaCleanupAttemptAtUtc" ON public.templates_generation_jobs USING btree ("LastUserMediaCleanupAttemptAtUtc");


--
-- Name: IX_templates_generation_jobs_Status_CompletedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_Status_CompletedAtUtc" ON public.templates_generation_jobs USING btree ("Status", "CompletedAtUtc");


--
-- Name: IX_templates_generation_jobs_Status_QueuedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_Status_QueuedAtUtc" ON public.templates_generation_jobs USING btree ("Status", "QueuedAtUtc");


--
-- Name: IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAt~; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_Status_RefundedAtUtc_RefundLastAt~" ON public.templates_generation_jobs USING btree ("Status", "RefundedAtUtc", "RefundLastAttemptedAtUtc");


--
-- Name: IX_templates_generation_jobs_TemplateId_Status_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_TemplateId_Status_CreatedAtUtc" ON public.templates_generation_jobs USING btree ("TemplateId", "Status", "CreatedAtUtc");


--
-- Name: IX_templates_generation_jobs_UserId_CreatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_UserId_CreatedAtUtc" ON public.templates_generation_jobs USING btree ("UserId", "CreatedAtUtc");


--
-- Name: IX_templates_generation_jobs_UserId_Status_ResultViewedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_UserId_Status_ResultViewedAtUtc" ON public.templates_generation_jobs USING btree ("UserId", "Status", "ResultViewedAtUtc");


--
-- Name: IX_templates_generation_jobs_UserMediaDeletedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_generation_jobs_UserMediaDeletedAtUtc" ON public.templates_generation_jobs USING btree ("UserMediaDeletedAtUtc");


--
-- Name: IX_templates_items_Status_Category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_items_Status_Category" ON public.templates_items USING btree ("Status", "Category");


--
-- Name: IX_templates_items_TemplateType_Status_UpdatedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_items_TemplateType_Status_UpdatedAtUtc" ON public.templates_items USING btree ("TemplateType", "Status", "UpdatedAtUtc");


--
-- Name: IX_templates_media_records_GenerationJobId_LifecycleState; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_media_records_GenerationJobId_LifecycleState" ON public.templates_media_records USING btree ("GenerationJobId", "LifecycleState");


--
-- Name: IX_templates_media_records_LifecycleState_ExpiresAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_media_records_LifecycleState_ExpiresAtUtc" ON public.templates_media_records USING btree ("LifecycleState", "ExpiresAtUtc");


--
-- Name: IX_templates_media_records_TemplateId_LifecycleState; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_media_records_TemplateId_LifecycleState" ON public.templates_media_records USING btree ("TemplateId", "LifecycleState");


--
-- Name: IX_templates_media_records_Url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_templates_media_records_Url" ON public.templates_media_records USING btree ("Url");


--
-- Name: IX_templates_push_device_tokens_Token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_templates_push_device_tokens_Token" ON public.templates_push_device_tokens USING btree ("Token");


--
-- Name: IX_templates_push_device_tokens_UserId_DisabledAtUtc_LastSeenA~; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_templates_push_device_tokens_UserId_DisabledAtUtc_LastSeenA~" ON public.templates_push_device_tokens USING btree ("UserId", "DisabledAtUtc", "LastSeenAtUtc");


--
-- Name: IX_user_claims_UserId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_user_claims_UserId" ON public.user_claims USING btree ("UserId");


--
-- Name: IX_user_email_codes_Email_Purpose_ConsumedAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_user_email_codes_Email_Purpose_ConsumedAtUtc" ON public.user_email_codes USING btree ("Email", "Purpose", "ConsumedAtUtc");


--
-- Name: IX_user_email_codes_UserId_Purpose_ExpiresAtUtc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_user_email_codes_UserId_Purpose_ExpiresAtUtc" ON public.user_email_codes USING btree ("UserId", "Purpose", "ExpiresAtUtc");


--
-- Name: IX_user_roles_RoleId; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "IX_user_roles_RoleId" ON public.user_roles USING btree ("RoleId");


--
-- Name: IX_users_Email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "IX_users_Email" ON public.users USING btree ("Email");


--
-- Name: RoleNameIndex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "RoleNameIndex" ON public.roles USING btree ("NormalizedName");


--
-- Name: UserNameIndex; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "UserNameIndex" ON public.users USING btree ("NormalizedUserName");


--
-- Name: external_logins FK_external_logins_users_UserId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_logins
    ADD CONSTRAINT "FK_external_logins_users_UserId" FOREIGN KEY ("UserId") REFERENCES public.users("Id") ON DELETE CASCADE;


--
-- Name: role_claims FK_role_claims_roles_RoleId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_claims
    ADD CONSTRAINT "FK_role_claims_roles_RoleId" FOREIGN KEY ("RoleId") REFERENCES public.roles("Id") ON DELETE CASCADE;


--
-- Name: support_messages FK_support_messages_support_conversations_ConversationId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_messages
    ADD CONSTRAINT "FK_support_messages_support_conversations_ConversationId" FOREIGN KEY ("ConversationId") REFERENCES public.support_conversations("Id") ON DELETE CASCADE;


--
-- Name: templates_analytics_events FK_templates_analytics_events_templates_items_TemplateId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_analytics_events
    ADD CONSTRAINT "FK_templates_analytics_events_templates_items_TemplateId" FOREIGN KEY ("TemplateId") REFERENCES public.templates_items("Id") ON DELETE CASCADE;


--
-- Name: templates_assets FK_templates_assets_templates_items_TemplateId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_assets
    ADD CONSTRAINT "FK_templates_assets_templates_items_TemplateId" FOREIGN KEY ("TemplateId") REFERENCES public.templates_items("Id") ON DELETE CASCADE;


--
-- Name: templates_generation_feedback FK_templates_generation_feedback_templates_generation_jobs_Gen~; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_generation_feedback
    ADD CONSTRAINT "FK_templates_generation_feedback_templates_generation_jobs_Gen~" FOREIGN KEY ("GenerationId") REFERENCES public.templates_generation_jobs("Id") ON DELETE CASCADE;


--
-- Name: templates_generation_feedback FK_templates_generation_feedback_templates_items_TemplateId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_generation_feedback
    ADD CONSTRAINT "FK_templates_generation_feedback_templates_items_TemplateId" FOREIGN KEY ("TemplateId") REFERENCES public.templates_items("Id") ON DELETE CASCADE;


--
-- Name: templates_generation_jobs FK_templates_generation_jobs_templates_items_TemplateId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_generation_jobs
    ADD CONSTRAINT "FK_templates_generation_jobs_templates_items_TemplateId" FOREIGN KEY ("TemplateId") REFERENCES public.templates_items("Id") ON DELETE CASCADE;


--
-- Name: templates_media_records FK_templates_media_records_templates_generation_jobs_Generatio~; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_media_records
    ADD CONSTRAINT "FK_templates_media_records_templates_generation_jobs_Generatio~" FOREIGN KEY ("GenerationJobId") REFERENCES public.templates_generation_jobs("Id") ON DELETE SET NULL;


--
-- Name: templates_media_records FK_templates_media_records_templates_items_TemplateId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.templates_media_records
    ADD CONSTRAINT "FK_templates_media_records_templates_items_TemplateId" FOREIGN KEY ("TemplateId") REFERENCES public.templates_items("Id") ON DELETE SET NULL;


--
-- Name: user_claims FK_user_claims_users_UserId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_claims
    ADD CONSTRAINT "FK_user_claims_users_UserId" FOREIGN KEY ("UserId") REFERENCES public.users("Id") ON DELETE CASCADE;


--
-- Name: user_roles FK_user_roles_roles_RoleId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT "FK_user_roles_roles_RoleId" FOREIGN KEY ("RoleId") REFERENCES public.roles("Id") ON DELETE CASCADE;


--
-- Name: user_roles FK_user_roles_users_UserId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT "FK_user_roles_users_UserId" FOREIGN KEY ("UserId") REFERENCES public.users("Id") ON DELETE CASCADE;


--
-- Name: user_tokens FK_user_tokens_users_UserId; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tokens
    ADD CONSTRAINT "FK_user_tokens_users_UserId" FOREIGN KEY ("UserId") REFERENCES public.users("Id") ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict pienfmtHhgPrJKla11wDhNHcaMtilQQBIv2WiYugAnErjJkurA87mhRem5s52vu

