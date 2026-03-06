# Repo Notes

- Before creating a commit, ensure `LESSONS_LEARNED.md` exists at repo root so future process corrections can be recorded without extra setup.
- Confirm the repo root first and use that root for every `git` command and `apply_patch` path.
- Keep internal fail-fast cancellation separate from active-job STOP control so running datasets can drain cleanly.
