---
name: site-runbooks
description: Audit and repair a Git-backed CMS site after it has shipped — content the CMS cannot reach, image fields that are text boxes rather than pickers, stored values the CMS cannot resolve, an image pipeline that discards uploads silently, text over photographs with no contrast guard, or a client editing guide that has drifted from the CMS it describes. Use when someone says a client cannot change something on their own site, when a site was built from an older template and its state is unknown, or before wiring a CMS on a new build. Routes to the runbooks in the site-runbooks repository.
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

## Pick one

Read `how-to-run.md` in the repository first if the situation is unclear.
Otherwise:

| Situation | Runbook |
| --- | --- |
| A client cannot edit something they can see | `runbooks/pagescms-field-mapping.md` |
| Site is old, state unknown, built from a template | `runbooks/kit-drift-remediation.md` |
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
