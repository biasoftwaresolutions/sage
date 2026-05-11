import importlib.util
import sys
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "sage_operations",
    Path(__file__).parent.parent / "scripts" / "sage-operations.py",
)
sage_ops = importlib.util.module_from_spec(_spec)
sys.modules["sage_operations"] = sage_ops
_spec.loader.exec_module(sage_ops)


def _setup_fake_wiki(tmp: Path):
    wiki = tmp / "wiki"
    (wiki / "concepts").mkdir(parents=True)
    (wiki / "sage-memory").mkdir(parents=True)
    (wiki / "concepts" / "llm-agents.md").write_text(
        "---\ntype: concept\ntitle: LLM Agents\n---\n# LLM Agents\n"
    )
    (wiki / "sage-memory" / "SOUL.md").write_text(
        "---\ntype: soul\n---\n# Soul\n"
    )
    (wiki / "sage-memory" / "USER.md").write_text(
        "---\ntype: user\n---\n# User\n"
    )
    return wiki


def test_load_wiki_pages_excludes_sage_memory(monkeypatch, tmp_path):
    wiki = _setup_fake_wiki(tmp_path)
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    pages = sage_ops._load_wiki_pages()
    assert "llm-agents" in pages
    assert "soul" not in pages
    assert "user" not in pages


def test_load_wiki_pages_excludes_heartbeat(monkeypatch, tmp_path):
    wiki = _setup_fake_wiki(tmp_path)
    (wiki / "sage-memory" / "HEARTBEAT.md").write_text("---\ntype: heartbeat\n---\n")
    (wiki / "sage-memory" / "MEMORY.md").write_text("---\ntype: memory\n---\n")
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    pages = sage_ops._load_wiki_pages()
    assert set(pages.keys()) == {"llm-agents"}
