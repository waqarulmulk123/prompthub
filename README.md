# PromptVault AI

A Flutter app for discovering visual prompt ideas, editing reusable variables, and launching a finished prompt in an AI tool. Public browsing uses an offline SQLite cache and a static Cloudflare catalog; private collections use Supabase.

## Run

Use Flutter 3.47.7 (see `.fvmrc`). The system SDK can remain unchanged.

```powershell
node tools/bootstrap_assets.mjs
flutter pub get
# First setup only: copy .env.example to .env and add publishable settings locally.
node tools/client_config.mjs
flutter run --web-port 8080 --dart-define-from-file=config/client.json
```

Only allowlisted public configuration enters the app. Never add `.env` to Flutter assets or pass it directly to `--dart-define-from-file`. `config/client.json`, server credentials, Android signing keys, and provider state are ignored by Git.

## Features

- Responsive discovery with categories, model filters, SQLite full-text search, masonry images, pagination, and offline catalog access.
- Live prompt compilation, editable variable chips, model output tabs, clipboard fallback, ChatGPT/Gemini/Claude launchers, and image recipe sharing.
- Email magic links and optional Google/Apple OAuth; private boards and cloud bookmarks with offline reading.
- Free-plan limits enforced by the backend; RevenueCat and Lemon Squeezy adapters with signed webhook validation.
- Authenticated image-to-prompt analysis with daily quotas and automatic refunds when analysis fails.
- Bend policy laws for licensed content and keeping paid prompt text off the public CDN.

The bundled catalog contains original starter templates and clearly labeled illustrative reference photos. It does not claim those photos are verified AI outputs. Add licensed, reviewed catalogs to `catalog/sources.json` to enable imports.

## Verify

```powershell
bend PROOF.bend
node tools/config_test.mjs
flutter analyze --fatal-infos
flutter test
node tools/backend_smoke.mjs
flutter build web --wasm --dart-define-from-file=config/client.json
flutter build apk --debug --dart-define-from-file=config/client.json
```

Database ownership, quota and entitlement tests are in `supabase/security_test.sql`; they roll back all test records. Migrations live in `supabase/migrations/`. After changing Drift tables, run `dart run build_runner build`.

## Services and production setup

See [service setup](docs/SERVICES.md), [implementation status](docs/IMPLEMENTATION.md), and [architecture decisions](docs/IMPLEMENTATION.md#decisions-and-corrections).

App Store / Play Store products, RevenueCat offerings, merchant checkout products, OAuth provider credentials, production SMTP and Apple signing require the owner's accounts. Their absence never unlocks paid features. Performance and cost targets in the PRD require measurements on real devices and live traffic.