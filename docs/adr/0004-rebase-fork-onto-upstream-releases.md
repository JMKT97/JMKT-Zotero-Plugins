# Track Upstream via rebase, not merge — force-pushing the Fork's branch is intentional

The Fork's patch stays small (per [ADR-0003](0003-local-only-annotation-persistence.md) and the decision to leave PSPDFKit dormant: a couple of files, notably `AppDelegate.swift`'s ~10 lines and wherever the Native Viewer Redirect itself lands in `DetailCoordinator.swift`). Given that, the Fork keeps its patch commits rebased on top of Zotero's real repo (added as a git `upstream` remote) rather than merging Upstream's new releases in: periodically `git fetch upstream --tags && git rebase <latest-tag>`, then force-push the Fork's branch.

This was a deliberate choice over merging Upstream in (which would need only a plain, non-force push): rebase keeps the patch as a small, always-clean set of commits sitting directly on top of the latest Upstream tag, so `git diff upstream/main..main` always shows exactly the Fork's own changes with no merge-commit noise — valued over avoiding force-push, since this is a personal fork with no collaborators who could have their own work clobbered by it.

Consequence: expect to see force-pushes to this repo's default branch on a recurring basis. That is normal for this project, not a mistake to "fix."
