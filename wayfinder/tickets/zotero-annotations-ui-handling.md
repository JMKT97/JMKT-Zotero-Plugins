---
title: Decide whether to hide or leave dormant Zotero's own Annotations UI
label: wayfinder:grilling
status: closed
assignee: JMKT
blocked_by: []
---

## Question

The Native Viewer Redirect bypasses Zotero's PSPDFKit-based reader entirely, which means the Fork will never create Zotero Annotations (Zotero's own structured highlight/note records, distinct from Native Markup embedded in the PDF itself). Zotero's UI likely still has screens/lists for browsing those Annotations (e.g. a per-item annotations sidebar) — should the Fork hide or remove that UI since it will always be empty, or leave it as dormant, unused UI that's simpler to keep merged with Upstream?

## Answer

Leave it dormant, untouched — consistent with the PSPDFKit decision: an always-empty Annotations list is a cosmetic non-issue, not a functional problem forcing a change, so it doesn't earn a diff. Its "jump to this annotation in the PDF" action almost certainly routes through the same `show(attachment:...)` choke point the Native Viewer Redirect already intercepts, so it likely already opens the native viewer correctly with no extra work. Flagged for whoever implements the patch: verify that jump-to-PDF action really does route through the intercepted path rather than a separate one — a build-time check, not a design decision.
