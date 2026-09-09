---
title: Determine whether PSPDFKit's trial-mode limitations require removing it from the Fork
label: wayfinder:research
status: closed
assignee: research-agent
blocked_by: []
---

## Question

The Fork builds without a paid PSPDFKit license (zotero-ios's `setup.sh` generates an empty license key, falling back to a time-limited evaluation mode), which is fine *if* that trial mode only affects screens that actually invoke PSPDFKit's reader UI — a screen the Native Viewer Redirect bypasses entirely.

But does PSPDFKit's trial limitation manifest more broadly than that — e.g. a nag screen, watermark, or expiry check that runs at app launch or elsewhere in the app regardless of whether its reader UI is ever shown? Check PSPDFKit's own SDK documentation/license-key behavior, and `zotero-ios`'s source for where `PSPDFKit.setLicenseKey(...)` / initialization is actually called (eagerly at launch in `AppDelegate`, vs. lazily right before showing the reader) — that call site determines whether the trial limitation can ever be triggered once the reader path is unreachable.

## Answer

`zotero-ios`'s `AppDelegate.didFinishLaunchingWithOptions` calls `PSPDFKit.SDK.setLicenseKey(...)` (with an empty string on an unlicensed/Fork build, since `Licenses.shared.pspdfkitKey` resolves to `Optional("")`, not `nil`) and then unconditionally touches `PSPDFKit.SDK.shared` (`.styleManager.setLastUsedValue(...)`, plus a conditional `.cache.clear()`) on every single app launch — this is eager, not lazy-before-reader. PSPDFKit/Nutrient's own docs state evaluation/demo mode is triggered by "using any other Nutrient APIs" before a real license is set (not by presenting its UI), and describe the consequence as an alert plus the app being "time-limited to 1 hour" / "terminates the app after 60 minutes" — an app-wide effect, not one confined to the reader screen. So the Fork cannot leave PSPDFKit merely dormant/unreachable while keeping `AppDelegate.swift` as-is; that file's ~10 lines of eager SDK-touching code must be removed or neutralized. Once that's done, PSPDFKit's framework, dependency, and unreached reader-scene code (~48 files) can safely stay in the tree — the vendor's trigger is API usage, not mere linkage, so no further stripping is required.

Full notes: [pspdfkit-trial-mode-research-notes.md](pspdfkit-trial-mode-research-notes.md)
