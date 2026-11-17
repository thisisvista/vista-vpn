# Repository agent instructions

Before changing this repository, read
[`.agents/skills/vista-continuous-development/SKILL.md`](.agents/skills/vista-continuous-development/SKILL.md)
and follow it for the full task.

In particular, continue through routine implementation, error repair, tests, and
validation without asking the user to approve each intermediate step. Keep work
on a feature branch, report only verified results, and obtain explicit user
approval before merging to `main`, publishing a public release, or distributing
an APK publicly.

Preserve Vista's branding, user settings, app-routing selections, and existing
relay architecture. Add tests for behavioral changes and never replay a
non-idempotent network request when it may already have reached its destination.
