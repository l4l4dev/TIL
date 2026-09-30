export const locales = ['ja','en'] as const;
export type Locale = typeof locales[number];
export const ui = {
 ja:{home:'ホーム',posts:'記事',about:'このブログについて',intro:'日々の学びと、ちょっとした寄り道。',description:'調べたこと、作ったもの、気になったことを少しずつ。',recent:'最近の記事',empty:'まだ記事はありません。',back:'記事一覧へ',skip:'本文へスキップ',theme:'ダークモード',missing:'この言語の翻訳はまだありません。',aboutText:'日々学んだことや、作ったものについて書く個人ブログです。技術の話も、日常の話も。'},
 en:{home:'Home',posts:'Posts',about:'About',intro:'Things learned along the way.',description:'Notes on things I explore, build, and find interesting.',recent:'Recent posts',empty:'No posts yet.',back:'Back to posts',skip:'Skip to content',theme:'Dark mode',missing:'This translation is not available yet.',aboutText:'A personal blog about things learned and things built. Technology, everyday life, and occasional detours.'}
};
export const href=(lang:Locale,path='')=>`${import.meta.env.BASE_URL.replace(/\/$/,'')}/${lang}/${path}`;
export const postHref=(post:{id:string;data:{lang:Locale}})=>href(post.data.lang,`posts/${post.id.split('/').slice(1).join('/')}/`);
