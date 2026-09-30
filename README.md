# TIL

Astro Pureのレイアウトとスタイルをベースにした日本語・英語の個人ブログです。

## 開発

Node.js 24を使います。

```sh
npm ci
npm run dev
npm run check
npm run build
```

開発URL: `http://localhost:4321/TIL/ja/` または `/TIL/en/`。

## 記事

`content/posts/ja/` と `content/posts/en/` にMarkdownを置きます。
必須フィールド: `title`, `description`, `lang`, `translationKey`, `publishDate`。
同じ記事の翻訳は同じ `translationKey` を使います。各言語内で重複させないでください。
`draft: true` の記事は一覧・URL・RSSから除外されます。
翻訳がない記事では言語切替は相手言語の記事一覧へ移動します。
各言語のディレクトリにMarkdownを追加してください。

## 公開

GitHub Settings → Pages → SourceをGitHub Actionsに設定します。
mainへのpushでビルド・公開、PRではビルドのみ実行します。
リポジトリはPublicで、PagesのSourceはGitHub Actionsです。下書きファイルもリポジトリ上では公開されます。

## Theme

[Astro Pure](https://github.com/cworld1/astro-theme-pure)

Pure v4.1.6のホーム・レイアウト・カラートークンを既存の日英記事ルートへ組み込んでいます。テーマ全体のデモ機能（コメント等）は導入していません。ライセンスと変更記録は `licenses/` にあります。
Pure upstream: `4ecd4762e1e750daf7a51978092d7cea8e14c0d6`。
旧Cactus由来のテーマ切替・記事用CSSも一部残しています。CactusのMITライセンスはLICENSE、PureのApache-2.0ライセンスはlicenses/に保持しています。記事の著作権は著者に帰属します。
旧Hugo構成は `archive/hugo` ブランチにあります。

## 開発方針

所有者の変更はローカル検証後にmainへ直接pushします。PRの作成は必須にしません。外部からの提案はPRで受け付け、直接pushは所有者・書き込み権限を与えたCollaboratorに限ります。公開前のレビュー指摘は採否を確認します。
