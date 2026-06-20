---
description: Audit AGENTS.md and README.md.gotmpl against the chart codebase, fixing inaccuracies, looping until convergence
agent: build
---

# Doc Accuracy Audit: $ARGUMENTS

Audit AGENTS.md and README.md.gotmpl against the chart codebase at $ARGUMENTS until all claims are accurate.

Ground truth = templates/, values.yaml, _helpers.tpl, .github/workflows/*.yaml, and any test specs. Docs must match ground truth, not vice versa — if docs describe intended behavior the chart doesn't actually implement, flag it explicitly rather than silently rewriting the chart to match.

## Each iteration

1. Build or update a checklist of every distinct feature, resource, config block, helper, convention, test unit and CI behavior present in the codebase. Persist this checklist in `.doccheck-progress.md` so the next iteration builds on confirmed items instead of re-deriving scope from zero.
2. For each checklist item, verify the docs describe it, and describe it correctly.
3. Fix every discrepancy found.
4. Re-verify your fixes by re-reading the relevant files fresh — do not trust your own prior pass's conclusions.

## Verification (required before declaring done)

Run and show full output:

helm-docs --dry-run
helm lint --strict
helm unittest --strict

All three must pass with zero errors.

## Completion

Only declare done if all verification commands above pass AND a fresh full pass against the checklist finds nothing left to fix.

If done:
<promise>Docs fully reconciled against codebase: checklist complete, helm-docs/lint/unittest all pass.</promise>

If not done, do not output the promise tag — summarize what remains and continue working.
