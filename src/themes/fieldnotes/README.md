# Fieldnotes

An experimental Astro theme for a bilingual personal blog. Neutral paper, charcoal tones and teal accents connect the design with the existing profile site. Posts use a dated list instead of a card grid.

Preview: `/TIL/ja/theme-preview/` and `/TIL/en/theme-preview/`.

`Layout.astro` and `theme.css` are kept together so the theme can later move into a separate repository. Preview routes adapt the blog's content collection. `CodeTools.astro` adds copy and wrapping controls. Existing public routes remain available during evaluation.

No profile or background photographs are required or loaded. The theme code is original; no third-party theme templates are copied. No personal name is included in theme files.

Article presentation takes visual cues from the original profile theme's public Markdown demo: a neutral outer background, a light reading area, a desktop contents rail, and dark code blocks. Layout and styles are independently implemented.

Light and dark modes follow the system preference until the reader chooses a mode. The shared ThemeProvider persists a manual choice across pages.
