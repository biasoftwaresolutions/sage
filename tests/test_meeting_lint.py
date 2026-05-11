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


def _setup_wiki(tmp: Path):
    wiki = tmp / "wiki"
    (wiki / "action-items").mkdir(parents=True)
    (wiki / "meetings").mkdir(parents=True)
    return wiki


def test_action_item_orphan_detected(monkeypatch, tmp_path):
    wiki = _setup_wiki(tmp_path)
    (wiki / "action-items" / "open.md").write_text(
        "# Open Action Items\n\n"
        "## 2026-05-03 — [Product Sync](../meetings/2026-05-03-product-sync.md)\n"
        "- [ ] Ship widget | owner: Alice\n"
    )
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    issues = sage_ops._check_action_item_orphans()
    assert len(issues) == 1
    assert issues[0]["type"] == "action_item_orphan"
    assert issues[0]["slug"] == "2026-05-03-product-sync"


def test_action_item_orphan_not_reported_when_meeting_exists(monkeypatch, tmp_path):
    wiki = _setup_wiki(tmp_path)
    (wiki / "meetings" / "2026-05-03-product-sync.md").write_text(
        "---\ntype: meeting\ntitle: Product Sync\n---\n# Product Sync\n"
    )
    (wiki / "action-items" / "open.md").write_text(
        "# Open Action Items\n\n"
        "## 2026-05-03 — [Product Sync](../meetings/2026-05-03-product-sync.md)\n"
        "- [ ] Ship widget | owner: Alice\n"
    )
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    issues = sage_ops._check_action_item_orphans()
    assert issues == []


def test_action_item_orphan_scans_closed_too(monkeypatch, tmp_path):
    wiki = _setup_wiki(tmp_path)
    (wiki / "action-items" / "open.md").write_text("# Open Action Items\n")
    (wiki / "action-items" / "closed.md").write_text(
        "# Closed Action Items\n\n"
        "## 2026-04-01 — [Old Meeting](../meetings/2026-04-01-old-meeting.md)\n"
        "- [x] Done thing | closed: 2026-04-01\n"
    )
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    issues = sage_ops._check_action_item_orphans()
    assert len(issues) == 1
    assert issues[0]["slug"] == "2026-04-01-old-meeting"
    assert issues[0]["file"] == "action-items/closed.md"


def test_action_item_orphan_no_action_items_dir(monkeypatch, tmp_path):
    wiki = tmp_path / "wiki"
    wiki.mkdir()
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    issues = sage_ops._check_action_item_orphans()
    assert issues == []


def test_action_item_orphan_missing_meetings_dir(monkeypatch, tmp_path):
    wiki = tmp_path / "wiki"
    (wiki / "action-items").mkdir(parents=True)
    (wiki / "action-items" / "open.md").write_text(
        "# Open Action Items\n\n"
        "## 2026-05-03 — [Some Meeting](../meetings/2026-05-03-some-meeting.md)\n"
        "- [ ] Do thing\n"
    )
    monkeypatch.setattr(sage_ops, "WIKI_DIR", wiki)
    issues = sage_ops._check_action_item_orphans()
    assert len(issues) == 1
    assert issues[0]["type"] == "action_item_orphan"
    assert issues[0]["slug"] == "2026-05-03-some-meeting"
    assert issues[0]["file"] == "action-items/open.md"
