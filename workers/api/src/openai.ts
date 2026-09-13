import { z } from 'zod';

type OpenAIContent = { type?: string; text?: string; refusal?: string };
type OpenAIResult = {
  status?: string;
  error?: { code?: string; message?: string } | null;
  incomplete_details?: { reason?: string } | null;
  output?: Array<{ content?: OpenAIContent[] }>;
};

export class OpenAIRequestError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'OpenAIRequestError';
  }
}

export type OpenAIRetryOptions = {
  maxAttempts?: number;
  maxRetryDelayMs?: number;
  timeoutMs?: number;
  sleep?: (milliseconds: number) => Promise<void>;
  random?: () => number;
};

const retryableStatuses = new Set([408, 409, 429, 500, 502, 503, 504]);
const nonRetryableCodes = new Set([
  'insufficient_quota',
  'billing_hard_limit_reached',
  'organization_spend_limit_exceeded',
  'project_spend_limit_exceeded',
]);

function responseError(body: unknown): { code?: string; message?: string } {
  if (!body || typeof body !== 'object') return {};
  const error = (body as { error?: unknown }).error;
  if (!error || typeof error !== 'object') return {};
  const value = error as { code?: unknown; message?: unknown };
  return {
    code: typeof value.code === 'string' ? value.code : undefined,
    message: typeof value.message === 'string' ? value.message : undefined,
  };
}

function retryAfterMs(response: Response): number | undefined {
  const value = response.headers.get('retry-after')?.trim();
  if (!value) return undefined;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return seconds * 1000;
  const date = Date.parse(value);
  if (Number.isFinite(date)) return Math.max(0, date - Date.now());
  return undefined;
}

async function readJson(response: Response): Promise<unknown | undefined> {
  try {
    return await response.json();
  } catch {
    return undefined;
  }
}

export async function requestStructured<T>(
  payload: Record<string, unknown>,
  apiKey: string,
  schema: z.ZodType<T>,
  request: typeof fetch = fetch,
  options: OpenAIRetryOptions = {},
): Promise<T> {
  const maxAttempts = Math.max(1, options.maxAttempts ?? 3);
  const maxRetryDelayMs = Math.max(0, options.maxRetryDelayMs ?? 4000);
  const timeoutMs = Math.max(1000, options.timeoutMs ?? 20000);
  const sleep = options.sleep ?? ((milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)));
  const random = options.random ?? Math.random;
  let waitedMs = 0;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    let response: Response;
    try {
      response = await request('https://api.openai.com/v1/responses', {
        method: 'POST',
        signal: AbortSignal.timeout(timeoutMs),
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });
    } catch (error) {
      if (attempt + 1 >= maxAttempts) {
        throw new OpenAIRequestError(
          'network_error',
          error instanceof Error ? error.message : 'OpenAIへの接続に失敗しました',
        );
      }
      const delay = Math.min(250 * 2 ** attempt + Math.floor(random() * 100), maxRetryDelayMs - waitedMs);
      if (delay <= 0) throw new OpenAIRequestError('network_error', 'OpenAIへの接続に失敗しました');
      await sleep(delay);
      waitedMs += delay;
      continue;
    }

    const body = await readJson(response);
    if (!response.ok) {
      const detail = responseError(body);
      const canRetry = retryableStatuses.has(response.status) && !nonRetryableCodes.has(detail.code ?? '');
      if (canRetry && attempt + 1 < maxAttempts) {
        const hinted = retryAfterMs(response);
        const fallback = 250 * 2 ** attempt + Math.floor(random() * 100);
        const delay = hinted ?? fallback;
        if (delay <= maxRetryDelayMs - waitedMs) {
          await sleep(delay);
          waitedMs += delay;
          continue;
        }
      }
      throw new OpenAIRequestError(
        detail.code ?? `http_${response.status}`,
        detail.message ?? `OpenAI API error ${response.status}`,
        response.status,
      );
    }

    if (body === undefined) {
      throw new OpenAIRequestError(
        'invalid_response',
        'OpenAIからJSONではない応答が返されました',
        response.status,
      );
    }

    const result = body as OpenAIResult;
    if (result.error) {
      throw new OpenAIRequestError(
        result.error.code ?? 'response_failed',
        result.error.message ?? 'OpenAIの応答生成に失敗しました',
        response.status,
      );
    }
    if (result.status !== 'completed') {
      const suffix = result.incomplete_details?.reason ? `: ${result.incomplete_details.reason}` : '';
      throw new OpenAIRequestError(
        `response_${result.status ?? 'invalid'}`,
        `OpenAIの応答が完了しませんでした${suffix}`,
        response.status,
      );
    }

    const contents = result.output?.flatMap((item) => item.content ?? []) ?? [];
    const refusal = contents.find((content) => content.type === 'refusal');
    if (refusal) {
      throw new OpenAIRequestError('refusal', refusal.refusal ?? 'OpenAIが応答を拒否しました', response.status);
    }
    const output = contents
      .filter((content) => content.type === 'output_text' && typeof content.text === 'string')
      .map((content) => content.text)
      .join('');
    let parsed: unknown;
    try {
      parsed = JSON.parse(output);
    } catch {
      throw new OpenAIRequestError('invalid_output', 'OpenAIの構造化出力がJSONではありません', response.status);
    }
    const validated = schema.safeParse(parsed);
    if (!validated.success) {
      throw new OpenAIRequestError('invalid_output', 'OpenAIの構造化出力がスキーマに一致しません', response.status);
    }
    return validated.data;
  }

  throw new OpenAIRequestError('retry_exhausted', 'OpenAIへの再試行回数を超えました');
}
