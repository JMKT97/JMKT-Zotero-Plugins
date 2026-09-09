---
title: Decide the Fork's git workflow for tracking Upstream
label: wayfinder:grilling
status: open
assignee:
blocked_by: []
---

## Question

The user wants a maintainable patch, not a one-time snapshot fork — they want to keep receiving Upstream Zotero's bug fixes over time. What git workflow should the Fork use to stay rebasable against Upstream releases?

Options to weigh: a long-lived feature branch periodically rebased onto Upstream's tags/releases, a maintained patch file (e.g. via `git format-patch`) reapplied onto fresh Upstream checkouts, or cherry-picking selected Upstream commits onto a permanent divergent branch. Consider how each interacts with keeping the Fork's repo public (required for the free CI Builder) and with the size of the diff decided in [Decide whether to strip PSPDFKit from the Fork entirely or leave it dormant](pspdfkit-strip-or-dormant.md) — a larger diff is harder to rebase cleanly.
