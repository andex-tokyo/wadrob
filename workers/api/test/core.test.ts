import { afterEach, describe, expect, it, vi } from 'vitest';
import { decodeJwt } from 'jose';
import { issueSession, verifySession } from '../src/auth';
import { BrowserFetcher, ChainFetcher, SimpleFetcher, validateUrl, zozoYahooMirror, type PageFetcher } from '../src/fetcher';
import { GenericHtmlParser, GenericJsonLdParser, OpenGraphParser, aiExtract, classifyProduct, collectPageImages, decodeHtml, dedupeImages, importUrl, mergeFields, searchProducts, tidyLabel } from '../src/import';
import { categories, itemSchema, sleeves, type Env } from '../src/model';

describe('URL security', () => {
  it.each(['file:///etc/passwd','http://localhost/x','http://127.0.0.1/x','http://169.254.169.254/latest','ftp://example.com/x'])('rejects %s', (url) => expect(() => validateUrl(url)).toThrow());
  it('accepts public product URLs', () => expect(validateUrl('https://example.com/item#x').href).toBe('https://example.com/item'));
});
describe('product parsing', () => {
  const html = `<html><head><meta property="og:title" content="Fallback"><meta property="og:image" content="https://cdn.example/a.jpg"></head><body><h1>HTML</h1><script type="application/ld+json">{"@type":"Product","name":"Coat","brand":{"name":"WADROB"},"offers":{"price":"15400","priceCurrency":"JPY"}}</script></body></html>`;
  it('uses JSON-LD ahead of fallbacks', () => { const f = mergeFields(new GenericJsonLdParser().parse(html, ''), new OpenGraphParser().parse(html, ''), new GenericHtmlParser().parse(html, '')); expect(f.name.value).toBe('Coat'); expect(f.listPrice.value).toBe(15400); expect(f.imageUrls.value).toEqual(['https://cdn.example/a.jpg']); });
});
describe('sessions', () => {
  it('round trips a scoped expiring token', async () => { const secret='a'.repeat(32), token=await issueSession('user-1',secret); expect(await verifySession(token,secret)).toBe('user-1'); expect(decodeJwt(token).aud).toBe('wadrob-mobile'); });
  it('rejects another secret', async () => { const token=await issueSession('u','a'.repeat(32)); await expect(verifySession(token,'b'.repeat(32))).rejects.toThrow(); });
});
describe('items', () => {
  it('allows name-only items and separates prices', () => { const item=itemSchema.parse({name:'シャツ',listPrice:15400,purchasePrice:2999}); expect(item.listPrice).toBe(15400); expect(item.purchasePrice).toBe(2999); });
  it('rejects negative prices', () => expect(() => itemSchema.parse({name:'服',purchasePrice:-1})).toThrow());
  it('keeps the category list to what the owner actually wears', () => {
    expect(categories).toContain('suits');
    for (const removed of ['denim','setup','bags','all_in_one']) expect(categories).not.toContain(removed);
    expect(itemSchema.parse({name:'スーツ',category:'suits'}).category).toBe('suits');
    expect(() => itemSchema.parse({name:'デニム',category:'denim'})).toThrow();
  });
  it('accepts a sleeve length and nothing else', () => {
    expect(sleeves).toEqual(['short','long','sleeveless','three_quarter']);
    expect(itemSchema.parse({name:'Tシャツ',sleeve:'short'}).sleeve).toBe('short');
    expect(() => itemSchema.parse({name:'Tシャツ',sleeve:'puff'})).toThrow();
  });
});

const aiReply=(product:Record<string,unknown>)=>new Response(JSON.stringify({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(product)}]}]}));
const aiProduct={name:null,brand:null,category:'knitwear',subCategory:null,originalColor:null,normalizedColor:'gray',sleeve:null,listPrice:null,currency:null,productCode:null,shopName:null};
const env=(extra:Partial<Env>={})=>({OPENAI_API_KEY:'test-key',OPENAI_MODEL:'gpt-5.6-luna',...extra}) as Env;
const htmlFetcher=(html:string):PageFetcher=>({get:async()=>({bytes:new TextEncoder().encode(html),url:'https://shop.example/item',type:'text/html'})});
const jsonLd=`<script type="application/ld+json">{"@type":"Product","name":"コットンニット","brand":{"name":"AURALEE"},"offers":{"price":"15400","priceCurrency":"JPY"}}</script>`;

afterEach(()=>vi.unstubAllGlobals());

describe('AI assisted import', () => {
  it('maps structured output to owned fields', async () => {
    const fields=await aiExtract('page text',env(),async()=>aiReply(aiProduct));
    expect(fields.category).toEqual({value:'knitwear',source:'ai',confidence:.5});
    expect(fields.normalizedColor?.value).toBe('gray');
  });
  it('drops unknown enum values without losing the rest', async () => {
    const fields=await aiExtract('page text',env(),async()=>aiReply({...aiProduct,brand:'AURALEE',category:'camisole'}));
    expect(fields.category).toBeUndefined();
    expect(fields.brand?.value).toBe('AURALEE');
  });
  it('converts non-JPY prices to minor units', async () => {
    const fields=await aiExtract('page text',env(),async()=>aiReply({...aiProduct,listPrice:120,currency:'USD'}));
    expect(fields.listPrice?.value).toBe(12000);
    expect(fields.currency?.value).toBe('USD');
  });
  it('ignores a zero price', async () => {
    const fields=await aiExtract('page text',env(),async()=>aiReply({...aiProduct,listPrice:0,currency:'JPY'}));
    expect(fields.listPrice).toBeUndefined();
  });
  it('reports OpenAI failures through warnings', async () => {
    vi.stubGlobal('fetch',async()=>new Response('nope',{status:429}));
    const result=await importUrl('https://shop.example/item',env(),htmlFetcher(`<html><body>${jsonLd}</body></html>`));
    expect(result.warnings).toContain('補助解析を利用できませんでした');
  });
});

describe('AI fallback triggering', () => {
  it('renders again when the fetched page is thin', async () => {
    const thin = '<html><head><title>読み込み中</title></head><body><div id="app"></div></body></html>';
    const rich = `<html><head><meta property="og:title" content="ウールコート"><meta property="og:image" content="https://cdn.example/a.jpg"></head>
      <body><script type="application/ld+json">{"@type":"Product","name":"ウールコート","brand":{"name":"AURALEE"},"image":["https://cdn.example/a.jpg","https://cdn.example/b.jpg","https://cdn.example/c.jpg"]}</script></body></html>`;
    const first: PageFetcher = { get: async () => ({ bytes: new TextEncoder().encode(thin), url: 'https://shop.example/item', type: 'text/html' }) };
    const rendered: PageFetcher = { get: async () => ({ bytes: new TextEncoder().encode(rich), url: 'https://shop.example/item', type: 'text/html' }) };
    const result = await importUrl('https://shop.example/item', env({ OPENAI_API_KEY: undefined }), first, rendered);
    expect(result.draft.name).toBe('ウールコート');
    expect((result.draft.imageUrls as string[]).length).toBe(3);
  });
  it('keeps the fetched page when rendering is not better', async () => {
    const rich = `<html><head><meta property="og:title" content="コットンニット"></head><body><img src="https://cdn.example/a_500.jpg"><img src="https://cdn.example/b_500.jpg"></body></html>`;
    const worse = '<html><body>rendered but empty</body></html>';
    const first: PageFetcher = { get: async () => ({ bytes: new TextEncoder().encode(rich), url: 'https://shop.example/item', type: 'text/html' }) };
    const rendered: PageFetcher = { get: async () => ({ bytes: new TextEncoder().encode(worse), url: 'https://shop.example/item', type: 'text/html' }) };
    const result = await importUrl('https://shop.example/item', env({ OPENAI_API_KEY: undefined }), first, rendered);
    expect(result.draft.name).toBe('コットンニット');
  });

  it('runs when a deterministic source leaves category or color empty', async () => {
    const calls=vi.fn(async()=>aiReply(aiProduct));
    vi.stubGlobal('fetch',calls);
    const result=await importUrl('https://shop.example/item',env(),htmlFetcher(`<html><body>${jsonLd}</body></html>`));
    expect(calls).toHaveBeenCalledTimes(1);
    expect(result.draft.category).toBe('knitwear');
    expect(result.draft.normalizedColor).toBe('gray');
    expect(result.draft.name).toBe('コットンニット');
    expect(result.draft.brand).toBe('AURALEE');
    expect(result.fields.brand.source).toBe('json_ld');
    expect(result.draft.listPrice).toBe(15400);
  });
  it('skips the API when no key is configured', async () => {
    const calls=vi.fn(async()=>aiReply(aiProduct));
    vi.stubGlobal('fetch',calls);
    const result=await importUrl('https://shop.example/item',env({OPENAI_API_KEY:undefined}),htmlFetcher(`<html><body>${jsonLd}</body></html>`));
    expect(calls).not.toHaveBeenCalled();
    expect(result.draft.category).toBeUndefined();
    expect(result.draft.name).toBe('コットンニット');
  });
});

const searchReply=(candidates:unknown[])=>new Response(JSON.stringify({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify({candidates})}]}]}));

describe('product search', () => {
  it('validates and de-duplicates candidate URLs', async () => {
    const result=await searchProducts('ニット','AURALEE',env(),async()=>searchReply([
      {url:'https://zozo.jp/shop/a/goods/1/',title:'ニット',shop:'ZOZOTOWN'},
      {url:'https://zozo.jp/shop/a/goods/1/#color',title:'同じ商品',shop:'ZOZOTOWN'},
      {url:'http://127.0.0.1/secret',title:'社内',shop:'x'},
      {url:'ちがう文字列',title:'壊れたURL',shop:'x'},
    ]));
    expect(result.candidates.map(c=>c.url)).toEqual(['https://zozo.jp/shop/a/goods/1/']);
    expect(result.query).toBe('AURALEE ニット');
  });
  it('reports a missing API key', async () => {
    await expect(searchProducts('ニット',undefined,env({OPENAI_API_KEY:undefined}),async()=>searchReply([]))).rejects.toThrow();
  });
  it('reports search failures', async () => {
    await expect(searchProducts('ニット',undefined,env(),async()=>new Response('nope',{status:429}))).rejects.toThrow();
  });
});

/** classify のモック応答 */
const classifyReply=(data:unknown)=>new Response(JSON.stringify({status:'completed',output:[{content:[{type:'output_text',text:JSON.stringify(data)}]}]}));

describe('classification', () => {
  it('returns the inferred category and color', async () => {
    const result=await classifyProduct('タートルネック ニット セーター','classicalelf',env(),async()=>classifyReply({category:'knitwear',normalizedColor:'gray',sleeve:'long',subCategory:'タートルネック'}));
    expect(result).toEqual({category:'knitwear',normalizedColor:'gray',sleeve:'long',subCategory:'タートルネック'});
  });
  it('drops an unknown category but keeps the color', async () => {
    const result=await classifyProduct('謎の服',undefined,env(),async()=>classifyReply({category:'camisole',normalizedColor:'black',sleeve:'puff',subCategory:null}));
    expect(result).toEqual({normalizedColor:'black'});
  });
  it('reports failures', async () => {
    await expect(classifyProduct('服',undefined,env(),async()=>new Response('nope',{status:500}))).rejects.toThrow();
  });
});

describe('label tidying', () => {
  it('strips decoration and a trailing shop name', () => {
    expect(tidyLabel('【新品】ウールコート | ZOZOTOWN','ZOZOTOWN')).toBe('ウールコート');
    expect(tidyLabel('  wool   coat  ')).toBe('wool coat');
    expect(tidyLabel('ウールコート | ZOZOTOWN')).toBe('ウールコート | ZOZOTOWN');
    expect(tidyLabel(null)).toBeUndefined();
  });
  it('handles mall titles that wrap the shop name', () => {
    expect(tidyLabel('ひらっと心が躍る。シアーカーディガンce1260606 | [公式]Classical Elf（クラシカルエルフ）通販','Classical Elf'))
      .toBe('ひらっと心が躍る。シアーカーディガンce1260606');
    expect(tidyLabel('＜二宮こずえさん出演YouTube紹介アイテム＞【追加予約】パールボタンニットベスト | [公式]カレンソロジー（Curensology）通販','Curensology'))
      .toBe('パールボタンニットベスト');
  });
});

describe('gallery images', () => {
  const page = (body: string) => `<html><body>${body}</body></html>`;
  it('collects product images from the DOM and drops chrome', () => {
    const html = page(`
      <img src="/common/logo.png">
      <img src="https://cdn.example/a_500.jpg">
      <img data-src="https://cdn.example/b_500.jpg?v=1">
      <img srcset="https://cdn.example/c_500.jpg 1x, https://cdn.example/c_1000.jpg 2x">
      <img src="https://cdn.example/tiny_50.jpg">
      <img src="https://cdn.example/thumb_s.jpg">
      <img src="https://cdn.example/sprite.png">
      <img src="/relative/d_500.jpg">
    `);
    expect(collectPageImages(html, 'https://shop.example/item')).toEqual([
      'https://cdn.example/a_500.jpg',
      'https://cdn.example/b_500.jpg?v=1',
      'https://cdn.example/c_500.jpg',
      'https://cdn.example/c_1000.jpg',
      'https://shop.example/relative/d_500.jpg',
    ]);
  });
  it('caps the number of candidates', () => {
    const html = page(
      Array.from({ length: 60 }, (_, n) => `<img src="https://cdn.example/p${n}_500.jpg">`).join(''),
    );
    expect(collectPageImages(html, 'https://shop.example/item').length).toBe(40);
  });
  it('finds gallery URLs embedded in scripts as relative paths', () => {
    const html = page(
      `<script>var gallery=["/img/932/item_1.jpg","/img/932/item_2.jpg","/img/932/item_3.jpg"];</script>`,
    );
    expect(collectPageImages(html, 'https://item.example/shop/a/')).toEqual([
      'https://item.example/img/932/item_1.jpg',
      'https://item.example/img/932/item_2.jpg',
      'https://item.example/img/932/item_3.jpg',
    ]);
  });
  it('prefers images sharing the product id over related products', () => {
    const related = Array.from(
      { length: 5 },
      (_, n) => `<img src="https://cdn.example/navi/related_${n}_500.jpg">`,
    ).join('');
    const own = Array.from(
      { length: 6 },
      (_, n) => `<img src="https://cdn.example/goods/item_123456_${n}.jpg">`,
    ).join('');
    const images = collectPageImages(page(related + own), 'https://shop.example/item/123456/');
    expect(images).toHaveLength(6);
    expect(images.every((url) => url.includes('123456'))).toBe(true);
  });
  it('matches alphanumeric product codes and drops related products', () => {
    const own = Array.from(
      { length: 5 },
      (_, n) => `<img src="https://cdn.example/goods/yctops82_${n}.jpg">`,
    ).join('');
    const related = `<img src="https://cdn.example/rel/other_1.jpg"><img src="https://cdn.example/rel/other_2.jpg">`;
    const images = collectPageImages(
      page(own + related),
      'https://shop.example/lingxiayuu/yctops82.html',
    );
    expect(images).toHaveLength(5);
    expect(images.every((url) => url.includes('yctops82'))).toBe(true);
  });
  it('merges the same image with a different query string', () => {
    expect(
      dedupeImages([
        'https://cdn.example/a_500.jpg',
        'https://cdn.example/a_500.jpg?width=600',
        'https://cdn.example/b_500.jpg',
      ]),
    ).toEqual(['https://cdn.example/a_500.jpg', 'https://cdn.example/b_500.jpg']);
  });
});

describe('page decoding', () => {
  it('decodes EUC-JP pages instead of corrupting them', () => {
    const euc=Uint8Array.from([0xa5,0xd6,0xa5,0xe9,0xa5,0xc3,0xa5,0xaf]);
    expect(decodeHtml(euc,'EUC-JP')).toBe('ブラック');
    // 宣言が無いバイト列は判定できないためUTF-8として扱う。
    expect(decodeHtml(euc)).toBe(new TextDecoder().decode(euc));
  });
  it('reads the charset from a meta tag', () => {
    const html=Uint8Array.from([...new TextEncoder().encode('<meta http-equiv="Content-Type" content="text/html; charset=EUC-JP">'),0xa5,0xd6,0xa5,0xe9,0xa5,0xc3,0xa5,0xaf]);
    expect(decodeHtml(html)).toContain('ブラック');
  });
  it('keeps UTF-8 pages unchanged', () => {
    expect(decodeHtml(new TextEncoder().encode('ニット'))).toBe('ニット');
  });
});

describe('page fetching', () => {
  it('calls fetch without a this binding', async () => {
    const seen: { receiver?: unknown } = {};
    const fake = function (this: unknown) {
      seen.receiver = this;
      return Promise.resolve(new Response('<html><body>ok</body></html>', { status: 200, headers: { 'content-type': 'text/html' } }));
    } as unknown as typeof fetch;
    const page = await new SimpleFetcher(fake, async () => {}).get('https://example.com/item', 'html');
    expect(seen.receiver).toBeUndefined();
    expect(new TextDecoder().decode(page.bytes)).toContain('ok');
  });
  it('renders bot-protected pages through Browser Run', async () => {
    const calls: unknown[] = [];
    const browser = {
      quickAction: async (action: string, options: unknown) => {
        calls.push([action, options]);
        return Response.json({ success: true, result: '<html><body>ZOZO ZOZOTOWN</body></html>', meta: { status: 200, title: 't' } });
      },
    } as unknown as BrowserRun;
    const page = await new BrowserFetcher(browser, async () => {}).get('https://zozo.jp/shop/coen/goods/1/', 'html');
    expect(calls.length).toBe(1);
    expect(new TextDecoder().decode(page.bytes)).toContain('ZOZOTOWN');
  });
  it('rejects a Browser Run error response', async () => {
    const browser = { quickAction: async () => Response.json({ success: false }, { status: 429 }) } as unknown as BrowserRun;
    await expect(new BrowserFetcher(browser, async () => {}).get('https://zozo.jp/x', 'html')).rejects.toThrow();
  });
  it('rejects a rendered block page', async () => {
    const browser = { quickAction: async () => Response.json({ success: true, result: '<html><head><title>Access Denied</title></head><body>Access Denied</body></html>', meta: { status: 403, title: 'Access Denied' } }) } as unknown as BrowserRun;
    await expect(new BrowserFetcher(browser, async () => {}).get('https://zozo.jp/x', 'html')).rejects.toThrow();
  });
  it('maps ZOZO goods to the Yahoo! Shopping mirror', () => {
    expect(zozoYahooMirror('https://zozo.jp/shop/publictokyo/goods/82019293/?pno=1')).toBe('https://store.shopping.yahoo.co.jp/zozo/82019293.html');
    expect(zozoYahooMirror('https://zozo.jp/category/tops/')).toBeUndefined();
    expect(zozoYahooMirror('https://example.com/shop/a/goods/1/')).toBeUndefined();
  });
  it('tries each fetcher in order and only moves on after a failure', async () => {
    const page = { bytes: new Uint8Array(), url: 'https://x/', type: 'text/html' };
    const ok: PageFetcher = { get: async () => page };
    const failing: PageFetcher = { get: async () => { throw new Error('boom'); } };
    let fallbacks = 0;
    const primaryFirst = new ChainFetcher([ok, failing], () => { fallbacks++; });
    expect(await primaryFirst.get('https://x/', 'html')).toBe(page);
    expect(fallbacks).toBe(0);
    const secondaryFirst = new ChainFetcher([failing, ok], () => { fallbacks++; });
    expect(await secondaryFirst.get('https://x/', 'html')).toBe(page);
    expect(fallbacks).toBe(1);
    await expect(new ChainFetcher([failing, failing], () => { fallbacks++; }).get('https://x/', 'html')).rejects.toThrow();
  });
});
