# Prompt and image resource audit — 2026-10-17

The published starter catalog has 30 original templates. Every reference image was fetched successfully in full, checked for a supported image signature, compared by SHA-256, and visually reviewed. URLs are compared without resize/query transforms. Normalized prompt text and IDs are also unique. Images are illustrative references, not verified outputs from the displayed AI model; no popularity counts or live trend claims are fabricated.

| PRD resource | Observed result | Publication decision |
|---|---|---|
| [Civitai images API](https://civitai.com/api/v1/images?limit=1&sort=Most%20Reactions&period=Week&nsfw=false&withMeta=true) | HTTP 200 with JSON | Disabled: API availability and an NSFW flag do not establish redistribution rights or a completed content review. |
| [Lexica search](https://lexica.art/api/v1/search?q=product%20photography) | HTTP 500, no usable JSON | Disabled: broken resource. |
| [AIGC-Hackers repository](https://github.com/AIGC-Hackers/awesome-ai-image-prompts-claude) | Repository accessible; no LICENSE in the root and no detected repository license | Disabled: no verified reuse license. |
| [PicoTrex repository](https://github.com/PicoTrex/Awesome-Nano-Banana-images) | Repository accessible; LICENSE detected as Apache-2.0, while the English README displays a CC-BY-4.0 badge and says examples come from social platforms | Disabled: resolve the conflicting license statements and individual image rights before importing. |
| Unsplash reference images | All 30 selected image bodies fetched and passed the catalog checks | Enabled with reference-photo attribution and original CC0 template text. |

`catalog/sources.json` intentionally contains no unreviewed external entries. A failing or removed approved source is omitted from the next snapshot; the importer never retains its old records. Images that fail on a device are hidden for that screen session. Availability can still change after a successful check.

Daily drops are text editions. Existing and future daily entries do not reuse discovery photographs. The server selects previously unpublished pool text, and hides a new drop if fewer than three fresh reviewed entries remain. Curators must replenish `private.drop_pool` with original, reviewed content; the unique index rejects repeated normalized text. Historical claimed text stays available to its owner. The initial pool is finite; the system does not pretend that rotating old prompts is a new daily drop.

The catalog refresh workflow still requires the intended Cloudflare Pages credential in GitHub Actions. Manual publication is available through the connected Cloudflare account. These checks prove the current snapshot; they do not establish an unlimited licensed live-trend feed.
