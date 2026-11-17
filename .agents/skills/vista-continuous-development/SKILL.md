---
name: vista-continuous-development
description: >
  Autonomous, test-driven workflow for continuing Vista VPN development.
  Use whenever working on this repository, especially when fixing errors,
  porting features, modifying Android or core networking code, or validating PRs.
---

# Vista Continuous Development

## Default execution rule

Work continuously through the next safe development steps. Do not stop after each
small step to ask the user for confirmation. Do not ask "should I continue?"
when the next step is already implied by the active task.

After each change:
1. Inspect the diff and check for unintended changes.
2. Run the narrowest relevant tests and static checks.
3. If a check fails, inspect the actual failure, fix the cause, and rerun it.
4. Then run broader relevant tests/builds.
5. Continue to the next logically required task and update the work log/PR notes.

Do not report a check as passed unless its result was observed. Distinguish
between not run, skipped, failed, and passed. Never hide or hand-wave failures.

## Repository safety

- Preserve Vista branding, package identity, signing configuration, and existing
  user data/preferences unless the task explicitly requires a reviewed migration.
- Keep changes isolated on the current feature branch and use pull requests for
  review; do not push feature work directly to `main`.
- Do not overwrite Vista-specific relay, manifest, or fallback behavior with
  another project's implementation without a compatibility review.
- Do not copy code that depends on unavailable private authorization, credentials,
  services, or profiles and claim it is functional.
- For per-app routing, preserve the user's saved app selections. Never implement
  an "all apps" mode by destructively clearing bypass/allow lists unless a safe
  backup/restore model is implemented and tested.
- Treat network retry/replay carefully. Never replay non-idempotent requests
  when the request may already have reached the server.
- Add or update tests for behavior changes, especially networking, routing,
  recovery, and persistence.

## User approval boundaries

Proceed without asking for routine implementation, investigation, test, repair,
documentation, and CI steps that are within the active task.

Explicit approval is still required before:
- merging any pull request into `main`;
- publishing a public release or publicly distributing an APK/artifact;
- deleting repositories, branches, user data, signing keys, or production resources;
- making paid infrastructure purchases or irreversible external changes.

If a task cannot safely proceed without a decision, ask only the single decision
that blocks progress. Explain the risk and offer a safe non-destructive alternative.

## Reporting

Keep the user informed with concise milestone updates, not permission requests.
At completion, report:
- what changed;
- which tests/builds actually passed or failed;
- what remains unverified or requires device/network testing;
- current branch and PR status;
- any action intentionally held for explicit approval.
