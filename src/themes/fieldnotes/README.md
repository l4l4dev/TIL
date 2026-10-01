# Fieldnotes

An experimental Astro theme for a bilingual personal blog. Neutral paper, charcoal photography and teal accents connect the design with the existing profile site. Posts use a dated list instead of a card grid.

Preview: `/TIL/ja/theme-preview/` and `/TIL/en/theme-preview/`.

`Layout.astro` and `theme.css` are kept together so the theme can later move into a separate repository. Preview routes adapt the blog's content collection. `CodeTools.astro` adds copy and wrapping controls. Existing public routes remain available during evaluation.

The preview reuses the site owner's existing public profile images by URL. The theme code is original; no third-party theme templates are copied. Before distribution, replace these URLs with configurable theme options. No personal name is included in theme files.
