# JMKT Zotero Plugins

A personal fork of Zotero's iOS app that replaces its built-in PDF reader with Apple's native document viewer, so annotation stays in one format across the user's whole library, plus supporting infrastructure to build and run that fork without owning Apple hardware.

## Language

**Fork**:
The personally-modified copy of `zotero-ios`'s source that this project maintains, patches, and builds. Never call it a "plugin" — Zotero iOS has no plugin/extension API; changing its behavior means changing and rebuilding its own source.
_Avoid_: Plugin, extension, mod, tweak (tweak implies a jailbreak-based binary patch, which this is not)

**Upstream**:
The original `zotero/zotero-ios` repository maintained by the Zotero project. The Fork tracks Upstream and periodically pulls its releases forward to keep receiving bug fixes.
_Avoid_: Original, official app

**Native Viewer Redirect**:
The behavior change at the heart of this project: routing a PDF attachment to Apple's Quick Look/Markup viewer, opened in place on the same file Zotero already manages, instead of Zotero's bundled PSPDFKit-based reader. Full replacement, not a mode — there is no toggle back to the built-in reader.
_Avoid_: Plugin behavior, redirect (ambiguous alone), PDF override

**Native Markup**:
Annotations (ink, highlights, text) written by Apple's Markup tool directly into a PDF's own embedded annotation objects. This is what the Redirect produces, and what the user's existing library of hundreds of annotated papers already uses — it is a property of the file itself, not a separate record.
_Avoid_: Annotations (alone — always disambiguate from Zotero Annotations), markup data

**Zotero Annotations**:
Zotero's own structured data-model objects (highlights, notes, tags) normally created through its bundled PSPDFKit reader and synced through Zotero's API as distinct records, independent of the PDF file's own contents. The Fork does not create or rely on these — the Redirect bypasses the reader that produces them entirely.
_Avoid_: Annotations (alone), notes

**Attachment Store**:
Where the Fork keeps a library's raw PDF files on local disk. Two locations are in play: the **App Container** (Zotero's current private, sandboxed app-group folder, invisible to the Files app and other apps) and a to-be-decided **Configurable Storage Directory** the user can point elsewhere — groundwork for eventually running a self-hosted Zotero sync solution, though that sync solution itself is separate future work.
_Avoid_: Storage (alone), library folder

**CI Builder**:
The public GitHub Actions macOS runner that compiles the Fork into an installable `.ipa`. Runs free and unmetered because the Fork's repo is public.
_Avoid_: Build server, pipeline (alone)

**Sideload Distributor**:
SideStore, the tool that free-signs the CI Builder's `.ipa` and keeps it refreshed on the iPad past the 7-day free-signing expiry, entirely over Wi-Fi with no ongoing computer involvement.
_Avoid_: AltStore (that's SideStore's predecessor/different tool, requires a Mac/Windows companion — not what this project uses)

**Pairing Host**:
The computer needed only once, to initially pair the Sideload Distributor with the iPad. Any of the user's Linux machines can serve this role; no Apple hardware is required even for this one-time step.
_Avoid_: Build machine (that's the CI Builder, a different component)
