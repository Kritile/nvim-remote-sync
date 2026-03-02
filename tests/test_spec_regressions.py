from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def read(rel):
    return (REPO / rel).read_text(encoding="utf-8")


def test_conflict_prompt_has_required_options():
    watcher = read("lua/sync/watcher.lua")
    assert "Cancel" in watcher
    assert "Overwrite remote" in watcher
    assert "Show diff" in watcher
    assert "BufWritePost" in watcher


def test_reconnect_and_heartbeat_edge_logic_present():
    ssh = read("lua/transport/ssh.lua")
    assert "start_reconnect" in ssh
    assert "reconnect_interval_ms" in ssh
    assert "max_retries" in ssh
    assert "heartbeat" in ssh
    assert "state.update_connection({ status = 'disconnected' })" in ssh


def test_remote_tree_chunked_refresh_for_large_directories():
    tree = read("lua/tui/tree.lua")
    assert "page_size = 200" in tree
    assert "chunked_set_nodes" in tree
    assert "vim.defer_fn(append_next, 5)" in tree
    assert "Keep incremental update scoped to the expanded node" in tree
    assert "[loading %d/%d]" in tree
    assert "__loading__" in tree


def test_removed_legacy_protocol_modules():
    assert not (REPO / "lua/sync/ftp.lua").exists()
    assert not (REPO / "lua/sync/scp.lua").exists()
