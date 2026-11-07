---
title: 'このサイトには OGP も JSON-LD もなかったので、Astro のレイアウトに追加した'
description: 'Astro で作っているこのサイトの head を確かめると、title、description、canonical、RSS、sitemap はあったが、OGP、Twitter カード、JSON-LD、OG 画像がなかった。共通のレイアウトに追加し、公開日を日本時間で書くことと、JSON-LD を script に埋めるときのエスケープに気をつけた。'
lang: ja
translationKey: til-site-ogp-jsonld
publishDate: 2026-11-07
tags: ['Astro', 'SEO']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) の開発で分かったことを、このサイトに書いています。サイトは Astro で作り、GitHub Pages の `/TIL/` の下に置いています。記事のリンクを貼ったときにどう見えるかが気になって、ページの head に何が入っているかを確かめました。

## title や canonical はあったが、OGP と JSON-LD はなかった

ビルドした記事ページ 1 本の head を、タグごとに数えました。

| タグ | 数 |
|---|---|
| `<title>` | 1 |
| `<meta name="description">` | 1 |
| `<link rel="canonical">` | 1 |
| `<link rel="alternate" hreflang>` | 1 |
| RSS の `<link rel="alternate">` | 1 |
| `og:` で始まる `<meta>` | 0 |
| `twitter:` で始まる `<meta>` | 0 |
| `<script type="application/ld+json">` | 0 |

sitemap も出力されていました。一方、次のものはどれもありませんでした。

- SNS にリンクを貼ったときのカードに使われる、OGP と Twitter カードのタグ
- 検索エンジンに記事の情報を渡す JSON-LD
- カードに出す画像

hreflang は相手の言語のページを指すものだけで、そのページ自身を指すものはありませんでした。

## 共通のレイアウトに、OGP、Twitter カード、JSON-LD を追加した

どのページも同じレイアウトのコンポーネントで head を出しているので、そこに追加しました。記事ページからは、公開日とタグを渡すようにしました。追加したものは次のとおりです。

- すべてのページ: `og:title`、`og:description`、`og:url` (canonical と同じ URL)、`og:site_name`、`og:locale`、`og:image`。Twitter カードは `summary_large_image` にして、タイトル、説明、画像を OGP と同じにした
- 記事ページだけ: `og:type` を `article` にし、`article:published_time` と `article:tag` を付けた。ほかのページは `website`
- 記事ページだけ: JSON-LD の `BlogPosting`。見出し、説明、公開日、言語、著者、記事の URL、画像を入れた
- hreflang: そのページ自身を指すものと、日本語版を指す `x-default` を追加した

デザインの確認用に置いているページは、もともと `noindex` で canonical も出していないので、OGP と JSON-LD も付けていません。カードに出す画像は、1200×630 の PNG を 1 枚だけ用意して、全ページで同じものを使っています。記事ごとに画像を作ることは、今回はしていません。

`og:image` には、サイトのドメインから始まる URL を書きます。このサイトは `/TIL/` の下にあるので、そのパスも入れる必要がありました。

```ts
const ogImage = new URL(`${import.meta.env.BASE_URL.replace(/\/$/, '')}/og-default.png`, Astro.site);
// https://l4l4dev.github.io/TIL/og-default.png
```

## 公開日は日付だけなので、そのまま ISO にすると日本時間の 9 時になる

記事の frontmatter には、`publishDate: 2026-11-06` のように日付だけを書いています。これは UTC の 0 時として読まれるので、`toISOString()` で書き出すと日本時間では 9 時になります。

```js
const d = new Date('2026-11-06');
d.toISOString();                                          // 2026-11-06T00:00:00.000Z
d.toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' });    // 2026/11/6 9:00:00
```

日付は日本時間のつもりで書いているので、日本時間の 0 時として `+09:00` を付けて書き出すことにしました。`article:published_time` と JSON-LD の `datePublished` の両方に、同じ値を使っています。

```ts
const publishedTime = `${publishDate.toLocaleDateString('en-CA', { timeZone: 'Asia/Tokyo' })}T00:00:00+09:00`;
// 2026-11-06T00:00:00+09:00
```

## JSON-LD を script に埋めるときは、`<` をエスケープする

JSON-LD は、`JSON.stringify` で作った文字列を Astro の `set:html` で `<script>` の中に入れています。`set:html` は文字列をそのまま出力します。`JSON.stringify` は `<` や `/` をエスケープしないので、タイトルに `</script>` が入っていると、そこで script が終わってしまいます。

```js
JSON.stringify({ headline: 'a </script><b>' });
// {"headline":"a </script><b>"}
```

そこで、`<`、`>`、`&` を `\u003c` などに置き換えてから埋めました。JSON の文字列の中では同じ文字として読まれるので、値は変わりません。

```ts
const jsonLd = JSON.stringify(data)
  .replace(/</g, '\\u003c')
  .replace(/>/g, '\\u003e')
  .replace(/&/g, '\\u0026');
```

今の記事のタイトルに `<` は入っていませんが、技術の記事ではコードの一部をタイトルに書くこともあるので、先に入れておきました。

## ルートのトップページは、canonical を日本語のトップに向けた

確かめている途中で、ルートの `/TIL/` と日本語のトップ `/TIL/ja/` が同じ中身で、どちらも自分自身を canonical にしていることに気づきました。英語のトップは日本語版として `/TIL/ja/` を指すのに、ルートは英語版として `/TIL/en/` を指すので、hreflang がお互いを指し合う形になっていませんでした。

ルートの canonical を `/TIL/ja/` に向け、sitemap からもルートを外しました。これで、日本語と英語のトップが互いを指し合います。

## 確かめたこと

ビルドした後、記事ページとトップページの head に上のタグが出ていることを確かめました。JSON-LD は、記事のすべてのページで取り出して `JSON.parse` し、読み込めることを確かめました。

```python
import glob, json, re
for p in glob.glob('dist/*/posts/*/index.html'):
    for j in re.findall(r'<script type="application/ld\+json">(.*?)</script>', open(p).read(), re.S):
        json.loads(j)
```

検索の結果やリンクのカードの見え方が変わったかは、まだ確かめていません。画像は公開してからでないと読み込めないので、カードの確認は公開した後に行います。

## まとめ

- title、description、canonical、RSS、sitemap はあったが、OGP、Twitter カード、JSON-LD、OG 画像はなかった
- 共通のレイアウトに追加し、記事ページからは公開日とタグを渡した。`og:image` にはサイトのパスも含めた URL を書く
- 日付だけの公開日を `toISOString()` で書き出すと、日本時間の 9 時になる。日本時間の 0 時として `+09:00` を付けた
- JSON-LD を `set:html` で埋めるときは、`<` をエスケープする

確かめた環境は次のとおりです。

- Astro 7.3.2
- Node.js 26.8.1

参考にしたもの:

- [The Open Graph protocol](https://ogp.me/)
- [Article structured data](https://developers.google.com/search/docs/appearance/structured-data/article) (Google 検索セントラル)
- [Tell Google about localized versions of your page](https://developers.google.com/search/docs/specialty/international/localized-versions) (Google 検索セントラル)
