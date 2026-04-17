# Xe Iaso Design System

A design system derived from [xeiaso.net](https://xeiaso.net) — the personal blog and portfolio of **Xe Iaso**, a solo blogger, coder, developer advocate, vtuber, and technical educator based in Ottawa, Canada. The brand voice is conversational, confident, terminally-online, and unapologetically *personal*. Visually: **Gruvbox** (by Morhetz) warm-neutral palette, serif headlines (Podkova) over sans body (Schibsted Grotesk), soft parchment-like surfaces.

## Sources

- **Codebase:** [github.com/Xe/site](https://github.com/Xe/site) — Go backend, Lume (Deno) static site generator, Tailwind, Preact JSX. Root config: `lume/tailwind.config.js`, `lume/src/styles.css`, `lume/src/_components/*`.
- **Fonts (provided):** Schibsted Grotesk (Google Fonts, variable + italic), Podkova (Google Fonts, variable). Plus linked Iosevka Iaso family from `https://files.xeiaso.net/static/font/iosevka/family.css` at runtime.
- **Icons:** Inline SVGs in components, mostly [Tabler Icons](https://tabler.io/icons) stroke style (24×24, stroke-width 2, round caps).
- **Stickers / mascots:** fetched live from `https://stickers.xeiaso.net/sticker/{character}/{mood}` — Xe, Mara, Cadey, Nicole, Aoi, and friends. Not stored here; refer to URL scheme.
- **Note:** The codebase is licensed such that reuse is discouraged — this system extracts the *visual language only* for creating new-but-on-brand work.

## Index

| Path | What it is |
|---|---|
| `colors_and_type.css` | Full token set — CSS variables for colors, type, radius, shadows, spacing; semantic rules for `h1`…`h6`, `a`, `pre`. |
| `fonts/` | Podkova + Schibsted Grotesk TTF variable fonts. |
| `assets/` | Xe mascot logo SVG, reference flowcharts. |
| `preview/` | Design-system cards (typography, color scales, components). |
| `SKILL.md` | Agent skill manifest — cross-compatible with Claude Code. |

---

## CONTENT FUNDAMENTALS

**Voice.** First-person, conversational, personal. Xe writes *with* you rather than *at* you. The tone swings between earnest technical walkthrough and dry shitpost, often in the same sentence.

**Personal pronouns.** Xe's pronouns are it/its (also they/them). Xe is **enbyware**.

**Capitalization.** Sentence case for headings ("Recent Articles", "Notable Publications"). Product/brand names preserve their casing (Tailscale, NixOS, Kubernetes, Anubis). "I" and "you" both used freely.

**Examples from live copy:**

> "I'm Xe Iaso, I'm a technical educator, conference speaker, twitch streamer, vtuber, and philosopher that focuses on ways to help make technology easier to understand and do cursed things in the process."

> "Don't. This code is not made for you to be able to use without extensive modification."

> "This post is a work of fiction. All events, persons, companies, and other alignment with observable reality are the product of the author's imagination…"

**Vibe.** Warm (Gruvbox cream surfaces reinforce this), slightly confrontational, protective of craft. Willing to be weird. Blog-post titles like "A weapon to surpass Metal Gear", "I was wrong about Nix", "Much ado about nothing". Character-driven: posts often feature a fictional cast (Mara, Cadey, Aoi) debating a topic via chat bubbles rendered with sticker avatars.

**Emoji.** Used sparingly. Mostly none in chrome; occasional in-body flourishes (🥺 is a personal Xe signature — literally a domain). Stickers do most of the emotional-signaling work emoji would normally do.

**Admonitions** use plain English titles: Note / Warning / Tip / Info — never "👀 Heads up!" etc.

---

## VISUAL FOUNDATIONS

**Palette — Gruvbox, by Morhetz.** Warm cream on warm cream in light mode (`#f9f5d7` hard → `#fbf1c7` primary → `#ebdbb2` raised). The "neutrals" are not gray; they're all *yellow-leaning beige*. Dark mode flips to warm charcoal (`#1d2021` → `#282828` → `#3c3836`). Accents are muted-saturated and distinctive: red `#cc241d`, yellow `#d79921`, green `#98971a`, blue `#458588`, purple `#b16286`, aqua `#689d6a`, orange `#d65d0e`. Every hue has a *bright* and a *muted* variant, and light vs. dark pick opposite ends — keeps contrast balanced across modes. **No blue-purple gradients. No neon. Neutrals are warm, never cool.**

**Type.** Headings: **Podkova** (a warm slab-ish serif, weight 400–800, typically 600). Body: **Schibsted Grotesk** (variable 400–900, usually 400 for prose, 600 for emphasis). Mono: **Iosevka Curly Iaso** (a quirky Iosevka variant; self-hosted). Fallbacks include the full Iosevka Iaso family (Aile / Etoile / Curly).

**Scale.** `text-3xl` (~30px) for page H1, `text-2xl` (~24px) section, `text-xl` (~20px) sub. Body 16px. Line-height 1.55 for prose. `text-wrap: pretty` in headings and `.prose p`.

**Backgrounds.** Mostly solid cream/charcoal — no gradients, no repeating textures. The one decorative gradient is the SponsorCard top rule (2px, orange→purple). Hero images are full-bleed figures with an italic caption; images are AVIF/WebP/JPG `<picture>` with loading=lazy. AI-generated hero art is cinematic and warmly graded — never cool or blue. Occasional *snow* animation on the homepage for winter.

**Animation.** Restrained. 200ms transitions. Buttons lift 1px on hover (`translateY(-1px)`). No bouncing, no parallax, no scroll-jacking. A loading spinner component exists but is used sparingly.

**Hover / press.**
- Buttons: darker shade of the same color, lift 1px, shadow grows from sm→md.
- Links: invert — text becomes `link-hover` (cream) on a `link-hover-bg` (magenta `#9e0045`). Visited links get their own darker hover state. This is the single most distinctive interaction pattern.
- Press: no custom press state; the anchor/hover styling carries.

**Borders.** 1px solid, color `fg-4` (light) / `fgDark-4` (dark). Never colored borders except semantic admonitions. No "left-border accent" cards.

**Shadows.** Two steps: `shadow-sm` (default) and `shadow-md` (hover). Soft, low, no glow.

**Radii.** 6px (`rounded-md`) cards, 8px (`rounded-lg`) details blocks, 12px (`rounded-xl`) pill buttons, 2px (`rounded-xs`) avatar frames (boxy on purpose — the sticker is the star).

**Cards.** `bg-bg-2` / `dark:bg-bgDark-2`, 1px border `border-fg-4`, `rounded-md`, `shadow-sm`. Padding `p-4` or `px-6 py-5`.

**Chat bubbles (Conv).** Stacked rows sharing a `bg-bg-soft` / `dark:bg-bgDark-soft` background. First row rounds top corners, last row rounds bottom; middle rows pull up 1px to form a continuous surface. 64×64 boxy sticker avatar on the left.

**Blockquote.** Custom: `mx-auto rounded-lg bg-bg-2 p-4`, no left border, prefixed with a literal `>` character — like email quoting.

**PullQuote.** Classic left-bar: 4px solid blue on the left, gray background, italic.

**Transparency / blur.** Not used. Everything is opaque.

**Imagery vibe.** Warm, slightly dreamy AI-generated hero art for many posts (Stable Diffusion, Flux). Screenshots and diagrams are inline SVGs rendered from Graphviz — classic blocky, functional.

**Layout.** Single column, max ~65–80ch prose width. Chat snippets go wider (`lg:w-[80ch]`). Generous vertical rhythm from `mb-4` between blocks. Not mobile-first in a flashy sense — mobile just gets full-width, light padding.

**Prose utility** (Tailwind Typography plugin): controls blog-post body styling — decorates `<p>`, `<ul>`, `<figure>`, `<figcaption>` (muted centered caption).

---

## ICONOGRAPHY

Xe's approach is **deliberately low-icon**. Stickers carry the personality load; UI chrome is mostly text.

- **Icon font / sprite:** none. All icons are inline SVGs.
- **Style:** [Tabler Icons](https://tabler.io/icons) — 24×24 viewBox, stroke-width 2, `stroke-linecap="round"`, `stroke-linejoin="round"`, `fill="none"`, color inherits `currentColor`. Used at 20×20 in the SponsorCard (Patreon / GitHub / Star), 24×24 in Admonitions (info/warning/tip/note).
- **SVGs:** A hand-drawn Xe orca mascot (`assets/xeiaso-logo.svg`) — used as the favicon and the giant `.logo-wumbo` mask (9.5em × 16em) in the footer. Several Graphviz-generated flowchart SVGs accompany technical posts.
- **PNGs:** `avatar.png` — a pink-haired orca character, used inline in the homepage intro card at max-height 6rem.
- **Unicode:** `>` for BlockQuote (email-style), `&` separator in "Xe & Co." style signatures.
- **Emoji:** rare in UI. When present, part of personal brand (the 🥺 domain). Never used decoratively in components.
- **Stickers:** not strictly iconography — character portraits (64×64) from `stickers.xeiaso.net` used in Conv / ChatBubble components as speaking-character avatars. Characters: xe, mara, cadey, nicole, aoi, etc. Moods: `aha`, `happy`, `confused`, `coffee`, `wat`, etc.

**Flagged substitutions:** For new work, you may link Tabler Icons via CDN — `https://cdn.jsdelivr.net/npm/@tabler/icons@latest/icons/{name}.svg` — matches the existing stroke style exactly. Fonts ship locally. The self-hosted Iosevka Iaso mono family is not bundled here; fall back to Iosevka / `ui-monospace` if needed and flag.

---

## Caveats & Known Substitutions

- **Fonts:** Podkova and Schibsted Grotesk are Google Fonts — local TTFs included. **Iosevka Curly Iaso** (the mono on the live site) is a custom-cut Iosevka served from `files.xeiaso.net`; not included here. Mono demos use `ui-monospace` fallback.
- **Sticker art:** Not copied locally — live URLs (`stickers.xeiaso.net/sticker/{char}/{mood}`) are referenced directly. If offline fidelity matters, download the specific moods you use.
- **Hero imagery:** Not copied — linked from `files.xeiaso.net/hero/{file}.{avif,webp,jpg}` in the original.
- **Iconography:** Tabler stroke icons inlined where needed; full set via CDN as documented above.
