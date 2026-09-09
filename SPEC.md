# Implementation Spec: Native Viewer Redirect for the Zotero iPad Fork

This is the buildable spec the wayfinder map (`wayfinder/map.md`) was charting toward. It is precise enough to execute from directly. See [CONTEXT.md](CONTEXT.md) for terminology and [docs/adr/](docs/adr/) for the full reasoning behind each decision below — this document states *what to build*, not *why*; read the ADRs if a "why" is needed.

## Goal

Produce the Fork: a personal, sideloaded build of Zotero's iPad app where opening a PDF attachment always opens Apple's native Quick Look/Markup viewer in place on the same file, instead of Zotero's built-in PSPDFKit reader. Zotero remains the library manager (search, tag, organize, sync-down); all annotation happens as Native Markup embedded in the PDF itself.

Explicitly out of scope for this spec (see `wayfinder/map.md`'s Out of scope section for why): a Configurable Storage Directory, a self-hosted Zotero sync solution, any jailbreak-based approach, a paid Apple Developer account, and any toggle back to the built-in reader.

## 1. Fork setup

- Fork `github.com/zotero/zotero-ios` on GitHub. **Keep the fork public** — this is required for free, unmetered GitHub Actions macOS runner minutes (ADR-0002).
- Add the original as a git remote named `upstream`:
  ```
  git remote add upstream https://github.com/zotero/zotero-ios.git
  ```
- Do all patch work on a single long-lived branch (e.g. `main`). Do not create a separate "clean mirror" branch — `upstream` the remote already serves that purpose.

## 2. Neutralize PSPDFKit's eager initialization

**File:** `Zotero/AppDelegate.swift`, in `didFinishLaunchingWithOptions`.

Remove (or make conditional on a real, present license key — there won't be one) the ~10 lines that:
- call `PSPDFKit.SDK.setLicenseKey(...)`
- touch `PSPDFKit.SDK.shared` (`.styleManager.setLastUsedValue(...)`, and the conditional `.cache.clear()`)

This is mandatory regardless of anything else: PSPDFKit's evaluation mode triggers on *any* SDK API use, not on presenting its reader UI, and time-limits the whole app to 1 hour once triggered (`wayfinder/tickets/pspdfkit-trial-mode-research.md`).

**Do not** touch anything else PSPDFKit-related. Leave its ~48 reader-scene files and its Swift Package Manager dependency (`PSPDFKit-SP`) in the tree, unreached and unmodified (`wayfinder/tickets/pspdfkit-strip-or-dormant.md`). This keeps the whole PSPDFKit-related footprint of the patch to this one file.

## 3. The Native Viewer Redirect

**File:** `Zotero/Scenes/Detail/DetailCoordinator.swift`, method `show(attachment:parentKey:libraryId:sourceItem:readerURL:)` (~line 219), specifically its `"application/pdf"` branch, which currently calls `private func showPdf(at url:...)` (~line 383). `showPdf(at:)` in turn calls `createPDFController(...)` (`Zotero/Scenes/Detail/PDF/PDFCoordinator.swift`) to build the PSPDFKit-based `PDFReaderViewController`.

Replace that call with one that presents Apple's `QLPreviewController` (Quick Look, with Markup built in) **in-app** — pushed/presented from the same coordinator, no app-switch — using the same local `file://` URL already resolved via `Files.attachmentFile(...)` (`Zotero/Models/Files.swift`). Attachments are stored as plain files at predictable paths, not a proprietary container, so this is a direct hand-off of the existing URL — no file copy, no new storage logic.

This is a **full replacement**, not a mode: there is no settings toggle back to the PSPDFKit reader, and no other code path should still be able to reach `showPdf(at:)`/`createPDFController(...)`.

**Implementation-time check, not a design decision:** confirm that Zotero's own Annotations UI (a per-item highlights/notes list — see below) also routes through this same `show(attachment:...)` choke point for its "jump to this annotation in the PDF" action, rather than a separate path that would bypass the redirect.

## 4. Zotero's own Annotations UI

Leave it untouched. It will always be empty, since the Fork never creates Zotero Annotations (Zotero's structured highlight/note records — distinct from Native Markup, which lives inside the PDF file itself and isn't tracked by Zotero at all). An always-empty list is cosmetic, not a functional problem, so it doesn't earn a diff (`wayfinder/tickets/zotero-annotations-ui-handling.md`).

## 5. Storage and sync — no changes needed

- **Attachment storage:** keep using the existing App Container path (`Files.swift`'s `<appGroupContainer>/downloads/<libraryFolder>/<itemKey>/<filename>`). The Configurable Storage Directory the user wants is explicitly a separate future patch, not part of this spec.
- **Sync:** no changes. The existing sync client (`Zotero/Controllers/Sync/`, `Zotero/Controllers/API/`) authenticates with the user's own Zotero API key, not an embedded secret, so it works unmodified in a self-built Fork.
- **Annotation persistence:** local-only for this spec (ADR-0003). Native Markup changes the PDF file in place; nothing pushes that change back through Zotero's sync engine. Do not build a "detect externally-modified attachment and re-upload" hook — it's explicitly deferred, not part of this spec.

## 6. Build pipeline (CI Builder)

Set up a GitHub Actions workflow (triggered on push to the patch branch, including the force-pushes from step 8 below) that:

1. Runs on a `macos-latest` runner (free and effectively unmetered because the fork repo is public).
2. Builds the app via `xcodebuild` (using `./scripts/setup.sh` per the project's own README; no paid PSPDFKit license needed — it builds with the evaluation key, which is moot once step 2 above is done).
3. Produces a signed-for-sideloading `.ipa` (free/Personal-Team signing; SideStore itself can also do this signing step, so this stage may just need to produce an unsigned/ad-hoc `.ipa` — confirm which during implementation).
4. Publishes the `.ipa` (e.g. as a GitHub Release asset) alongside an **AltSource-format JSON manifest** for SideStore:
   ```json
   {
     "name": "<source name>",
     "identifier": "<reverse-dns id>",
     "apps": [{
       "bundleIdentifier": "<matches the ipa's CFBundleIdentifier>",
       "versions": [
         { "version": "<matches CFBundleShortVersionString>", "date": "<ISO date>", "downloadURL": "<ipa URL>", "size": <bytes> }
       ]
     }]
   }
   ```
   Do **not** include a `sha256` field or PAL-format fields (`marketplaceID`, `buildVersion`) — those belong to AltStore's separate, incompatible notarized-source format (`wayfinder/tickets/sidestore-source-format-research.md`).

## 7. Distribution (Sideload Distributor)

- Install SideStore on the iPad.
- Pair SideStore once using a Linux machine as the Pairing Host (`SideServer-for-Linux` or `Altcon` — no Mac/Windows machine needed for this, even for this one-time step).
- Add the CI Builder's published AltSource JSON URL as a custom source in SideStore, and install the Fork through it.
- SideStore's background refresh keeps the free-signed app alive past its 7-day expiry automatically, with no further computer involvement.

**Updating after this initial install is not fully hands-off**: SideStore only auto-refreshes the signing expiry on what's already installed — pulling in a *new* build requires opening the SideStore app and tapping Update when it appears (`wayfinder/tickets/sidestore-source-format-research.md`).

## 8. Keeping the Fork current with Upstream

Per ADR-0004: periodically —
```
git fetch upstream --tags
git rebase <latest-upstream-tag>
git push --force
```
Force-pushing this branch is expected and intentional, not a mistake — this is a personal fork with no collaborators to disrupt. The CI Builder workflow re-runs automatically on the resulting push, producing a new `.ipa` and manifest; install the update by tapping Update in SideStore per step 7.

## Open implementation-time checks (not blocking, but verify while building)

- That removing `AppDelegate.swift`'s PSPDFKit calls doesn't break compilation elsewhere (no other code assumes `PSPDFKit.SDK.shared` was already configured).
- That the Annotations UI's jump-to-PDF action really does route through the intercepted `show(attachment:...)` path (step 3).
- Whether the CI Builder needs to produce a fully free-signed `.ipa` itself, or whether an ad-hoc/unsigned build is sufficient for SideStore to sign — affects step 6.3.
