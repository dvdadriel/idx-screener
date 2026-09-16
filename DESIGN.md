---
name: IdxScreener
description: A bench instrument for reading one momentum strategy honestly, once a day.
colors:
  void: "oklch(0.128 0.008 265)"
  well: "oklch(0.163 0.008 265)"
  panel: "oklch(0.196 0.009 265)"
  rule: "oklch(0.285 0.010 265)"
  rule-hi: "oklch(0.395 0.012 265)"
  read: "oklch(0.965 0.003 265)"
  read-2: "oklch(0.775 0.008 265)"
  read-3: "oklch(0.635 0.010 265)"
  trace: "oklch(0.868 0.196 122)"
  rise: "oklch(0.808 0.135 162)"
  fall: "oklch(0.712 0.165 25)"
  proven: "oklch(0.808 0.135 162)"
  watch: "oklch(0.808 0.145 78)"
  failed: "oklch(0.635 0.010 265)"
typography:
  display:
    fontFamily: "IBM Plex Mono, ui-monospace, SFMono-Regular, monospace"
    fontSize: "22px"
    fontWeight: 500
    lineHeight: 1.15
    letterSpacing: "normal"
    fontFeature: "tnum 1, zero 1"
  title:
    fontFamily: "IBM Plex Mono, ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.5
  body:
    fontFamily: "IBM Plex Mono, ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
    fontFeature: "tnum 1, zero 1"
  prose:
    fontFamily: "IBM Plex Sans, ui-sans-serif, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "IBM Plex Mono, ui-monospace, monospace"
    fontSize: "11px"
    fontWeight: 400
    letterSpacing: "normal"
rounded:
  edge: "2px"
spacing:
  cell: "7px 12px"
  rail: "14px 16px"
  band: "40px"
components:
  reading:
    backgroundColor: "{colors.void}"
    textColor: "{colors.read}"
    typography: "{typography.display}"
    padding: "14px 16px"
  table-row:
    backgroundColor: "{colors.void}"
    textColor: "{colors.read-2}"
    typography: "{typography.body}"
    padding: "7px 12px"
  table-row-hover:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.read-2}"
  table-head:
    backgroundColor: "{colors.well}"
    textColor: "{colors.read-3}"
    typography: "{typography.label}"
    padding: "7px 12px"
  chip:
    backgroundColor: "transparent"
    textColor: "{colors.read-2}"
    rounded: "{rounded.edge}"
    typography: "{typography.label}"
    padding: "2px 7px"
  nav-link:
    backgroundColor: "transparent"
    textColor: "{colors.read-3}"
    typography: "{typography.title}"
    padding: "4px 0"
  nav-link-hover:
    textColor: "{colors.read}"
---

# Design System: IdxScreener

## 1. Overview

**Creative North Star: "The Bench Instrument"**

This is not an app that reports on a strategy; it is a device that takes readings of one. A bench instrument has a face, not a home page. It shows a value, the conditions the value was taken under, and how much the value is worth — and it does not editorialise about any of them. Nothing on the face exists to reassure the operator that the machine is working.

The register is product, and the reader is exactly one person: the operator who built the system, opening it once a day after IDX closes, often on a phone. They know what ATR and a permutation test are. What they cannot hold in their head is which numbers have earned trust and which have not, so the interface carries that instead — every figure is rendered next to its evidence status, in the same visual weight as the figure.

What this system rejects, by name, is everything PRODUCT.md lists as an anti-reference: **emoji as iconography**, **gradients and glow**, **uppercase tracked eyebrows above every section**, and **uniform card grids**. It also refuses the first reflex for its own category. "Futuristic trading dashboard" resolves to neon-on-black glassmorphism; the reflex one tier deeper resolves to a Bloomberg-amber or terminal-green console. Both were considered and rejected. Futurism here is carried by precision — tabular figures, hairline rules, one scarce signal colour — not by effects. A modern instrument looks modern because it is exact, not because it is lit.

**Key Characteristics:**
- Mono-forward: the monospace face runs the interface; the proportional face is reserved for prose
- Tables and hairline rules instead of cards; nothing is boxed that is not genuinely a separate object
- One signal colour, budgeted under 5% of the surface
- Every figure carries an evidence glyph, and every direction carries a sign
- Density over chunking: one expert reader, one screen, once a day

## 2. Colors: The Calibration Palette

A near-black ground carrying a trace of blue chroma, a three-step text ramp, and exactly one saturated colour that is spent sparingly.

### Primary
- **Calibration Chartreuse** (`trace`): The single signal. It appears on the leading rank marker, the focus ring, the nav-link underline on hover, and the flash that reports a new row — and nowhere else. It reads as an oscilloscope trace or a calibration mark, which is why it was chosen over the three obvious candidates: cyber-cyan is the AI reflex for "futuristic", amber is the Bloomberg reflex, and terminal green is the console reflex.

### Secondary
- **Jade Rise** (`rise`) and **Clay Fall** (`fall`): Direction. Never load-bearing on their own; every figure they colour also carries a `+` or `−` (U+2212, so the sign aligns with tabular digits), and every direction cell also carries a `▲` / `▼` glyph.

### Tertiary
- **Proven Jade** (`proven`), **Watch Ochre** (`watch`), **Failed Grey** (`failed`): Evidence status. Always paired with the glyphs `●` `◐` `○` so the status survives greyscale, colour deficiency, and a screenshot pasted into a chat.

### Neutral
- **Void** (`void`): The page ground. Near-black with 0.008 chroma toward blue — the instrument's own hue, not a default-warm tint and not a dead grey.
- **Well** (`well`): Sunken surfaces. Sticky table headers only.
- **Panel** (`panel`): The single raised surface, used only for row hover.
- **Rule** (`rule`) / **Rule Hi** (`rule-hi`): Hairline dividers and section boundaries. These do the work cards used to do.
- **Read / Read-2 / Read-3**: The text ramp — figures and headings, body and units, labels and captions. Measured at 18.2:1, 9.9:1 and 5.9:1 against Void.

### Named Rules

**The Scarce Signal Rule.** Calibration Chartreuse covers under 5% of any screen. If a second element wants it, one of them is wrong. Its rarity is the entire reason it means something.

**The Never-Colour-Alone Rule.** No fact may be encoded in hue alone. Direction carries a sign and a glyph; evidence status carries a glyph; regime carries a word. Strip the colour and the page must still be readable — red-green deficiency is common and this is financial data.

**The Measured-Not-Assumed Rule.** Every text-on-background pair ships only after its contrast ratio is computed. The palette this replaced used `zinc-500` / `600` / `700` for labels, measuring 4.12 / 2.57 / 1.91:1 on `zinc-950` — two of the three failed AA outright, and nobody noticed because they "looked elegant".

## 3. Typography

**Display / Body / Label Font:** IBM Plex Mono (with `ui-monospace`, `SFMono-Regular`, Menlo)
**Prose Font:** IBM Plex Sans (with `ui-sans-serif`, `system-ui`)

**Character:** A superfamily pairing across a real contrast axis — monospace against proportional, same skeleton, different job. Plex Mono is engineered rather than playful; it has the narrow, even colour of a data face without the branded quirks of JetBrains Mono. Tabular figures and slashed zero (`font-feature-settings: "tnum" 1, "zero" 1`) are on globally, because a column of numbers that does not align is not a column.

### Hierarchy
- **Display** (500, 22px, 1.15): Instrument readings only — the value in a rail cell. This is the largest type on the page; there is no hero.
- **Title** (500, 13px, 1.5): Section headings and the wordmark. Barely larger than body, because a section heading is a label for a band, not an announcement.
- **Body** (400, 13px, 1.5): Table cells, figures, the interface at large.
- **Prose** (400, 13px, 1.5, Plex Sans, ≤70ch): Explanatory paragraphs only — the caveat under a table, the empty-state explanation.
- **Label** (400, 11px): Reading labels, notes, table headers, evidence text, captions.

### Named Rules

**The Numbers-Are-The-Typography Rule.** The type scale spans 11px to 22px — a ratio of about 1.2 across five steps. That is deliberately shallow. Emphasis comes from alignment, tabular figures, and colour budget, not from size. If a value needs to be bigger to be noticed, the layout is wrong.

**The No-Eyebrow Rule.** Section headings are a title and a rule that runs to the edge. No small uppercase tracked kicker above them, ever. A tracked all-caps eyebrow on every section is the saturated AI scaffold of the era, and the rule already does the separating work.

## 4. Elevation

There are no shadows in this system. None. Depth is conveyed by three things: a hairline (`rule`) between peers, a heavier hairline (`rule-hi`) between sections, and a single tonal step (`panel`) that appears only on row hover. The sticky instrument bar is the one element that floats, and it announces itself with a `backdrop-filter: blur(6px)` and a bottom `rule-hi`, not with a drop shadow.

An instrument face is milled flat. The moment a surface lifts off the page, it reads as a card, and cards were removed on purpose.

### Named Rules

**The Flat Face Rule.** `box-shadow` is prohibited. If an element needs to separate from its neighbour, give it a 1px rule. If it needs to separate from the page, give it a tonal step. There is no third option.

**The Glow Audit.** The previous system carried `glow-emerald`, `glow-sky`, `glow-rose` and `glow-amber` as `box-shadow: 0 0 24px -8px rgba(...)`. If you find yourself reaching for a coloured blur to make something feel important, the information hierarchy has failed and the blur is covering for it.

## 5. Components

### Measurement rail
The signature component. A row of readings separated by hairlines, collapsing to two columns on tablet and one on phone.
- **Structure:** `display: grid`, `grid-auto-flow: column` above 52rem; explicit two-column grid between 30rem and 52rem; stacked below.
- **Anatomy:** label (11px, `read-3`) → value (22px, 500, `read`, tabular) → note (11px, `read-3`, often an evidence line).
- **Why not cards:** the readings are facets of one instrument state, not five independent objects. Boxing them would assert a separation that does not exist.

### Instrument table
- **Shape:** No radius, no outer border, no zebra striping. Rows are separated by 1px `rule`; the header sits on `well` with a `rule-hi` beneath it.
- **Sticky header:** `position: sticky; top: 49px` — clears the instrument bar.
- **Alignment:** Figures right-aligned with `font-variant-numeric: tabular-nums`, so decimal points form a vertical edge the eye can run down. Symbols are `read` and 500; everything else is `read-2`.
- **Hover:** background steps to `panel`. No transform, no shadow.
- **Rank marker:** zero-padded (`01`, `02`) in `read-3`; rank 1 alone takes `trace`.

### Evidence marker
- **Style:** a glyph plus a word at 11px — `● tervalidasi`, `◐ observasi`, `○ gagal uji`.
- **Placement:** in the note line of a rail cell, or as its own table column.
- **Rule:** a figure whose backing failed a test must never be able to pass for one that did. The marker is not a footnote; it is a field.

### Chip
- **Style:** 1px border in `currentColor`, 2px radius, 11px, 2px 7px padding, transparent background.
- **Use:** the regime state in the instrument bar, and nothing else so far. It borrows the text colour for its border so a `rise` / `fall` chip needs no extra token.

### Navigation
- **Style:** plain text links at 12px in `read-3`, with a transparent 1px bottom border.
- **Hover / focus:** colour steps to `read` and the bottom border becomes `trace`, over 160ms on `cubic-bezier(0.22, 1, 0.36, 1)`.
- **Mobile:** the bar wraps; the regime block drops to its own full-width row below the wordmark and nav, since regime is the fact that must survive a narrow screen.

### Empty state
- **Style:** a 1px `rule` box with a `read` title line and a Plex Sans paragraph beneath.
- **Rule:** an empty state must name the mechanism and say what would fill it. "Cash — tidak ada peringkat yang direkam hari ini" (the system worked and chose cash) is a different state from "Belum ada snapshot sama sekali" (the pipeline is dead), and the interface must never render one when it means the other.

## 6. Do's and Don'ts

### Do:
- **Do** compute the contrast ratio of every new text/background pair before shipping it. AA (4.5:1 body, 3:1 large) is the floor, not the target.
- **Do** pair every colour-encoded fact with a sign, glyph, or word. Direction gets `+` / `−` and `▲` / `▼`; evidence gets `●` `◐` `○`.
- **Do** use U+2212 (−) for negative numbers, not a hyphen. It shares the width of a tabular digit.
- **Do** format numbers Indonesian-style: `.` for thousands, `,` for decimals. The interface is in Indonesian; `13,041` reads as thirteen-point-oh-four-one to this reader.
- **Do** separate peers with a 1px `rule` and sections with `rule-hi`.
- **Do** keep prose under 70ch and set it in Plex Sans. Everything else is Plex Mono.
- **Do** let motion report a state change and nothing else — the `trace-in` row flash is the whole vocabulary.
- **Do** give every animation a `prefers-reduced-motion: reduce` path.

### Don't:
- **Don't** use **emoji as iconography**. No ⚡ 🔍 🇮🇩 💰 📈 🚀 📊 in the wordmark, nav, or beside a heading. This was the single strongest AI tell in the system this replaced.
- **Don't** use **gradients or glow**: no `linear-gradient` surfaces, no blurred colour orbs in corners, no `box-shadow` glows, no gradient wordmark. `background-clip: text` on a gradient is prohibited outright.
- **Don't** put an **uppercase tracked eyebrow above every section**. No `text-[10px] uppercase tracking-wider` kicker above a heading.
- **Don't** build **uniform card grids**. No `rounded-2xl` boxes repeated down the page, and never a card inside a card.
- **Don't** reach for **neon-on-black cyber terminal** or **glassmorphism**. Both were considered as the "futuristic" reading and rejected as the category reflex.
- **Don't** build a **hero metric**: giant number, small label, supporting stats, accent gradient. The rail exists so that no single reading gets to shout.
- **Don't** use a coloured `border-left` wider than 1px as a decorative stripe.
- **Don't** spend `trace` on decoration. If more than one element on a screen is chartreuse, one of them is wrong.
- **Don't** hide a failed result. Retired strategies stay on screen marked `○`, because the reason they were removed is evidence, and hidden evidence gets repeated.
