# Fixing images and media in a PagesCMS project

A portable checklist, written after fixing all of it on a live Astro +
Cloudflare site. **Nothing here assumes a particular kit or framework** — it
applies to any static site where PagesCMS edits content that a build turns into
pages. Every number in it was measured, not estimated.

Work through it in order. Items 1–3 are the ones that make a client say *"there
is a photo there and I can't change it"*; 4–6 are what stops them breaking the
site once they can; 7 is the one that decides whether they ever find out any of
it happened.

---

## 0. First, find out what is actually unreachable

Do this before deciding anything. Almost every project has more hardcoded
images than the developer remembers.

```bash
# every image referenced as a literal string inside a page/template
grep -rn 'src="/\|name="[a-z]\|image="[a-z]\|poster="[a-z]' src/pages src/layouts src/components
```

Then the reverse — for each CMS-backed data file, does every key resolve to a
declared field? A key with no field is content the client can see on the page
and cannot touch.

Write it as a script and keep it. On the site this came from, that audit is
what would have caught the whole problem months earlier:

- every `name=`/`image=`/`src=` in a page is an expression, never a literal
- every key in every CMS-backed file resolves to a field, **recursively** —
  nested objects and list items included

**The rule worth adopting:** an image the page renders is either a field or a
deliberate, stated exception. Never an oversight dressed up as a principle.
I wrote *"photographs are chosen in code"* into a config to justify five
fields, and it silently excused eight more that should have existed.

---

## 1. PagesCMS gives you a PATH; your code may want something else

This is the single most common reason image fields end up as `type: string`
with a description telling the client to type a filename from memory. That is
not an editable field, it is a quiz.

The picker cannot return your internal identifier — it returns the public path
of a file it found on disk:

```
you want:  photos/hero            (a key into a manifest, or an import alias)
you get:   /img/photos/hero-1200.webp
```

**If your pipeline emits predictable filenames, the mapping back is exact.**
Write one function and use it everywhere you resolve an image:

```js
// /img/ + key + -<width>.<ext>  →  key
export const toImageKey = (v) =>
  v.startsWith('/img/')
    ? v.replace(/^\/img\//, '')
       .replace(/-\d+(?=\.[a-z0-9]+$)/i, '')   // width suffix, anchored to the extension
       .replace(/\.[a-z0-9]+$/i, '')            // extension
    : v;
```

Three properties to verify in YOUR project, all of which bit me:

- **Any variant must resolve to the same thing.** The picker shows every width;
  the client will click whichever looks right. `-480` and `-1800` must produce
  identical output. Prove it by putting each into the data and diffing the
  built page — mine came out byte-identical.
- **A name ending in a digit must survive.** Anchor the width strip to the
  extension or `gallery-1` reached via `gallery-1-480.webp` becomes `gallery`.
- **Non-primary formats must work.** Social cards were `.jpg` while everything
  else was `.webp`; an extension-agnostic regex handles both.

If your setup uses framework image imports rather than a manifest, the same
principle applies in reverse: store the path and resolve it at build, or accept
the path directly.

### ⚠ Making the reader tolerant is only HALF the job — and the dangerous half

This is the mistake I actually shipped, so read it twice.

Once `toImageKey` accepts **either** form, your code works with both. Your CMS
does not. `type: image` is built entirely around the path: its picker returns
one, its thumbnail loads one, its "View on GitHub" link resolves one against
`media.input`. Hand it an internal key and it will treat that key as a repo
path — and correctly report that no such file exists.

So the moment you convert a field to `type: image`, **migrate every stored
value to the path form**. Usually one line, since your manifest already knows
the answer:

```js
if (value && !value.startsWith(mediaOutput)) value = manifest[value].src;
```

**And understand why this is so easy to miss.** A tolerant reader means the
site renders perfectly from the wrong shape. On mine: build green, type-check
clean, accessibility clean, and the rendered HTML **byte-identical** to before.
Every signal said correct. The client opened the CMS and saw eighteen grey
squares.

> A reader that accepts two formats will never tell you which one you stored.

### While you are there, check `options.path` points somewhere real

Same class of silent error. A picker scoped to `public/img/brand` when the
files live in `brand-v2/` opens on an empty folder. Nothing warns you; the
build does not care; it is visible only to the person using the CMS.

---

## 2. Uploads fail because of DIRECTION, not permissions

The most confusing failure in the whole category, and the explanation is one
sentence:

> The folder the CMS uploads into is where your pipeline **writes**, not where
> it **reads**.

A typical config points `media.input` at the built output (`public/img`,
`static/uploads`). A file dropped there is servable but has never been
resized, converted, or recorded — so it ships at one size, with no dimensions,
and the page shifts as it loads. If your image component requires a manifest
entry it will hard-fail instead.

**The fix is to point a media source at the pipeline's input:**

```yaml
media:
  - name: uploads
    label: New photographs
    input: media/source/uploads     # what the pipeline READS
    output: /img/uploads            # what it will WRITE, once processed
    extensions: [jpg, jpeg, png, heic, heif, tif, tiff]
```

…and run the pipeline in the build (`npm run media && astro build`, or your
equivalent). Verified end to end: an upload of `media/source/uploads/x.jpg`
makes PagesCMS store `/img/uploads/x.jpg`, which `toImageKey` turns into
`uploads/x` — exactly the key the pipeline creates.

**Measure the build cost before committing to it.** Mine: 94 images, cold run
**55s**, and deterministic (regenerated byte-for-byte). Acceptable. Yours may
not be.

⚠ **Check what your build image actually has.** My social-card generator needs
ImageMagick, which a Cloudflare build container does not carry. Not fatal —
those cards only regenerate when a card's photo changes, and their output is
committed — but a plan that says "run the pipeline in CI" must survive contact
with the actual container.

**If you do not enable uploads**, make the failure legible instead. Detect the
"came from the picker but has no processed variant" case specifically and say
so in words a non-developer can act on. Note in the message that the last good
deploy stays live, so the site is not broken — the change just does not appear.

---

## 3. Restrict formats at the door

Clients send what their phone produces. `extensions` on the media source is the
only layer that refuses an unusable format **in the UI, at upload time**,
rather than failing a build twenty minutes later.

```yaml
extensions: [jpg, jpeg, png, webp]        # for browsing processed output
extensions: [jpg, jpeg, png, heic, heif]  # for an upload source
```

**Include HEIC if your image library can read it.** Check rather than assume —
mine could, and was discarding iPhone photos anyway because of an over-narrow
regex in the pipeline:

```bash
node -e "console.log(require('sharp').format.heif)"
```

---

## 4. Make the pipeline say what it ignored

Test this by dropping a `.heic`, a `.gif`, a `.txt` and a deliberately corrupt
`.jpg` into your source folder. On mine, all four vanished — no output, no
warning, no entry. The failure surfaced much later as the image component
refusing to build, pointing at a file plainly sitting in the repo, which reads
as a bug in the tooling rather than a rejected upload.

Three fixes, all small:

- **Report every source file that produced no image**, with the reason. A PDF
  or a `.txt` in the folder is often legitimate — this is a report, not an
  error.
- **Wrap per-file processing in try/catch.** One corrupt upload used to abort
  the run midway, after outputs were written and the manifest partially
  updated — leaving the manifest describing a state on disk that no longer
  matched it. Name the file, carry on.
- **Flag oversized originals.** They are committed to git forever. Output size
  is capped by your width ladder so visitors are unaffected; only the repo
  carries it. Say that explicitly or someone will "fix" the wrong thing. This
  check immediately found an 11.9 MB / 5472×3648 original nobody had noticed.

Separate the two costs when you report them — *big for visitors* and *big for
the repo* feel like one problem and are not.

---

## 5. Text over photographs: measure it, do not forbid the edit

If any text sits on an image — a nav bar, a caption, a tile label — you have a
real reason to hesitate before handing that image to a client. **No automated
tool can help you here:** axe and pa11y report a flat ~1.01:1 for text over a
photograph, because no runner composites a transparent element over an image.

That makes the choice look binary: let clients break the navigation, or do not
let them choose. It is not binary.

**Write a build-time check that measures the composite off the rendered
pixels** — sample the region the text occupies, apply your scrim gradient in
code, compute contrast against the actual text colour, use per-channel maxima
so the brightest pixel decides rather than the average. Fail the build below
4.5:1. A failed build means the last good deploy stays live, which is the
correct outcome.

**Then feed each check a deliberately hostile frame.** A guard nobody has seen
fail is a guard nobody knows works. Doing that produced the most useful finding
of the whole exercise:

```
band header, 82% ink scrim   near-white photo →  9.66:1   cannot fail
tile label,  72% ink scrim   near-white photo →  6.76:1   cannot fail
script text, 62% cream scrim near-black photo →  2.86:1   ✗ REJECTED
```

Two of the three could not fail. Those scrims were strong enough that no
photograph gets through them — which is what a scrim is *for*. The fear that
had kept those images out of the CMS was unfounded, and the design had already
solved the problem while we went on acting as if it had not.

**The danger is not the photograph. It is a weakened scrim.** The one real
exposure was a wash lightened from 92% to 62% so a client's new photography
could show its colour — a good change, and the check is what makes it safe to
keep.

---

## 6. Do not put derived values in the CMS

Not image-specific, but it surfaces in the same pass and causes the same class
of bug. If `tel:`, `mailto:` or a maps URL is stored next to the phone number,
email or address it is built from, then two fields hold one fact — and that is
exactly how a tap-to-call link ends up dialling last year's number. Someone
changes the number they can see and has no reason to suspect a second copy.

Derive them in code. Show the client only the values that genuinely differ.

## 7. The handover document goes stale silently, and then it LIES

Everything above makes the CMS better. This is the part that decides whether
the client can use it.

If you wrote a "how to edit your website" guide — and if you hand a client a
CMS you should have — **it was written against the CMS as it was that week.**
Mine described six entries. There were thirteen by the time anyone looked.

Being out of date is the mild half. The serious half is what it said:

    the business address and phone number ... are not editable

which had been true and then wasn't. A client reading that either asks you to
do something they can do themselves, or — much worse — assumes their address
updates everywhere on its own, because your document told them the site owns
it.

**A CMS guide does not decay gracefully. It goes from helpful to actively
wrong, and the client is the only one who finds out.**

Two things worth doing:

- **Automate the cross-reference.** Every group and entry label in
  `.pages.yml` must appear in the guide. Ten lines, and it is the only thing
  standing between "we added a CMS entry" and "the handover document is now
  wrong". I wrote it ad hoc to find the above; it should not have been ad hoc.
- **Write the section on photographs that the guide almost certainly lacks.**
  Clients think in "can I change this picture", not in fields. Tell them: swap
  any picture for one already on the site; the several files listed per
  photograph are the same picture at different sizes and it does not matter
  which they pick; a brand-new photograph has to come to you first, and why.

And if you built the contrast check from item 5, tell them about it — not as a
restriction but as a reassurance. "Where words sit on a photograph the site
checks the two work together and refuses to publish one that would make the
words unreadable" is the sentence that turns a nervous editor into a confident
one.

---

## Verify before you call it done

### ⚠ grep gives confident wrong answers about binary and compressed files

Twice in one day here, and both times only rendering or decoding the artefact
gave the truth:

- searching a source file returned nothing, because a few NUL bytes in it made
  grep treat the whole file as binary. Nothing distinguishes that from "no
  match" — same empty output, same exit code
- searching a generated PDF for embedded font names found almost nothing, and I
  nearly concluded the fonts had been lost. The renderer writes compressed
  object streams; the data was there, just not as plain text. Rendering page one
  to an image settled it in seconds

If a check on a generated or binary artefact comes back clean, ask whether the
tool could see inside it at all.

### ⚠ Byte-identical output proves less than it looks like it proves

I leaned on "diff the built page" repeatedly and it is genuinely strong — for
refactors. It says the pages did not change.

It says **nothing** about whether the CMS can use the data, because the CMS is
not a page and the build never renders it. Every picker on my site was broken
while that diff came back clean. Treat the build and the CMS as two separate
systems that happen to read the same files, because that is what they are.

**Rendering checks**

- Put a picker path into the data by hand and diff the built page against the
  key version — should be byte-identical
- Do the same with the smallest AND largest variant
- Run the pipeline twice; the second run should report zero file changes
- Drop a bad format in the source folder; confirm it is named, not silent
- Run your contrast check against a hostile frame; confirm it actually FAILS —
  a guard nobody has seen fail is a guard nobody knows works

### ⚠ Test every guard against input that HAS the problem

This bit me a second time, writing a different check in this same body of work,
and the second one is more instructive because the check *looked* right.

I wrote a one-liner to find source files that git classifies as binary. It
reads perfectly, and it prints nothing — whether or not such a file exists. It
would have shipped as a check that always passes, inside a document arguing
that guards must be seen to fail.

The only reason it did not is that I ran it against an old commit that still
contained the bad file, and got silence there too.

**A green check is evidence of nothing until you have watched it go red.**
Keep a known-bad input around — a hostile frame, an old commit, a deliberately
malformed value — and run every guard against it once.

**CMS checks — none of the above touch these**

- For every `type: image`, assert the stored value starts with that media
  source's `output` **and** that the file exists under its `input`. Automate
  it; this is the check whose absence cost me a client-visible bug
- Assert every `options.path` resolves to a directory that exists and is not
  empty
- Assert every group and entry label in `.pages.yml` appears in the client
  guide — see item 7. Ten lines, and it is the only thing that notices when a
  new CMS entry makes the handover document wrong
- Re-run the audit from item 0 — no literals, no unreachable keys
- **Then open the CMS and look at every entry.** If a page shows a photograph
  and its form does not offer one, or offers a grey square, you are not
  finished. This is the only surface where these failures are visible, and it
  is the one nobody automates.
