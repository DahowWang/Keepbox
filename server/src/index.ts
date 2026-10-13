// Keepbox 同步 API。
// - D1 `records`：每筆檔案／資料夾／標籤一列，seq 為全域遞增異動序號
// - R2 `content/<id>`：檔案的 HTML 內容（可能含 base64 圖片，獨立存放）
// 衝突處理：同一筆以 updatedAt 較新者為準（last-write-wins）。

const RECORD_TYPES = new Set(["file", "folder", "tag"]);
const ID_PATTERN = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const MAX_PUSH = 200;
const MAX_PULL = 500;
const MAX_CONTENT_BYTES = 50 * 1024 * 1024;

interface IncomingRecord {
	type: string;
	id: string;
	updatedAt: number;
	deleted: boolean;
	data: Record<string, unknown>;
}

interface RecordRow {
	type: string;
	id: string;
	data: string;
	updated_at: number;
	deleted: number;
	seq: number;
}

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);

		if (url.pathname === "/v1/health") return json({ ok: true });

		if (!(await authorized(request, env))) return json({ error: "unauthorized" }, 401);

		try {
			if (url.pathname === "/v1/changes" && request.method === "GET") return await pullChanges(url, env);
			if (url.pathname === "/v1/push" && request.method === "POST") return await pushChanges(request, env);

			const contentMatch = url.pathname.match(/^\/v1\/content\/([^/]+)$/);
			if (contentMatch) {
				const id = contentMatch[1];
				if (!ID_PATTERN.test(id)) return json({ error: "invalid id" }, 400);
				if (request.method === "PUT") return await putContent(id, request, env);
				if (request.method === "GET") return await getContent(id, env);
			}
		} catch (err) {
			console.error("request failed", url.pathname, err);
			return json({ error: "internal error" }, 500);
		}

		return json({ error: "not found" }, 404);
	},
} satisfies ExportedHandler<Env>;

async function authorized(request: Request, env: Env): Promise<boolean> {
	const header = request.headers.get("Authorization") ?? "";
	if (!env.SYNC_TOKEN || !header.startsWith("Bearer ")) return false;
	// 先各自雜湊成等長，再做常數時間比較
	const encoder = new TextEncoder();
	const [given, expected] = await Promise.all([
		crypto.subtle.digest("SHA-256", encoder.encode(header.slice(7))),
		crypto.subtle.digest("SHA-256", encoder.encode(env.SYNC_TOKEN)),
	]);
	return crypto.subtle.timingSafeEqual(given, expected);
}

async function pullChanges(url: URL, env: Env): Promise<Response> {
	const since = Number(url.searchParams.get("since") ?? "0");
	const limit = Math.min(Number(url.searchParams.get("limit") ?? MAX_PULL), MAX_PULL);
	if (!Number.isInteger(since) || since < 0 || !Number.isInteger(limit) || limit < 1) {
		return json({ error: "invalid since/limit" }, 400);
	}

	const { results } = await env.DB.prepare(
		"SELECT type, id, data, updated_at, deleted, seq FROM records WHERE seq > ? ORDER BY seq LIMIT ?",
	)
		.bind(since, limit + 1)
		.all<RecordRow>();

	const more = results.length > limit;
	const rows = more ? results.slice(0, limit) : results;
	return json({
		records: rows.map((r) => ({
			type: r.type,
			id: r.id,
			updatedAt: r.updated_at,
			deleted: r.deleted === 1,
			seq: r.seq,
			data: JSON.parse(r.data),
		})),
		cursor: rows.length ? rows[rows.length - 1].seq : since,
		more,
	});
}

async function pushChanges(request: Request, env: Env): Promise<Response> {
	const body = (await request.json().catch(() => null)) as { records?: unknown } | null;
	const records = parseRecords(body?.records);
	if (!records) return json({ error: "invalid records" }, 400);
	if (records.length === 0) return json({ accepted: 0 });

	// 每筆在同一個 transaction 內依序取得新的 seq；只有 updatedAt 較新才覆蓋
	const upsert = env.DB.prepare(
		`INSERT INTO records (type, id, data, updated_at, deleted, seq)
		 VALUES (?1, ?2, ?3, ?4, ?5, (SELECT COALESCE(MAX(seq), 0) + 1 FROM records))
		 ON CONFLICT (type, id) DO UPDATE SET
		   data = excluded.data,
		   updated_at = excluded.updated_at,
		   deleted = excluded.deleted,
		   seq = excluded.seq
		 WHERE excluded.updated_at > records.updated_at`,
	);
	const results = await env.DB.batch(
		records.map((r) =>
			upsert.bind(r.type, r.id, JSON.stringify(r.data), r.updatedAt, r.deleted ? 1 : 0),
		),
	);
	const accepted = results.filter((res) => res.meta.changes > 0).length;

	// 刪除生效的檔案，一併清掉 R2 內容
	const deletedFiles = records.filter((r, i) => r.type === "file" && r.deleted && results[i].meta.changes > 0);
	if (deletedFiles.length) await env.CONTENT.delete(deletedFiles.map((r) => `content/${r.id}`));

	return json({ accepted });
}

function parseRecords(value: unknown): IncomingRecord[] | null {
	if (!Array.isArray(value) || value.length > MAX_PUSH) return null;
	const records: IncomingRecord[] = [];
	for (const item of value) {
		if (typeof item !== "object" || item === null) return null;
		const r = item as Record<string, unknown>;
		if (typeof r.type !== "string" || !RECORD_TYPES.has(r.type)) return null;
		if (typeof r.id !== "string" || !ID_PATTERN.test(r.id)) return null;
		if (typeof r.updatedAt !== "number" || !Number.isFinite(r.updatedAt)) return null;
		if (typeof r.data !== "object" || r.data === null || Array.isArray(r.data)) return null;
		records.push({
			type: r.type,
			id: r.id.toUpperCase(),
			updatedAt: Math.trunc(r.updatedAt),
			deleted: r.deleted === true,
			data: r.data as Record<string, unknown>,
		});
	}
	return records;
}

async function putContent(id: string, request: Request, env: Env): Promise<Response> {
	const length = Number(request.headers.get("Content-Length") ?? "0");
	if (length > MAX_CONTENT_BYTES) return json({ error: "content too large" }, 413);
	if (!request.body) return json({ error: "empty body" }, 400);

	const bytes = await request.arrayBuffer();
	if (bytes.byteLength > MAX_CONTENT_BYTES) return json({ error: "content too large" }, 413);
	const hash = toHex(await crypto.subtle.digest("SHA-256", bytes));
	await env.CONTENT.put(`content/${id.toUpperCase()}`, bytes, {
		httpMetadata: { contentType: "text/html; charset=utf-8" },
		customMetadata: { sha256: hash },
	});
	return json({ sha256: hash });
}

async function getContent(id: string, env: Env): Promise<Response> {
	const object = await env.CONTENT.get(`content/${id.toUpperCase()}`);
	if (!object) return json({ error: "not found" }, 404);
	return new Response(object.body, {
		headers: {
			"Content-Type": "text/html; charset=utf-8",
			"X-Content-SHA256": object.customMetadata?.sha256 ?? "",
		},
	});
}

function toHex(buffer: ArrayBuffer): string {
	return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(body: unknown, status = 200): Response {
	return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}
