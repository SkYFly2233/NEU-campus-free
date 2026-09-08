#!/usr/bin/env python3
"""Small multi-user manager for sing-box Hysteria2/TUIC deployments.

Each managed user receives a dedicated UDP port for each installed protocol.
Linux firewall counters on those ports provide persistent per-user accounting without
depending on the optional sing-box v2ray_api build tag.
"""

from __future__ import annotations

import argparse
import copy
import contextlib
import datetime as dt
import decimal
import http.server
import io
import json
import os
import re
import secrets
import shutil
import socket
import sqlite3
import subprocess
import sys
import urllib.parse
import uuid
from pathlib import Path

try:
    import fcntl
except ImportError:  # Windows unit tests; deployed targets are Linux.
    fcntl = None


WORK_DIR = Path(os.environ.get("SB_WORK_DIR", "/etc/sing-box"))
CONF_DIR = WORK_DIR / "conf"
SUBSCRIBE_DIR = WORK_DIR / "subscribe"
USERS_DIR = WORK_DIR / "users"
DB_PATH = WORK_DIR / "users.db"
SING_BOX = WORK_DIR / "sing-box"
ADMIN_PAGE_PATH = WORK_DIR / "admin-page.html"
WEB_HOST = "127.0.0.1"
WEB_PORT = int(os.environ.get("SB_USER_WEB_PORT", "18081"))
DRY_RUN = os.environ.get("SB_USER_DRY_RUN") == "1"
GIB = 1024 ** 3
PORT_MIN = 30000
PORT_MAX = 39999
TUIC_PORT_MIN = 40000
TUIC_PORT_MAX = 49999
COUNTER_IN = "SBU_IN"
COUNTER_OUT = "SBU_OUT"
COUNTER_PREFIX = "SBU"
MANAGED_CONF_GLOBS = (
    "30_sbuser_*_hysteria2_inbounds.json",
    "31_sbuser_*_tuic_inbounds.json",
)
USERNAME_RE = re.compile(r"^[A-Za-z0-9_-]{1,32}$")
TOKEN_RE = re.compile(r"^[a-f0-9]{64}$")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


class ManagerError(RuntimeError):
    pass


class WebRequestError(ManagerError):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def run(cmd: list[str], *, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    if DRY_RUN:
        return subprocess.CompletedProcess(cmd, 0, "", "")
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture else subprocess.DEVNULL,
    )


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def connect() -> sqlite3.Connection:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(WORK_DIR, 0o755)
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            is_admin INTEGER NOT NULL DEFAULT 0 CHECK (is_admin IN (0, 1)),
            token TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            port INTEGER NOT NULL UNIQUE,
            quota_bytes INTEGER NOT NULL DEFAULT 0 CHECK (quota_bytes >= 0),
            upload_bytes INTEGER NOT NULL DEFAULT 0 CHECK (upload_bytes >= 0),
            download_bytes INTEGER NOT NULL DEFAULT 0 CHECK (download_bytes >= 0),
            last_upload_counter INTEGER NOT NULL DEFAULT 0,
            last_download_counter INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
    )
    columns = {row[1] for row in conn.execute("PRAGMA table_info(users)")}
    if "tuic_port" not in columns:
        conn.execute(
            "ALTER TABLE users ADD COLUMN tuic_port INTEGER NOT NULL DEFAULT 0 CHECK (tuic_port >= 0)"
        )
    conn.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_tuic_port "
        "ON users(tuic_port) WHERE tuic_port > 0"
    )
    conn.commit()
    try:
        os.chmod(DB_PATH, 0o600)
    except FileNotFoundError:
        pass
    return conn


@contextlib.contextmanager
def process_lock():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = WORK_DIR / "sb-user.lock"
    with lock_path.open("a+", encoding="utf-8") as lock_file:
        os.chmod(lock_path, 0o600)
        if fcntl is not None:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        yield


def parse_quota_gb(value: str) -> int:
    try:
        amount = decimal.Decimal(value)
    except decimal.InvalidOperation as exc:
        raise ManagerError("流量额度必须是数字，单位为 GB；0 表示不限量。") from exc
    if not amount.is_finite():
        raise ManagerError("流量额度必须是有限数字，单位为 GB；0 表示不限量。")
    if amount < 0:
        raise ManagerError("流量额度不能小于 0。")
    quota_bytes = int(amount * GIB)
    if quota_bytes > 2 ** 63 - 1:
        raise ManagerError("流量额度过大。")
    return quota_bytes


def fmt_gb(value: int) -> str:
    return f"{value / GIB:.2f} GB"


def usage_status(row: sqlite3.Row, *, compact: bool = False) -> str:
    used = row["upload_bytes"] + row["download_bytes"]
    if not row["enabled"]:
        return f"{row['username']} 已停用 已用{fmt_gb(used)}"
    quota = row["quota_bytes"]
    if quota == 0:
        return f"{row['username']} 已用{fmt_gb(used)} 可用不限量"
    remaining = max(quota - used, 0)
    prefix = "⚠️超额 " if used >= quota else ""
    if compact:
        return f"{prefix}{row['username']} 已用{fmt_gb(used)} 可用{fmt_gb(remaining)} 限额{fmt_gb(quota)}"
    return f"{prefix}{row['username']} 已用{fmt_gb(used)} 剩余{fmt_gb(remaining)} 限额{fmt_gb(quota)}"


def active_users(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM users WHERE enabled=1 ORDER BY id").fetchall()


def all_users(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM users ORDER BY id").fetchall()


def find_base_hy2_config() -> tuple[Path, dict]:
    preferred = CONF_DIR / "12_hysteria2_inbounds.json"
    candidates = [preferred] if preferred.exists() else []
    candidates.extend(
        p for p in sorted(CONF_DIR.glob("*hysteria2_inbounds.json"))
        if p != preferred and not p.name.startswith("30_sbuser_")
    )
    for path in candidates:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            inbound = data.get("inbounds", [])[0]
            if inbound.get("type") == "hysteria2":
                return path, inbound
        except (OSError, json.JSONDecodeError, IndexError, TypeError):
            continue
    raise ManagerError("未找到基础 Hysteria2 入站配置，请先用主脚本安装 Hysteria2。")


def find_base_tuic_config() -> tuple[Path, dict] | None:
    preferred = CONF_DIR / "13_tuic_inbounds.json"
    candidates = [preferred] if preferred.exists() else []
    candidates.extend(
        p for p in sorted(CONF_DIR.glob("*tuic_inbounds.json"))
        if p != preferred and not p.name.startswith("31_sbuser_")
    )
    for path in candidates:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            inbound = data.get("inbounds", [])[0]
            if inbound.get("type") == "tuic":
                return path, inbound
        except (OSError, json.JSONDecodeError, IndexError, TypeError):
            continue
    return None


def base_proxy_lines() -> list[str]:
    path = SUBSCRIBE_DIR / "proxies"
    if not path.exists():
        raise ManagerError("未找到 subscribe/proxies，请先启用订阅并生成节点信息。")
    result = [
        line for line in path.read_text(encoding="utf-8").splitlines()
        if ("type: hysteria2" in line or "type: tuic" in line)
        and line.lstrip().startswith("-")
    ]
    if not any("type: hysteria2" in line for line in result):
        raise ManagerError("基础订阅中没有 Hysteria2 节点。")
    if find_base_tuic_config() is not None and not any("type: tuic" in line for line in result):
        raise ManagerError("已安装 TUIC，但基础订阅中没有 TUIC 节点。")
    return result


def base_hy2_proxy_lines() -> list[str]:
    return [line for line in base_proxy_lines() if "type: hysteria2" in line]


def subscription_base_url_state_path() -> Path:
    """Return the root-only state file written by the installer.

    Strict multi-user installations intentionally have no public subscription
    URL, so the manager must not try to reconstruct its own address from an
    externally reachable subscription path.
    """
    return USERS_DIR / "subscription-base-url"


def subscription_base_url() -> str:
    state_path = subscription_base_url_state_path()
    if state_path.exists():
        value = state_path.read_text(encoding="utf-8", errors="strict").strip().rstrip("/")
        if re.fullmatch(r"https?://(?:\[[^]/\s]+\]|[A-Za-z0-9.-]+)(?::[0-9]{1,5})?", value):
            return value
        raise ManagerError(f"订阅服务器地址状态文件无效：{state_path}")

    # Compatibility with installations created before strict multi-user mode.
    sources = [WORK_DIR / "list", SUBSCRIBE_DIR / "clash-campus-free", SUBSCRIBE_DIR / "clash"]
    patterns = [
        re.compile(r"(https?://(?:\[[^]]+\]|[^/\s]+?)(?::\d+)?)/[^/\s]+/clash-campus-free"),
        re.compile(r"url:\s*(https?://(?:\[[^]]+\]|[^/\s]+?)(?::\d+)?)/[^/\s]+/proxies"),
    ]
    for path in sources:
        if not path.exists():
            continue
        text = ANSI_RE.sub("", path.read_text(encoding="utf-8", errors="ignore"))
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                return match.group(1).rstrip("/")
    raise ManagerError("无法从现有订阅文件确定订阅服务器地址。请先运行主脚本查看节点信息。")


def atomic_write(path: Path, content: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(content, encoding="utf-8")
    os.chmod(temp, mode)
    os.replace(temp, path)


def yaml_quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def tuic_uuid(row: sqlite3.Row) -> str:
    """Derive a stable non-secret TUIC UUID from the rotatable user password."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"sb-user-tuic:{row['password']}"))


def customize_proxy_line(line: str, row: sqlite3.Row, name: str) -> str:
    updated = re.sub(r'name:\s*"[^"]*"', f"name: {yaml_quote(name)}", line, count=1)
    if "type: tuic" in line:
        if not row["tuic_port"]:
            raise ManagerError(f"用户 {row['username']} 尚未分配 TUIC 端口。")
        updated = re.sub(r"port:\s*[0-9]+", f"port: {row['tuic_port']}", updated, count=1)
        updated = re.sub(r"uuid:\s*[^,}]+", f"uuid: {yaml_quote(tuic_uuid(row))}", updated, count=1)
    else:
        updated = re.sub(r"port:\s*[0-9]+", f"port: {row['port']}", updated, count=1)
    updated = re.sub(r"password:\s*[^,}]+", f"password: {yaml_quote(row['password'])}", updated, count=1)
    updated = re.sub(r",?\s*ports:\s*[^,]+,\s*hop-interval:\s*[^,]+", "", updated, count=1)
    updated = re.sub(r",\s*realm-opts:\s*\{.*\}(?=\})", "", updated, count=1)
    return updated


def user_proxy_lines(row: sqlite3.Row, everyone: list[sqlite3.Row]) -> list[str]:
    base_lines = base_proxy_lines()
    result = []
    for index, line in enumerate(base_lines, 1):
        match = re.search(r'name:\s*"([^"]*)"', line)
        protocol = "TUIC" if "type: tuic" in line else "Hysteria2"
        original_name = match.group(1) if match else f"{protocol} #{index}"
        # 真实节点只保留正常名称。流量信息单独放入一个不参与测速或分流的代理组。
        result.append(customize_proxy_line(line, row, original_name))
    return result


def usage_proxy_name(row: sqlite3.Row) -> str:
    """Return one display-only proxy name for one visible user's usage."""
    role = "管理员" if row["is_admin"] else "用户"
    return f"📊 {role} {usage_status(row, compact=True)}"


def add_usage_proxy_group(config: str, row: sqlite3.Row, everyone: list[sqlite3.Row]) -> str:
    """Insert one fixed usage group backed only by local direct display items."""
    visible_users = everyone if row["is_admin"] else [row]
    names = [usage_proxy_name(item) for item in visible_users]
    display_proxies = "".join(
        f"  - name: {yaml_quote(name)}\n"
        "    type: direct\n"
        "    udp: true\n"
        for name in names
    )
    group = (
        f"  - name: {yaml_quote('📊 整体流量检测')}\n"
        "    type: select\n"
        "    proxies:\n"
        + "".join(f"      - {yaml_quote(name)}\n" for name in names)
    )
    updated, proxies_count = re.subn(
        r"(?m)^proxies:[ \t]*$", f"proxies:\n{display_proxies}", config, count=1
    )
    if proxies_count != 1:
        raise ManagerError("订阅模板缺少 proxies，无法加入流量信息展示项。")
    updated, groups_count = re.subn(
        r"(?m)^proxy-groups:[ \t]*$", f"proxy-groups:\n{group}", updated, count=1
    )
    if groups_count != 1:
        raise ManagerError("订阅模板缺少 proxy-groups，无法加入流量信息代理组。")
    return updated


def render_subscriptions(conn: sqlite3.Connection) -> None:
    template_path = SUBSCRIBE_DIR / "clash-campus-free"
    if not template_path.exists():
        raise ManagerError("未找到 clash-campus-free 模板，请先启用订阅。")
    ensure_tuic_ports(conn)
    template = template_path.read_text(encoding="utf-8")
    base_url = subscription_base_url()
    everyone = all_users(conn)
    USERS_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(USERS_DIR, 0o700)
    valid_tokens = {row["token"] for row in everyone}

    for entry in USERS_DIR.iterdir():
        if entry.is_dir() and TOKEN_RE.fullmatch(entry.name) and entry.name not in valid_tokens:
            shutil.rmtree(entry)

    for row in everyone:
        user_dir = USERS_DIR / row["token"]
        user_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(user_dir, 0o700)
        provider_url = f"{base_url}/user/{row['token']}/proxies"
        config = re.sub(
            r"(?m)^(\s*url:\s*)\S+/proxies\s*$",
            lambda match: f"{match.group(1)}{provider_url}",
            template,
        )
        config = re.sub(r"(?m)^(\s*interval:)\s*3600\s*$", r"\1 300", config)
        config = add_usage_proxy_group(config, row, everyone)
        proxies = "proxies:\n" + "\n".join(user_proxy_lines(row, everyone)) + "\n"
        atomic_write(user_dir / "clash-campus-free", config)
        atomic_write(user_dir / "proxies", proxies)


def render_inbounds(conn: sqlite3.Connection) -> None:
    _, base = find_base_hy2_config()
    tuic_base_result = find_base_tuic_config()
    tuic_base = tuic_base_result[1] if tuic_base_result is not None else None
    expected: set[Path] = set()
    for row in active_users(conn):
        inbound = copy.deepcopy(base)
        inbound["tag"] = f"sb-user-{row['id']}-{row['username']}"
        # The base inbound is kept on loopback as an internal template in
        # strict mode.  Managed users must explicitly listen on the public
        # dual-stack address; omitting `listen` makes sing-box use loopback.
        inbound["listen"] = "::"
        inbound["listen_port"] = row["port"]
        inbound["users"] = [{"name": row["username"], "password": row["password"]}]
        inbound.pop("realm", None)
        target = CONF_DIR / f"30_sbuser_{row['id']}_hysteria2_inbounds.json"
        expected.add(target)
        atomic_write(target, json.dumps({"inbounds": [inbound]}, ensure_ascii=False, indent=2) + "\n")
        if tuic_base is not None:
            tuic_inbound = copy.deepcopy(tuic_base)
            tuic_inbound["tag"] = f"sb-user-tuic-{row['id']}-{row['username']}"
            tuic_inbound["listen"] = "::"
            tuic_inbound["listen_port"] = row["tuic_port"]
            tuic_inbound["users"] = [{
                "name": row["username"],
                "uuid": tuic_uuid(row),
                "password": row["password"],
            }]
            tuic_target = CONF_DIR / f"31_sbuser_{row['id']}_tuic_inbounds.json"
            expected.add(tuic_target)
            atomic_write(
                tuic_target,
                json.dumps({"inbounds": [tuic_inbound]}, ensure_ascii=False, indent=2) + "\n",
            )
    for pattern in MANAGED_CONF_GLOBS:
        for path in CONF_DIR.glob(pattern):
            if path not in expected:
                path.unlink(missing_ok=True)


def lock_base_inbound(protocol: str) -> None:
    """Make an original protocol inbound an internal-only template.

    This invalidates cached legacy public nodes: user-specific inbounds are
    the only managed protocol endpoints reachable from the Internet.
    """
    if protocol == "hysteria2":
        path, inbound = find_base_hy2_config()
    else:
        result = find_base_tuic_config()
        if result is None:
            return
        path, inbound = result
    if inbound.get("listen") == "127.0.0.1":
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    for candidate in data.get("inbounds", []):
        if candidate.get("type") == protocol and candidate.get("tag") == inbound.get("tag"):
            candidate["listen"] = "127.0.0.1"
            atomic_write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
            return
    raise ManagerError(f"无法锁定基础 {protocol} 入站：{path}")


def lock_base_hy2_inbound() -> None:
    lock_base_inbound("hysteria2")


def lock_base_tuic_inbound() -> None:
    lock_base_inbound("tuic")


def is_port_available(port: int) -> bool:
    with socket.socket(socket.AF_INET6, socket.SOCK_DGRAM) as sock:
        try:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
            sock.bind(("::", port))
            return True
        except OSError:
            return False


def allocate_port(conn: sqlite3.Connection) -> int:
    used = {
        value
        for row in conn.execute("SELECT port,tuic_port FROM users")
        for value in row
        if value
    }
    for port in range(PORT_MIN, PORT_MAX + 1):
        if port not in used and is_port_available(port):
            return port
    raise ManagerError(f"{PORT_MIN}-{PORT_MAX} 范围内没有可用 UDP 端口。")


def allocate_tuic_port(conn: sqlite3.Connection) -> int:
    used = {
        value
        for row in conn.execute("SELECT port,tuic_port FROM users")
        for value in row
        if value
    }
    for port in range(TUIC_PORT_MIN, TUIC_PORT_MAX + 1):
        if port not in used and is_port_available(port):
            return port
    raise ManagerError(f"{TUIC_PORT_MIN}-{TUIC_PORT_MAX} 范围内没有可用 TUIC UDP 端口。")


def ensure_tuic_ports(conn: sqlite3.Connection) -> bool:
    """Allocate TUIC ports lazily so existing Hysteria2-only databases migrate safely."""
    if find_base_tuic_config() is None:
        return False
    changed = False
    for row in conn.execute("SELECT * FROM users WHERE tuic_port=0 ORDER BY id").fetchall():
        conn.execute(
            "UPDATE users SET tuic_port=?,updated_at=? WHERE id=?",
            (allocate_tuic_port(conn), now_iso(), row["id"]),
        )
        changed = True
    if changed:
        conn.commit()
    return True


def user_ports(row: sqlite3.Row, *, include_stale_tuic: bool = False) -> list[int]:
    ports = [row["port"]]
    if row["tuic_port"] and (include_stale_tuic or find_base_tuic_config() is not None):
        ports.append(row["tuic_port"])
    return ports


def firewall_backend() -> str:
    if command_exists("ufw"):
        result = run(["ufw", "status"], check=False, capture=True)
        if re.search(r"^Status:\s+active", result.stdout, re.MULTILINE | re.IGNORECASE):
            return "ufw"
    if command_exists("firewall-cmd"):
        result = run(["firewall-cmd", "--state"], check=False, capture=True)
        if result.returncode == 0:
            return "firewalld"
    return "iptables"


def firewall_open(port: int) -> None:
    if DRY_RUN:
        return
    backend = firewall_backend()
    if backend == "ufw":
        run(["ufw", "allow", f"{port}/udp", "comment", f"Sing-box multi-user {port}"], check=False)
    elif backend == "firewalld":
        run(["firewall-cmd", "--zone=public", f"--add-port={port}/udp", "--permanent"], check=False)
        run(["firewall-cmd", "--reload"], check=False)
    else:
        for tool in ("iptables", "ip6tables"):
            if not command_exists(tool):
                continue
            comment = f"Sing-box multi-user {port}"
            rule = ["INPUT", "-p", "udp", "--dport", str(port), "-m", "comment", "--comment", comment, "-j", "ACCEPT"]
            if run([tool, "-C", *rule], check=False).returncode != 0:
                run([tool, "-A", *rule], check=False)


def firewall_close(port: int) -> None:
    if DRY_RUN:
        return
    backend = firewall_backend()
    if backend == "ufw":
        run(["ufw", "--force", "delete", "allow", f"{port}/udp"], check=False)
    elif backend == "firewalld":
        run(["firewall-cmd", "--zone=public", f"--remove-port={port}/udp", "--permanent"], check=False)
        run(["firewall-cmd", "--reload"], check=False)
    else:
        for tool in ("iptables", "ip6tables"):
            if not command_exists(tool):
                continue
            comment = f"Sing-box multi-user {port}"
            rule = ["INPUT", "-p", "udp", "--dport", str(port), "-m", "comment", "--comment", comment, "-j", "ACCEPT"]
            while run([tool, "-C", *rule], check=False).returncode == 0:
                run([tool, "-D", *rule], check=False)


def ensure_chain(tool: str, chain: str, hook: str) -> None:
    if not command_exists(tool):
        return
    if run([tool, "-nL", chain], check=False).returncode != 0:
        run([tool, "-N", chain])
    if run([tool, "-C", hook, "-j", chain], check=False).returncode != 0:
        run([tool, "-I", hook, "1", "-j", chain])
    run([tool, "-F", chain])


def sync_counter_rules(conn: sqlite3.Connection) -> None:
    users = active_users(conn)
    for tool in ("iptables", "ip6tables"):
        if not command_exists(tool):
            continue
        ensure_chain(tool, COUNTER_IN, "INPUT")
        ensure_chain(tool, COUNTER_OUT, "OUTPUT")
        for row in users:
            for port in user_ports(row):
                run([
                    tool, "-A", COUNTER_IN, "-p", "udp", "--dport", str(port),
                    "-m", "comment", "--comment", f"{COUNTER_PREFIX}:{row['id']}:up", "-j", "RETURN",
                ])
                run([
                    tool, "-A", COUNTER_OUT, "-p", "udp", "--sport", str(port),
                    "-m", "comment", "--comment", f"{COUNTER_PREFIX}:{row['id']}:down", "-j", "RETURN",
                ])
    conn.execute("UPDATE users SET last_upload_counter=0, last_download_counter=0 WHERE enabled=1")
    conn.commit()


def remove_counter_rules() -> None:
    for tool in ("iptables", "ip6tables"):
        if not command_exists(tool):
            continue
        for hook, chain in (("INPUT", COUNTER_IN), ("OUTPUT", COUNTER_OUT)):
            while run([tool, "-C", hook, "-j", chain], check=False).returncode == 0:
                run([tool, "-D", hook, "-j", chain], check=False)
            run([tool, "-F", chain], check=False)
            run([tool, "-X", chain], check=False)


def read_counters() -> tuple[dict[int, dict[str, int]], set[tuple[int, str]]]:
    totals: dict[int, dict[str, int]] = {}
    seen: set[tuple[int, str]] = set()
    pattern = re.compile(r"^\[[0-9]+:([0-9]+)\].*--comment\s+\"?SBU:([0-9]+):(up|down)\"?")
    for tool in ("iptables-save", "ip6tables-save"):
        if not command_exists(tool):
            continue
        result = run([tool, "-c", "-t", "filter"], check=False, capture=True)
        for line in result.stdout.splitlines():
            match = pattern.search(line)
            if not match:
                continue
            count, user_id, direction = int(match.group(1)), int(match.group(2)), match.group(3)
            totals.setdefault(user_id, {"up": 0, "down": 0})[direction] += count
            seen.add((user_id, direction))
    return totals, seen


def collect_usage(conn: sqlite3.Connection, *, render: bool = True) -> None:
    counters, seen = read_counters()
    users = active_users(conn)
    for row in users:
        current = counters.get(row["id"], {"up": 0, "down": 0})
        old_up = row["last_upload_counter"]
        old_down = row["last_download_counter"]
        delta_up = current["up"] - old_up if current["up"] >= old_up else current["up"]
        delta_down = current["down"] - old_down if current["down"] >= old_down else current["down"]
        conn.execute(
            """UPDATE users SET upload_bytes=upload_bytes+?, download_bytes=download_bytes+?,
               last_upload_counter=?, last_download_counter=?, updated_at=? WHERE id=?""",
            (delta_up, delta_down, current["up"], current["down"], now_iso(), row["id"]),
        )
    conn.commit()
    expected = {(row["id"], direction) for row in users for direction in ("up", "down")}
    if not expected.issubset(seen):
        for row in users:
            for port in user_ports(row):
                firewall_open(port)
        sync_counter_rules(conn)
    if render and all_users(conn):
        render_subscriptions(conn)


def validate_and_reload() -> None:
    if DRY_RUN:
        return
    result = run([str(SING_BOX), "check", "-C", str(CONF_DIR)], check=False, capture=True)
    if result.returncode != 0:
        raise ManagerError(f"sing-box 配置检查失败：\n{result.stderr.strip()}")
    if command_exists("systemctl"):
        result = run(["systemctl", "reload", "sing-box"], check=False)
        if result.returncode != 0:
            run(["systemctl", "restart", "sing-box"])
    else:
        result = run(["rc-service", "sing-box", "reload"], check=False)
        if result.returncode != 0:
            run(["rc-service", "sing-box", "restart"])


def apply_runtime(conn: sqlite3.Connection, removed_ports: list[int] | None = None) -> None:
    ensure_tuic_ports(conn)
    render_inbounds(conn)
    render_subscriptions(conn)
    validate_and_reload()
    for port in removed_ports or []:
        firewall_close(port)
    for row in active_users(conn):
        for port in user_ports(row):
            firewall_open(port)
    sync_counter_rules(conn)


def get_user(conn: sqlite3.Connection, username: str) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
    if row is None:
        raise ManagerError(f"用户不存在：{username}")
    return row


def user_link(row: sqlite3.Row) -> str:
    return f"{subscription_base_url()}/user/{row['token']}/clash-campus-free"


def admin_page_link(row: sqlite3.Row) -> str:
    return f"{subscription_base_url()}/user/{row['token']}/page"


def cmd_init(conn: sqlite3.Connection, _args: argparse.Namespace) -> None:
    find_base_hy2_config()
    base_proxy_lines()
    subscription_base_url()
    ensure_tuic_ports(conn)
    lock_base_hy2_inbound()
    lock_base_tuic_inbound()
    if not DRY_RUN and not command_exists("iptables-save"):
        raise ManagerError("未找到 iptables-save，无法进行按用户流量统计。")
    USERS_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(USERS_DIR, 0o700)
    if all_users(conn):
        render_inbounds(conn)
        render_subscriptions(conn)
    for row in active_users(conn):
        for port in user_ports(row):
            firewall_open(port)
    sync_counter_rules(conn)
    validate_and_reload()
    print(f"多用户数据库已就绪：{DB_PATH}")


def cmd_add(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    if not USERNAME_RE.fullmatch(args.username):
        raise ManagerError("用户名只能包含字母、数字、下划线和连字符，长度 1-32。")
    collect_usage(conn)
    is_admin = 1 if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0 else 0
    stamp = now_iso()
    try:
        conn.execute(
            """INSERT INTO users
               (username,is_admin,token,password,port,quota_bytes,created_at,updated_at)
               VALUES (?,?,?,?,?,?,?,?)""",
            (
                args.username,
                is_admin,
                secrets.token_hex(32),
                secrets.token_hex(32),
                allocate_port(conn),
                parse_quota_gb(args.quota_gb),
                stamp,
                stamp,
            ),
        )
        conn.commit()
    except sqlite3.IntegrityError as exc:
        raise ManagerError(f"用户已存在或随机凭据发生冲突：{args.username}") from exc
    apply_runtime(conn)
    row = get_user(conn, args.username)
    print(f"用户：{row['username']} ({'管理员' if row['is_admin'] else '普通用户'})")
    print(f"Hysteria2 端口：{row['port']}/udp")
    if row["tuic_port"]:
        print(f"TUIC 端口：{row['tuic_port']}/udp")
        print(f"TUIC UUID：{tuic_uuid(row)}")
    print(f"协议密码：{row['password']}")
    print(f"额度：{'不限量' if row['quota_bytes'] == 0 else fmt_gb(row['quota_bytes'])}")
    print(f"订阅：{user_link(row)}")
    if row["is_admin"]:
        print(f"管理网页：{admin_page_link(row)}")


def print_user(row: sqlite3.Row, *, include_secret: bool = False) -> None:
    used = row["upload_bytes"] + row["download_bytes"]
    quota = "不限量" if row["quota_bytes"] == 0 else fmt_gb(row["quota_bytes"])
    remaining = "不限量" if row["quota_bytes"] == 0 else fmt_gb(max(row["quota_bytes"] - used, 0))
    state = "启用"
    if not row["enabled"]:
        state = "停用"
    elif row["quota_bytes"] and used >= row["quota_bytes"]:
        state = "已超额（仅提示）"
    protocol_ports = f"Hysteria2 {row['port']}"
    if row["tuic_port"] and find_base_tuic_config() is not None:
        protocol_ports += f" / TUIC {row['tuic_port']}"
    print(
        f"{row['id']:>3}  {row['username']:<16}  {'管理员' if row['is_admin'] else '用户':<4}  "
        f"{state:<12}  端口 {protocol_ports}  上传 {fmt_gb(row['upload_bytes'])}  "
        f"下载 {fmt_gb(row['download_bytes'])}  已用 {fmt_gb(used)}  可用 {remaining}  限额 {quota}"
    )
    if include_secret:
        print(f"     协议密码：{row['password']}")
        if row["tuic_port"] and find_base_tuic_config() is not None:
            print(f"     TUIC UUID：{tuic_uuid(row)}")
        print(f"     订阅：{user_link(row)}")
        if row["is_admin"]:
            print(f"     管理网页：{admin_page_link(row)}")


def cmd_list(conn: sqlite3.Connection, _args: argparse.Namespace) -> None:
    collect_usage(conn)
    rows = all_users(conn)
    if not rows:
        print("还没有用户。第一个创建的用户将成为管理员。")
        return
    for row in rows:
        print_user(row)
    total_up = sum(row["upload_bytes"] for row in rows)
    total_down = sum(row["download_bytes"] for row in rows)
    print(f"总计：用户 {len(rows)}，上传 {fmt_gb(total_up)}，下载 {fmt_gb(total_down)}，已用 {fmt_gb(total_up + total_down)}")


def cmd_show(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    collect_usage(conn)
    print_user(get_user(conn, args.username), include_secret=True)


def cmd_quota(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    collect_usage(conn)
    row = get_user(conn, args.username)
    conn.execute("UPDATE users SET quota_bytes=?,updated_at=? WHERE id=?", (parse_quota_gb(args.quota_gb), now_iso(), row["id"]))
    conn.commit()
    render_subscriptions(conn)
    print_user(get_user(conn, args.username))


def cmd_reset(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    collect_usage(conn, render=False)
    row = get_user(conn, args.username)
    conn.execute(
        """UPDATE users SET upload_bytes=0,download_bytes=0,
           last_upload_counter=0,last_download_counter=0,updated_at=? WHERE id=?""",
        (now_iso(), row["id"]),
    )
    conn.commit()
    sync_counter_rules(conn)
    render_subscriptions(conn)
    print(f"已清零用户 {args.username} 的上传和下载累计流量。")


def cmd_toggle(conn: sqlite3.Connection, args: argparse.Namespace, enabled: bool) -> None:
    collect_usage(conn, render=False)
    row = get_user(conn, args.username)
    conn.execute("UPDATE users SET enabled=?,updated_at=? WHERE id=?", (1 if enabled else 0, now_iso(), row["id"]))
    conn.commit()
    apply_runtime(conn, removed_ports=None if enabled else user_ports(row, include_stale_tuic=True))
    print(f"用户 {args.username} 已{'启用' if enabled else '停用'}。")


def cmd_delete(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    if not args.yes:
        raise ManagerError("删除用户会使其凭据和订阅失效；请追加 --yes 确认。")
    collect_usage(conn, render=False)
    row = get_user(conn, args.username)
    if row["is_admin"]:
        successor = conn.execute("SELECT id FROM users WHERE id<>? ORDER BY id LIMIT 1", (row["id"],)).fetchone()
        if successor is not None:
            conn.execute("UPDATE users SET is_admin=1,updated_at=? WHERE id=?", (now_iso(), successor["id"]))
    conn.execute("DELETE FROM users WHERE id=?", (row["id"],))
    conn.commit()
    apply_runtime(conn, removed_ports=user_ports(row, include_stale_tuic=True))
    print(f"用户 {args.username} 已删除。")


def cmd_rotate(conn: sqlite3.Connection, args: argparse.Namespace, field: str) -> None:
    collect_usage(conn, render=False)
    row = get_user(conn, args.username)
    value = secrets.token_hex(32)
    conn.execute(f"UPDATE users SET {field}=?,updated_at=? WHERE id=?", (value, now_iso(), row["id"]))
    conn.commit()
    if field == "password":
        apply_runtime(conn)
        print(f"用户 {args.username} 的 Hysteria2/TUIC 密码已轮换，旧节点立即失效。")
    else:
        render_subscriptions(conn)
        print(f"用户 {args.username} 的订阅令牌已轮换，旧订阅 URL 立即失效。")
    print_user(get_user(conn, args.username), include_secret=True)


def cmd_collect(conn: sqlite3.Connection, _args: argparse.Namespace) -> None:
    collect_usage(conn)


def cmd_render(conn: sqlite3.Connection, _args: argparse.Namespace) -> None:
    collect_usage(conn, render=False)
    apply_runtime(conn)
    print("用户配置、订阅、端口和计数规则已重新生成。")


def cmd_cleanup(conn: sqlite3.Connection, _args: argparse.Namespace) -> None:
    collect_usage(conn, render=False)
    for row in all_users(conn):
        for port in user_ports(row, include_stale_tuic=True):
            firewall_close(port)
    remove_counter_rules()


def web_user_payload(row: sqlite3.Row) -> dict[str, object]:
    used = row["upload_bytes"] + row["download_bytes"]
    quota = row["quota_bytes"]
    return {
        "username": row["username"],
        "is_admin": bool(row["is_admin"]),
        "enabled": bool(row["enabled"]),
        "hysteria2_port": row["port"],
        "tuic_port": row["tuic_port"],
        "upload_bytes": row["upload_bytes"],
        "download_bytes": row["download_bytes"],
        "used_bytes": used,
        "quota_bytes": quota,
        "remaining_bytes": max(quota - used, 0) if quota else 0,
        "quota_gb": round(quota / GIB, 6),
        "subscription": user_link(row),
    }


def web_users_payload(conn: sqlite3.Connection, admin: sqlite3.Row) -> dict[str, object]:
    collect_usage(conn)
    rows = all_users(conn)
    total_up = sum(row["upload_bytes"] for row in rows)
    total_down = sum(row["download_bytes"] for row in rows)
    return {
        "admin": admin["username"],
        "refreshed_at": now_iso(),
        "totals": {
            "user_count": len(rows),
            "upload_bytes": total_up,
            "download_bytes": total_down,
            "used_bytes": total_up + total_down,
        },
        "users": [web_user_payload(row) for row in rows],
    }


class SbUserWebServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


class AdminWebHandler(http.server.BaseHTTPRequestHandler):
    server_version = "sb-user-admin"
    sys_version = ""
    max_body_bytes = 4096
    route_re = re.compile(r"^/user/([a-f0-9]{64})/(page|api(?:/.*)?)$")

    def log_message(self, _format: str, *_args: object) -> None:
        # URL paths contain administrator credentials. Never copy them to logs.
        return

    def _security_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
            "connect-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'self'; "
            "frame-ancestors 'none'",
        )

    def _send_bytes(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self._security_headers()
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_json(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self._send_bytes(status, body, "application/json; charset=utf-8")

    def _error(self, status: int, message: str) -> None:
        self._send_json(status, {"error": message})

    def _route(self) -> tuple[str, str]:
        path = urllib.parse.urlsplit(self.path).path
        match = self.route_re.fullmatch(path)
        if match is None:
            raise WebRequestError(404, "页面或接口不存在。")
        return match.group(1), match.group(2)

    def _authenticate(self, conn: sqlite3.Connection, token: str) -> sqlite3.Row:
        row = conn.execute("SELECT * FROM users WHERE token=?", (token,)).fetchone()
        if row is None or not row["is_admin"]:
            raise WebRequestError(403, "管理员令牌无效或无权访问。")
        return row

    def _json_body(self) -> dict[str, object]:
        self._require_write_headers()
        raw_length = self.headers.get("Content-Length")
        try:
            length = int(raw_length or "")
        except ValueError as exc:
            raise WebRequestError(400, "请求长度无效。") from exc
        if length < 0 or length > self.max_body_bytes:
            raise WebRequestError(413, "请求内容过大。")
        try:
            data = json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            raise WebRequestError(400, "JSON 内容无效。") from exc
        if not isinstance(data, dict):
            raise WebRequestError(400, "JSON 顶层必须是对象。")
        return data

    def _require_write_headers(self) -> None:
        if self.headers.get("X-SB-Admin") != "1":
            raise WebRequestError(403, "缺少管理操作确认标头。")
        if not self.headers.get("Content-Type", "").lower().startswith("application/json"):
            raise WebRequestError(415, "请求内容必须是 JSON。")

    @contextlib.contextmanager
    def _admin_connection(self, token: str):
        with process_lock():
            with contextlib.closing(connect()) as conn:
                yield conn, self._authenticate(conn, token)

    @staticmethod
    def _quiet_call(function, conn: sqlite3.Connection, args: argparse.Namespace, *extra: object) -> None:
        with contextlib.redirect_stdout(io.StringIO()):
            function(conn, args, *extra)

    @staticmethod
    def _web_user(conn: sqlite3.Connection, username: str) -> sqlite3.Row:
        if not USERNAME_RE.fullmatch(username):
            raise WebRequestError(400, "用户名格式无效。")
        row = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        if row is None:
            raise WebRequestError(404, "用户不存在。")
        return row

    def _dispatch(self) -> None:
        token, resource = self._route()
        if self.command == "GET" and resource == "page":
            with self._admin_connection(token):
                if not ADMIN_PAGE_PATH.is_file():
                    raise WebRequestError(503, "管理员页面尚未安装。")
                self._send_bytes(200, ADMIN_PAGE_PATH.read_bytes(), "text/html; charset=utf-8")
            return

        if resource == "api/users" and self.command == "GET":
            with self._admin_connection(token) as (conn, admin):
                self._send_json(200, web_users_payload(conn, admin))
            return

        if resource == "api/users" and self.command == "POST":
            data = self._json_body()
            username = data.get("username")
            quota_gb = data.get("quota_gb")
            if not isinstance(username, str) or not USERNAME_RE.fullmatch(username):
                raise WebRequestError(400, "用户名只能包含字母、数字、下划线和连字符，长度 1-32。")
            if isinstance(quota_gb, bool) or not isinstance(quota_gb, (str, int, float)):
                raise WebRequestError(400, "流量额度必须是数字，单位为 GB。")
            with self._admin_connection(token) as (conn, _admin):
                if conn.execute("SELECT 1 FROM users WHERE username=?", (username,)).fetchone():
                    raise WebRequestError(409, "用户已存在。")
                self._quiet_call(cmd_add, conn, argparse.Namespace(username=username, quota_gb=str(quota_gb)))
            self._send_json(201, {"ok": True})
            return

        match = re.fullmatch(r"api/users/([^/]+)/(quota|status)", resource)
        if match and self.command == "PATCH":
            username = urllib.parse.unquote(match.group(1))
            operation = match.group(2)
            data = self._json_body()
            with self._admin_connection(token) as (conn, _admin):
                row = self._web_user(conn, username)
                if operation == "quota":
                    quota_gb = data.get("quota_gb")
                    if isinstance(quota_gb, bool) or not isinstance(quota_gb, (str, int, float)):
                        raise WebRequestError(400, "流量额度必须是数字，单位为 GB。")
                    self._quiet_call(cmd_quota, conn, argparse.Namespace(username=username, quota_gb=str(quota_gb)))
                else:
                    enabled = data.get("enabled")
                    if not isinstance(enabled, bool):
                        raise WebRequestError(400, "enabled 必须是布尔值。")
                    if row["is_admin"]:
                        raise WebRequestError(403, "不能在网页中停用管理员。")
                    self._quiet_call(cmd_toggle, conn, argparse.Namespace(username=username), enabled)
            self._send_json(200, {"ok": True})
            return

        match = re.fullmatch(r"api/users/([^/]+)", resource)
        if match and self.command == "DELETE":
            self._require_write_headers()
            username = urllib.parse.unquote(match.group(1))
            with self._admin_connection(token) as (conn, _admin):
                row = self._web_user(conn, username)
                if row["is_admin"]:
                    raise WebRequestError(403, "不能删除当前管理员。")
                self._quiet_call(cmd_delete, conn, argparse.Namespace(username=username, yes=True))
            self._send_json(200, {"ok": True})
            return

        raise WebRequestError(404, "页面或接口不存在。")

    def _handle(self) -> None:
        try:
            self._dispatch()
        except WebRequestError as exc:
            self._error(exc.status, str(exc))
        except ManagerError as exc:
            self._error(400, str(exc))
        except (OSError, sqlite3.Error, subprocess.SubprocessError):
            self._error(500, "服务器处理请求失败。请查看 sb-user-web 服务日志。")

    do_GET = _handle
    do_POST = _handle
    do_PATCH = _handle
    do_DELETE = _handle


def create_web_server(port: int = WEB_PORT, host: str = WEB_HOST) -> SbUserWebServer:
    return SbUserWebServer((host, port), AdminWebHandler)


def cmd_web(args: argparse.Namespace) -> None:
    if not 1 <= args.port <= 65535:
        raise ManagerError("网页服务端口必须在 1-65535 之间。")
    if not ADMIN_PAGE_PATH.is_file():
        raise ManagerError(f"管理员页面文件不存在：{ADMIN_PAGE_PATH}")
    with contextlib.closing(connect()):
        pass
    server = create_web_server(args.port)
    print(f"管理员网页服务正在监听 {WEB_HOST}:{args.port}", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="sb-user", description="sing-box Hysteria2/TUIC 多用户与流量管理")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init", help="初始化数据库与计数规则")
    add = sub.add_parser("add", help="创建用户；第一个用户自动成为管理员")
    add.add_argument("username")
    add.add_argument("quota_gb", help="流量额度，单位 GB；0 表示不限量")
    sub.add_parser("list", help="列出全部用户和总流量")
    show = sub.add_parser("show", help="查看用户、密码和订阅 URL")
    show.add_argument("username")
    quota = sub.add_parser("quota", help="修改用户流量额度")
    quota.add_argument("username")
    quota.add_argument("quota_gb")
    reset = sub.add_parser("reset", help="清零用户累计流量")
    reset.add_argument("username")
    enable = sub.add_parser("enable", help="启用用户")
    enable.add_argument("username")
    disable = sub.add_parser("disable", help="停用用户")
    disable.add_argument("username")
    delete = sub.add_parser("delete", help="删除用户")
    delete.add_argument("username")
    delete.add_argument("--yes", action="store_true")
    rotate_token = sub.add_parser("rotate-token", help="轮换订阅 URL")
    rotate_token.add_argument("username")
    rotate_password = sub.add_parser("rotate-password", help="轮换 Hysteria2/TUIC 密码")
    rotate_password.add_argument("username")
    sub.add_parser("collect", help=argparse.SUPPRESS)
    sub.add_parser("cleanup", help=argparse.SUPPRESS)
    sub.add_parser("render", help="重建全部用户配置")
    web = sub.add_parser("web", help="运行仅限本机访问的管理员网页后端")
    web.add_argument("--port", type=int, default=WEB_PORT)
    return parser


def main() -> int:
    os.umask(0o077)
    parser = build_parser()
    args = parser.parse_args()
    try:
        if args.command == "web":
            cmd_web(args)
            return 0
        with process_lock():
            with connect() as conn:
                handlers = {
                    "init": cmd_init,
                    "add": cmd_add,
                    "list": cmd_list,
                    "show": cmd_show,
                    "quota": cmd_quota,
                    "reset": cmd_reset,
                    "enable": lambda c, a: cmd_toggle(c, a, True),
                    "disable": lambda c, a: cmd_toggle(c, a, False),
                    "delete": cmd_delete,
                    "rotate-token": lambda c, a: cmd_rotate(c, a, "token"),
                    "rotate-password": lambda c, a: cmd_rotate(c, a, "password"),
                    "collect": cmd_collect,
                    "cleanup": cmd_cleanup,
                    "render": cmd_render,
                }
                handlers[args.command](conn, args)
        return 0
    except (ManagerError, OSError, sqlite3.Error, subprocess.SubprocessError) as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
