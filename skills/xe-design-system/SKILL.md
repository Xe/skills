---
name: xe-design-system
description: A warm, Gruvbox-rooted design system derived from xeiaso.net. Use for personal-blog, technical-educator, or character-driven content that wants serif headlines, parchment surfaces, and chat-bubble layouts. Distinctive: magenta inverted link hovers, boxy 2px-radius sticker avatars, no gradients except the SponsorCard top rule.
---

# Xe Iaso Design System — Skill

## When to use
Reach for this system when building anything that should feel like **xeiaso.net** — a personal technical blog with a conversational voice, warm neutrals, and a cast of sticker characters. Good fits: long-form posts, one-person portfolios, zine-style project pages, fictional-conversation explainers. Bad fits: enterprise dashboards, consumer apps, anything that wants to feel "clean, modern SaaS."

## Files
- `README.md` — full context, content fundamentals, visual foundations, iconography
- `colors_and_type.css` — drop-in tokens + primitives; start here
- `fonts/` — Podkova (serif, headings), Schibsted Grotesk (sans, body)
- `assets/` — Xe orca mascot logo SVG, Graphviz diagrams
- `preview/` — small design-system cards (type, color scales, components)

## Using it
1. Link `colors_and_type.css` into your HTML. It registers `@font-face` for Podkova and Schibsted Grotesk (Iosevka Curly Iaso is only aspirational — falls back to `ui-monospace`).
2. Use the CSS vars for colors: `--bg-hard / --bg-soft / --bg-0..4` for surfaces, `--fg-0..4` for text, muted accents (`--red`, `--blue`, etc.) in light mode and their `-bright` siblings in dark.
3. Typeset with the defaults — `<h1..h6>` are already Podkova, body is Schibsted Grotesk. Add `text-wrap: pretty` for headings (already applied to `p`).
4. For distinctive interactions, let links pick up the invert-on-hover magenta — don't override `a:hover`.
5. For characters talking, use the Conv/chat pattern shown in `preview/chat-conv.html` — stacked rows sharing a `--bg-soft` background, 64×64 boxy avatar, name link + message.

## Do
- Warm cream surfaces (`#f9f5d7`) in light, warm charcoal (`#1d2021`) in dark.
- Serif headings (Podkova 600), sans body.
- 1px borders, soft two-step shadows, 6–12px radii.
- Tabler stroke icons (24×24, stroke-width 2, round caps) when icons are needed — usually they aren't.
- Stickers from `stickers.xeiaso.net/sticker/{char}/{mood}` when showing characters speak.
- Sentence-case headings, first-person conversational voice, dry humor.

## Don't
- Don't introduce blue-purple gradients, neon, or cool grays — the palette is Gruvbox warm-neutral.
- Don't add emoji decoratively; the stickers are the emotional channel.
- Don't use "left-border accent" cards — only PullQuote has the left bar, intentionally.
- Don't invent icons in SVG — use placeholders or Tabler.
- Don't override link hover behavior — the magenta invert is a signature.
- Don't pad with filler copy; this voice is spare and personal.

## Content tone
Xe writes *with* the reader: warm, a bit confrontational, willing to be weird. Pronouns it/its (also they/them). Technical terms keep their casing (NixOS, Kubernetes, Tailscale). When in doubt, be specific and slightly funny; never generic.

## Known substitutions
- Iosevka Curly Iaso mono is custom-cut and served from `files.xeiaso.net` — not bundled. `ui-monospace` fallback is fine.
- Sticker art lives at live URLs; not copied locally.
- Hero imagery is linked from `files.xeiaso.net/hero/` in the original; use placeholders for new work and flag if real imagery is needed.
