# PromptVault AI implementation

The PRD, phase instructions and six-screen attachment were read in full. The app implements the five requested phases in order: adaptive Material 3 shell; Drift/FTS offline cache and CDN sync; masonry discovery; editable prompt studio and model launchers; authenticated private boards and trusted subscriptions. Reverse image analysis, image sharing and a licensed catalog pipeline are included.

## Discovery behavior

- The first page contains at most 10 templates. Each manual Load 10 more action appends at most 10; filters and search reset to page one.
- Results sort by supplied popularity counts, then featured Fashion, Men and Women categories, then stable catalog order. The original templates have zero popularity counts; no live trend metrics are invented.
- The bundled catalog contains 30 original free templates and three Pro previews and illustrative Unsplash reference photographs. These are not verified model outputs. The attachment supplied layout descriptions but no source/API URLs. Approved external JSON sources can be added to catalog/sources.json after license and safety review.
- Imports require a permitted license, attribution, reviewed content and valid categories. Only approved image hosts are accepted. Image requests have deadlines, reject redirects and check MIME plus image signatures. A failing source does not stop healthy sources; removed/failed imports disappear from the next published snapshot. Images that fail during browsing are hidden for that screen session.
- Health checks cannot guarantee third-party availability between refreshes, or infer semantic relevance from arbitrary external content. Safety review is an explicit requirement for imports.

## Service status

Supabase schema, private row policies, quota/entitlement RPCs and eleven Edge Functions are deployed. Database security checks and an authenticated Gemini reverse-image request passed. Cloudflare catalog and app projects and a Vercel project are provisioned. See SERVICES.md for deployment details.

RevenueCat products, Apple/Google OAuth credentials, Lemon Squeezy merchant products and production email delivery still require owner configuration. Their controls remain unavailable or return a clear service-unavailable response until configured. The user explicitly requested completion of the app and available services without waiting for those accounts.

## Technical limits

The installed SDK is Flutter 3.47.5 / Dart 3.13.4; CI and build scripts pin Flutter 3.47.7. An isolated upgrade did not complete. Android signing material is local and ignored. iOS signing and device validation require an Apple build environment. Public previews never contain paid prompt text; entitlements and quotas use trusted backend writes. Server secrets never enter Flutter defines. Reverse images are resized and encoded as PNG before transmission. External AI launchers use clipboard fallbacks.

Neither a zero-cost deployment at 50,000 users nor 120 fps is established without measured traffic and device benchmarks. Decoded 600×600 images require approximately 1.44 MB each.

## Creator engagement implementation

Added Daily Drop and Streak Vault with a server-clock countdown, account-bound permanent claims and a reward of three scans for each seven consecutive claimed days. The homepage displays the drop above discovery. The Pro archive hides unclaimed historical prompt text. A private Brand DNA profile adapts product, colors and visual direction without mutating the original prompt. Quick Inspire is a navigation tab with swipe and accessible button equivalents, selectable ChatGPT/Gemini destination, and quota-checked saves. Prompt Booster calls Gemini through an authenticated server function. Community remixes use private uploads, manual review, verified votes, report/block controls and a seven-day weekly reward; no fake community counts are displayed.

Validation: 22 Flutter tests pass; analyzer reports no issues; fifteen Node tests and the client configuration security test pass. Transactional database tests cover claims, streak idempotency, bonus credits/refunds, quotas, private brands/claims, moderation, votes and blocking. Live authenticated tests passed for the daily claim, Gemini booster, private upload and image deletion, followed by test account cleanup. The admin additions introduce intentional guarded SECURITY DEFINER notices and an outstanding leaked-password protection setting; see ADMIN.md for their status. OneSignal structural checker passes with one advisory: initialization is delegated from main to the centralized wrapper. Actual device push delivery, Apple signing, real store purchases, verified trend-source ingestion and load/performance testing remain separate launch gates.
