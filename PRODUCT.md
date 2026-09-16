# Product

## Register

product

## Users

One operator — the person who built the system — reading it once a day after IDX closes (~17:00 WIB), usually on a laptop, often on a phone from somewhere other than a desk.

The job is not "find a stock to buy." It is **check whether the system still deserves to be trusted**: did the daily chain run, is the regime gate on or off, what does momentum rank today, and is the forward-tracking evidence still holding up against the backtest that predicted it.

No onboarding. No term glossary. The reader knows what MA50, ATR, alpha, and a permutation test are, and will notice immediately if a number is wrong. What they cannot do is remember, at a glance, which numbers have been validated and which have not — the interface has to carry that for them.

## Product Purpose

IdxScreener ranks Indonesian (IDX) stocks by cross-sectional momentum, gates entries on an IHSG regime filter, and paper-trades the result so the strategy accumulates a forward-tracking record before any real money is involved.

It exists because the operator kept testing strategies that looked good in a backtest and failed out of sample. Four of them — confluence, squeeze breakout, swing pick, per-trade backtesting — have already been deleted on the evidence of this system's own measurements. A foreign-flow "smart money" overlay was built, tested, and left switched off because it could not beat a random subset of the same size (p ≈ 0.32).

Success is not a rising equity curve. Success is **the screen telling the truth fast enough that a bad strategy gets killed early.**

## Brand Personality

**Instrument, not application.** Three words: *precise, candid, unhurried.*

It should read like a measuring device — something that reports a value and its error bar without editorializing. The voice is the voice already in the codebase comments and `docs/backtest-results.md`: plain, specific, willing to say "this is not working" in the same tone it says anything else. No hype, no reassurance, no celebration of a green number.

"Futuristic" here means **precision, not effects**: dense aligned numerals, hairline rules, a single signal color, nothing glowing. A modern instrument looks modern because it is exact, not because it is lit.

## Anti-references

Rejected by name, all currently present in the codebase and to be removed:

- **Emoji as iconography.** ⚡ 🔍 🇮🇩 💰 📈 🚀 📊 in the logo, nav, and above every section heading. The single strongest AI tell on the page.
- **Gradients and glow.** `bg-gradient-to-br` on every card, blurred color orbs in card corners, `glow-emerald` / `glow-sky` / `glow-rose` box-shadows, a gradient logo badge.
- **Uppercase tracked eyebrows above every section.** "FEAR & GREED", "COMPOSITE SENTIMENT", "LATEST CLOSES", "IDX RADAR" — the 2023 kicker applied as page grammar.
- **Uniform card grids.** Every piece of information wrapped in an identically-sized `rounded-2xl`, including cards nested inside cards.

Also rejected:

- **Neon-on-black cyber terminal.** The first-order reflex for "futuristic trading dashboard." Avoided deliberately, not by accident.
- **Glassmorphism** as a default surface treatment.
- **The hero-metric template**: giant number, small label, supporting stats, accent gradient.
- Any treatment that makes an unvalidated number look as settled as a validated one.

## Design Principles

1. **Uncertainty is a data field, not a disclaimer.** Every figure carries its evidence status — validated / observation / failed-test — rendered with the same weight as the figure. A number whose backing failed a permutation test must never be able to pass for one that didn't.

2. **Density is respect.** One expert reader, once a day. Show the whole picture on one screen rather than paginating it into friendly chunks. Tables beat cards; alignment beats decoration.

3. **The signal color is a scarce resource.** Color marks state (regime on/off, position held/cash, gain/loss) and nothing else. If something is colored, it means something.

4. **Numbers are the typography.** Tabular figures, right-aligned, one monospace family doing the real work. Chrome recedes; the data is the design.

5. **Nothing moves unless something changed.** Motion reports state transitions — a new rank, a regime flip, a fresh row. There is no page-load choreography; the operator opens this to read, not to watch.

## Accessibility & Inclusion

- **WCAG 2.1 AA.** Body text ≥ 4.5:1, large text ≥ 3:1. The current `text-zinc-500/600/700` on `zinc-950` almost certainly fails and must be re-checked, not assumed.
- **Never encode gain/loss in color alone.** Sign (`+` / `−`), position, or glyph must carry the same information. Red-green deficiency is the most common form and financial data is where it does the most damage.
- **`prefers-reduced-motion: reduce` is honored everywhere.** Every transition has a still or crossfade alternative.
- **Phone is a first-class target,** not a fallback. Dense tables must degrade to a readable stacked form without losing the evidence-status column.
