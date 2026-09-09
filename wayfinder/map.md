---
label: wayfinder:map
---

## Destination

A maintainable, personal fork of Zotero's iOS app (the **Fork**) that fully replaces its built-in PDF reader with an in-app Quick Look/Markup redirect (the **Native Viewer Redirect**), opened in place on the same file Zotero already manages — no duplicate copies, no toggle back to the original reader. Zotero remains the library manager; all annotation happens as **Native Markup** embedded directly in the PDF, matching the format already used across the user's existing library of annotated papers.

This map's destination is a complete, buildable **spec** — a plan precise enough to hand off and execute later — not the Fork itself. No code is written while resolving this map's tickets.

## Notes

Domain: iOS app development (Swift/UIKit/Xcode), Zotero's data model and sync protocol, Apple code-signing/sideloading ecosystem. See [CONTEXT.md](../CONTEXT.md) for the project glossary, and [docs/adr/](../docs/adr/) (0001-0003) for the architectural decisions already locked in during destination-naming: forking instead of a plugin or jailbreak, the Mac-free/free-tier build pipeline, and local-only annotation persistence.

Standing constraints: no Mac or Apple hardware beyond the iPad itself; no paid Apple Developer account; all other dev machines are Linux.

Standing preferences: full replacement of the built-in reader, no toggle; the Fork's repo stays public (required for the free CI Builder); a maintainable patch rebased against Upstream, not a one-time snapshot.

This map does **not** carry execution — resolving a ticket means making a decision or finding a fact, never writing code. Call the Skill tool for `grilling` (and `domain-modeling` if new terminology/ADRs surface) to resolve grilling-type tickets; call it for `research` to resolve research-type tickets.

## Decisions so far

- [Determine SideStore's custom app-source format and update behavior](tickets/sidestore-source-format-research.md): no fully hands-off updates — SideStore only auto-refreshes the 7-day signing expiry on what's already installed; a new build always needs a manual tap in the SideStore app. Source format is classic AltStore/AltSource JSON (`name`/`identifier`/`apps[].bundleIdentifier` + `versions[]` with `version`/`date`/`downloadURL`/`size`, no `sha256`).
- [Determine whether PSPDFKit's trial-mode limitations require removing it from the Fork](tickets/pspdfkit-trial-mode-research.md): PSPDFKit is initialized eagerly in `AppDelegate.swift` on every launch regardless of reader use, and its evaluation mode triggers on any SDK API use (not on presenting its UI), time-limiting the whole app to 1 hour once triggered. So `AppDelegate.swift`'s ~10 lines of eager SDK calls must be stripped/neutralized either way — but once that's done, the rest of PSPDFKit's dependency and unreached reader-scene code (~48 files) can safely stay in the tree.

## Not yet specified

- Any follow-on tooling to apply the git workflow chosen in [Decide the Fork's git workflow for tracking Upstream](tickets/fork-maintenance-git-workflow.md) (e.g. automation to check for or apply new Upstream releases).

## Out of scope

- **Configurable Storage Directory** (pointing the Attachment Store at the folder the user already dumps downloaded papers into) — the user's own call: "realistically this should be considered a separate patch." A future effort, not part of this map.
- **Self-hosted Zotero sync solution** — explicitly deferred by the user; only one device is in use today, so this isn't needed yet.
- **Jailbreak-based interception** — ruled out early (see [ADR-0001](../docs/adr/0001-fork-instead-of-plugin-or-jailbreak.md)): no existing tweak precedent, would need to be built from scratch against a closed native app, and would break on every Zotero update.
- **Paid Apple Developer Program membership** — ruled out (see [ADR-0002](../docs/adr/0002-mac-free-free-tier-build-pipeline.md)): the user won't pay $99/year for a personal single-device app.
- **A toggle between the Native Viewer Redirect and Zotero's original built-in reader** — ruled out; full replacement only, since Zotero is purely a library manager for this user.
