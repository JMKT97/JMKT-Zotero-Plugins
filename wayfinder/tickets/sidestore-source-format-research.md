---
title: Determine SideStore's custom app-source format and update behavior
label: wayfinder:research
status: closed
assignee: research-agent
blocked_by: []
---

## Question

Earlier research confirmed SideStore can serve and refresh a free-signed personal `.ipa` with no ongoing computer involvement, but left one thing unconfirmed: when the CI Builder publishes a new `.ipa` build, does SideStore automatically detect and redownload it from a custom "app source," or does its background refresh only re-sign the already-installed binary in place (requiring a manual tap in the SideStore app to pull a new version)?

Also determine the exact JSON/manifest format SideStore expects for a custom app source (what AltStore-derived source format it needs — version, download URL, signing metadata fields), so the CI Builder knows what artifact to publish alongside the `.ipa` itself.

## Answer

SideStore's own FAQ states plainly that installing a new version requires manual action: "Does SideStore support OTA updates? Yep! Just click the update button when it appears!" Background refresh is a separate mechanism that only re-signs already-installed apps to reset the free-signing 7-day expiry; it does not silently download and install a new `.ipa`. There is circumstantial evidence (the source schema's `News.notify` doc comment) that SideStore checks sources for new versions during background refresh, so the "Update" affordance may appear without the user manually re-adding the source, but the actual install step is always user-initiated — there is no fully hands-off update path with vanilla SideStore. The source format is the classic AltStore/AltSource JSON: a top-level object with `name`, `identifier`, `apps` (each with `bundleIdentifier` matching the ipa's `CFBundleIdentifier`, plus a `versions` array in reverse-chronological order, each version requiring `version` (matching `CFBundleShortVersionString`), `date`, `downloadURL`, and `size` in bytes). No `sha256`/checksum field exists in this format — that belongs to AltStore's separate, incompatible "PAL"/notarized-source format (fields like `marketplaceID`, `buildVersion`), which SideStore's docs explicitly warn against including by accident.

Full notes: [sidestore-source-format-research-notes.md](sidestore-source-format-research-notes.md)
