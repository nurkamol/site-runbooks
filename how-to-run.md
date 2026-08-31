# Which runbook, and how to run it

Three documents. They are not alternatives — different audiences, and two of
them are meant to be *executed by an agent*, not read by a person.

| Runbook | Audience | Read or run |
| --- | --- | --- |
| [`runbooks/pagescms-field-mapping.md`](runbooks/pagescms-field-mapping.md) | an agent, in a project whose CMS is incomplete | **run** |
| [`runbooks/kit-drift-remediation.md`](runbooks/kit-drift-remediation.md) | an agent, in a shipped project that has fallen behind | **run** |
| [`runbooks/pagescms-media-playbook.md`](runbooks/pagescms-media-playbook.md) | a human or agent building or reviewing | read |

The two runnable ones share a shape, and it is the important part: **detect
first, report real findings, ask, then act.** Neither changes a file before you
have seen what it found and chosen a scope.

---

## Which one

**"The client says there is a photo on the page and no way to change it."**
→ `pagescms-field-mapping.md`. Coverage and organisation: every word and every
picture reachable, grouped so a non-developer can navigate them.

**"This site was built a while ago and I do not know what it is missing."**
→ `kit-drift-remediation.md`. Eight checks across the media pipeline, the CMS,
and the client's own documentation.

**"I am building something new and want to not create this problem."**
→ `pagescms-media-playbook.md`, read before wiring the CMS. Its items 0, 1 and
7 are design stances rather than repairs, and cost nothing at the start.

They overlap deliberately. Running both runnable ones on the same project is
fine — the second finds the first already fixed.

---

## Running one

Open the project, confirm the tree is clean, then:

```
> Read <path-to-this-repo>/runbooks/<runbook>.md and follow it.
  You are working in this repository. Phase 1 only until I answer.
```

**Type "Phase 1 only until I answer" even though the file says it.** It is the
instruction most likely to be skipped, and the whole value of these runbooks is
that they show findings before touching anything.

Expect a findings table and a short list of options with one recommended. If a
client is actively editing the site, take the smallest scope — usually "only
what the client can see". Most visible benefit, regenerates no assets.

### Not built from a template?

`kit-drift-remediation.md` reads as though it assumes one. **Seven of its eight
checks do not.** They ask whether image fields are pickers, whether stored
values resolve, whether pages hold hardcoded images, whether the pipeline
reports what it skipped, whether text over photographs is guarded, and whether
the client guide still matches the CMS — all true of any Git-backed CMS project.

Only the first check compares against an upstream template. Without one:

```
> ...This project was not built from a template, so treat D1 as
  "does the pipeline emit a modern format at all, and can its
  encoder produce one" rather than as a comparison.
```

---

## Rolling this out across several live sites

Deployed sites with clients on them. Order matters more than speed.

**Fix the upstream template first**, if the sites share one. Otherwise every
project you repair drifts again the next time you scaffold, and you do the work
twice.

**Take one project end to end before starting a second.** Resist running
detection across all of them at once. The first project is where you learn what
a runbook gets wrong about *your* stack — three checks in these over-reported
until they were tuned against a real tree. Learn that once, fix the runbook
here, and the rest go quickly.

**Order by client activity, not by size.** The site whose owner is in the CMS
this week gives the fastest feedback on whether the grouping actually makes
sense to someone who is not a developer.

### Per project

1. Clean tree, everything pushed. These repairs touch a lot of files and you
   want an obvious rollback point
2. Attach the runbook, **Phase 1 only**
3. Read the findings before choosing a scope
4. **Diff the built site against HEAD before deploying.** Most of this work
   should be byte-identical — moving copy into JSON, converting fields,
   migrating stored values. If a page changed and you did not intend it to,
   stop and find out why
5. Deploy, then **open the CMS and click through every group**
6. If the site has a written client guide, re-render it. It is almost certainly
   describing a CMS that no longer exists

### Three things that will bite

**A green build proves nothing about the CMS.** Every field can be unreachable
and every stored value unusable while the build is green, the types check, the
accessibility suite passes and the HTML is byte-identical. That combination is
not hypothetical — it shipped twice on the site these came from. The CMS is not
a page; the build never renders it.

**Regenerating images is the slow, noisy step.** Adding a modern output format
rewrites every file in the image directory and roughly doubles what the repo
carries. Own commit, not mixed into a CMS change.

**Do not wire dead files into the CMS.** Every project accumulates data modules
nothing imports. A form that edits a file nothing reads is worse than no form —
it invites someone to spend an afternoon rewording a page that will never
change. Check before converting; one project here had four.
