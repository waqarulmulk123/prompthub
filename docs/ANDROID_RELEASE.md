# Android release handoff

Package: `com.waqarulmulk.promptvault`. Version: `1.0.0+1`.

## Reproduce

```powershell
node tools/bootstrap_assets.mjs
node tools/client_config.mjs
flutter pub get
flutter analyze --fatal-infos
flutter test
bend PROOF.bend
flutter build appbundle --release --dart-define-from-file=config/client.json
flutter build apk --release --split-per-abi --dart-define-from-file=config/client.json
```

Release builds require the ignored `android/key.properties` and upload keystore. The build fails if signing configuration is missing or incomplete. Back up these files securely. Do not put them in Git, Flutter assets, CI logs or downloadable artifacts.

The manifest disables app backup and cleartext HTTP. The launcher uses PromptVault's native vector/adaptive icon. Gradle is limited to two workers and a 3 GB heap to avoid exhausting this Windows host's paging file. TLS, authentication, quotas and entitlements remain enforced by the backend.

The emulator smoke test is in `integration_test/android_smoke_test.dart`. Run it on a booted Android device with:

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/android_smoke_test.dart -d emulator-5554 --dart-define-from-file=config/client.json
```

## Store configuration

Public privacy policy: https://promptvault-ai.pages.dev/privacy.html

Public account deletion resource: https://promptvault-ai.pages.dev/delete-account.html

The app includes permanent account deletion with an explicit confirmation. Its server endpoint removes the account's remix objects before deleting Auth and cascading owned app rows. A live disposable-user test verifies that the account, bookmarks, remix row and stored image disappear and the old session is rejected. Deletion does not cancel store billing; the confirmation and web resource explain this.

Before public distribution, configure production SMTP/OAuth, the Google Play app and RevenueCat products, Firebase FCM credentials in OneSignal, and native push delivery testing. `ONESIGNAL_NATIVE_READY` must stay false until FCM is configured. Store products, billing renewal/restore/cancellation, production email delivery and push delivery require real owner accounts and vendor credentials; a successful build does not validate those services.

The owner must review the published privacy/terms text and complete Play Console Data Safety, content rating and store listing declarations against the final configured SDKs. Current [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878) and [16 KB compatibility guidance](https://developer.android.com/guide/practices/page-sizes) apply. Device performance, download-size targets and production load/cost claims require measurements, not assumptions.
