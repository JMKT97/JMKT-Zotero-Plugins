---
title: Research notes — SideStore custom app-source format and update behavior
label: wayfinder:notes
---

# Research notes

Research date: 2026-09-08

## Question recap

1. Does SideStore's background refresh auto-detect and redownload a NEW `.ipa` from a custom app source, or does it only re-sign the already-installed binary (requiring a manual tap to pull a new version)?
2. What exact JSON/manifest format does a SideStore custom "app source" need, so a CI pipeline knows what to publish alongside the `.ipa`?

## Part 1 — Auto-update vs. manual tap

**Answer: manual tap is required to install a new version. Background refresh only re-signs/re-provisions already-installed apps to prevent the 7-day free-signing expiry; it is a separate mechanism from installing a new app version.**

Direct evidence, straight from SideStore's own FAQ (`docs.sidestore.io`, raw source fetched from `github.com/SideStore/SideStore-Docs/main/docs/faq.mdx`):

- "SideStore will periodically 'refresh' your apps in the background, to keep their normal 7-day development period from expiring." — this is the *re-signing* refresh, not a version-update mechanism.
- Q: **"Does SideStore support OTA updates?"** A: **"Yep! Just click the update button when it appears!"**
  - This is the single most direct piece of documentation on this question. It confirms OTA updates exist (SideStore can tell there's a new version at a source) but explicitly frames installing it as something the user does by tapping an "update button" — i.e. not a fully silent, automatic install.

Supporting/circumstantial evidence:

- In SideStore's own source-format type definitions (`github.com/SideStore/sidestore-source-types`, `schema.json`, field `News.notify`): "the notification will occur whenever SideStore attempts a background refresh (the same time that update notifications occur)." This implies SideStore *does* check sources for new app versions as part of its periodic background-refresh cycle (that's how it would know to show an update notification/badge), but nothing in the docs says the new `.ipa` is silently downloaded and installed without the user opening the app and tapping the update control. So: check-for-update can happen in the background; the actual install step is user-initiated.
- GitHub issues (e.g. `SideStore/SideStore#893` "Automatic refresh reports no errors but app no longer opens", `SideStore/SideStore#822` "Sidestore does NOT refresh via 'Refresh all apps' shortcut") are about the re-signing refresh flakiness, not about auto-installing new versions — they don't touch on auto-install either way, but they reinforce that "refresh" in SideStore's vocabulary = re-sign/re-provision, a distinct concept from "update" = install new version.
- No SideStore doc page (FAQ, App Sources guide, wiki) claims new versions are downloaded/installed automatically in the background. The App Sources guide (`docs/advanced/app-sources.mdx`) only covers how to author/distribute a source, not update mechanics.

**Confidence: high** that a manual tap is required to actually install a new version (this is stated in SideStore's own FAQ in plain language). **Confidence: medium** on the nuance that update *detection* (not installation) can happen silently during a background refresh (inferred from the `notify` field's doc comment, not explicitly spelled out anywhere as a general statement about version-update checks).

Practical implication for the CI pipeline: publishing a new `.ipa` + updated source JSON is necessary and sufficient for SideStore to *know* an update exists and show the "Update" control next time the user opens the app (or possibly sooner, if background refresh polls the source) — but the user (i.e., the project owner) will still need to open SideStore on the iPad and tap "Update" to actually pull down and install the new build. There is no fully hands-off, zero-interaction update path with vanilla SideStore.

## Part 2 — Concrete source JSON schema

SideStore explicitly reuses the AltStore ("AltSource") source format. Confirmed via:
- `docs.sidestore.io` → App Sources page (`docs/advanced/app-sources.mdx`): "SideStore is fully compatible with AltStore Sources (or AltSources). The official AltSource documentation provides all the details you need..." (links to `faq.altstore.io/developers/make-a-source`).
- SideStore also publishes its own authoritative machine-readable schema: **`github.com/SideStore/sidestore-source-types`**, raw schema at `https://raw.githubusercontent.com/SideStore/sidestore-source-types/main/schema.json` (JSON Schema draft-07, generated from TypeScript types; docs rendered at `sidestore.io/sidestore-source-types`). This is the most authoritative, current source of truth for what SideStore itself parses (as opposed to AltStore's newer "PAL"/notarized format, which SideStore does NOT support — see caveat below).

### Top-level `Source` object (required: `name`, `identifier`, `apps`)

| field | type | notes |
|---|---|---|
| `name` | string | Source name shown in SideStore |
| `identifier` | string | Reverse-DNS-style bundle-identifier-like string uniquely identifying the source. **Warning from docs: changing this later breaks existing users** — they'll get a conflicting-identifier error and have to remove/re-add the source. |
| `apps` | array of `App` | required |
| `news` | array of `News` | optional |
| `sourceURL` | string | optional; self-referential URL to the source file itself, speeds up SideStore's re-fetch |

(AltStore's classic format additionally supports optional cosmetic top-level fields not in SideStore's own schema.json but accepted since SideStore parses AltStore sources: `subtitle`, `description`, `iconURL`, `headerURL`, `website`, `tintColor`, `featuredApps`.)

### `App` object (required: `name`, `bundleIdentifier`, `developerName`, `localizedDescription`, `iconURL`, `versions`)

| field | type | notes |
|---|---|---|
| `name` | string | app display name |
| `bundleIdentifier` | string | **must match the ipa's `CFBundleIdentifier`** — SideStore uses this to open the app post-install and to match update entries to the installed app |
| `developerName` | string | shown in listing |
| `localizedDescription` | string | full description text |
| `iconURL` | string | required (SideStore's schema; some AltStore tooling treats it as optional) |
| `subtitle` | string | optional, short one-liner |
| `tintColor` | string | optional, 6-hex-char color, `#` optional |
| `screenshotURLs` | array of string | optional |
| `permissions` | array of `{type, usageDescription}` | optional; `type` enum: photos, camera, location, contacts, reminders, music, microphone, speech-recognition, background-audio, background-fetch, bluetooth, network, calendars, faceid, siri, motion |
| `versions` | array of `Version` | **required** — current (v2.0 AltSource API) way to declare releases; **order matters: must be reverse-chronological, since SideStore treats the first entry (whose min/max OS is compatible) as "latest" regardless of actual version/date values** |
| `beta` | boolean | optional, marks app as beta |
| deprecated legacy (v1) fields, still accepted for backwards compat but should NOT be used for new sources: `version`, `versionDate`, `versionDescription`, `downloadURL` (singular, at App level), `size` (at App level) | — | superseded by the `versions` array |

### `Version` object (required: `version`, `date`, `downloadURL`, `size`)

| field | type | notes |
|---|---|---|
| `version` | string | **must exactly match the ipa's `CFBundleShortVersionString`** or SideStore's update logic breaks |
| `date` | string | `YYYY-MM-DD`, or `YYYY-MM-DDTHH:MM:SS` (assumed UTC unless a `-HH:MM` offset is appended) for scheduled/future releases with a countdown |
| `downloadURL` | string | direct link to the `.ipa` file; doesn't need to resolve yet if scheduling a future release |
| `size` | number | ipa size **in bytes** |
| `localizedDescription` | string | optional; per-version changelog text |
| `minOSVersion` | string | optional |
| `maxOSVersion` | string | optional |

**Important — no `sha256`/checksum field in SideStore's actual schema.** An earlier web-search AI summary claimed a `sha256` field exists for integrity verification; this was NOT found in SideStore's own `schema.json`, nor in AltStore's official classic example (`altstoreio/FAQ` repo, `.gitbook/assets/ExampleSource.json` and `altsource-template.json`, both fetched directly). Those newer/alternate fields (`buildVersion`, `marketplaceID`, `assetURLs`, "downloadURLs" plural per-platform, notarization hashes) belong to AltStore's newer **PAL / notarized-source** format, which is a *different, incompatible* source type — SideStore's own docs explicitly warn against accidentally including PAL-only fields: "you must remove the autogenerated-by-default marketplaceID and Build fields, otherwise SideStore will believe it to be a notarized source and prevent your source being added." **For this project's use case (free-signed personal build, not notarized), the CI pipeline must emit the classic AltSource shape above and must NOT include `marketplaceID` or `buildVersion`.**

### Minimal concrete example (classic/SideStore-compatible; adapted from AltStore's own template + SideStore's schema)

```json
{
  "name": "Personal Zotero Fork Source",
  "identifier": "org.example.zoterofork.source",
  "apps": [
    {
      "name": "Zotero (Fork)",
      "bundleIdentifier": "org.zotero.ios.fork",
      "developerName": "you",
      "localizedDescription": "Personal fork of Zotero iOS with Native Viewer Redirect.",
      "iconURL": "https://.../icon.png",
      "versions": [
        {
          "version": "1.2.3",
          "date": "2026-09-08",
          "downloadURL": "https://.../ZoteroFork-1.2.3.ipa",
          "size": 123456789,
          "localizedDescription": "Rebased on upstream v1.2.3."
        }
      ]
    }
  ]
}
```

This is the artifact the CI Builder should publish (host it at a stable URL, e.g. alongside the `.ipa` in the same GitHub Release / raw-GitHub-content location) and update — bumping `versions[0]` (prepending a new entry, keeping reverse-chronological order) — every time a new build is produced.

## Sources consulted

- https://docs.sidestore.io/docs/faq (rendered) and raw: https://raw.githubusercontent.com/SideStore/SideStore-Docs/main/docs/faq.mdx — direct quote on OTA updates and background refresh
- https://docs.sidestore.io/docs/advanced/app-sources (rendered) and raw: https://raw.githubusercontent.com/SideStore/SideStore-Docs/main/docs/advanced/app-sources.mdx — confirms AltSource compatibility, PAL-field caveat
- https://github.com/SideStore/sidestore-source-types — SideStore's own JSON Schema / TypeScript type defs for the source format; raw schema fetched from https://raw.githubusercontent.com/SideStore/sidestore-source-types/main/schema.json
- https://sidestore.io/sidestore-source-types/ — rendered docs for the above (schema itself more informative than the rendered landing page)
- https://faq.altstore.io/developers/make-a-source — official AltStore source-authoring doc (referenced by SideStore's own docs as the canonical spec)
- https://github.com/altstoreio/FAQ — raw example files: `.gitbook/assets/ExampleSource.json`, `.gitbook/assets/altsource-template.json` (classic AltSource examples, confirms field names/no sha256)
- https://github.com/SideStore/SideStore/issues/735 — bug report distinguishing classic `downloadURL` vs PAL `downloadURLs`/notarized format, confirms two divergent schemas exist
- https://github.com/SideStore/SideStore/issues/893, /822 — background-refresh reliability issues (confirms "refresh" = re-signing, separate from version updates; no info either way on auto-install)
- https://wiki.sidestore.io/advanced/app-sources/ — now redirects to docs.sidestore.io (docs site was consolidated/renamed at some point)

## Remaining uncertainty

- Whether SideStore's background refresh cycle checks *every* added custom source for new app versions (not just the official Community Source / SideStore Connect sources), and how frequently, is not explicitly documented anywhere I found. The `notify` field's doc comment implies general source-checking happens during background refresh, but there's no dedicated doc page or code comment that spells out the polling scope/frequency for arbitrary user-added sources. If exact polling behavior matters for the spec, the next step would be reading SideStore's actual Swift source (`github.com/SideStore/SideStore`, refresh/background-task code) rather than relying on docs.
- Confidence that manual tap is required to *install*: high (directly stated in FAQ). Confidence that *checking* for updates happens automatically/silently in the background for custom sources specifically: medium (inferred, not explicitly stated).
