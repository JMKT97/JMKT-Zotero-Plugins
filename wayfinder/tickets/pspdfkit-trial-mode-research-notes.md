# Research notes: PSPDFKit trial-mode behavior vs. Native Viewer Redirect

## Method

1. Shallow-cloned `https://github.com/zotero/zotero-ios` (depth 1) into a scratch directory
   (`/tmp/.../scratchpad/zotero-ios`, outside this repo) and grepped for PSPDFKit
   initialization/license call sites.
2. Read PSPDFKit/Nutrient's own public documentation (the product was rebranded "Nutrient";
   docs now live at nutrient.io) on evaluation/demo-license behavior.
3. Synthesized whether the Fork can leave PSPDFKit compiled-in-but-unreached with zero
   consequences, or whether something forces active removal/neutering.

## 1. Where zotero-ios calls into PSPDFKit at launch

Call site: `Zotero/AppDelegate.swift`, inside
`application(_:didFinishLaunchingWithOptions:)` (confirmed present in the current default
branch at clone time), roughly:

```swift
if let key = Licenses.shared.pspdfkitKey {
    PSPDFKit.SDK.setLicenseKey(key)
}
DDLogInfo("AppDelegate: clearPSPDFKitCacheGuard: \(Defaults.shared.clearPSPDFKitCacheGuard); currentClearPSPDFKitCacheGuard: \(Defaults.currentClearPSPDFKitCacheGuard)")
if Defaults.shared.clearPSPDFKitCacheGuard < Defaults.currentClearPSPDFKitCacheGuard {
    PSPDFKit.SDK.shared.cache.clear()
    DDLogInfo("AppDelegate: did clear PSPDFKit cache")
    Defaults.shared.clearPSPDFKitCacheGuard = Defaults.currentClearPSPDFKitCacheGuard
}
PSPDFKit.SDK.shared.styleManager.setLastUsedValue(AnnotationsConfig.imageAnnotationLineWidth,
                                                  forProperty: "lineWidth",
                                                  forKey: PSPDFKit.Annotation.ToolVariantID(tool: .square))
```

Key findings from this block:

- **This runs unconditionally on every app launch**, in `AppDelegate`, long before any
  reader/detail screen exists. It is *eager*, not lazy-before-reader as the ticket
  hypothesized might be the case.
- The last line, `PSPDFKit.SDK.shared.styleManager.setLastUsedValue(...)`, is **not gated by
  any condition** — it runs every single launch regardless of the `clearPSPDFKitCacheGuard`
  check above it. Simply touching `PSPDFKit.SDK.shared` forces PSPDFKit's core SDK singleton
  to initialize.
- `Licenses.shared.pspdfkitKey` is read from a generated `licenses/licenses.plist` file (see
  `setup.sh` → `licenses.sh`, which is run by CI/local setup and is *not* committed to the
  repo). The generated template is:
  ```xml
  <key>pspdfkit</key>
  <string></string>
  ```
  So on an unlicensed/Fork build, `pspdfkitKey` resolves to `Optional("")` — a **non-nil empty
  string**, not `nil`. That means the `if let key = ...` guard is satisfied and
  `PSPDFKit.SDK.setLicenseKey("")` is actually called with an empty string, not skipped.
- 48 Swift files under `Zotero/Scenes/Detail/PDF/...` and related import `PSPDFKit`/
  `PSPDFKitUI`, but all of that code is only reachable by presenting the PDF reader scene
  (`PDFReaderViewController` / `PDFCoordinator`), which the Native Viewer Redirect plan
  bypasses. The reader-UI code itself is not the concern — the `AppDelegate` block is.

## 2. PSPDFKit/Nutrient's own documented evaluation-mode behavior

Sources (fetched directly, quotes reproduced from the fetched page content):

- "Adding the Nutrient license key" (iOS getting-started guide),
  https://www.nutrient.io/guides/ios/getting-started/adding-the-license-key/
- "License Troubleshooting | iOS", https://www.nutrient.io/guides/ios/troubleshooting/license-troubleshooting/

Key quotes / paraphrases:

- "It's important that you set the license key before using any other Nutrient APIs;
  otherwise, Nutrient will run in evaluation mode, which adds watermarks to documents **and
  terminates the app after 60 minutes**."
- Troubleshooting guide, on unexpectedly landing in demo mode even when a real key is set
  elsewhere: "If you're setting a valid license key but seeing an alert about being limited to
  using Nutrient for 1 hour in demo mode... It's likely you're accidentally calling APIs from
  Nutrient before you set your license key. This results in Nutrient using a demo license."
  The literal log/alert text quoted is: *"This version is not for redistribution and is
  time-limited to 1 hour."*
- The guide's own recommended debugging technique is a **symbolic breakpoint on
  `PSPDFEnsureCoreLicenseIsInitialized`** (module `PSPDFKit`), which it says "activates both
  when the license is set successfully and when something else causes the license to
  initialize too early." This confirms the core-license/evaluation-mode check is triggered by
  *touching SDK APIs generally* (e.g. accessing `PSPDFKit.SDK.shared` or its subsystems), not
  specifically by presenting a PSPDFKit view controller.
- Nothing in the docs found suggests evaluation mode requires the reader UI to be shown to
  activate — the trigger is API usage, and the consequence (per the docs) is scoped partly to
  documents (watermark) but partly described as **app-level** ("terminates the app after 60
  minutes").

Confidence: **High** that (a) evaluation mode is triggered by any SDK API touch, not
specifically by UI presentation, and (b) zotero-ios's `AppDelegate` unconditionally performs
such a touch (`PSPDFKit.SDK.shared...`) on every launch. **Medium** on the precise mechanics of
"terminates the app after 60 minutes" (e.g., whether this is a hard `exit()`/crash, a blocking
alert the user must dismiss, or disabling further API calls) — the docs are consistent across
two independently-fetched pages but I could not find a from-the-source engineering deep-dive or
independent third-party report (GitHub issue, blog post) corroborating the exact runtime
mechanism, only the vendor's own guide text describing the alert and the "1 hour" limit.

## 3. Synthesis / answer

**No — the Fork cannot leave PSPDFKit merely "dormant and unreachable" while keeping
`AppDelegate.swift` unmodified, and expect zero consequences.** The reader-UI code path being
unreachable is not sufficient, because `zotero-ios`'s own `AppDelegate.didFinishLaunchingWithOptions`
already eagerly touches `PSPDFKit.SDK.shared` (via `styleManager.setLastUsedValue`,
unconditionally, and conditionally via `cache.clear()`) on *every single launch*, independent of
whether any reader/detail screen is ever presented. Combined with `Licenses.shared.pspdfkitKey`
resolving to an empty string (not `nil`) on an unlicensed build, this launch-time code very
plausibly satisfies PSPDFKit's own documented trigger for evaluation/demo mode — a trigger the
vendor says fires from "using any other Nutrient APIs" before/without a real license key, not
from showing PSPDFKit's UI. The documented consequence includes an alert nag and an app
termination timer ("time-limited to 1 hour" / "terminates the app after 60 minutes"), which
would be an app-wide, launch-triggered problem, not something confined to a reader screen the
Fork never shows.

**However, this does not require ripping the PSPDFKit dependency out of the project.** The fix
is narrow and localized: neutralize the ~10 lines in `AppDelegate.swift` that call
`PSPDFKit.SDK.setLicenseKey(...)`, `PSPDFKit.SDK.shared.cache.clear()`, and
`PSPDFKit.SDK.shared.styleManager.setLastUsedValue(...)` (delete them or gate them out, e.g.
behind a compile flag), so that no code path anywhere in the Fork ever touches
`PSPDFKit.SDK.shared` or any other PSPDFKit API at all. If that's done, and the reader scene is
genuinely never presented (per the Native Viewer Redirect plan), then PSPDFKit's framework
being merely linked into the binary (unused, no API ever called) should be fully inert — the
vendor's documented trigger is API usage, not framework presence — so leaving the dependency and
the ~48 reader-scene Swift files in the tree (uncompiled-out, just unreached) should be safe.

**Bottom line:** PSPDFKit's trial-mode nag/expiry is not confined to its own view controllers
being shown — it's triggered by any SDK API touch, and zotero-ios's `AppDelegate.swift` makes
such a touch unconditionally at launch today. The Fork must patch out that handful of
`AppDelegate.swift` lines (small, well-isolated change) as part of the redirect work; it does
**not** need to strip PSPDFKit from the build/dependency graph entirely, and it does not need to
avoid presenting the reader UI as the *only* mitigation — avoiding all AppDelegate-level API
calls into PSPDFKit is the actual requirement.

## Sources

- https://www.nutrient.io/guides/ios/getting-started/adding-the-license-key/
- https://www.nutrient.io/guides/ios/troubleshooting/license-troubleshooting/
- `zotero-ios` repo (shallow clone, HEAD at research time): `Zotero/AppDelegate.swift`,
  `Zotero/Models/Licenses.swift`, `licenses.sh`/`setup.sh` at repo root scripts directory.
