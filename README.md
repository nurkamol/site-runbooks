# site-runbooks

**Agent-runnable runbooks for repairing Git-backed CMS sites after they ship.**

Every one of these came out of a live client site, and every number in them was
measured on it rather than estimated. They are written to be *attached to a
coding agent inside a project* — the agent audits, reports what it found, asks
how you want it fixed, and only then changes anything.

```
> Read ~/coding/site-runbooks/runbooks/pagescms-field-mapping.md and follow it.
  You are working in this repository. Phase 1 only until I answer.
```

---

## The runbooks

| | What it does | |
| --- | --- | --- |
| **[pagescms-field-mapping](runbooks/pagescms-field-mapping.md)** | Makes every word and picture on a site reachable from the CMS, grouped so a non-developer can navigate it | run |
| **[kit-drift-remediation](runbooks/kit-drift-remediation.md)** | Eight checks across the image pipeline, the CMS and the client's own guide, for a site that has fallen behind its template | run |
| **[pagescms-media-playbook](runbooks/pagescms-media-playbook.md)** | The reasoning behind both — read before building, not only when repairing | read |

**[how-to-run.md](how-to-run.md)** — which one to reach for, how to invoke it,
and how to sequence this across several live sites without doing the work
twice.

### Install the skill

```bash
git clone https://github.com/nurkamol/site-runbooks.git
cd site-runbooks && ./install.sh
```

That does three things: symlinks `skill/` into your Claude skills directory so
`site-runbooks` is available in every project without attaching a file; enables
the pre-commit guard; and seeds the denylist outside the repo.

**Run it on every clone.** `core.hooksPath` lives in `.git/config`, which git
does not clone — so a fresh clone of this repository has no guard at all until
`install.sh` runs. That was verified by cloning it and successfully committing
a client name. A guard sitting in the tree is not a guard that is installed.

The skill is linked rather than copied on purpose: a copied skill is a second
vintage of the same instructions, which is the failure these runbooks are
about. `git pull` here updates it everywhere.

---

## The problem they solve

A client opens their CMS, sees a photograph on their own homepage, and has no
way to change it. Or changes their phone number and the tap-to-call link keeps
dialling the old one. Or uploads a photo from their phone and it silently
vanishes.

None of that shows up in a build. That is the whole difficulty:

> **A green build proves the pages render. It proves nothing about the CMS** —
> the CMS is not a page, and the build never renders it.

On the site these came from, every image picker was broken while the build was
green, the types checked, the accessibility suite passed, and the rendered HTML
was byte-for-byte identical to the previous deploy. The only surface where it
was visible was the one nobody automates.

So each runbook ends by telling you to open the CMS and click through it.

---

## How they are built

**Detect, report, ask, act.** In that order, never reordered. A runbook that
offers a menu before it has findings is worthless — *"shall I fix your images?"*
is not a decision anyone can make, while *"your pipeline emits WebP only and
your 94 images are 19% larger than they need to be"* is.

**Every check has been run against a tree that has the fault.** This is not a
formality. Three checks across these documents were wrong when first written
and every one looked authoritative:

- one matched every `name="…"` attribute and returned form fields, icon names
  and `<meta name="viewport">` — fifteen hits where the truth was zero
- one flagged alt-text fields, which are correctly plain strings
- one printed nothing whether or not the problem existed, and would have
  shipped as a check that always passes

Each was caught by `git worktree add` on an older commit that still had the
fault. Every check is now annotated with what it excludes and why.

> **A check you have not watched fail is not yet a check.**

**No client data, and the denylist is not in here either.** A pre-commit hook
blocks machine paths, email addresses, phone numbers and credential shapes.
Client-specific names come from a file outside the repository
(`~/.config/site-runbooks/denylist.txt`), because a public repo containing a
list of your clients has leaked them regardless of what it does with the list.

That is not a hypothetical distinction. The first version of that script held
the names in plaintext, each labelled `# client`, `# person`, `# place` — and
it excluded itself from its own scan, necessarily, since its patterns would
always match themselves. **The one file whose job was to prevent exposure was
the only file that caused it, and it was structurally invisible to every check
including its own.** It reached a public repository before anyone noticed.

The script now contains no names, so it no longer needs the exemption, so it
gets scanned like everything else. The measurements stay — they are what makes
the advice credible and they identify nobody.

---

## Where they came from

A production marketing site built from an internal Astro template, running on
Cloudflare with [PagesCMS](https://pagescms.org) for client editing. The
findings are not specific to that stack — anywhere a build turns
version-controlled content into pages, the same failures are available.

The template's own repairs are tracked separately and deliberately are not
here: they name specific commits in one codebase and belong beside it. What is
here is the part that transfers.

---

## Contributing to these

If a runbook is wrong about your stack, fix it here rather than locally. That
is the entire reason this repo exists: the failure these documents describe —
a fix that never reached the projects that needed it — is the same failure as
four copies of a runbook in four client repositories, each slightly different,
none of them canonical.

When you change a check, run it against a tree that has the fault before
committing it.

---

## Licence

MIT. Use them, adapt them, tell someone if they save you an afternoon.
