# Lessons Learned

## 2026-03-06T13:37:48+05:30

- What went wrong: I initially targeted the wrong working directory for repo edits and git inspection, which caused failed patch application and non-repo git output.
- Why it happened: I acted from the parent materials directory before anchoring every operation to the actual repository root.
- Rule for next time: Confirm the exact repo root first and use repo-root-relative paths plus the correct `workdir` for every git or patch action.

## 18:50

- What went wrong: I initially wired `stop_event` into the same control callback used by running dataset tasks, which turned one real failure into synthetic in-flight failures under parallel `stop_on_first_fail`.
- Why it happened: I conflated two different concerns: cancelling pending jobs and interrupting already-running jobs.
- Rule for next time: Separate pending-job cancellation from in-flight task control so internal fail-fast logic drains running work while external STOP controls can still interrupt active jobs.
