---
title: Decide whether to strip PSPDFKit from the Fork entirely or leave it dormant
label: wayfinder:grilling
status: open
assignee:
blocked_by: [pspdfkit-trial-mode-research]
---

## Question

Given [Determine whether PSPDFKit's trial-mode limitations require removing it from the Fork](pspdfkit-trial-mode-research.md)'s findings: should the patch fully remove PSPDFKit from the Fork's dependencies and codebase, or just leave its ~51 files unreachable-but-present once the Native Viewer Redirect bypasses `showPdf(at:)`?

Fully removing it means a larger, riskier diff against Upstream (harder to keep the patch maintainable/rebasable) but a cleaner, smaller app with no unused commercial SDK and no possibility of a trial nag ever surfacing. Leaving it dormant is the smaller patch but only acceptable if the research ticket confirms the trial limitation truly can't trigger without the reader UI being shown.
