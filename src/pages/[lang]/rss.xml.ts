import rss from '@astrojs/rss';
import {getCollection} from 'astro:content';
import {locales,ui,postHref,type Locale} from '@/i18n';
export function getStaticPaths(){return locales.map(lang=>({params:{lang}}));}
export async function GET({params,site}:{params:{lang?:string};site:URL|undefined}){const lang=params.lang as Locale;const posts=await getCollection('post',({data})=>!data.draft&&data.lang===lang);return rss({title:'TIL',description:ui[lang].description,site:site!,items:posts.sort((a,b)=>b.data.publishDate.valueOf()-a.data.publishDate.valueOf()).map(post=>({title:post.data.title,description:post.data.description,pubDate:post.data.publishDate,link:postHref(post)})),customData:`<language>${lang}</language>`});}
