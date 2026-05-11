#!/usr/bin/env python3
"""
sage ops — deterministic wiki operations, no LLM required.

Usage:
  python3 sage-operations.py lint              # run all health checks, output JSON
  python3 sage-operations.py lint --fix        # same + auto-apply deterministic fixes
  python3 sage-operations.py discover          # find raw files not yet ingested
  python3 sage-operations.py rebuild-knowledge-graph # regenerate _knowledge-graph.json
  python3 sage-operations.py status            # quick wiki stats
  python3 sage-operations.py relocate <path>   # move sage wiki root to a new directory

Root resolution order:
  1. SAGE_ROOT env var
  2. ~/.config/sage/config.json → "root" key  (set by sage-relocate)
  3. ~/sage/  (default install location)
  4. sage-operations.py parent directory  (dev mode fallback)
"""
from __future__ import annotations
import argparse, fnmatch, json, os, re, sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

_CONFIG_FILE = Path.home() / ".config" / "sage" / "config.json"


def _load_config() -> dict:
    if _CONFIG_FILE.exists():
        try:
            return json.loads(_CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {}


def _save_config(config: dict) -> None:
    _CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    _CONFIG_FILE.write_text(json.dumps(config, indent=2), encoding="utf-8")


def _find_sage_root() -> Path:
    # 1. SAGE_ROOT env var
    env = os.environ.get("SAGE_ROOT")
    if env:
        return Path(env).expanduser().resolve()
    # 2. User config file
    config = _load_config()
    if config.get("root"):
        p = Path(config["root"]).expanduser().resolve()
        if p.exists():
            return p
    # 3. ~/sage/ default install location
    default = Path.home() / "sage"
    if default.exists():
        return default
    # 4. sage-operations.py parent (dev mode)
    return Path(__file__).parent.parent.resolve()


ROOT = _find_sage_root()
WIKI_DIR = ROOT / "wiki"
SOURCES_DIR = ROOT / "sources"
INGEST_IGNORE = [
    ".git/", ".DS_Store", ".gitkeep",
    "*.tmp", "node_modules/", "sources/meetings/",
]


# ── helpers ───────────────────────────────────────────────────────────

def _parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith("---"):
        return {}, text
    end = text.find("---", 3)
    if end == -1:
        return {}, text
    meta: dict = {}
    for line in text[3:end].strip().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            v = v.strip().strip('"').strip("'")
            if v.startswith("[") and v.endswith("]"):
                v = [x.strip().strip('"').strip("'") for x in v[1:-1].split(",") if x.strip()]
            meta[k.strip()] = v
    return meta, text[end + 3:].strip()


def _load_wiki_pages() -> dict[str, dict]:
    pages: dict[str, dict] = {}
    for md in WIKI_DIR.rglob("*.md"):
        if md.name.startswith("."):
            continue
        rel = md.relative_to(WIKI_DIR)
        if len(rel.parts) == 1:  # skip index.md, log.md
            continue
        if rel.parts[0] == "sage-memory":  # never lint memory layer files
            continue
        text = md.read_text(encoding="utf-8", errors="replace")
        meta, body = _parse_frontmatter(text)
        stem = md.stem.lower()
        pages[stem] = {
            "path": md,
            "rel": str(rel),
            "meta": meta,
            "body": body,
            "text": text,
            "lines": len(text.splitlines()),
        }
    return pages


def _get_wikilinks(text: str) -> list[str]:
    return [m.group(1).strip().lower() for m in re.finditer(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]", text)]


def _check_action_item_orphans() -> list[dict]:
    """Report meeting headers in action-items/ that point to missing wiki/meetings/ pages."""
    ai_dir = WIKI_DIR / "action-items"
    if not ai_dir.exists():
        return []
    meetings_dir = WIKI_DIR / "meetings"
    header_re = re.compile(r"^## \d{4}-\d{2}-\d{2} — \[.+?\]\(\.\./meetings/(.+?)\.md\)")
    issues: list[dict] = []
    for fname in ("open.md", "closed.md"):
        fpath = ai_dir / fname
        if not fpath.exists():
            continue
        for line in fpath.read_text(encoding="utf-8").splitlines():
            m = header_re.match(line)
            if m:
                slug = m.group(1)
                if not (meetings_dir / f"{slug}.md").exists():
                    issues.append({
                        "type": "action_item_orphan",
                        "file": f"action-items/{fname}",
                        "slug": slug,
                    })
    return issues



def _is_ignored(rel_path: str, patterns: list[str]) -> bool:
    rel_lower = rel_path.lower()
    for pat in patterns:
        pat_lower = pat.lower()
        if fnmatch.fnmatch(rel_lower, pat_lower) or fnmatch.fnmatch(rel_lower.split("/")[-1], pat_lower):
            return True
        if pat_lower.rstrip("/") in rel_lower:
            return True
    return False


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── auto-fix routines (no LLM) ────────────────────────────────────────

def _fix_confidence_gaps(pages: dict[str, dict]) -> list[str]:
    """Add [confidence: medium] to Key Fact bullets missing confidence tags."""
    fixed = []
    for stem, page in pages.items():
        lines = page["text"].splitlines()
        new_lines = []
        in_key_facts = False
        changed = False
        for line in lines:
            if re.match(r"^## Key Facts", line):
                in_key_facts = True
            elif line.startswith("## "):
                in_key_facts = False
            if in_key_facts and re.match(r"^- \*\*", line) and "[confidence:" not in line:
                line = line.rstrip() + " `[confidence: medium]`"
                changed = True
            new_lines.append(line)
        if changed:
            page["path"].write_text("\n".join(new_lines) + "\n", encoding="utf-8")
            fixed.append(f"confidence_gap: {stem}")
    return fixed


def _fix_dead_links(pages: dict[str, dict], page_names: set[str]) -> list[str]:
    """Remove brackets from dead wikilinks with no matching page."""
    fixed = []
    wl_re = re.compile(r"\[\[([^\]|]+)(?:\|([^\]]*))?\]\]")
    for stem, page in pages.items():
        text = page["text"]
        new_text = text
        for m in wl_re.finditer(text):
            target = m.group(1).strip().lower()
            if target not in page_names:
                display = m.group(2).strip() if m.group(2) else m.group(1).strip()
                new_text = new_text.replace(m.group(0), display, 1)
        if new_text != text:
            page["path"].write_text(new_text, encoding="utf-8")
            fixed.append(f"dead_link: {stem}")
    return fixed


def _fix_index_drift(pages: dict[str, dict], page_names: set[str]) -> list[str]:
    """Add pages missing from index.md."""
    index_path = WIKI_DIR / "index.md"
    if not index_path.exists():
        return []
    index_text = index_path.read_text(encoding="utf-8", errors="replace")
    fixed = []
    additions: list[str] = []
    for stem in sorted(page_names):
        if f"[[{stem}]]" not in index_text and f"[[{stem}|" not in index_text:
            page = pages[stem]
            tldr = ""
            tldr_m = re.search(r">\s*\*\*TLDR:\*\*\s*(.+)", page["body"])
            if tldr_m:
                tldr = tldr_m.group(1).strip()
            maturity = page["meta"].get("maturity", "seed")
            sc = page["meta"].get("source_count", "1")
            entry = f"- [[{stem}]] — {tldr or '(no TLDR)'}. {maturity} · {sc} sources"
            additions.append(entry)
            fixed.append(f"index_drift: {stem}")
    if additions:
        # Append to index under a catch-all section if needed
        if "## Uncategorized" not in index_text:
            index_text = index_text.rstrip() + "\n\n## Uncategorized\n"
        else:
            index_text = index_text.rstrip() + "\n"
        index_text += "\n".join(additions) + "\n"
        index_path.write_text(index_text, encoding="utf-8")
    return fixed


def _fix_maturity(pages: dict[str, dict]) -> list[str]:
    """Update maturity field based on source_count."""
    def _expected_maturity(sc: int) -> str:
        if sc >= 7:
            return "established"
        if sc >= 4:
            return "mature"
        if sc >= 2:
            return "growing"
        return "seed"

    fixed = []
    for stem, page in pages.items():
        try:
            sc = int(page["meta"].get("source_count", 1))
        except (ValueError, TypeError):
            sc = 1
        expected = _expected_maturity(sc)
        current = page["meta"].get("maturity", "")
        if current != expected:
            text = page["text"]
            new_text = re.sub(r'^maturity:\s*.+$', f'maturity: {expected}', text, flags=re.MULTILINE)
            if new_text != text:
                page["path"].write_text(new_text, encoding="utf-8")
                fixed.append(f"maturity: {stem} {current}→{expected}")
    return fixed


def _annotate_index_backlinks(backlinks: dict[str, list]) -> list[str]:
    """Annotate index.md lines with backlink counts."""
    index_path = WIKI_DIR / "index.md"
    if not index_path.exists():
        return []
    index_text = index_path.read_text(encoding="utf-8", errors="replace")
    link_re = re.compile(r'- \[\[([^\]|]+)\]\]')
    lines = index_text.splitlines()
    new_lines = []
    annotated = []
    changed = False
    for line in lines:
        m = link_re.search(line)
        if m:
            stem = m.group(1).strip().lower()
            count = len(backlinks.get(stem, []))
            # Strip existing annotation
            clean_line = re.sub(r' · \d+ links', '', line)
            if count > 0:
                new_line = clean_line.rstrip() + f' · {count} links'
                if new_line != line:
                    changed = True
                new_lines.append(new_line)
                annotated.append(f"backlinks: {stem} ({count} links)")
            else:
                if clean_line != line:
                    changed = True
                new_lines.append(clean_line)
        else:
            new_lines.append(line)
    if changed:
        index_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    return annotated


def _append_log(entry: str) -> None:
    log_path = WIKI_DIR / "log.md"
    if log_path.exists():
        existing = log_path.read_text(encoding="utf-8", errors="replace")
    else:
        existing = "# sage Wiki Log\n\n*Append-only record of all wiki operations.*\n\n---\n\n"
    log_path.write_text(existing + entry, encoding="utf-8")


# ── commands ──────────────────────────────────────────────────────────

def cmd_lint(args) -> int:
    fix_mode: bool = getattr(args, "fix", False)
    pages = _load_wiki_pages()
    page_names = set(pages.keys())

    bl_path = WIKI_DIR / "_knowledge-graph.json"
    backlinks: dict[str, list] = {}
    if bl_path.exists():
        raw = json.loads(bl_path.read_text(encoding="utf-8"))
        backlinks = raw.get("backlinks", raw) if isinstance(raw, dict) else {}

    index_text = (WIKI_DIR / "index.md").read_text(encoding="utf-8", errors="replace") if (WIKI_DIR / "index.md").exists() else ""

    issues: list[dict] = []

    for stem, page in pages.items():
        text = page["text"]

        for link in _get_wikilinks(text):
            if link not in page_names:
                issues.append({"type": "dead_link", "page": stem, "link": link})

        if page["lines"] > 100:
            issues.append({"type": "bloated", "page": stem, "lines": page["lines"]})

        if page["meta"].get("maturity") == "seed":
            issues.append({"type": "thin", "page": stem, "source_count": page["meta"].get("source_count", "1")})

        in_key_facts = False
        for line in page["body"].splitlines():
            if re.match(r"^## Key Facts", line):
                in_key_facts = True
            elif line.startswith("## "):
                in_key_facts = False
            elif in_key_facts and re.match(r"^- \*\*", line) and "[confidence:" not in line:
                issues.append({"type": "confidence_gap", "page": stem, "line": line[:120]})

        dp = page["meta"].get("date_published", "")
        if dp:
            try:
                pub_year = int(dp[:4])
                if datetime.now().year - pub_year > 2:
                    issues.append({"type": "stale", "page": stem, "date_published": dp})
            except (ValueError, IndexError):
                pass

        if f"[[{stem}]]" not in index_text and f"[[{stem}|" not in index_text:
            issues.append({"type": "index_drift", "page": stem})

    for stem in page_names:
        if not backlinks.get(stem):
            issues.append({"type": "orphan", "page": stem})

    for stem, page in pages.items():
        ptype = page["meta"].get("type", "")
        cat = page["rel"].split("/")[0]
        if ptype == "entity" and cat == "concepts":
            issues.append({"type": "misclassified", "page": stem, "in": cat, "should_be": "entities"})
        if ptype == "concept" and cat == "entities":
            issues.append({"type": "misclassified", "page": stem, "in": cat, "should_be": "concepts"})

    # gap: concept pages with no entity examples / entities linked by no concept
    entity_stems = {s for s, p in pages.items() if p["meta"].get("type") == "entity"}
    concept_stems = {s for s, p in pages.items() if p["meta"].get("type") == "concept"}

    for stem in concept_stems:
        forward_links = set(_get_wikilinks(pages[stem]["body"]))
        if not forward_links & entity_stems:
            issues.append({"type": "gap", "page": stem, "detail": "concept with no entity examples"})

    for stem in entity_stems:
        linkers = set(backlinks.get(stem, []))
        if not linkers & concept_stems:
            issues.append({"type": "gap", "page": stem, "detail": "entity linked by no concept page"})

    # duplicate_candidate: name/alias collisions and tag-overlap
    name_index: dict[str, list[str]] = {}
    for stem, page in pages.items():
        keys = [stem]
        aliases = page["meta"].get("aliases", [])
        if isinstance(aliases, str):
            aliases = [a.strip() for a in aliases.split(",") if a.strip()]
        for alias in aliases:
            keys.append(alias.lower().replace(" ", "-"))
        for key in keys:
            name_index.setdefault(key, []).append(stem)

    for name, stems_list in name_index.items():
        if len(stems_list) > 1:
            for i, s1 in enumerate(stems_list):
                for s2 in stems_list[i + 1:]:
                    issues.append({"type": "duplicate_candidate", "page": s1, "alias": name, "conflicts_with": s2})

    type_tags: dict[str, list[tuple[str, set]]] = {}
    for stem, page in pages.items():
        ptype = page["meta"].get("type", "")
        tags = page["meta"].get("tags", [])
        if isinstance(tags, str):
            tags = [t.strip() for t in tags.split(",") if t.strip()]
        if ptype and tags:
            type_tags.setdefault(ptype, []).append((stem, set(tags)))

    for ptype, items in type_tags.items():
        for i, (s1, t1) in enumerate(items):
            for s2, t2 in items[i + 1:]:
                overlap = t1 & t2
                if len(overlap) >= 3:
                    issues.append({"type": "duplicate_candidate", "page": s1, "shared_tags": sorted(overlap), "conflicts_with": s2})

    # action item orphans
    issues += _check_action_item_orphans()

    auto_fixed: list[str] = []
    if fix_mode:
        auto_fixed += _fix_confidence_gaps(pages)
        auto_fixed += _fix_dead_links(pages, page_names)
        auto_fixed += _fix_index_drift(pages, page_names)
        auto_fixed += _fix_maturity(pages)
        import io, contextlib as _cl
        with _cl.redirect_stdout(io.StringIO()):
            cmd_rebuild_knowledge_graph(args)
        bl_path2 = WIKI_DIR / "_knowledge-graph.json"
        if bl_path2.exists():
            _bl2 = json.loads(bl_path2.read_text(encoding="utf-8"))
            _bl2 = _bl2.get("backlinks", _bl2) if isinstance(_bl2, dict) else {}
        else:
            _bl2 = {}
        auto_fixed += _annotate_index_backlinks(_bl2)

        # remove fixed issues from the list
        fixed_types = {i.split(":")[0] for i in auto_fixed}
        fixed_types.add("maturity")
        issues = [i for i in issues if i["type"] not in fixed_types or i["type"] in ("dead_link",)]
        # re-check dead_link after fix
        pages = _load_wiki_pages()
        page_names = set(pages.keys())
        issues = [i for i in issues if not (i["type"] == "dead_link" and i.get("link") not in page_names)]

    summary: dict[str, int] = {}
    for issue in issues:
        summary[issue["type"]] = summary.get(issue["type"], 0) + 1

    if fix_mode:
        ts = _now_iso()
        log_entry = f"## [{ts}] lint | automated health check\n\n"
        if auto_fixed:
            log_entry += "- Auto-fixed: " + ", ".join(auto_fixed) + "\n"
        if issues:
            log_entry += "- Flagged: " + ", ".join(f"{v}x {k}" for k, v in summary.items()) + "\n"
        else:
            log_entry += "- No remaining issues\n"
        log_entry += "\n---\n\n"
        _append_log(log_entry)

    result = {
        "timestamp": _now_iso(),
        "sage_root": str(ROOT),
        "page_count": len(pages),
        "auto_fixed": auto_fixed,
        "issue_count": len(issues),
        "summary": summary,
        "issues": issues,
    }
    print(json.dumps(result, indent=2))
    return 0 if not issues else 1


def cmd_discover(_args) -> int:
    ignore_patterns = INGEST_IGNORE

    ingested: set[str] = set()
    sources_dir = WIKI_DIR / "sources"
    if sources_dir.exists():
        ref_re = re.compile(r"`(sources/[^`]+)`")
        for md in sources_dir.rglob("*.md"):
            text = md.read_text(encoding="utf-8", errors="replace")
            for m in ref_re.finditer(text):
                ingested.add(m.group(1).lower())
            meta, _ = _parse_frontmatter(text)
            sf = meta.get("source_file", "")
            if sf:
                ingested.add(sf.lower())

    new_files: list[str] = []
    if SOURCES_DIR.exists():
        for f in sorted(SOURCES_DIR.rglob("*")):
            if not f.is_file():
                continue
            rel = str(f.relative_to(ROOT)).replace("\\", "/")
            if _is_ignored(rel.lower(), ignore_patterns):
                continue
            if rel.lower() not in ingested:
                new_files.append(rel)

    result = {
        "sage_root": str(ROOT),
        "new_files": new_files,
        "new_count": len(new_files),
        "ingested_count": len(ingested),
    }
    print(json.dumps(result, indent=2))
    return 0


def cmd_rebuild_knowledge_graph(_args) -> int:
    backlinks: dict[str, list] = {}
    forward: dict[str, list] = {}
    wl_re = re.compile(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]")

    for md in WIKI_DIR.rglob("*.md"):
        if md.name.startswith("."):
            continue
        rel = md.relative_to(WIKI_DIR)
        if rel.parts[0] == "sage-memory":
            continue
        text = md.read_text(encoding="utf-8", errors="replace")
        _, body = _parse_frontmatter(text)
        source = md.stem.lower()
        for m in wl_re.finditer(body):
            target = m.group(1).strip().lower()
            if target == source:
                continue
            if source not in backlinks.get(target, []):
                backlinks.setdefault(target, []).append(source)
            if target not in forward.get(source, []):
                forward.setdefault(source, []).append(target)

    bl_path = WIKI_DIR / "_knowledge-graph.json"
    bl_path.write_text(json.dumps({"backlinks": backlinks, "forward": forward}, indent=2), encoding="utf-8")
    _annotate_index_backlinks(backlinks)
    result = {"rebuilt": True, "pages_indexed": len(backlinks), "sage_root": str(ROOT)}
    print(json.dumps(result, indent=2))
    return 0


def cmd_trends(args) -> int:
    pages = _load_wiki_pages()
    months = getattr(args, "months", 12)
    cutoff = (datetime.now() - timedelta(days=months * 30)).strftime("%Y-%m-%d")

    tag_sources: dict[str, list] = {}
    for stem, page in pages.items():
        if page["meta"].get("type") != "source":
            continue
        dp = page["meta"].get("date_published", "")
        tags = page["meta"].get("tags", [])
        if isinstance(tags, str):
            tags = [t.strip() for t in tags.split(",") if t.strip()]
        for tag in tags:
            tag_sources.setdefault(tag, []).append({"page": stem, "date": dp})

    trending = []
    for tag, sources in tag_sources.items():
        recent = [s for s in sources if s["date"] >= cutoff] if cutoff else sources
        if len(recent) >= 2:
            trending.append({
                "tag": tag,
                "recent_count": len(recent),
                "total_count": len(sources),
                "latest": max((s["date"] for s in sources if s["date"]), default=""),
                "pages": [s["page"] for s in recent],
            })

    trending.sort(key=lambda x: x["recent_count"], reverse=True)

    result = {
        "sage_root": str(ROOT),
        "months": months,
        "trend_count": len(trending),
        "trending": trending,
    }
    print(json.dumps(result, indent=2))
    return 0


def cmd_status(_args) -> int:
    pages = _load_wiki_pages()
    by_type: dict[str, int] = {}
    by_maturity: dict[str, int] = {}
    for page in pages.values():
        t = page["meta"].get("type", "unknown")
        by_type[t] = by_type.get(t, 0) + 1
        m = page["meta"].get("maturity", "unknown")
        by_maturity[m] = by_maturity.get(m, 0) + 1

    raw_count = 0
    if SOURCES_DIR.exists():
        ignore_patterns = INGEST_IGNORE
        for f in SOURCES_DIR.rglob("*"):
            if f.is_file() and not _is_ignored(f.name, ignore_patterns):
                raw_count += 1

    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        cmd_discover(None)
    discover = json.loads(buf.getvalue())

    result = {
        "sage_root": str(ROOT),
        "page_count": len(pages),
        "by_type": by_type,
        "by_maturity": by_maturity,
        "raw_files": raw_count,
        "uningestd_files": discover["new_count"],
    }
    print(json.dumps(result, indent=2))
    return 0


def cmd_digest(args) -> int:
    log_path = WIKI_DIR / "log.md"
    days = getattr(args, "days", 7)
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    entry_re = re.compile(r'## \[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\] (\w+) \| (.+)')
    entries: list[dict] = []
    by_operation: dict[str, int] = {}
    if log_path.exists():
        text = log_path.read_text(encoding="utf-8", errors="replace")
        for m in entry_re.finditer(text):
            ts_str, operation, description = m.group(1), m.group(2), m.group(3)
            try:
                ts = datetime.strptime(ts_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            if ts >= cutoff:
                entries.append({"timestamp": ts_str, "operation": operation, "description": description})
                by_operation[operation] = by_operation.get(operation, 0) + 1
    result = {
        "days": days,
        "entry_count": len(entries),
        "by_operation": by_operation,
        "entries": entries,
    }
    print(json.dumps(result, indent=2))
    return 0


def cmd_relocate(args) -> int:
    import shutil
    target = Path(args.path).expanduser().resolve()

    if target == ROOT:
        print(json.dumps({"error": "Target is already the current sage root."}))
        return 1

    if target.exists() and any(target.iterdir()):
        print(json.dumps({"error": f"Target directory exists and is not empty: {target}"}))
        return 1

    # Move the entire current root to the new location
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(ROOT), str(target))
    except Exception as e:
        print(json.dumps({"error": f"Move failed: {e}"}))
        return 1

    # Update config to point to new location
    config = _load_config()
    config["root"] = str(target)
    _save_config(config)

    print(json.dumps({
        "relocated": True,
        "from": str(ROOT),
        "to": str(target),
        "config": str(_CONFIG_FILE),
        "note": "entire sage root moved — takes effect on next sage-operations.py invocation",
    }))
    return 0


# ── secret scanning ──────────────────────────────────────────────────

_SECRET_PATTERNS = [
    (r"sk-[A-Za-z0-9]{20,}", "openai_key"),
    (r"AKIA[0-9A-Z]{16}", "aws_access_key"),
    (r"AIza[0-9A-Za-z\-_]{35}", "google_api_key"),
    (r"ghp_[A-Za-z0-9]{36}", "github_pat"),
    (r"github_pat_[A-Za-z0-9_]{82}", "github_fine_pat"),
    (r"xoxb-[0-9A-Za-z\-]{50,}", "slack_bot_token"),
    (r"-----BEGIN [A-Z ]+PRIVATE KEY-----", "private_key"),
    (r"(?i)(api[_-]?key|apikey)\s*[=:]\s*['\"]?([A-Za-z0-9_\-]{16,})", "api_key"),
    (r"(?i)(password|passwd|pwd)\s*[=:]\s*['\"]([^'\"]{6,})['\"]", "password"),
    (r"(?i)bearer\s+[A-Za-z0-9\-._~+/]{20,}", "bearer_token"),
    (r"anthropic-[A-Za-z0-9_\-]{40,}", "anthropic_key"),
]
_SECRET_RES = [(re.compile(p), t) for p, t in _SECRET_PATTERNS]


def cmd_scan(_args) -> int:
    findings = []
    files_scanned = 0
    if SOURCES_DIR.exists():
        for f in sorted(SOURCES_DIR.rglob("*")):
            if not f.is_file():
                continue
            rel = str(f.relative_to(ROOT)).replace("\\", "/")
            if _is_ignored(rel, INGEST_IGNORE):
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            files_scanned += 1
            for lineno, line in enumerate(text.splitlines(), 1):
                for pattern, label in _SECRET_RES:
                    if pattern.search(line):
                        preview = line.strip()[:80] + ("…" if len(line.strip()) > 80 else "")
                        findings.append({"file": rel, "line": lineno, "type": label, "preview": preview})
                        break
    print(json.dumps({
        "sage_root": str(ROOT),
        "files_scanned": files_scanned,
        "finding_count": len(findings),
        "safe": len(findings) == 0,
        "findings": findings,
    }, indent=2))
    return 0 if not findings else 1


# ── entry point ───────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="sage wiki operations")
    subs = parser.add_subparsers(dest="cmd")

    lint_p = subs.add_parser("lint", help="Run all health checks, output JSON")
    lint_p.add_argument("--fix", action="store_true", help="Auto-apply deterministic fixes")

    subs.add_parser("discover", help="Find raw files not yet ingested")
    subs.add_parser("rebuild-knowledge-graph", help="Regenerate _knowledge-graph.json")
    subs.add_parser("status", help="Quick wiki stats")

    digest_p = subs.add_parser("digest", help="Summarize recent wiki activity")
    digest_p.add_argument("--days", type=int, default=7, help="Lookback window in days")

    trends_p = subs.add_parser("trends", help="Surface topics accumulating sources")
    trends_p.add_argument("--months", type=int, default=12, help="Lookback window in months")

    relocate_p = subs.add_parser("relocate", help="Move sage wiki root to a new directory")
    relocate_p.add_argument("path", help="New root directory path (created if it doesn't exist)")

    subs.add_parser("scan", help="Scan sources/ for secrets and credentials")

    args = parser.parse_args()

    dispatch = {
        "lint": cmd_lint,
        "discover": cmd_discover,
        "rebuild-knowledge-graph": cmd_rebuild_knowledge_graph,
        "status": cmd_status,
        "digest": cmd_digest,
        "trends": cmd_trends,
        "relocate": cmd_relocate,
        "scan": cmd_scan,
    }
    fn = dispatch.get(args.cmd)
    if not fn:
        parser.print_help()
        sys.exit(1)
    sys.exit(fn(args))


if __name__ == "__main__":
    main()
