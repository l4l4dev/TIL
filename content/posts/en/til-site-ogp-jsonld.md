---
title: 'This site had no OGP or JSON-LD, so I added them to the Astro layout'
description: 'The head of this Astro site had a title, description, canonical, RSS and sitemap, but no OGP, Twitter card, JSON-LD or OG image. I added them to the shared layout, writing the publish date in Japan time and escaping the JSON-LD embedded in a script tag.'
lang: en
translationKey: til-site-ogp-jsonld
publishDate: 2026-11-07
tags: ['Astro', 'SEO']
draft: false
---

I write what I learn while building [FirnPlanner](https://firnplanner.l4l4.dev/), a macOS day planner I make as a personal project, on this site. The site is built with Astro and served from `/TIL/` on GitHub Pages. I wanted to know how links to it look when shared, so I checked what was in the head of its pages.

## There was a title and canonical, but no OGP or JSON-LD

I counted the tags in the head of one built post page.

| Tag | Count |
|---|---|
| `<title>` | 1 |
| `<meta name="description">` | 1 |
| `<link rel="canonical">` | 1 |
| `<link rel="alternate" hreflang>` | 1 |
| RSS `<link rel="alternate">` | 1 |
| `<meta>` starting with `og:` | 0 |
| `<meta>` starting with `twitter:` | 0 |
| `<script type="application/ld+json">` | 0 |

A sitemap was generated too. None of the following existed:

- OGP and Twitter card tags, which are used for the card shown when a link is shared on social media
- JSON-LD, which gives search engines information about the post
- An image for the card

The only hreflang link pointed to the page in the other language. None pointed to the page itself.

## I added OGP, Twitter cards and JSON-LD to the shared layout

Every page renders its head through the same layout component, so I added them there. Post pages now pass their publish date and tags to it. Here is what I added:

- On every page: `og:title`, `og:description`, `og:url` (the same URL as the canonical), `og:site_name`, `og:locale` and `og:image`. The Twitter card is `summary_large_image`, with the same title, description and image as OGP
- On post pages only: `og:type` is `article`, with `article:published_time` and `article:tag`. Other pages use `website`
- On post pages only: a JSON-LD `BlogPosting` with the headline, description, publish date, language, author, post URL and image
- hreflang: a link to the page itself, and an `x-default` that points to the Japanese version

The pages I keep for checking the design were already `noindex` with no canonical, so they get no OGP or JSON-LD either. For the card image, I made one 1200×630 PNG and use it on every page. I did not make a separate image for each post this time.

`og:image` needs a URL that starts with the site domain. This site lives under `/TIL/`, so the URL has to include that path as well.

```ts
const ogImage = new URL(`${import.meta.env.BASE_URL.replace(/\/$/, '')}/og-default.png`, Astro.site);
// https://l4l4dev.github.io/TIL/og-default.png
```

## The publish date has no time, so converting it to ISO gives 9:00 in Japan

The frontmatter of each post only has a date, like `publishDate: 2026-11-06`. That is read as midnight UTC, so writing it out with `toISOString()` gives 9:00 in Japan time.

```js
const d = new Date('2026-11-06');
d.toISOString();                                          // 2026-11-06T00:00:00.000Z
d.toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' });    // 2026/11/6 9:00:00
```

I write those dates as Japan dates, so I write them out as midnight in Japan with `+09:00`. `article:published_time` and the JSON-LD `datePublished` both use this value.

```ts
const publishedTime = `${publishDate.toLocaleDateString('en-CA', { timeZone: 'Asia/Tokyo' })}T00:00:00+09:00`;
// 2026-11-06T00:00:00+09:00
```

## Escape `<` when embedding JSON-LD in a script tag

The JSON-LD is a string made with `JSON.stringify`, placed inside `<script>` with Astro's `set:html`. `set:html` outputs the string as is. `JSON.stringify` does not escape `<` or `/`, so if a title contained `</script>`, the script would end there.

```js
JSON.stringify({ headline: 'a </script><b>' });
// {"headline":"a </script><b>"}
```

So I replace `<`, `>` and `&` with `\u003c` and so on before embedding it. Inside a JSON string these are read as the same characters, so the values do not change.

```ts
const jsonLd = JSON.stringify(data)
  .replace(/</g, '\\u003c')
  .replace(/>/g, '\\u003e')
  .replace(/&/g, '\\u0026');
```

None of the current post titles contain `<`, but technical posts sometimes put a bit of code in the title, so I added this ahead of time.

## The root page now has its canonical set to the Japanese top page

While checking, I noticed that the root `/TIL/` and the Japanese top page `/TIL/ja/` had the same content, and each named itself as canonical. The English top page pointed to `/TIL/ja/` as its Japanese version, but the root pointed to `/TIL/en/` as its English version, so the hreflang links did not point at each other.

I set the canonical of the root to `/TIL/ja/` and removed the root from the sitemap. Now the Japanese and English top pages point at each other.

## How I checked

After building, I checked that the tags above appear in the head of post pages and top pages. For JSON-LD, I extracted it from every post page and ran it through a JSON parser to make sure it loads.

```python
import glob, json, re
for p in glob.glob('dist/*/posts/*/index.html'):
    for j in re.findall(r'<script type="application/ld\+json">(.*?)</script>', open(p).read(), re.S):
        json.loads(j)
```

I have not checked whether search results or link cards look any different. The image can only be loaded once the site is deployed, so I will check the cards after that.

## Summary

- The site had a title, description, canonical, RSS and sitemap, but no OGP, Twitter card, JSON-LD or OG image
- I added them to the shared layout, with post pages passing their publish date and tags. `og:image` needs a URL that includes the site path
- Writing a date-only publish date with `toISOString()` gives 9:00 in Japan. I write it as midnight in Japan with `+09:00`
- When embedding JSON-LD with `set:html`, escape `<`

I tested with:

- Astro 7.3.2
- Node.js 26.8.1

References:

- [The Open Graph protocol](https://ogp.me/)
- [Article structured data](https://developers.google.com/search/docs/appearance/structured-data/article) (Google Search Central)
- [Tell Google about localized versions of your page](https://developers.google.com/search/docs/specialty/international/localized-versions) (Google Search Central)
