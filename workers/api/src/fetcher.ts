import ipaddr from 'ipaddr.js';
import { ApiError } from './model';
export function validateUrl(raw:string):URL {
 let u:URL;try{u=new URL(raw);}catch{throw new ApiError('INVALID_URL','有効なURLを入力してください');}
 const host=u.hostname.replace(/^\[|\]$/g,'').replace(/\.$/,'').toLowerCase();
 if(!['http:','https:'].includes(u.protocol)||u.username||u.password||(u.port&&!['80','443'].includes(u.port))||!host.includes('.')||/^(localhost|metadata)(\.|$)/.test(host)||/\.(localhost|local|internal|test|invalid)$/.test(host))throw new ApiError('UNSAFE_URL','公開商品ページのURLを指定してください');
 if(ipaddr.isValid(host)&&ipaddr.process(host).range()!=='unicast')throw new ApiError('UNSAFE_URL','このアドレスは取得できません');
 u.hash='';return u;
}
export async function publicDns(host:string, fetcher:typeof fetch=fetch){
 if(ipaddr.isValid(host))return;
 const results=await Promise.all(['A','AAAA'].map(async type=>{
  const r=await fetcher('https://cloudflare-dns.com/dns-query?name='+encodeURIComponent(host)+'&type='+type,{headers:{accept:'application/dns-json'},signal:AbortSignal.timeout(4000)});
  if(!r.ok)throw new ApiError('FETCH_FAILED','名前解決に失敗しました');
  return await r.json() as {Answer?:{type:number;data:string}[]};
 }));
 const addresses=results.flatMap(x=>x.Answer??[]).filter(a=>a.type===1||a.type===28);
 if(!addresses.length||addresses.some(a=>!ipaddr.isValid(a.data)||ipaddr.process(a.data).range()!=='unicast'))throw new ApiError('UNSAFE_URL','このアドレスは取得できません');
}
export async function boundedBody(r:Response,max:number):Promise<Uint8Array>{
 if(Number(r.headers.get('content-length'))>max)throw new ApiError('TOO_LARGE','ファイルが大きすぎます',413);
 const reader=r.body?.getReader();if(!reader)return new Uint8Array();
 const chunks:Uint8Array[]=[];let size=0;
 while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>max){await reader.cancel();throw new ApiError('TOO_LARGE','ファイルが大きすぎます',413);}chunks.push(value);}
 const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}return bytes;
}
export interface PageFetcher {get(url:string,kind:'html'|'image'):Promise<{bytes:Uint8Array;url:string;type:string;charset?:string}>}
export class SimpleFetcher implements PageFetcher {
 private readonly request:typeof fetch;
 private readonly dns:typeof publicDns;
 constructor(request:typeof fetch=fetch,dns:typeof publicDns=publicDns){
  // workerd rejects a stored global fetch called as a method ("Illegal invocation"),
  // so wrap it in a plain call.
  this.request=(...args)=>request(...args);
  this.dns=(...args)=>dns(...args);
 }
 async get(raw:string,kind:'html'|'image'){
  let url=validateUrl(raw);
  const signal=AbortSignal.timeout(12000);
  for(let i=0;i<=4;i++){
   await this.dns(url.hostname,this.request);
   const r=await this.request(url.toString(),{redirect:'manual',signal,headers:{'User-Agent':'Wadrob/1.0',Accept:kind==='html'?'text/html,application/xhtml+xml':'image/jpeg,image/png,image/webp'}});
   if([301,302,303,307,308].includes(r.status)){await r.body?.cancel();const location=r.headers.get('location');if(!location)break;url=validateUrl(new URL(location,url).href);continue;}
   if(!r.ok)throw new ApiError('FETCH_FAILED','ページを取得できませんでした');
   const rawType=r.headers.get('content-type')??'';
   const type=rawType.split(';')[0].trim().toLowerCase();
   const charset=/charset\s*=\s*"?([\w-]+)/i.exec(rawType)?.[1];
   if(!(kind==='html'?['text/html','application/xhtml+xml']:['image/jpeg','image/png','image/webp']).includes(type))throw new ApiError('INVALID_CONTENT','対応していない形式です');
   return {bytes:await boundedBody(r,kind==='html'?2000000:10000000),url:url.toString(),type,charset};
  }
  throw new ApiError('FETCH_FAILED','リダイレクトが多すぎます');
 }
}

// Renders the page with Cloudflare Browser Run. Bot-protected shops reject plain
// fetches, so this is the fallback for pages SimpleFetcher cannot read.
export class BrowserFetcher implements PageFetcher {
 private readonly dns:typeof publicDns;
 constructor(private browser:BrowserRun,dns:typeof publicDns=publicDns){this.dns=(...args)=>dns(...args);}
 async get(raw:string,kind:'html'|'image'){
  if(kind!=='html')throw new ApiError('INVALID_CONTENT','レンダリング取得は画像に対応していません');
  const url=validateUrl(raw);
  await this.dns(url.hostname);
  const response=await this.browser.quickAction('content',{url:url.toString(),gotoOptions:{waitUntil:'networkidle2',timeout:20000},setExtraHTTPHeaders:{'Accept-Language':'ja-JP,ja;q=0.9'}});
  if(!response.ok)throw new ApiError('FETCH_FAILED','ページを取得できませんでした');
  const data=await response.json() as {success?:boolean;result?:string;meta?:{status?:number;title?:string}};
  const html=typeof data?.result==='string'?data.result:'';
  const bytes=new TextEncoder().encode(html);
  if(!bytes.length)throw new ApiError('FETCH_FAILED','ページを取得できませんでした');
  // A rendered block page is still a successful render, so reject it explicitly.
  const denied=/access denied|forbidden|403/i.test(data?.meta?.title??'')||/access denied|forbidden|アクセスが拒否|アクセスは拒否/i.test(html.slice(0,4000));
  if(denied||(data?.meta?.status??200)>=400)throw new ApiError('FETCH_FAILED','ページを取得できませんでした');
  if(bytes.length>2000000)throw new ApiError('TOO_LARGE','ページが大きすぎます',413);
  return {bytes,url:url.toString(),type:'text/html'};
 }
}

// ZOZOTOWN blocks server-side fetches, but the same goods are served by the
// ZOZOTOWN shop on Yahoo! Shopping under the same goods id.
export function zozoYahooMirror(raw:string):string|undefined{
 let url:URL;try{url=validateUrl(raw);}catch{return undefined;}
 if(url.hostname.toLowerCase()!=='zozo.jp')return undefined;
 const matched=/^\/shop\/[^/]+\/goods\/(\d+)\/?$/.exec(url.pathname);
 return matched?`https://store.shopping.yahoo.co.jp/zozo/${matched[1]}.html`:undefined;
}

export class MirroredFetcher implements PageFetcher {
 constructor(private inner:PageFetcher,private target:string){}
 get(_url:string,kind:'html'|'image'){return this.inner.get(this.target,kind);}
}

export class ChainFetcher implements PageFetcher {
 constructor(private steps:PageFetcher[],private onFallback:(error:unknown)=>void=()=>{}){}
 async get(url:string,kind:'html'|'image'){
  let last:unknown;
  for(const [index,step] of this.steps.entries()){
   try{return await step.get(url,kind);}
   catch(error){last=error;if(index<this.steps.length-1)this.onFallback(error);}
  }
  throw last ?? new ApiError('FETCH_FAILED','ページを取得できませんでした');
 }
}
