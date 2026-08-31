# Making a whole site editable in PagesCMS

**You are an agent working in an existing project.** Someone attached this and
pressed enter. Treat it as your instructions.

This is about **coverage and organisation** — every word and every picture on
the site reachable from the CMS, grouped so a non-technical person can find
them. Images specifically have their own document
([`pagescms-media-playbook.md`](pagescms-media-playbook.md)); this one assumes
you will read that too and does not repeat it.

Three phases, and **do not reorder them**:

1. **Audit.** Find what is unreachable. Change nothing.
2. **Report and ask.** Real counts, then how they want it done.
3. **Convert**, in dependency order, verifying each step.

The failure this prevents is not "the CMS is missing a feature". It is a client
opening a page, seeing their own words, and having nowhere to change them.

---

## Phase 1 — Audit. Change nothing.

### Run it, do not re-derive it

`check-cms.mjs` in the website-build-kit template already detects A1, A2 and A3 — content living
in code, data files with no form behind them, and keys inside a declared file with no field. It is
read-only.

```bash
npm run check:cms
```

⚠ **It runs against any project, including one built before it existed.** Every path it resolves
is relative to the working directory, so a clone of the kit can audit a site in place:

```bash
cd path/to/the-site
node path/to/website-build-kit/template/scripts/check-cms.mjs
```

Verified on a shipped site carrying none of those scripts: it ran and `git status` reported zero
changed files. You are not committing tooling to a client's repository in order to read it.

⚠ **The bash that used to sit under A1–A3 is gone on purpose.** It was a second implementation of
checks the kit already ships and tests, free to disagree with the first — the failure this
repository exists to describe. The sections below say what each finding *means* and what to do,
which is the half no script carries. **A4 has no check and cannot have one**: whether a sidebar is
organised or merely a list is a judgement.

### A1 · Content that lives in code

PagesCMS edits YAML, JSON and markdown. **It cannot structure-edit TypeScript.**
Any copy in a `.ts` file — or worse, in a component's frontmatter — is
invisible to it.


Separate what you find into three piles, and be honest about the third:

- **content** — prose, prices, questions, testimonials. Belongs in the CMS
- **structure** — navigation, routes, environment switches, search indexes.
  Deliberately stays in code; a mistyped nav path is a broken page, and it
  should fail a build rather than ship
- **dead** — imported by nothing. Check before assuming:


**Do not wire dead files into the CMS.** A form that edits a file nothing reads
is worse than no form — it invites someone to spend an afternoon rewording a
page that will never change. Report them; deleting is a separate decision.

### A2 · Data files with no form behind them

The reverse of A1, and the one that will catch you:


I added this check only after it caught me: a data file was created, wired into
its page, and its `.pages.yml` entry silently failed to apply. The page
rendered it. Every other check passed, because every other check walks the
*config* and validates what it points at — none of them can see a file the
config never mentions.

### A3 · Keys inside a declared file with no field


### A4 · Is it organised, or is it a list?

```bash
python3 - <<'PY'
import yaml
cfg = yaml.safe_load(open('.pages.yml'))
groups = [i for i in cfg['content'] if i.get('type')=='group']
loose  = [i for i in cfg['content'] if i.get('type')!='group']
colls  = []
def flat(i):
    for it in i:
        if it.get('type')=='group': yield from flat(it.get('items',[]))
        else: yield it
for e in flat(cfg['content']):
    if e.get('type')=='collection' and not (e.get('view') or {}).get('sort'):
        colls.append(e['name'])
print(f"groups: {len(groups)}   ungrouped entries: {len(loose)}")
print("collections with no sort options →", colls or "none")
PY
```

More than about six ungrouped entries and the sidebar is a list to scan rather
than a place to navigate. Collections without `view.sort` cannot be reordered
by the person using them.

---

## Phase 2 — Report, then ask

Give counts, not adjectives. *"Six of nineteen content areas are editable; the
homepage, About Us, the four class pages and the founder's letter are not"* is
a decision someone can make.

Then offer, and recommend one:

- **A · All of it** — every content area, grouped, in one pass
- **B · Pages first** — the copy a client actually asks to change; leave
  settings and structure alone
- **C · Organisation only** — group and sort what is already editable, add
  nothing
- **D · Report only**

**B is usually right.** It is the work a client will notice, and it does not
touch business facts, which are the dangerous ones.

**Wait for an answer.**

---

## Phase 3 — Convert

### 1 · Split each module into JSON + a typed façade

The values go into `.json` so PagesCMS can edit them. The types, and every
sentence of reasoning about *why the content is the way it is*, stay in the
`.ts` beside it:

```ts
import raw from './about.json';

export interface About { script: string; intro: string[]; /* … */ }
export const about: About = raw;
```

This is not ceremony. The reasoning is usually the most valuable thing in the
file — why a line breaks where it does, which words came from the client
verbatim, what was measured. Moving it into JSON would delete it. Moving the
*values* out and leaving the reasoning behind keeps both.

**Extract the values by EXECUTING the declaration, never by retyping it.**
Strip the imports from the frontmatter, append a `console.log(JSON.stringify(…))`,
run it with node, write the result. Retyping a client's copy is how a curly
apostrophe becomes a straight one and an em-dash becomes a hyphen — silently,
in prose someone wrote carefully.

Verify: build, and diff the built site against HEAD. **It must be byte-identical.**

### 2 · Group by how nervously a thing is edited

Not by where it appears on the site. The useful axis is blast radius:

| Group | What | Why together |
| --- | --- | --- |
| **Pages** | one entry per page | changed often, low risk |
| **Prices & offers** | prices, promotions | changed most often of all |
| **Studio details** | name, address, phone, shared header image | changed once in years, touches everything at once |
| **Words** | FAQ, journal, legal | long-form, its own rhythm |

Grouping is by risk, so the thing that touches twenty pages is never one
mis-click from the thing that touches one.

`type: group` is real and nests. The docs page for it 404s — it is confirmed in
`lib/schema.ts` in the pages-cms source, which treats `group` as a navigation
node with `items[]` and recurses:

```yaml
content:
  - name: pages
    label: Pages
    type: group
    icon: file-text
    items:
      - name: home
        label: Home
        type: file
        path: src/data/home.json
        format: json
        fields: [ … ]
```

### 3 · Choose field types by what a wrong value costs

- **`select`, not `string`, for anything load-bearing.** A URL slug, a session
  type, an environment key — if a typo produces a broken page rather than a
  wrong word, it must not be free text
- **`object` + `list: true`** for repeating things. Drag-reorder comes free,
  and list order is often the page order
- **`text` not `string`** wherever a line break is meaningful — and say so in
  the description, because a single-line field silently flattens it
- **`pattern`** on links, so `/about` and `https://…` are the only shapes that
  save
- **`min`/`max`** on lists where the design expects a count

Write a `description` on every non-obvious field, addressed to the client, not
to yourself. It is the only documentation they will ever read.

### 4 · Derive, do not store twice

If a `tel:` link, a `mailto:` or a map URL is stored beside the number, address
or email it is built from, two fields hold one fact — and that is how a
tap-to-call link ends up dialling last year's number. Compute them in the
façade. Show the client only the values that genuinely differ.

### 5 · Collections get a view

```yaml
view:
  fields: [title, publishedAt, draft]
  primary: title
  sort: [publishedAt, updatedAt, title]
  search: [title, description, categories]
  default: { sort: publishedAt, order: desc }
```

### 6 · Say what is NOT editable, and why

In the config, as prose, where the next developer will read it. Navigation,
layouts, redirects and environment switches stay in code because a bad value
should fail a build rather than ship quietly.

Be specific about anything that looks like an omission. An accessibility
statement, for instance, is a published legal claim whose worth is that every
line of it is true — a form that let anyone type "fully compliant" into it
would be a liability, not a feature. Write that down or someone will "fix" it.

---

## Verify

Re-run A2, A3 and A4. All clean.

**Then the two traps.**

**Byte-identical output proves the pages did not change. Nothing else.** The
CMS is not a page and the build never renders it — every field can be
unreachable, or every stored value unusable, while that diff is clean. It is
the single most misleading green check in this work.

**Ask each check what it cannot see.** A3 walks the config and validates what
it points at, so a data file the config never mentions is invisible to it —
which is exactly how one shipped. Whenever you write a check, ask what shape of
problem sits outside its reach, and write the check for that too.

Last:

- open the CMS and click through every group
- **if a page shows a photograph or a paragraph and its form does not offer
  one, you are not finished**
- if you hand the client a written guide, cross-reference it against
  `.pages.yml` — every group and entry label should appear in it, or the guide
  is already out of date
