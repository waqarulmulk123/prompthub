# Service setup

## Connected resources

- Supabase project: `wtzpoahcqyxayxvumneu`, US East.
- Cloudflare account: `159dd6c7e80382dc910b9297507a42d0`.
- Cloudflare catalog: https://promptvault-catalog.pages.dev/manifest.json
- Cloudflare app project: https://promptvault-ai.pages.dev
- Vercel project: `promptvault-ai` / `prj_qzpdl46VTN5R6dSYOHzoTf1PCsLu`.
- GitHub: https://github.com/waqarulmulk123/prompthub

The connected GitHub and Vercel plugins use different credentials from this machine's CLIs. Use the connected tools for these resources; do not silently deploy into a different CLI account.

## Deployment access

The catalog production snapshot was updated on 2026-10-17 with 30 validated starter entries. The Vercel deployment API returned 403 for the intended team/project; the local CLI uses a different identity and also lacks access. Reauthorize deployment access to that exact project before using Vercel. Do not create a duplicate under the CLI default account.

The scheduled catalog workflow is prepared but still needs a scoped Cloudflare Pages token in GitHub Actions secrets. Manual catalog refresh/deployment was verified.

## Local secrets

`.env` contains local settings. `tools/client_config.mjs` exports only publishable settings to ignored `config/client.json`; it rejects privileged Supabase keys. `tools/server_config.mjs` prepares an ignored `.env.server` for server provisioning without printing values. Windows ACLs restrict generated credentials to the current user, SYSTEM and Administrators.

The Android upload keystore is `android/app/promptvault-upload.jks`, with configuration in `android/key.properties`. Both are ignored. Back up these files and `.env` securely. Never upload them as source files or build artifacts.

## Supabase

- Four public tables have ownership policies: profiles, entitlements, collections, saved_prompts.
- Entitlements are readable only by their owner and writable only by trusted backend code.
- Free bookmarks and customizations are checked under a database lock, avoiding races.
- Premium text, usage events and payment idempotency keys live in the private schema.
- `reverse-prompt` validates the session, reserves a scan, calls Gemini, and refunds the reservation if the provider fails.
- `create-checkout` creates a signed-in user's Lemon Squeezy checkout with trusted user metadata.
- Payment webhooks reject unsigned events and ignore duplicate/older events.

Server settings are uploaded with `supabase secrets set --project-ref wtzpoahcqyxayxvumneu --env-file .env.server`. Never upload `.env` directly.

## Accounts to configure later

The owner confirmed these products and credentials do not exist yet:

1. Configure production SMTP for reliable magic-link delivery. Supabase's built-in sender has restricted recipients and rate limits.
2. Create Google OAuth credentials and an Apple Services ID. Add them to Supabase Auth, then set `GOOGLE_AUTH_ENABLED` / `APPLE_AUTH_ENABLED` to true in the public build config.
3. Create iOS/Android apps and products in the stores. Connect RevenueCat, create a `pro` entitlement and offerings, and set the public per-platform SDK keys.
4. Set the RevenueCat webhook URL to `https://wtzpoahcqyxayxvumneu.supabase.co/functions/v1/revenuecat-webhook`, with `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>` from the local secret file.
5. Create Lemon Squeezy monthly/yearly subscription variants. Set the API key, store ID and variant IDs in `.env`, run `node tools/server_config.mjs`, and upload `.env.server` again. Set the webhook to `/functions/v1/lemonsqueezy-webhook` with the local signing secret.
6. Configure the Apple Developer team and signing in Xcode. The bundle identifier is `com.waqarulmulk.promptvault`; a Windows host cannot produce or validate an iOS archive.
7. Add an approved licensed prompt source to `catalog/sources.json`. The GitHub scheduled job needs a scoped Cloudflare Pages token as an Actions secret and account ID as an Actions variable, or an authorized Git integration.

Do not advertise subscriptions as available until real store sandbox purchases, renewal, cancellation, restore and webhook delivery have been tested.

## Daily drops, creator features and push

Daily drops refresh at 9:00 AM America/New_York, including DST. Claims are permanent and independent of the ten-bookmark Free limit. Seven consecutive daily claims earn three bonus reverse-image scans. Bonus scans are deducted only after the normal daily allowance and refunded if the provider fails. Brand DNA is private and requires verified Pro access. Prompt Booster uses Gemini with five daily boosts on Free and 50 on Pro.

OneSignal app: `35457a90-e34c-4e5a-92c7-78aec84ca238` (PromptVault AI, Megilance organization). Web push origin is `https://promptvault-ai.pages.dev`. The owner approved the 11-file SDK patch. Native push still requires Firebase FCM credentials and Apple APNs/signing. Set the public ONESIGNAL_NATIVE_READY build define only after those platform credentials are configured.

Daily notification dispatch uses an idempotent outbox and a database cron at minutes 1 and 6 of every hour; the function sends only during the ten minutes following the New York 9am drop. A private Vault secret authenticates the cron call. The owner approved creation of the app-scoped notification key, which is stored in ignored local .env and uploaded to Supabase server secrets. A real opted-in subscription and a delivered test push still need verification.

Community images stay in a private bucket. Submissions require explicit publishing rights and manual review using the service-only review_remix RPC. Three uploads per day are reserved before storage. Image deletion removes the stored object; reporting hides the image for the reporter and three reports from established accounts return it to review. Verified accounts at least one day old may vote (no self votes; 30 per day). The approved weekly winner needs three unique votes and receives a seven-day server entitlement without overwriting a paid subscription. Claims, rewards, quotas, moderation and isolation are covered by engagement_security_test.sql.
