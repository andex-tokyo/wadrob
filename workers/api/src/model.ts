import { z } from 'zod';
export const categories = ['outerwear','tops','shirts','pants','suits','shoes','accessories','other'] as const;
export const colors = ['black','gray','white','navy','blue','brown','beige','green','red','purple','yellow','orange','silver','gold','multi','other'] as const;
export const sleeves = ['short','long','sleeveless','three_quarter'] as const;
const topsByName=/(オールインワン|つなぎ|ジャンプスーツ|カバーオール|all[- ]?in[- ]?one|jumpsuit|coverall)/i;
export function normalizeCategory(name:unknown,category:unknown){return category==='knitwear'||(typeof name==='string'&&topsByName.test(name))?'tops':category;}
const text = z.string().trim().max(500).nullable().optional();
const itemObject = z.object({
 name: z.string().trim().min(1).max(200), brand:text, category:z.enum(categories).nullable().optional(), subCategory:text,
 originalColor:text, normalizedColor:z.enum(colors).nullable().optional(), sleeve:z.enum(sleeves).nullable().optional(), size:text,
 listPrice:z.number().int().min(0).max(100000000000).nullable().optional(), purchasePrice:z.number().int().min(0).max(100000000000).nullable().optional(),
 currency:z.string().regex(/^[A-Z]{3}$/).default('JPY'), purchasedAt:z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
 productCode:text, sku:text, shopName:text, sourceUrl:z.string().url().max(4096).refine(v=>/^https?:/.test(v)).nullable().optional(),
 description:z.string().max(10000).nullable().optional(), status:z.enum(['active','archived']).default('active'), groupId:text,
 imageIds:z.array(z.string().uuid()).max(8).optional(), imageUrls:z.array(z.string().url().max(4096)).max(8).optional(),
 // 表示順つきの画像。先頭がメイン画像になる。imageIds/imageUrls は後方互換のため残す。
 images:z.array(z.union([z.object({id:z.string().uuid()}),z.object({url:z.string().url().max(4096)})])).max(8).optional(),
}).strict();
export const itemSchema = z.preprocess(input=>{
 if(!input||typeof input!=='object'||Array.isArray(input))return input;
 const value=input as Record<string,unknown>,category=normalizeCategory(value.name,value.category);
 return category===value.category?input:{...value,category};
},itemObject);
export const column = (key:string) => key.replace(/[A-Z]/g, x=>'_'+x.toLowerCase());
export const camel = (row:Record<string,unknown>) => Object.fromEntries(Object.entries(row).map(([k,v])=>[k.replace(/_([a-z])/g,(_,c:string)=>c.toUpperCase()),v]));
export class ApiError extends Error { constructor(public code:string, message:string, public status=400){super(message);} }
export interface Env { DB:D1Database; IMAGES:R2Bucket; SESSION_SECRET:string; GOOGLE_SERVER_CLIENT_ID:string; OPENAI_API_KEY?:string; OPENAI_MODEL?:string; BROWSER?:BrowserRun; AI_RATE_LIMITER?:RateLimit }
export type AppEnv = {Bindings:Env; Variables:{userId:string; requestId:string}};
