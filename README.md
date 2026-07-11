# evidencias

Disposable, **public** hosting for review evidence (screenshots) produced by the
[orquestra](https://github.com/jvmartins/orquestra) agent runs. Images pushed
here are embedded in PR "Evidence" comments (via `raw.githubusercontent.com`
URLs, which render inline even on private-repo PRs) and attached to Notion
tickets (`notion-create-attachment` needs a public URL).

## Layout

```
<target-repo>/<YYYY-MM-DD>-<ticket-slug>/<screenshot>.png
```

e.g. `saymyname-learning/2026-07-11-graduation-school-tab/school-tab-desktop.png`

## Rules

- **This repo is world-readable.** Never push anything sensitive: no secrets,
  no test-account credentials on screen, no real user PII. If a screenshot must
  show sensitive data, don't push it — describe it in the ticket instead.
- Evidence only — no code, no logs with tokens, nothing that merges anywhere.
- Agents push directly to `main` here (explicit carve-out from orquestra's
  Golden Rule 1 — this is an artifact store, not machinery).

## Cleanup

Old evidence can be deleted freely — a periodic board task clears past
directories. Deleting breaks the inline images on old (already-reviewed) PRs,
which is acceptable. If size ever matters, the whole repo can be deleted and
recreated; nothing depends on its history.
