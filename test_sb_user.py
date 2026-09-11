import argparse
import contextlib
import importlib.util
import json
import os
import re
import subprocess
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path


SCRIPT = Path(__file__).with_name("sb-user.py")
SPEC = importlib.util.spec_from_file_location("sb_user", SCRIPT)
sb_user = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(sb_user)


class MultiUserManagerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        sb_user.WORK_DIR = root
        sb_user.CONF_DIR = root / "conf"
        sb_user.SUBSCRIBE_DIR = root / "subscribe"
        sb_user.USERS_DIR = root / "users"
        sb_user.DB_PATH = root / "users.db"
        sb_user.SING_BOX = root / "sing-box"
        sb_user.ADMIN_PAGE_PATH = root / "admin-page.html"
        sb_user.DRY_RUN = True
        sb_user.CONF_DIR.mkdir()
        sb_user.SUBSCRIBE_DIR.mkdir()
        base = {
            "inbounds": [{
                "type": "hysteria2",
                "tag": "base hysteria2",
                "listen": "::",
                "listen_port": 11451,
                "users": [{"password": "base-password"}],
                "ignore_client_bandwidth": False,
                "tls": {
                    "enabled": True,
                    "certificate_path": str(root / "cert.pem"),
                    "key_path": str(root / "private.key"),
                },
            }]
        }
        (sb_user.CONF_DIR / "12_hysteria2_inbounds.json").write_text(json.dumps(base), encoding="utf-8")
        tuic_base = {
            "inbounds": [{
                "type": "tuic",
                "tag": "base tuic",
                "listen": "::",
                "listen_port": 11452,
                "users": [{"uuid": "00000000-0000-4000-8000-000000000001", "password": "base-password"}],
                "congestion_control": "bbr",
                "zero_rtt_handshake": False,
                "tls": {
                    "enabled": True,
                    "certificate_path": str(root / "cert.pem"),
                    "key_path": str(root / "private.key"),
                },
            }]
        }
        (sb_user.CONF_DIR / "13_tuic_inbounds.json").write_text(json.dumps(tuic_base), encoding="utf-8")
        (sb_user.SUBSCRIBE_DIR / "proxies").write_text(
            'proxies:\n'
            '  - {name: "base hysteria2 [2001:db8::1]", type: hysteria2, server: 2001:db8::1, port: 11451, up: "200 Mbps", down: "1000 Mbps", password: base-password, sni: example.com, skip-cert-verify: false, fingerprint: AA:BB}\n'
            '  - {name: "base tuic [2001:db8::1]", type: tuic, server: 2001:db8::1, port: 11452, uuid: 00000000-0000-4000-8000-000000000001, password: base-password, alpn: [h3], udp-relay-mode: native, congestion-controller: bbr, sni: example.com, skip-cert-verify: false, fingerprint: AA:BB}\n',
            encoding="utf-8",
        )
        template = """mixed-port: 7890
proxy-providers:
  所有节点:
    type: http
    url: http://192.0.2.1:8080/old-token/proxies
    interval: 3600
  仅IPv6节点:
    type: http
    url: http://192.0.2.1:8080/old-token/proxies
    interval: 3600
rule-providers:
  reject:
    type: http
    behavior: domain
    url: https://example.invalid/reject.txt
    path: ./ruleset/reject.yaml
    interval: 86400
proxies:
proxy-groups:
  - name: 节点选择
    type: select
    proxies: [DIRECT]
rules:
  - RULE-SET,reject,REJECT
  - MATCH,PROXY
"""
        (sb_user.SUBSCRIBE_DIR / "clash-campus-free").write_text(template, encoding="utf-8")
        (sb_user.USERS_DIR / "subscription-base-url").parent.mkdir(parents=True, exist_ok=True)
        (sb_user.USERS_DIR / "subscription-base-url").write_text(
            "http://198.51.100.1:8443\n", encoding="utf-8"
        )
        (root / "list").write_text(
            "http://192.0.2.1:8080/old-token/clash-campus-free\n",
            encoding="utf-8",
        )
        sb_user.ADMIN_PAGE_PATH.write_text(
            SCRIPT.with_name("admin-page.html").read_text(encoding="utf-8"),
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_quick_install_selects_only_hysteria2_and_tuic(self):
        shell = SCRIPT.with_name("sing-box.sh").read_text(encoding="utf-8")
        match = re.search(r"(?ms)^quick_install_hy2_tuic\(\) \{.*?^\}", shell)
        self.assertIsNotNone(match)
        body = match.group(0)
        self.assertIn("CHOOSE_PROTOCOLS='cd'", body)
        self.assertIn("IS_SUB='is_sub'", body)
        self.assertIn("IS_ARGO='no_argo'", body)
        self.assertIn("IS_HOPPING='no_hopping'", body)
        self.assertIn("unset HY2_PORT_HOPPING_RANGE", body)
        self.assertIn("unset IS_HY2_REALM IS_HY2_WARP", body)
        self.assertNotIn("CHOOSE_PROTOCOLS='a'", body)
        self.assertNotIn("IS_ARGO='is_argo'", body)

        install_match = re.search(r"(?ms)^install_sing-box\(\) \{.*?^\}", shell)
        self.assertIsNotNone(install_match)
        install_body = install_match.group(0)
        self.assertIn("if [ \"$IS_ARGO\" = 'is_argo' ]; then", install_body)
        self.assertIn('cp "$TEMP_DIR/cloudflared" "${WORK_DIR}/cloudflared"', install_body)
        self.assertNotIn("cp $TEMP_DIR/cloudflared ${WORK_DIR}", install_body)
        self.assertIn("systemctl disable --now argo", shell)
        self.assertIn('"$ARGO_DAEMON_FILE"', shell)
        self.assertIn('$(text 197) ${REINSTALL_BACKUP_DIR}', shell)

        export_start = shell.index("\nexport_list() {")
        export_end = shell.index("\n# 创建快捷方式", export_start)
        export_body = shell[export_start:export_end]
        self.assertIn("check_install status_only", export_body)
        self.assertIn("if ! is_strict_multi_user_mode; then", export_body)
        self.assertNotIn("wget --no-check-certificate --continue", export_body)
        self.assertLess(
            export_body.index("install_multi_user_manager || error"),
            export_body.index("if ensure_stats_data; then"),
        )

    def test_clash_orders_ipv6_nodes_and_group_defaults_first(self):
        proxy_path = sb_user.SUBSCRIBE_DIR / "proxies"
        proxy_path.write_text(
            "proxies:\n"
            '  - {name: "hy2-v4", type: hysteria2, server: 192.0.2.1, port: 10001, password: base-password}\n'
            '  - {name: "hy2-v6-a", type: hysteria2, server: 2001:db8::1, port: 10001, password: base-password}\n'
            '  - {name: "hy2-v6-b", type: hysteria2, server: 2001:db8::2, port: 10001, password: base-password}\n'
            '  - {name: "hy2-v6-c", type: hysteria2, server: 2001:db8::3, port: 10001, password: base-password}\n'
            '  - {name: "tuic-v4", type: tuic, server: 192.0.2.1, port: 10002, uuid: 00000000-0000-4000-8000-000000000001, password: base-password}\n'
            '  - {name: "tuic-v6-a", type: tuic, server: 2001:db8::1, port: 10002, uuid: 00000000-0000-4000-8000-000000000001, password: base-password}\n'
            '  - {name: "tuic-v6-b", type: tuic, server: 2001:db8::2, port: 10002, uuid: 00000000-0000-4000-8000-000000000001, password: base-password}\n'
            '  - {name: "tuic-v6-c", type: tuic, server: 2001:db8::3, port: 10002, uuid: 00000000-0000-4000-8000-000000000001, password: base-password}\n',
            encoding="utf-8",
        )

        ordered_names = [
            re.search(r'name: "([^"]+)"', line).group(1)
            for line in sb_user.base_proxy_lines()
        ]
        self.assertEqual(
            ordered_names,
            [
                "hy2-v6-a", "hy2-v6-b", "hy2-v6-c",
                "tuic-v6-a", "tuic-v6-b", "tuic-v6-c",
                "hy2-v4", "tuic-v4",
            ],
        )

        shell = SCRIPT.with_name("sing-box.sh").read_text(encoding="utf-8")
        self.assertIn(
            "proxies: ['♻️ 自动选择', '🚀 节点选择']",
            shell,
        )
        self.assertIn("CAMPUS_DIRECT_DOMAINS=''", shell)
        self.assertIn("DOMAIN-SUFFIX,${_domain},DIRECT", shell)
        self.assertNotIn("IP-CIDR6,::/0,🌐 IPv6代理组", shell)
        self.assertIn("其余所有公网地址（包括 IPv4 与 IPv6）→ 免流节点", shell)

    def test_adds_distinct_users_and_renders_admin_summary(self):
        conn = sb_user.connect()
        try:
            sb_user.cmd_init(conn, argparse.Namespace())
            sb_user.cmd_add(conn, argparse.Namespace(username="admin", quota_gb="0"))
            sb_user.cmd_add(conn, argparse.Namespace(username="alice", quota_gb="10"))
            users = sb_user.all_users(conn)
            self.assertEqual(len(users), 2)
            self.assertEqual(users[0]["is_admin"], 1)
            self.assertEqual(users[1]["is_admin"], 0)
            self.assertNotEqual(users[0]["token"], users[1]["token"])
            self.assertNotEqual(users[0]["password"], users[1]["password"])
            self.assertNotEqual(users[0]["port"], users[1]["port"])
            self.assertNotEqual(users[0]["tuic_port"], users[1]["tuic_port"])
            self.assertTrue(sb_user.TUIC_PORT_MIN <= users[0]["tuic_port"] <= sb_user.TUIC_PORT_MAX)
            self.assertRegex(users[0]["token"], r"^[a-f0-9]{64}$")
            self.assertEqual(
                sb_user.admin_page_link(users[0]),
                f"http://198.51.100.1:8443/user/{users[0]['token']}/page",
            )

            conn.execute(
                "UPDATE users SET upload_bytes=?,download_bytes=? WHERE username='alice'",
                (6 * sb_user.GIB, 5 * sb_user.GIB),
            )
            conn.commit()
            sb_user.render_subscriptions(conn)

            admin_proxies = (sb_user.USERS_DIR / users[0]["token"] / "proxies").read_text(encoding="utf-8")
            alice_proxies = (sb_user.USERS_DIR / users[1]["token"] / "proxies").read_text(encoding="utf-8")
            admin_config = (sb_user.USERS_DIR / users[0]["token"] / "clash-campus-free").read_text(encoding="utf-8")
            alice_config = (sb_user.USERS_DIR / users[1]["token"] / "clash-campus-free").read_text(encoding="utf-8")
            self.assertNotIn("总计", admin_proxies)
            self.assertNotIn("⚠️超额 alice", admin_proxies)
            self.assertNotIn("⚠️超额 alice", alice_proxies)
            self.assertEqual(admin_proxies.count("- {name:"), 2)
            self.assertIn("[2001:db8::1]", alice_proxies)
            self.assertIn("type: hysteria2", alice_proxies)
            self.assertIn("type: tuic", alice_proxies)
            self.assertIn(f"port: {users[1]['port']}", alice_proxies)
            self.assertIn(f"port: {users[1]['tuic_port']}", alice_proxies)
            self.assertIn(f"uuid: \"{sb_user.tuic_uuid(users[1])}\"", alice_proxies)
            self.assertIn('name: "📊 整体流量检测"', admin_config)
            self.assertIn('name: "📊 整体流量检测"', alice_config)
            self.assertIn("📊 月流量总计 已用11.00 GB 可用3.99 TB 上限4.00 TB", admin_config)
            self.assertIn("📊 管理员 admin 已用0.00 GB 共享可用3.99 TB 月上限4.00 TB", admin_config)
            self.assertIn("📊 用户 ⚠️超额 alice 已用11.00 GB 可用0.00 GB 限额10.00 GB", admin_config)
            self.assertNotIn("📊 管理员 admin", alice_config)
            self.assertIn("📊 用户 ⚠️超额 alice 已用11.00 GB 可用0.00 GB 限额10.00 GB", alice_config)
            self.assertEqual(admin_config.count("    type: direct"), 3)
            self.assertEqual(alice_config.count("    type: direct"), 1)
            self.assertNotIn("月流量总计", alice_config)
            self.assertIn("type: select\n    proxies:\n", alice_config)
            self.assertIn(f"/user/{users[1]['token']}/proxies", alice_config)
            self.assertIn(f"url: http://198.51.100.1:8443/user/{users[1]['token']}/proxies", alice_config)
            self.assertNotIn("old-token/proxies", alice_config)
            self.assertIn("interval: 300", alice_config)
            self.assertIn("rule-providers:\n  reject:", alice_config)
            self.assertIn("RULE-SET,reject,REJECT", alice_config)

            configs = list(sb_user.CONF_DIR.glob("30_sbuser_*_hysteria2_inbounds.json"))
            self.assertEqual(len(configs), 2)
            generated = json.loads(configs[1].read_text(encoding="utf-8"))["inbounds"][0]
            self.assertEqual(generated["users"][0]["name"], "alice")
            self.assertEqual(generated["listen_port"], users[1]["port"])
            self.assertEqual(generated["listen"], "::")
            tuic_configs = list(sb_user.CONF_DIR.glob("31_sbuser_*_tuic_inbounds.json"))
            self.assertEqual(len(tuic_configs), 2)
            generated_tuic = json.loads(tuic_configs[1].read_text(encoding="utf-8"))["inbounds"][0]
            self.assertEqual(generated_tuic["users"][0]["name"], "alice")
            self.assertEqual(generated_tuic["users"][0]["uuid"], sb_user.tuic_uuid(users[1]))
            self.assertEqual(generated_tuic["listen_port"], users[1]["tuic_port"])
            self.assertEqual(generated_tuic["listen"], "::")

            base_after_init = json.loads(
                (sb_user.CONF_DIR / "12_hysteria2_inbounds.json").read_text(encoding="utf-8")
            )["inbounds"][0]
            self.assertEqual(base_after_init["listen"], "127.0.0.1")
            tuic_base_after_init = json.loads(
                (sb_user.CONF_DIR / "13_tuic_inbounds.json").read_text(encoding="utf-8")
            )["inbounds"][0]
            self.assertEqual(tuic_base_after_init["listen"], "127.0.0.1")
        finally:
            conn.close()

    def test_combines_ipv4_and_ipv6_firewall_counters(self):
        sample_v4 = '[12:1024] -A SBU_IN -p udp --dport 30000 -m comment --comment "SBU:1:up" -j RETURN\n'
        sample_v6 = '[20:2048] -A SBU_IN -p udp --dport 30000 -m comment --comment "SBU:1:up" -j RETURN\n[30:4096] -A SBU_OUT -p udp --sport 30000 -m comment --comment "SBU:1:down" -j RETURN\n'
        original_exists = sb_user.command_exists
        original_run = sb_user.run
        try:
            sb_user.command_exists = lambda name: name in {"iptables-save", "ip6tables-save"}

            def fake_run(cmd, **_kwargs):
                output = sample_v4 if cmd[0] == "iptables-save" else sample_v6
                return subprocess.CompletedProcess(cmd, 0, output, "")

            sb_user.run = fake_run
            counters, seen = sb_user.read_counters()
            self.assertEqual(counters[1]["up"], 3072)
            self.assertEqual(counters[1]["down"], 4096)
            self.assertEqual(seen, {(1, "up"), (1, "down")})
        finally:
            sb_user.command_exists = original_exists
            sb_user.run = original_run

    def test_existing_hysteria2_user_gains_tuic_after_protocol_install(self):
        tuic_config = sb_user.CONF_DIR / "13_tuic_inbounds.json"
        saved_tuic_config = tuic_config.read_text(encoding="utf-8")
        tuic_config.unlink()
        proxy_path = sb_user.SUBSCRIBE_DIR / "proxies"
        proxy_lines = proxy_path.read_text(encoding="utf-8").splitlines()
        tuic_line = next(line for line in proxy_lines if "type: tuic" in line)
        proxy_path.write_text(
            "\n".join(line for line in proxy_lines if "type: tuic" not in line) + "\n",
            encoding="utf-8",
        )

        conn = sb_user.connect()
        try:
            sb_user.cmd_init(conn, argparse.Namespace())
            sb_user.cmd_add(conn, argparse.Namespace(username="admin", quota_gb="0"))
            before = sb_user.get_user(conn, "admin")
            self.assertEqual(before["tuic_port"], 0)

            tuic_config.write_text(saved_tuic_config, encoding="utf-8")
            with proxy_path.open("a", encoding="utf-8") as stream:
                stream.write(tuic_line + "\n")
            sb_user.cmd_init(conn, argparse.Namespace())

            after = sb_user.get_user(conn, "admin")
            self.assertTrue(sb_user.TUIC_PORT_MIN <= after["tuic_port"] <= sb_user.TUIC_PORT_MAX)
            self.assertTrue((sb_user.CONF_DIR / "31_sbuser_1_tuic_inbounds.json").exists())
            rendered = (sb_user.USERS_DIR / after["token"] / "proxies").read_text(encoding="utf-8")
            self.assertIn("type: hysteria2", rendered)
            self.assertIn("type: tuic", rendered)
        finally:
            conn.close()

    def test_collects_only_counter_deltas_and_handles_counter_reset(self):
        conn = sb_user.connect()
        original_reader = sb_user.read_counters
        try:
            sb_user.cmd_add(conn, argparse.Namespace(username="admin", quota_gb="1"))
            row = sb_user.get_user(conn, "admin")
            user_id = row["id"]
            samples = iter([
                ({user_id: {"up": 1000, "down": 2000}}, {(user_id, "up"), (user_id, "down")}),
                ({user_id: {"up": 1300, "down": 2600}}, {(user_id, "up"), (user_id, "down")}),
                ({user_id: {"up": 50, "down": 70}}, {(user_id, "up"), (user_id, "down")}),
            ])
            sb_user.read_counters = lambda: next(samples)
            sb_user.collect_usage(conn, render=False)
            sb_user.collect_usage(conn, render=False)
            sb_user.collect_usage(conn, render=False)
            result = sb_user.get_user(conn, "admin")
            self.assertEqual(result["upload_bytes"], 1350)
            self.assertEqual(result["download_bytes"], 2670)
        finally:
            sb_user.read_counters = original_reader
            conn.close()

    def test_monthly_cycle_resets_usage_and_counter_baselines(self):
        conn = sb_user.connect()
        original_month = sb_user.current_traffic_month
        try:
            sb_user.cmd_add(conn, argparse.Namespace(username="admin", quota_gb="0"))
            conn.execute(
                "UPDATE users SET upload_bytes=?,download_bytes=?,last_upload_counter=?,last_download_counter=?",
                (3 * sb_user.GIB, 2 * sb_user.GIB, 1234, 5678),
            )
            conn.execute(
                "UPDATE meta SET value='2025-12' WHERE key=?",
                (sb_user.TRAFFIC_MONTH_META_KEY,),
            )
            conn.commit()
            sb_user.current_traffic_month = lambda: "2026-01"
            sb_user.collect_usage(conn, render=False)
            row = sb_user.get_user(conn, "admin")
            self.assertEqual(row["upload_bytes"], 0)
            self.assertEqual(row["download_bytes"], 0)
            self.assertEqual(row["last_upload_counter"], 0)
            self.assertEqual(row["last_download_counter"], 0)
            month = conn.execute(
                "SELECT value FROM meta WHERE key=?", (sb_user.TRAFFIC_MONTH_META_KEY,)
            ).fetchone()["value"]
            self.assertEqual(month, "2026-01")
        finally:
            sb_user.current_traffic_month = original_month
            conn.close()

    def test_admin_web_page_authentication_and_user_management(self):
        with contextlib.closing(sb_user.connect()) as conn:
            sb_user.cmd_init(conn, argparse.Namespace())
            sb_user.cmd_add(conn, argparse.Namespace(username="admin", quota_gb="0"))
            sb_user.cmd_add(conn, argparse.Namespace(username="alice", quota_gb="10"))
            admin = sb_user.get_user(conn, "admin")
            alice = sb_user.get_user(conn, "alice")
            admin_token = admin["token"]
            alice_token = alice["token"]

        server = sb_user.create_web_server(0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        origin = f"http://127.0.0.1:{server.server_address[1]}"

        def request(path, method="GET", payload=None, headers=None):
            body = None if payload is None else json.dumps(payload).encode("utf-8")
            request_headers = {"Accept": "application/json", **(headers or {})}
            if method != "GET":
                request_headers.setdefault("Content-Type", "application/json")
            req = urllib.request.Request(
                origin + path,
                data=body,
                headers=request_headers,
                method=method,
            )
            return urllib.request.urlopen(req, timeout=5)

        admin_base = f"/user/{admin_token}"
        try:
            with request(f"{admin_base}/page") as response:
                self.assertEqual(response.status, 200)
                self.assertIn("流量管理控制台", response.read().decode("utf-8"))
                self.assertEqual(response.headers["Cache-Control"], "no-store, max-age=0")

            with self.assertRaises(urllib.error.HTTPError) as ordinary_page:
                request(f"/user/{alice_token}/page")
            self.assertEqual(ordinary_page.exception.code, 403)
            ordinary_page.exception.close()

            with request(f"{admin_base}/api/users") as response:
                data = json.load(response)
            self.assertEqual(data["admin"], "admin")
            self.assertEqual(data["totals"]["user_count"], 2)
            self.assertEqual({item["username"] for item in data["users"]}, {"admin", "alice"})
            self.assertIn("subscription", data["users"][0])
            self.assertEqual(data["server_monthly_quota_bytes"], 4 * sb_user.TIB)
            self.assertEqual(data["server_monthly_remaining_bytes"], 4 * sb_user.TIB)
            admin_payload = next(item for item in data["users"] if item["username"] == "admin")
            alice_payload = next(item for item in data["users"] if item["username"] == "alice")
            self.assertTrue(admin_payload["uses_server_quota"])
            self.assertEqual(admin_payload["display_total_bytes"], 4 * sb_user.TIB)
            self.assertFalse(alice_payload["uses_server_quota"])
            self.assertEqual(alice_payload["display_total_bytes"], 10 * sb_user.GIB)

            with request(f"{admin_base}/clash-campus-free") as response:
                self.assertEqual(
                    response.headers["Subscription-Userinfo"],
                    f"upload=0; download=0; total={4 * sb_user.TIB}",
                )
            with request(f"/user/{alice_token}/clash-campus-free") as response:
                self.assertEqual(
                    response.headers["Subscription-Userinfo"],
                    f"upload=0; download=0; total={10 * sb_user.GIB}",
                )

            with self.assertRaises(urllib.error.HTTPError) as missing_confirmation:
                request(
                    f"{admin_base}/api/users",
                    "POST",
                    {"username": "bob", "quota_gb": 25},
                )
            self.assertEqual(missing_confirmation.exception.code, 403)
            missing_confirmation.exception.close()

            write_headers = {"X-SB-Admin": "1"}
            with request(
                f"{admin_base}/api/server-quota",
                "PATCH",
                {"quota_tb": 5},
                write_headers,
            ) as response:
                self.assertEqual(response.status, 200)
            with request(f"{admin_base}/api/users") as response:
                quota_data = json.load(response)
            self.assertEqual(quota_data["server_monthly_quota_bytes"], 5 * sb_user.TIB)

            with request(
                f"{admin_base}/api/users",
                "POST",
                {"username": "bob", "quota_gb": 25},
                write_headers,
            ) as response:
                self.assertEqual(response.status, 201)

            with request(
                f"{admin_base}/api/users/bob/quota",
                "PATCH",
                {"quota_gb": 12.5},
                write_headers,
            ) as response:
                self.assertEqual(response.status, 200)
            with request(
                f"{admin_base}/api/users/bob/status",
                "PATCH",
                {"enabled": False},
                write_headers,
            ) as response:
                self.assertEqual(response.status, 200)

            with contextlib.closing(sb_user.connect()) as conn:
                bob = sb_user.get_user(conn, "bob")
                bob_token = bob["token"]
                self.assertEqual(bob["quota_bytes"], int(sb_user.decimal.Decimal("12.5") * sb_user.GIB))
                self.assertEqual(bob["enabled"], 0)

            with self.assertRaises(urllib.error.HTTPError) as disabled_subscription:
                request(f"/user/{bob_token}/clash-campus-free")
            self.assertEqual(disabled_subscription.exception.code, 403)
            disabled_subscription.exception.close()

            with request(
                f"{admin_base}/api/users",
                "POST",
                {"username": "shared", "quota_gb": 0},
                write_headers,
            ) as response:
                self.assertEqual(response.status, 201)
            with contextlib.closing(sb_user.connect()) as conn:
                shared_token = sb_user.get_user(conn, "shared")["token"]
            with request(f"/user/{shared_token}/clash-campus-free") as response:
                self.assertEqual(
                    response.headers["Subscription-Userinfo"],
                    f"upload=0; download=0; total={5 * sb_user.TIB}",
                )

            with self.assertRaises(urllib.error.HTTPError) as delete_admin:
                request(f"{admin_base}/api/users/admin", "DELETE", None, write_headers)
            self.assertEqual(delete_admin.exception.code, 403)
            delete_admin.exception.close()

            with request(f"{admin_base}/api/users/bob", "DELETE", None, write_headers) as response:
                self.assertEqual(response.status, 200)
            with request(f"{admin_base}/api/users/shared", "DELETE", None, write_headers) as response:
                self.assertEqual(response.status, 200)
            with contextlib.closing(sb_user.connect()) as conn:
                self.assertIsNone(conn.execute("SELECT 1 FROM users WHERE username='bob'").fetchone())
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
