---
name: site-runbooks
description: Organise the repair of a Git-backed CMS once its problems are already known — grouping fields so a non-developer can navigate them, deciding what belongs in a CMS at all, and migrating stored values in bulk across a collection. Also the design stances worth taking before wiring a CMS on a new build. Use when an audit has produced findings and the question is how to structure the repair rather than what is wrong. Detection lives in the website-build-kit's `site-repair` skill, which runs the checks these runbooks call.
---

# Site runbooks

**This skill file lives inside the runbooks repository** — it is symlinked into
the skills directory rather than copied, so the runbooks sit one level up from
this file:

```
<repo>/skill/SKILL.md      ← you are here
<repo>/how-to-run.md
<repo>/runbooks/*.md
```

Resolve the repository with `readlink -f "$(dirname SKILL.md)"/..`, or find it
at `github.com/nurkamol/site-runbooks`. It routes to those runbooks and
deliberately does not restate what they contain — two copies of a check drift,
and the entire point of that repository is that they do not.

## Detection is not here

⚠ **Run the checks first, and they live in the kit.** `check-drift.mjs` and
`check-cms.mjs` in website-build-kit are gated, mutation-tested and shipped
into every project; these runbooks call them rather than restating what they
find. The `site-repair` skill runs them and reports.

Come here once there are findings and the question is what to do about them.

## Pick one

Read `how-to-run.md` in the repository first if the situation is unclear.
Otherwise:

| Situation | Runbook |
| --- | --- |
| Findings exist; the CMS needs restructuring so a client can navigate it | `runbooks/pagescms-field-mapping.md` |
| Findings exist across the pipeline, the CMS and the client's guide | `runbooks/kit-drift-remediation.md` |
| Building something new, want to avoid all of it | `runbooks/pagescms-media-playbook.md` |

Read the chosen file in full and follow it. They are written to be executed.

## The three rules that survive whichever you pick

**Detect before you offer anything.** All of these open with an audit phase
that changes nothing. Do not present options until you have real findings —
*"shall I fix your images?"* is not a decision anyone can make, while *"your
pipeline emits WebP only and your 94 images are 19% larger than they need to
be"* is. Report counts and measurements, then ask, then wait.

**A green build proves nothing about the CMS.** The CMS is not a page and the
build never renders it. Every field can be unreachable and every stored value
unusable while the build is green, the types check, the accessibility suite
passes and the HTML is byte-for-byte identical to the last deploy. That has
shipped. When you finish, open the CMS and click through it — that is the only
surface where these failures are visible.

**A check you have not watched fail is not yet a check.** Several checks in
these runbooks were wrong when first written and every one looked
authoritative: one matched every `name="…"` attribute and returned fifteen
false positives, one flagged alt-text fields, one printed nothing whether or
not the problem existed. Before trusting any check you write or adapt, run it
against a tree that has the fault — `git worktree add --detach <old-commit>` is
usually the fastest way.

## If a runbook is wrong about this stack

Fix it in the site-runbooks repository, not locally. A runbook corrected in one
client repository and nowhere else is the exact failure these documents exist
to describe — and because the skill is symlinked rather than copied, a fix
there reaches every project on this machine at once.
