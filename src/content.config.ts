import {defineCollection} from 'astro:content';
import {glob} from 'astro/loaders';
import {z} from 'astro/zod';
export const collections={post:defineCollection({loader:glob({base:'./content/posts',pattern:'**/*.md'}),schema:z.object({title:z.string(),description:z.string(),lang:z.enum(['ja','en']),translationKey:z.string(),publishDate:z.coerce.date(),draft:z.boolean().default(false),tags:z.array(z.string()).default([])})})};
