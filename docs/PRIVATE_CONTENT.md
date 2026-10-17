# Private editorial inventory

Public migrations define schema and functions only. Daily future inventory and paid full text belong in private Supabase tables, never public Git or Flutter assets. Thirty original daily templates and three commercial templates were seeded during the audit. Public Pro entries contain only title, reference image and category. Already-public prototype migration text remains in Git history; the replacement future inventory uses new original text.

Keep the reviewed original master in ignored `config/editorial.private.json` with `reviewed: true`, `license: "CC0-1.0"`, `daily` and `packs` arrays. Run `node tools/prepare_private_content.mjs` to validate it and prepare ignored `config/editorial.private.sql`. Apply that file in the trusted project database SQL environment. Do not paste it into logs, chat, Git, public assets or a client build. Protect both files with local filesystem permissions and back them up securely. The helper preserves existing published drops and claims while replacing future inventory; curate at least three new entries before exhaustion.

Public preview IDs are `pv_pro_001` through `pv_pro_003`. Paid text is fetched only through the authenticated entitlement-checked RPC. Publishing more paid previews requires matching private records and reviewed reference rights.
