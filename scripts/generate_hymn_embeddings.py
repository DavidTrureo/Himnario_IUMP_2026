#!/usr/bin/env python3
"""
Genera el catálogo compacto de letras limpias (`functions/data/hymn_digests.json`)
y, cuando se proporciona clave API de Gemini (`GEMINI_API_KEY` o `--api-key`),
calcula los embeddings vectoriales compactos (`int8`, 256 dimensiones) mediante
`gemini-embedding-001` para habilitar búsqueda vectorial híbrida tanto en la
Cloud Function como dentro de la app Flutter.

Uso:
  python3 scripts/generate_hymn_embeddings.py --digests-only
  GEMINI_API_KEY=... python3 scripts/generate_hymn_embeddings.py --with-embeddings
"""

import argparse
import hashlib
import json
import math
import os
import re
import struct
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COLLECTIONS = [
    ("iump", ROOT / "assets/json/hymns.json"),
    ("especiales", ROOT / "assets/json/special_hymns.json"),
    ("coros", ROOT / "assets/json/coros.json"),
]

CHORD_RE = re.compile(r"\[[^\]]*\]")
WS_RE = re.compile(r"[ \t]+")
NON_ALNUM_RE = re.compile(r"[^a-z0-9\s]")


def normalize_for_dedup(text: str) -> str:
    import unicodedata

    nfd = unicodedata.normalize("NFD", text.lower())
    no_accents = "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")
    return re.sub(r"\s+", " ", NON_ALNUM_RE.sub(" ", no_accents)).strip()


def clean_lyrics(raw: str) -> str:
    text = CHORD_RE.sub("", raw or "")
    text = text.replace("\r\n", "\n")
    text = WS_RE.sub(" ", text)
    return text.strip()


def build_compact_digest(title: str, lyrics: str, max_chars: int = 440) -> str:
    cleaned = clean_lyrics(lyrics)
    if not cleaned:
        return title.strip()
    lines = [ln.strip() for ln in cleaned.split("\n") if ln.strip()]
    seen = set()
    unique_lines = []
    for ln in lines:
        norm = normalize_for_dedup(ln)
        is_label = len(ln) <= 10 and (ln.endswith(":") or bool(re.match(r"^\d+\.?$", ln)))
        if len(norm) >= 6 and not is_label:
            if norm in seen:
                continue
            seen.add(norm)
        unique_lines.append(ln)
    joined = " / ".join(unique_lines)
    if len(joined) <= max_chars:
        return joined
    return joined[: max_chars - 1].rstrip() + "…"


def build_embedding_text(collection: str, title: str, lyrics: str, max_chars: int = 1600) -> str:
    col_label = {
        "iump": "Himnario Oficial IUMP",
        "especiales": "Alabanza Especial",
        "coros": "Coro de Avivamiento",
    }.get(collection, collection)
    cleaned = clean_lyrics(lyrics)
    lines = [ln.strip() for ln in cleaned.split("\n") if ln.strip()]
    seen = set()
    unique_lines = []
    for ln in lines:
        norm = normalize_for_dedup(ln)
        if len(norm) >= 6:
            if norm in seen:
                continue
            seen.add(norm)
        unique_lines.append(ln)
    body = "\n".join(unique_lines)
    full = f"[{col_label}] {title.strip()}\n{body}".strip()
    if len(full) > max_chars:
        return full[:max_chars]
    return full


def load_all_songs():
    songs = []
    for col, path in COLLECTIONS:
        data = json.loads(path.read_text(encoding="utf-8"))
        for item in data:
            h_id = int(item["id"])
            title = str(item.get("title") or "").strip()
            lyrics = str(item.get("lyrics") or "")
            digest = build_compact_digest(title, lyrics)
            embed_text = build_embedding_text(col, title, lyrics)
            h_hash = hashlib.sha1(f"{title}\n{clean_lyrics(lyrics)}".encode("utf-8")).hexdigest()[:10]
            songs.append(
                {
                    "c": col,
                    "i": h_id,
                    "t": title,
                    "d": digest,
                    "h": h_hash,
                    "embed_text": embed_text,
                }
            )
    return songs


def write_server_digests(songs):
    out_dir = ROOT / "functions/data"
    out_dir.mkdir(parents=True, exist_ok=True)
    digest_map = {
        f"{s['c']}-{s['i']}": {
            "id": s["i"],
            "collection": s["c"],
            "title": s["t"],
            "digest": s["d"],
        }
        for s in songs
    }
    out_path = out_dir / "hymn_digests.json"
    out_path.write_text(json.dumps(digest_map, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"[OK] {out_path} generado con {len(digest_map)} cantos ({out_path.stat().st_size / 1024:.1f} KB)")


class DailyQuotaReachedError(RuntimeError):
    """Se lanza cuando la cuota gratuita diaria (1,000/día) de embeddings se agota."""


def batch_embed(texts, api_key: str, dims: int = 256):
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents"
    payload = {
        "requests": [
            {
                "model": "models/gemini-embedding-001",
                "content": {"parts": [{"text": txt}]},
                "taskType": "RETRIEVAL_DOCUMENT",
                "outputDimensionality": dims,
            }
            for txt in texts
        ]
    }
    data = json.dumps(payload).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": api_key,
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=45) as resp:
                body = json.loads(resp.read().decode("utf-8"))
                return [item["values"] for item in body["embeddings"]]
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="ignore")
            is_daily = "PerDay" in err_body or bool(re.search(r"retry in \d+[hm]", err_body, re.I))
            if e.code == 429 and is_daily:
                raise DailyQuotaReachedError(err_body) from e
            if e.code in (429, 500, 502, 503) and attempt < 7:
                retry_match = re.search(r"retry in (\d+(?:\.\d+)?)s", err_body, re.I)
                wait = (
                    math.ceil(float(retry_match.group(1))) + 2
                    if retry_match
                    else min(65, 10 + attempt * 8)
                )
                print(f"  [Rate limit/HTTP {e.code}] esperando {wait}s (intento {attempt + 1}/8)...")
                time.sleep(wait)
                continue
            raise RuntimeError(f"HTTP {e.code}: {err_body}") from e
    raise RuntimeError("No se pudo obtener respuesta de batchEmbedContents")


def quantize_int8(vec):
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    unit = [v / norm for v in vec]
    return [max(-127, min(127, int(round(v * 127.0)))) for v in unit]


def read_dotenv_key():
    env_path = ROOT / "functions/.env"
    if not env_path.exists():
        return ""
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--digests-only", action="store_true")
    parser.add_argument("--with-embeddings", action="store_true")
    parser.add_argument("--api-key", default="")
    parser.add_argument("--dims", type=int, default=256)
    parser.add_argument("--batch-size", type=int, default=35)
    args = parser.parse_args()

    songs = load_all_songs()
    write_server_digests(songs)

    if args.digests_only or not args.with_embeddings:
        return

    api_key = args.api_key.strip() or os.environ.get("GEMINI_API_KEY", "").strip() or read_dotenv_key()
    if not api_key:
        raise SystemExit("Falta GEMINI_API_KEY (o --api-key) para generar embeddings.")

    print(f"Generando embeddings ({args.dims}d int8) para {len(songs)} cantos...")
    cache_path = ROOT / "scripts/.embed_cache.jsonl"
    legacy_tmp_cache = Path("/tmp/himnario_embed_cache.jsonl")
    if not cache_path.exists() and legacy_tmp_cache.exists():
        cache_path.write_text(legacy_tmp_cache.read_text(encoding="utf-8"), encoding="utf-8")

    cached_vecs = {}
    if cache_path.exists():
        for line in cache_path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            rec = json.loads(line)
            cached_vecs[f"{rec['c']}-{rec['i']}:{rec['h']}"] = rec["q"]
        if cached_vecs:
            print(f"  [Cache persistente] {len(cached_vecs)} cantos recuperados de {cache_path.name}.")

    pending = [
        s for s in songs if f"{s['c']}-{s['i']}:{s['h']}" not in cached_vecs
    ]
    if pending:
        try:
            with cache_path.open("a", encoding="utf-8") as cf:
                for start in range(0, len(pending), args.batch_size):
                    chunk = pending[start : start + args.batch_size]
                    texts = [s["embed_text"] for s in chunk]
                    vectors = batch_embed(texts, api_key=api_key, dims=args.dims)
                    for song, vec in zip(chunk, vectors):
                        q = quantize_int8(vec)
                        k = f"{song['c']}-{song['i']}:{song['h']}"
                        cached_vecs[k] = q
                        cf.write(json.dumps({"c": song["c"], "i": song["i"], "h": song["h"], "q": q}) + "\n")
                    cf.flush()
                    done = min(start + len(chunk), len(pending))
                    print(f"  Progreso nuevo: {done}/{len(pending)} (total {len(cached_vecs)}/{len(songs)})", flush=True)
                    time.sleep(0.8)
        except DailyQuotaReachedError as dq:
            print(
                f"\n[PAUSA SEGURA - CUOTA DIARIA] Se alcanzó el tope gratuito de 1,000 cantos/día de gemini-embedding-001.\n"
                f"Progreso guardado en {cache_path}: {len(cached_vecs)}/{len(songs)} cantos.\n"
                f"Detalle: {dq}"
            )
            return

    all_bytes = bytearray()
    meta_items = []
    for song in songs:
        q = cached_vecs[f"{song['c']}-{song['i']}:{song['h']}"]
        all_bytes.extend(struct.pack(f"{args.dims}b", *q))
        meta_items.append({"c": song["c"], "i": song["i"], "h": song["h"]})

    meta_payload = json.dumps(
        {
            "model": "gemini-embedding-001",
            "dims": args.dims,
            "count": len(meta_items),
            "items": meta_items,
        },
        separators=(",", ":"),
    )

    for target_dir in [ROOT / "assets/json", ROOT / "functions/data"]:
        target_dir.mkdir(parents=True, exist_ok=True)
        (target_dir / "hymn_embeddings.bin").write_bytes(bytes(all_bytes))
        (target_dir / "hymn_embeddings_meta.json").write_text(meta_payload, encoding="utf-8")
        print(f"[OK] Escrito índice vectorial en {target_dir} ({len(all_bytes) / 1024:.1f} KB)")


if __name__ == "__main__":
    main()

