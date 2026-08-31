# Fixing a shipped site that was built from an older kit

**You are an agent working inside a live, already-deployed project.** Someone
attached this file and pressed enter. Treat it as your instructions.

This is a remediation runbook, not a reading document. It has three phases and
**you must not reorder them**:

1. **Detect.** Run every check below. Change nothing.
2. **Report, then ask.** Show what you actually found, then ask which way to fix it.
3. **Fix**, the way they chose, verifying each step.

The one rule that matters: **do not present a menu before you have findings.**
A generic "shall I fix your images?" is worthless. "Your pipeline emits WebP
only and your 94 images are 19% larger than they need to be" is a decision
someone can make. Detect first, always.

---

## Phase 1 — Detect. Change nothing.

Run all of these. Each is read-only. Record the result of every one, including
the ones that come back clean — "not applicable" is a finding too, and the
report is more trustworthy when it says so.

Some checks will not apply: not every project has a media manifest, a CMS, or
client documentation. Say so and move on rather than forcing it.

**Adapt every one of these to the project in front of you, and sanity-check it
before you believe it.** Three of the eight below were wrong the first time I
wrote them — two over-reported on a project whose true answer was zero, and one
printed nothing whether or not the problem existed. Each is now annotated with
what it excludes and why. A check you have not seen produce both answers is not
yet a check.

### D1 · Does the pipeline emit a modern format?

```bash
grep -n "avif\|AVIF" scripts/optimize-media.mjs 2>/dev/null | head -3
node -e "const s=require('sharp');console.log('avif writable:', !!s.format.heif?.output)" 2>/dev/null
```

Missing AVIF while the encoder supports it is the highest-value, lowest-risk
finding you will get. **Measure it before reporting it** — the saving depends
entirely on the source photography and quoting someone else's number is how
you lose trust:

```bash
# after any AVIF port, compare like-for-like
python3 - <<'PY'
import pathlib
w=a=0
for f in pathlib.Path('public/img').rglob('*.webp'):
    g=f.with_suffix('.avif')
    if g.exists(): w+=f.stat().st_size; a+=g.stat().st_size
print(f"webp {w/1048576:.2f} MB → avif {a/1048576:.2f} MB ({(a-w)/w*100:+.1f}%)" if w else "no pairs yet")
PY
```

### D2 · Source files your tools cannot read

```bash
GLOBS=('*.mjs' '*.js' '*.ts' '*.astro' '*.css' '*.md')
comm -23 \
  <(git ls-files -- "${GLOBS[@]}" | sort) \
  <(git grep -I -l '' -- "${GLOBS[@]}" | sort)
```

Anything printed contains bytes that make git and grep classify it as binary.
That file is invisible to code review, to `grep`, and to any provenance or
secret-scanning gate that uses `grep -I`.

⚠ **This check is easy to get wrong.** `git grep -I --files-without-match ''`
looks like it should do the same job and prints nothing either way. If you
write your own variant, run it against a commit that still has the problem
before trusting it.

### D3 · CMS image fields that are not pickers

Skip if there is no `.pages.yml`.

```bash
python3 - <<'PY'
import yaml, json, pathlib
cfg = yaml.safe_load(open('.pages.yml'))
def flat(i):
    for it in i:
        if it.get('type')=='group': yield from flat(it.get('items',[]))
        else: yield it
def walk(fs, trail, out):
    for f in fs or []:
        n=f"{trail}.{f['name']}"
        low = f['name'].lower()
        looks = any(k in low for k in ('image','photo','glyph','badge','picture'))
        # only `string` — an `object` here is a wrapper holding the real field,
        # and a name ending "alt" is a description that SHOULD be text
        if looks and not low.endswith('alt') and f.get('type')=='string':
            out.append((n, f.get('type')))
        walk(f.get('fields'), n, out)
out=[]
for e in flat(cfg['content']):
    if e.get('type')=='file': walk(e.get('fields'), e['name'], out)
print("image-ish fields that are NOT type: image →", out or "none")
PY
```

A field named `image` typed `string` is a text box asking a non-technical
person to type a filename from memory. That is not an editable field.

**Two exclusions, both learned by over-reporting.** A field whose name ends in
`alt` is a description and is *correctly* a string; an `object` here is usually
a wrapper holding the real image field one level down. Without both, this check
flagged four fields on a project whose true answer was zero. Verified in both
directions: none on a fixed tree, and exactly the four real ones on the commit
before the pickers were added.

### D4 · Stored values the CMS cannot resolve

The one that renders perfectly and is completely broken. Skip if no
`.pages.yml`.

```bash
python3 - <<'PY'
import yaml, json, pathlib, os
cfg = yaml.safe_load(open('.pages.yml'))
srcs = {m.get('name','default'): m for m in (cfg['media'] if isinstance(cfg['media'],list) else [cfg['media']])}
def flat(i):
    for it in i:
        if it.get('type')=='group': yield from flat(it.get('items',[]))
        else: yield it
bad=[]
def walk(fs, data, trail):
    for f in fs or []:
        if not data or f['name'] not in data: continue
        v=data[f['name']]; at=f"{trail}.{f['name']}"
        if f.get('type')=='image':
            m=srcs.get((f.get('options') or {}).get('media','default'))
            for one in (v if isinstance(v,list) else [v]):
                if not one: continue
                if not one.startswith(m['output']): bad.append((at,one,'not a path under '+m['output']))
                elif not os.path.exists(one.replace(m['output'],m['input'],1)): bad.append((at,one,'file missing'))
        elif f.get('type')=='object':
            for item in (v if isinstance(v,list) else [v]):
                if isinstance(item,dict): walk(f.get('fields'), item, at)
for e in flat(cfg['content']):
    if e.get('type')=='file': walk(e.get('fields'), json.load(open(e['path'])), e['name'])
print("unusable image values →", bad or "none")
PY
```

**Report this one carefully.** The site will build, type-check, pass
accessibility and render byte-identically while every picker is broken. If you
tell them "everything passes", you will be wrong in the one place they can see.

### D5 · Images the page shows and the CMS cannot touch

```bash
grep -rnoE '(name|image|poster)="[a-z0-9][a-z0-9._-]*/[a-z0-9][^"]*"' \
  src/pages src/layouts src/components 2>/dev/null
```

**The slash is doing the work.** My first version matched any `name="..."` and
returned form fields, icon names and `<meta name="viewport">` — fifteen hits on
a project where the real answer was zero. Requiring a `/` isolates path-like
image references from every other attribute that happens to be called `name`.
Verified in both directions: zero on a cleaned tree, and exactly the eight real
ones on the commit before they were fixed.

Adjust the pattern to how *this* project addresses images before trusting it —
if it uses bare filenames with no slash, you need a different discriminator.

Every hit is a photograph on a live page with no field behind it. Also check
the reverse — content in a CMS-backed data file with no field declared for it.

### D6 · Does the pipeline say what it ignored?

```bash
grep -n "RASTER\|files.filter" scripts/optimize-media.mjs 2>/dev/null | head -5
```

If the file list is filtered before the loop, unrecognised files are dropped
in silence. Test it rather than reading it: drop a `.heic`, a `.gif`, a `.txt`
and a deliberately corrupt `.jpg` into the source folder, run the pipeline, and
see whether it says anything. Delete them afterwards.

Check whether the encoder can read HEIC — most can — because that is what a
client's phone produces and it is often being discarded by an over-narrow
regex rather than by any real limitation.

### D7 · Text sitting on photographs, unguarded

```bash
grep -rln "scrim\|gradient" src/components src/pages 2>/dev/null | head
ls scripts/check-contrast.mjs 2>/dev/null || echo "no contrast guard"
```

If any nav bar, caption or tile label sits over an image, and there is no
build-time contrast check, then nothing in the project can see that failure —
axe and pa11y both report a flat ~1.01:1 for text over a photograph because no
runner composites a transparent element over an image.

### D8 · Is the client's guide still true?

```bash
python3 - <<'PY'
import yaml, pathlib, glob
g = next((p for p in glob.glob('docs/*edit*.md')+glob.glob('docs/*client*.md')), None)
if not g: print("no client guide found"); raise SystemExit
cfg = yaml.safe_load(open('.pages.yml')); txt = pathlib.Path(g).read_text()
def flat(i):
    for it in i:
        if it.get('type')=='group': yield it['label']; yield from flat(it.get('items',[]))
        else: yield it['label']
missing=[l for l in flat(cfg['content']) if l not in txt]
print(f"{g}: labels absent from the guide →", missing or "none")
PY
```

Expect near-misses rather than exact matches: a guide that shortens an entry
labelled "Courses (teacher training)" to just "Courses" is fine. **Read the
output, do not treat it as pass/fail** — it is there to make you look, not to
gate.

Also read it for statements that have since become false — "X is not
editable" is the dangerous shape. A guide that is merely out of date is a
nuisance; one that tells the client something untrue about who controls their
address is a liability.

---

## Phase 2 — Report what you found, then ask

Write the findings as a table. Real numbers, no hedging, and an explicit line
for every check that came back clean or not applicable.

| # | Finding | Evidence | Impact | Risk to fix |
| --- | --- | --- | --- | --- |
| D1 | WebP only, no AVIF | 94 images | ~19% larger than needed | low |
| D4 | 18 CMS image values unusable | every picker | client cannot change any photo | low |
| … | | | | |

Then ask. Offer these, and **recommend one**, with your reason:

- **A · Everything, in dependency order.** The full remediation below.
- **B · Only what the client can see.** D3, D4, D5, D8 — the CMS and the
  handover doc. No pipeline changes, no rebuilt assets, no new dependencies.
- **C · Only the invisible correctness fixes.** D1, D2, D6, D7 — output size,
  binary files, silent skips, the contrast guard. Nothing about the CMS.
- **D · Report only.** Write the findings to a file and stop.

Say which you would pick. On a site with a client actively editing, B first is
usually right: it is the smallest change with the most visible benefit, and it
does not regenerate a single asset.

**Wait for an answer. Do not begin.**

---

## Phase 3 — Fix, in this order

Order matters: later items depend on earlier ones. Verify each before moving on.

### 1 · Pipeline first (D1, D6)

Port the newer pipeline from the kit — **do not copy the project's file over
the kit's, or the reverse, without diffing them.** Drift usually runs both
ways: the project may have local improvements the kit lacks.

Add AVIF alongside WebP, never instead. Accept HEIC. Report skipped files.
Wrap per-file processing in try/catch so one corrupt upload cannot abort a run
midway and leave the manifest describing a state that no longer exists.

Verify: run twice, second run reports zero changes. Measure the saving.

### 2 · Make the reader accept both forms (D3 prerequisite)

If images are addressed by an internal key, teach the resolver to accept the
CMS's public path too, so the two can meet:

```js
export const toImageKey = (v) =>
  v.startsWith(PUBLIC_PREFIX)
    ? v.replace(PUBLIC_PREFIX,'').replace(/-\d+(?=\.[a-z0-9]+$)/i,'').replace(/\.[a-z0-9]+$/i,'')
    : v;
```

Verify three things, all of which bite: any variant width resolves to the same
key; a name ending in a digit survives; non-primary extensions work.

### 3 · Convert the fields AND migrate the data (D3 + D4 together)

**These are one change. Doing the first without the second is the bug in D4.**

Once the reader is tolerant, the site renders correctly from the old values —
so nothing will tell you the CMS is broken. Convert `type: string` to
`type: image`, then migrate every stored value to the path form in the same
commit:

```js
if (value && !value.startsWith(mediaOutput)) value = manifest[value].src;
```

Scope each field's picker with `options.path`, and check that path is a
directory that exists and is not empty.

Verify: re-run D4. It must be clean. Then **open the CMS and look.**

### 4 · Make every displayed image a field (D5)

Move every hardcoded image reference into data and give it a field. An image
the page renders is either a field or a deliberate, stated exception — never
an oversight.

Verify: re-run D5, expect nothing.

### 5 · Guard what you just exposed (D7)

If text sits on any image you have now made editable, add a build-time
contrast check that measures the composite off the rendered pixels — per
channel maxima, every format served, failing below 4.5:1.

Then **fire a hostile frame at it and watch it fail.** A guard nobody has seen
fail is a guard nobody knows works. Expect a surprise: strong scrims often
turn out to make certain images unbreakable, which means the fear that kept
them out of the CMS was unfounded and you can say so.

### 6 · Update the handover document (D8)

Correct anything that became false — especially "you cannot change X" where X
is now editable. Add the photographs section. Automate the label
cross-reference so it cannot silently drift again.

### 7 · Add the checks to the build

Whatever you wrote for D2, D4, D7 and D8 belongs in the production build, not
in your memory. They are the only things that look at the editing surface
rather than the rendered one.

---

## Verifying, and the two traps that will catch you

**Byte-identical output proves the pages did not change. Nothing more.** It
does not cover the CMS, because the CMS is not a page and the build never
renders it. Every picker can be broken while that diff is clean — that is
precisely how D4 ships unnoticed.

**grep lies about binary and compressed files.** A file with a few stray NUL
bytes returns nothing and exits 1, exactly as it does for "no match". A
generated PDF or an image will not yield its internals to a text search. If a
check on a generated artefact comes back clean, ask whether the tool could see
inside it at all — then render or decode it instead.

Final pass:

- pipeline twice → zero changes on the second run
- D2, D4, D5, D8 all clean
- contrast guard seen to fail on a hostile input
- site builds, deploys, and the pages are unchanged
- **the CMS opened and looked at, entry by entry**

If a page shows a photograph and its form does not offer one, you are not
finished.
