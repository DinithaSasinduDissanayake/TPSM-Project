# Lessons Learned

## 2026-03-06T13:37:48+05:30

- What went wrong: I initially targeted the wrong working directory for repo edits and git inspection, which caused failed patch application and non-repo git output.
- Why it happened: I acted from the parent materials directory before anchoring every operation to the actual repository root.
- Rule for next time: Confirm the exact repo root first and use repo-root-relative paths plus the correct `workdir` for every git or patch action.
