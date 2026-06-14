-- Local-only seed helper for watermark monetization manual QA.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v free_user_id="'00000000-0000-0000-0000-000000000001'" \
--     -v no_credit_user_id="'00000000-0000-0000-0000-000000000002'" \
--     -v premium_user_id="'00000000-0000-0000-0000-000000000003'" \
--     -v public_base_url="'http://localhost:5000'" \
--     -f scripts/qa/seed-watermark-manual-qa.sql
--
-- The users must already exist in Identity. Register them through the API or
-- use known local QA users first. This script only seeds wallet balances,
-- completed generation rows, and watermark settings.

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO economy_wallets ("UserId", "Balance", "AdRewardsClaimedInWindow", "UpdatedAtUtc")
VALUES
  (:free_user_id::uuid, 5, 0, now()),
  (:no_credit_user_id::uuid, 0, 0, now()),
  (:premium_user_id::uuid, 5, 0, now())
ON CONFLICT ("UserId") DO UPDATE
SET
  "Balance" = EXCLUDED."Balance",
  "AdRewardsClaimedInWindow" = EXCLUDED."AdRewardsClaimedInWindow",
  "UpdatedAtUtc" = EXCLUDED."UpdatedAtUtc";

INSERT INTO economy_wallet_ledger ("Id", "UserId", "Delta", "BalanceAfter", "Source", "Reason", "CreatedAtUtc")
VALUES
  ('30000000-0000-4000-8000-000000000001', :free_user_id::uuid, 5, 5, 'admin_grant', 'watermark-manual-qa-free-balance', now()),
  ('30000000-0000-4000-8000-000000000002', :premium_user_id::uuid, 5, 5, 'admin_grant', 'watermark-manual-qa-premium-balance', now())
ON CONFLICT ("Id") DO NOTHING;

DELETE FROM templates_generation_watermark_unlocks
WHERE "GenerationJobId" IN (
  '50000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000002',
  '50000000-0000-4000-8000-000000000003',
  '50000000-0000-4000-8000-000000000004',
  '50000000-0000-4000-8000-000000000005');

DELETE FROM templates_analytics_events
WHERE "GenerationId" IN (
  '50000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000002',
  '50000000-0000-4000-8000-000000000003',
  '50000000-0000-4000-8000-000000000004',
  '50000000-0000-4000-8000-000000000005');

DELETE FROM economy_wallet_ledger
WHERE "Source" = 'watermark_unlock'
  AND "Reason" IN (
    'template_watermark_unlock:50000000000040008000000000000001',
    'template_watermark_unlock:50000000000040008000000000000002',
    'template_watermark_unlock:50000000000040008000000000000003',
    'template_watermark_unlock:50000000000040008000000000000004',
    'template_watermark_unlock:50000000000040008000000000000005');

INSERT INTO templates_watermark_settings (
  "Id",
  "Enabled",
  "Text",
  "LogoUrl",
  "Opacity",
  "Position",
  "Size",
  "CostCredits",
  "ApplyToImages",
  "ApplyToVideos",
  "PreviewImageUrl",
  "PreviewVideoFrameUrl",
  "CreatedAtUtc",
  "UpdatedAtUtc")
VALUES (
  '40000000-0000-4000-8000-000000000001',
  true,
  'Made with PetMagic',
  null,
  0.55,
  'bottom-right',
  'small',
  1,
  true,
  true,
  regexp_replace(:public_base_url::text, '/+$', '') || '/templates-media/manual-qa/watermark-preview-image.png',
  regexp_replace(:public_base_url::text, '/+$', '') || '/templates-media/manual-qa/watermark-preview-video-frame.png',
  now(),
  now())
ON CONFLICT ("Id") DO UPDATE
SET
  "Enabled" = EXCLUDED."Enabled",
  "Text" = EXCLUDED."Text",
  "LogoUrl" = EXCLUDED."LogoUrl",
  "Opacity" = EXCLUDED."Opacity",
  "Position" = EXCLUDED."Position",
  "Size" = EXCLUDED."Size",
  "CostCredits" = EXCLUDED."CostCredits",
  "ApplyToImages" = EXCLUDED."ApplyToImages",
  "ApplyToVideos" = EXCLUDED."ApplyToVideos",
  "PreviewImageUrl" = EXCLUDED."PreviewImageUrl",
  "PreviewVideoFrameUrl" = EXCLUDED."PreviewVideoFrameUrl",
  "UpdatedAtUtc" = EXCLUDED."UpdatedAtUtc";

WITH qa_config AS (
  SELECT regexp_replace(:public_base_url::text, '/+$', '') AS public_base_url
),
image_template AS (
  SELECT "Id" FROM templates_items
  WHERE "TemplateType" = 1 AND "Status" = 2
  ORDER BY "CreatedAtUtc", "Id"
  LIMIT 1
),
video_template AS (
  SELECT "Id" FROM templates_items
  WHERE "TemplateType" = 2 AND "Status" = 2
  ORDER BY "CreatedAtUtc", "Id"
  LIMIT 1
),
seed_jobs AS (
  SELECT
    '50000000-0000-4000-8000-000000000001'::uuid AS id,
    :free_user_id::uuid AS user_id,
    (SELECT "Id" FROM image_template) AS template_id,
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/free-image-source.jpg' AS source_url,
    'free-image-source.jpg' AS source_name,
    'image/jpeg' AS source_type,
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/free-image-clean.png' AS clean_url,
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/free-image-watermarked.png' AS watermarked_url,
    true AS watermark_required,
    false AS watermark_removed,
    null::text AS watermark_failure
  UNION ALL
  SELECT
    '50000000-0000-4000-8000-000000000002'::uuid,
    :free_user_id::uuid,
    (SELECT "Id" FROM video_template),
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/free-video-source.jpg',
    'free-video-source.jpg',
    'image/jpeg',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/free-video-clean.mp4',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/free-video-watermarked.mp4',
    true,
    false,
    null::text
  UNION ALL
  SELECT
    '50000000-0000-4000-8000-000000000003'::uuid,
    :no_credit_user_id::uuid,
    (SELECT "Id" FROM image_template),
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/no-credit-source.jpg',
    'no-credit-source.jpg',
    'image/jpeg',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/no-credit-clean.png',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/no-credit-watermarked.png',
    true,
    false,
    null::text
  UNION ALL
  SELECT
    '50000000-0000-4000-8000-000000000004'::uuid,
    :premium_user_id::uuid,
    (SELECT "Id" FROM image_template),
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/premium-image-source.jpg',
    'premium-image-source.jpg',
    'image/jpeg',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/premium-image-clean.png',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/premium-image-watermarked.png',
    true,
    false,
    null::text
  UNION ALL
  SELECT
    '50000000-0000-4000-8000-000000000005'::uuid,
    :free_user_id::uuid,
    (SELECT "Id" FROM image_template),
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/preparing-source.jpg',
    'preparing-source.jpg',
    'image/jpeg',
    (SELECT public_base_url FROM qa_config) || '/templates-media/manual-qa/preparing-clean.png',
    null::text,
    true,
    false,
    'manual_qa_watermark_pending'
)
INSERT INTO templates_generation_jobs (
  "Id",
  "UserId",
  "TemplateId",
  "Status",
  "TokenCost",
  "SourceImageUrl",
  "SourceImageFileName",
  "SourceImageContentType",
  "ResultUrl",
  "WatermarkedResultUrl",
  "IsWatermarkRequired",
  "IsWatermarkRemoved",
  "WatermarkFailureCode",
  "InputSourceType",
  "AttemptCount",
  "RefundAttemptCount",
  "CreatedAtUtc",
  "QueuedAtUtc",
  "StartedAtUtc",
  "CompletedAtUtc",
  "UpdatedAtUtc")
SELECT
  seed_jobs.id,
  seed_jobs.user_id,
  seed_jobs.template_id,
  3,
  0,
  seed_jobs.source_url,
  seed_jobs.source_name,
  seed_jobs.source_type,
  seed_jobs.clean_url,
  seed_jobs.watermarked_url,
  seed_jobs.watermark_required,
  seed_jobs.watermark_removed,
  seed_jobs.watermark_failure,
  'user_upload',
  1,
  0,
  now() - interval '10 minutes',
  now() - interval '10 minutes',
  now() - interval '9 minutes',
  now() - interval '8 minutes',
  now() - interval '8 minutes'
FROM seed_jobs
WHERE seed_jobs.template_id IS NOT NULL
ON CONFLICT ("Id") DO UPDATE
SET
  "UserId" = EXCLUDED."UserId",
  "TemplateId" = EXCLUDED."TemplateId",
  "Status" = EXCLUDED."Status",
  "ResultUrl" = EXCLUDED."ResultUrl",
  "WatermarkedResultUrl" = EXCLUDED."WatermarkedResultUrl",
  "IsWatermarkRequired" = EXCLUDED."IsWatermarkRequired",
  "IsWatermarkRemoved" = EXCLUDED."IsWatermarkRemoved",
  "WatermarkFailureCode" = EXCLUDED."WatermarkFailureCode",
  "RefundAttemptCount" = EXCLUDED."RefundAttemptCount",
  "UpdatedAtUtc" = EXCLUDED."UpdatedAtUtc";

COMMIT;

SELECT 'watermark manual QA seed complete' AS status;
SELECT "Id", "UserId", "ResultUrl", "WatermarkedResultUrl", "IsWatermarkRequired", "IsWatermarkRemoved"
FROM templates_generation_jobs
WHERE "Id" IN (
  '50000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000002',
  '50000000-0000-4000-8000-000000000003',
  '50000000-0000-4000-8000-000000000004',
  '50000000-0000-4000-8000-000000000005')
ORDER BY "Id";
