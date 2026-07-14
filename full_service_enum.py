#!/usr/bin/env python3
"""Standalone, non-authenticated service triage and evidence collector.

This tool combines the earlier service prober and the timestamped Nmap evidence
collector in one file.  It accepts either Nmap grepable output (.gnmap/.out) or
the JSONL report written by the prior prober, selects a conservative target
scope, and produces one self-contained run directory.

It intentionally does *not* perform credential attempts, password spraying,
default-credential checks, share enumeration, exploit delivery, Metasploit,
NetExec/NXC, or Impacket actions.  The only active checks are low-impact TCP
connections, protocol handshakes/metadata reads, and a fixed allowlist of
non-authenticated Nmap NSE scripts.

Examples:
  # Review the default highest-priority plan without network traffic.
  python3 full_service_evidence.py --input nmap.out --dry-run

  # Collect prober output plus safe Nmap evidence for the highest-priority hosts.
  python3 full_service_evidence.py --input nmap.out --out runs

  # Use an existing prober report as input and include the broader focus set.
  python3 full_service_evidence.py --input report.out --scope focus --out runs

  # Restrict to an explicitly approved list and include every known open port.
  python3 full_service_evidence.py --input nmap.out --scope all \
      --targets approved-hosts.txt --out runs
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import ipaddress
import json
import re
import shlex
import shutil
import socket
import ssl
import subprocess
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


TOOL_VERSION = "1.0.0"
PORT_RECORD_RE = re.compile(
    r"(?:^|,\s+)"
    r"(?P<port>\d+)/"
    r"(?P<state>[^/]*)/"
    r"(?P<protocol>[^/]*)/"
    r"(?P<owner>[^/]*)/"
    r"(?P<service>[^/]*)/"
    r"(?P<rpcinfo>[^/]*)/"
    r"(?P<version>.*?)(?=,\s+\d+/[^/]*/[^/]*/|$)"
)


@dataclass(frozen=True)
class OpenPort:
    host: str
    port: int
    service: str
    version: str
    source_line: int


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def host_key(host: str) -> tuple[int, int | str]:
    try:
        return (0, int(ipaddress.ip_address(host)))
    except ValueError:
        return (1, host)


def csv_ports(values: Iterable[int]) -> str:
    ports = sorted(set(values))
    return ",".join(str(port) for port in ports) if ports else "-"


def parse_gnmap(path: Path) -> list[OpenPort]:
    records: list[OpenPort] = []
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for source_line, raw in enumerate(handle, start=1):
            if not raw.startswith("Host: ") or "Ports:" not in raw:
                continue
            split = re.split(r"\s+Ports:\s*", raw, maxsplit=1)
            if len(split) != 2:
                continue
            host_match = re.match(r"Host:\s+(\S+)", split[0])
            if not host_match:
                continue
            host = host_match.group(1)
            for match in PORT_RECORD_RE.finditer(split[1].rstrip("\n")):
                if match.group("state") != "open" or match.group("protocol") != "tcp":
                    continue
                records.append(
                    OpenPort(
                        host=host,
                        port=int(match.group("port")),
                        service=(match.group("service") or "unknown").strip(),
                        version=(match.group("version") or "").strip(),
                        source_line=source_line,
                    )
                )
    return records


def parse_report_jsonl(path: Path) -> list[OpenPort]:
    records: list[OpenPort] = []
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for source_line, raw in enumerate(handle, start=1):
            try:
                item = json.loads(raw)
                nmap = item["nmap"]
                records.append(
                    OpenPort(
                        host=str(item["host"]),
                        port=int(item["port"]),
                        service=str(nmap.get("service", "unknown")),
                        version=str(nmap.get("version", "")),
                        source_line=int(nmap.get("source_line", source_line)),
                    )
                )
            except (json.JSONDecodeError, KeyError, TypeError, ValueError):
                continue
    return records


def parse_input(path: Path) -> list[OpenPort]:
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        first = next((line.lstrip() for line in handle if line.strip()), "")
    records = parse_report_jsonl(path) if first.startswith("{") else parse_gnmap(path)
    unique: dict[tuple[str, int], OpenPort] = {}
    for record in records:
        # A report can contain repeated output from prior runs. Keep the last
        # record, which is normally the most complete service fingerprint.
        unique[(record.host, record.port)] = record
    return sorted(unique.values(), key=lambda item: (host_key(item.host), item.port))


def parse_port_list(value: str) -> set[int]:
    ports: set[int] = set()
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        try:
            port = int(item)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(f"invalid port: {item!r}") from exc
        if not 1 <= port <= 65535:
            raise argparse.ArgumentTypeError(f"port out of range: {port}")
        ports.add(port)
    if not ports:
        raise argparse.ArgumentTypeError("supply at least one port")
    return ports


def read_target_file(path: Path | None, inline: Iterable[str] | None) -> set[str]:
    targets: set[str] = set()
    for raw in inline or []:
        targets.update(value.strip() for value in raw.split(",") if value.strip())
    if path is not None:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for raw in handle:
                value = raw.split("#", 1)[0].strip()
                if value:
                    targets.add(value)
    return targets


def record_is_http(record: OpenPort) -> bool:
    service = record.service.lower()
    if service.startswith("ncacn_"):
        return False
    return "http" in service or "proxy" in service or record.port in {80, 443}


def record_is_tls(record: OpenPort) -> bool:
    service = record.service.lower()
    return "ssl" in service or "https" in service or record.port in {443, 465, 636, 3269}


def record_is_smtp(record: OpenPort) -> bool:
    return "smtp" in f"{record.service} {record.version}".lower() or record.port in {25, 465, 2525}


def roles_for_host(records: list[OpenPort]) -> tuple[list[str], bool, bool]:
    ports = {record.port for record in records}
    fingerprint = " ".join(f"{record.service} {record.version}".lower() for record in records)
    roles: list[str] = []
    p1 = False
    focus = False

    if 4533 in ports and "microsoft sql server 2016" in fingerprint:
        roles.append("sql_legacy")
        p1 = focus = True
    if "dell idrac 8" in fingerprint:
        roles.append("idrac8")
        p1 = focus = True
    if 3268 in ports or 3269 in ports:
        roles.append("directory")
        p1 = focus = True
    if 111 in ports and 1099 in ports:
        roles.append("rpc_rmi")
        p1 = focus = True
    if 445 in ports and 3389 in ports and "windows server 2008 r2 - 2012" in fingerprint:
        roles.append("legacy_windows")
        focus = True
    if ports.intersection({1521, 2030, 2481, 3306, 4521, 4533}):
        roles.append("database")
        focus = True
    if {514, 515, 1514}.issubset(ports):
        roles.append("legacy_shell_printer")
        focus = True
    if 111 in ports or 1099 in ports:
        if "rpc_rmi" not in roles:
            roles.append("rpc_or_rmi")
        focus = True
    if not roles:
        roles.append("inventory")
    return roles, p1, focus


def select_records(
    records: list[OpenPort], scope: str, targets: set[str], ports: set[int] | None
) -> tuple[list[OpenPort], dict[str, list[str]]]:
    by_host: dict[str, list[OpenPort]] = defaultdict(list)
    for record in records:
        if targets and record.host not in targets:
            continue
        by_host[record.host].append(record)

    selected_hosts: set[str] = set()
    roles: dict[str, list[str]] = {}
    for host, host_records in by_host.items():
        host_roles, p1, focus = roles_for_host(host_records)
        include = scope == "all" or (scope == "p1" and p1) or (scope == "focus" and focus)
        if include:
            selected_hosts.add(host)
            roles[host] = host_roles

    selected = [
        record
        for record in records
        if record.host in selected_hosts and (ports is None or record.port in ports)
    ]
    return sorted(selected, key=lambda item: (host_key(item.host), item.port)), roles


class RunLogger:
    def __init__(self, run_dir: Path, dry_run: bool) -> None:
        self.run_dir = run_dir
        self.dry_run = dry_run
        self.command_log = (run_dir / "commands.log").open("w", encoding="utf-8")
        self.summary = (run_dir / "summary.tsv").open("w", encoding="utf-8")
        self.command_log.write(
            f"# full-service-evidence {TOOL_VERSION}\n"
            f"# started_utc={utc_now()}\n"
            f"# dry_run={str(dry_run).lower()}\n"
        )
        self.summary.write("host\tlabel\tstart_utc\tend_utc\texit_code\toutput\n")

    def event(self, event: str, host: str, label: str, detail: str) -> None:
        line = f"{utc_now()}\t{event}\thost={host}\tlabel={label}\t{detail}\n"
        self.command_log.write(line)
        self.command_log.flush()

    def execute(self, host: str, label: str, output: Path, command: list[str], timeout: int) -> int:
        output.parent.mkdir(parents=True, exist_ok=True)
        start = utc_now()
        rendered = shlex.join(command)
        self.event("START", host, label, f"cmd={rendered}")
        if self.dry_run:
            output.write_text(f"[{start}] DRY RUN\n{rendered}\n", encoding="utf-8")
            rc = 0
            print(f"PLAN {rendered}")
        else:
            try:
                with output.open("w", encoding="utf-8") as handle:
                    handle.write(f"[{start}] START {rendered}\n\n")
                    completed = subprocess.run(
                        command,
                        stdout=handle,
                        stderr=subprocess.STDOUT,
                        text=True,
                        timeout=timeout,
                        check=False,
                    )
                    rc = completed.returncode
                    handle.write(f"\n[{utc_now()}] END exit_code={rc}\n")
            except subprocess.TimeoutExpired:
                rc = 124
                with output.open("a", encoding="utf-8") as handle:
                    handle.write(f"\n[{utc_now()}] END timeout_after_seconds={timeout}\n")
            except OSError as exc:
                rc = 127
                with output.open("a", encoding="utf-8") as handle:
                    handle.write(f"\n[{utc_now()}] END error={type(exc).__name__}: {exc}\n")
        end = utc_now()
        self.event("END", host, label, f"exit_code={rc}\toutput={output}")
        self.summary.write(f"{host}\t{label}\t{start}\t{end}\t{rc}\t{output}\n")
        self.summary.flush()
        return rc

    def close(self) -> None:
        self.command_log.close()
        self.summary.close()


def tcp_check(host: str, port: int, timeout: float) -> dict[str, Any]:
    started = time.monotonic()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            pass
        return {"reachable": True, "elapsed_ms": round((time.monotonic() - started) * 1000, 1)}
    except OSError as exc:
        return {"reachable": False, "error": f"{type(exc).__name__}: {exc}"}


def receive_until(sock: socket.socket | ssl.SSLSocket, marker: bytes, limit: int = 16384) -> bytes:
    chunks: list[bytes] = []
    size = 0
    while size < limit:
        chunk = sock.recv(min(4096, limit - size))
        if not chunk:
            break
        chunks.append(chunk)
        size += len(chunk)
        if marker in b"".join(chunks):
            break
    return b"".join(chunks)


def tls_connect(host: str, port: int, timeout: float, sni: str | None) -> tuple[ssl.SSLSocket, dict[str, Any]]:
    raw = socket.create_connection((host, port), timeout=timeout)
    raw.settimeout(timeout)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    try:
        wrapped = context.wrap_socket(raw, server_hostname=sni)
    except BaseException:
        raw.close()
        raise
    certificate = wrapped.getpeercert(binary_form=True)
    cipher = wrapped.cipher()
    return wrapped, {
        "version": wrapped.version(),
        "cipher": cipher[0] if cipher else None,
        "certificate_sha256": hashlib.sha256(certificate).hexdigest() if certificate else None,
    }


def read_ssh_banner(host: str, port: int, timeout: float) -> dict[str, Any]:
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            sock.settimeout(timeout)
            text = receive_until(sock, b"\n", 2048).decode("ascii", errors="replace")
        lines = text.splitlines()
        return {"banner": next((line for line in lines if line.startswith("SSH-")), None), "pre_banner": lines[:5]}
    except OSError as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}


def tls_fingerprint(host: str, port: int, timeout: float, sni: str | None) -> dict[str, Any]:
    sock: ssl.SSLSocket | None = None
    try:
        sock, data = tls_connect(host, port, timeout, sni)
        return data
    except (OSError, ssl.SSLError, ValueError) as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}
    finally:
        if sock is not None:
            sock.close()


def http_head(host: str, port: int, timeout: float, use_tls: bool, name: str, sni: str | None) -> dict[str, Any]:
    sock: socket.socket | ssl.SSLSocket | None = None
    try:
        tls: dict[str, Any] | None = None
        if use_tls:
            sock, tls = tls_connect(host, port, timeout, sni)
        else:
            sock = socket.create_connection((host, port), timeout=timeout)
            sock.settimeout(timeout)
        request = (
            f"HEAD / HTTP/1.1\r\nHost: {name}\r\n"
            "User-Agent: full-service-evidence/1.0\r\nAccept: */*\r\nConnection: close\r\n\r\n"
        ).encode("ascii", errors="strict")
        sock.sendall(request)
        response = receive_until(sock, b"\r\n\r\n")
        lines = response.split(b"\r\n\r\n", 1)[0].decode("latin-1", errors="replace").split("\r\n")
        keep = {"server", "location", "content-type", "www-authenticate", "strict-transport-security"}
        headers: dict[str, str] = {}
        for line in lines[1:]:
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            if key.strip().lower() in keep:
                headers[key.strip().lower()] = value.strip()
        result: dict[str, Any] = {"request": "HEAD /", "status": lines[0] if lines else None, "headers": headers}
        if tls is not None:
            result["tls"] = tls
        return result
    except (OSError, ssl.SSLError, ValueError) as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}
    finally:
        if sock is not None:
            sock.close()


def smtp_ehlo(host: str, port: int, timeout: float) -> dict[str, Any]:
    sock: socket.socket | ssl.SSLSocket | None = None
    try:
        tls: dict[str, Any] | None = None
        if port == 465:
            sock, tls = tls_connect(host, port, timeout, None)
        else:
            sock = socket.create_connection((host, port), timeout=timeout)
            sock.settimeout(timeout)
        banner = receive_until(sock, b"\n").decode("utf-8", errors="replace").splitlines()
        sock.sendall(b"EHLO evidence-collector.invalid\r\n")
        reply = receive_until(sock, b"\r\n").decode("utf-8", errors="replace").splitlines()
        result: dict[str, Any] = {"banner": banner[:5], "ehlo": reply[:30]}
        if tls is not None:
            result["tls"] = tls
        return result
    except (OSError, ssl.SSLError, ValueError) as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}
    finally:
        if sock is not None:
            sock.close()


def mysql_greeting(host: str, port: int, timeout: float) -> dict[str, Any]:
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            sock.settimeout(timeout)
            data = sock.recv(1024)
        if len(data) < 6:
            return {"bytes_received": len(data), "server_version": None}
        payload = data[4:]
        return {
            "bytes_received": len(data),
            "protocol": payload[0],
            "server_version": payload[1:].split(b"\0", 1)[0].decode("ascii", errors="replace"),
        }
    except OSError as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}


def passive_banner(host: str, port: int, timeout: float) -> dict[str, Any]:
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            sock.settimeout(min(timeout, 0.75))
            data = sock.recv(512)
        return {"bytes_received": len(data), "text": data.decode("utf-8", errors="replace").replace("\0", "\\0")}
    except OSError as exc:
        return {"error": f"{type(exc).__name__}: {exc}"}


def triage_probe(record: OpenPort, timeout: float, app_probes: bool, http_host: str | None, sni: str | None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "type": "triage",
        "tool_version": TOOL_VERSION,
        "host": record.host,
        "port": record.port,
        "nmap": {"service": record.service, "version": record.version, "source_line": record.source_line},
        "tcp": tcp_check(record.host, record.port, timeout),
    }
    if not result["tcp"].get("reachable"):
        return result
    if record.port == 22:
        result["ssh"] = read_ssh_banner(record.host, record.port, timeout)
    if not app_probes:
        return result
    if record_is_http(record):
        result["http"] = http_head(record.host, record.port, timeout, record_is_tls(record), http_host or record.host, sni)
    elif record_is_smtp(record):
        result["smtp"] = smtp_ehlo(record.host, record.port, timeout)
    elif record.port == 3306:
        result["mysql"] = mysql_greeting(record.host, record.port, timeout)
    elif record_is_tls(record):
        result["tls"] = tls_fingerprint(record.host, record.port, timeout, sni)
    elif any(flag in record.service.lower() for flag in ("rxmon?", "vmrdp?", "hosts2-ns?", "xfer?", "newoak?")):
        result["passive_banner"] = passive_banner(record.host, record.port, timeout)
    return result


def nse_tag_ports(records: list[OpenPort]) -> dict[str, list[int]]:
    tags: dict[str, list[int]] = defaultdict(list)
    for record in records:
        port, service = record.port, record.service.lower()
        if record_is_http(record):
            tags["web"].append(port)
        if record_is_tls(record):
            tags["tls"].append(port)
        if port == 22 or "ssh" in service:
            tags["ssh"].append(port)
        if port == 53 or service == "domain":
            tags["dns"].append(port)
        if port == 445 or "microsoft-ds" in service:
            tags["smb"].append(port)
        if port == 3389 or "ms-wbt" in service:
            tags["rdp"].append(port)
        if record_is_smtp(record):
            tags["smtp"].append(port)
        if port in {389, 636, 3268, 3269} or "ldap" in service:
            tags["ldap"].append(port)
        if port == 111 or "rpcbind" in service:
            tags["rpc"].append(port)
        if port == 1099 or "rmi" in service:
            tags["rmi"].append(port)
        if port in {1433, 4533} or "ms-sql" in service:
            tags["mssql"].append(port)
        if port == 3306 or "mysql" in service:
            tags["mysql"].append(port)
        if port in {1521, 2030, 2481, 4521} or "oracle" in service:
            tags["oracle"].append(port)
    return {tag: sorted(set(ports)) for tag, ports in tags.items()}


NSE_SCRIPTS: dict[str, tuple[str, ...]] = {
    "web": ("http-title", "http-headers", "http-methods"),
    "tls": ("ssl-cert", "ssl-enum-ciphers"),
    "ssh": ("ssh2-enum-algos",),
    "dns": ("dns-nsid", "dns-recursion"),
    "smb": ("smb2-security-mode", "smb2-time"),
    "rdp": ("rdp-enum-encryption",),
    "smtp": ("smtp-commands",),
    "ldap": ("ldap-rootdse",),
    "rpc": ("rpcinfo",),
    "rmi": ("rmi-dumpregistry",),
    "mssql": ("ms-sql-info",),
    "mysql": ("mysql-info",),
    "oracle": ("oracle-tns-version",),
}


def write_manifest(path: Path, records: list[OpenPort], roles: dict[str, list[str]]) -> None:
    by_host: dict[str, list[OpenPort]] = defaultdict(list)
    for record in records:
        by_host[record.host].append(record)
    columns = ["host", "role", "ports", *NSE_SCRIPTS]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(columns)
        for host in sorted(by_host, key=host_key):
            tags = nse_tag_ports(by_host[host])
            writer.writerow(
                [
                    host,
                    ",".join(roles.get(host, ["inventory"])),
                    csv_ports(record.port for record in by_host[host]),
                    *[csv_ports(tags.get(tag, [])) for tag in NSE_SCRIPTS],
                ]
            )


def write_report(path: Path, records: list[OpenPort], roles: dict[str, list[str]], results: list[dict[str, Any]], run_dir: Path) -> None:
    by_host: dict[str, list[OpenPort]] = defaultdict(list)
    for record in records:
        by_host[record.host].append(record)
    reachable = sum(1 for result in results if result.get("tcp", {}).get("reachable"))
    planned = sum(1 for result in results if result.get("planned"))
    with path.open("w", encoding="utf-8") as handle:
        handle.write("# Full service evidence report\n\n")
        handle.write(
            f"Collected from **{len(records)}** open TCP records across **{len(by_host)}** selected hosts. "
            "This is a non-authenticated inventory/configuration run; it does not establish a confirmed vulnerability.\n\n"
        )
        handle.write("## Selected hosts\n\n")
        handle.write("| Host | Role(s) | Known TCP ports |\n|---|---|---|\n")
        for host in sorted(by_host, key=host_key):
            handle.write(
                f"| `{host}` | {', '.join(roles.get(host, ['inventory']))} | "
                f"`{csv_ports(record.port for record in by_host[host])}` |\n"
            )
        handle.write("\n## Lightweight prober result\n\n")
        if planned:
            handle.write(f"Dry-run plan contains **{planned}** service probes; no network traffic was generated.\n\n")
        else:
            handle.write(f"Reachable from this scanner: **{reachable}/{len(results)}** service records.\n\n")
        handle.write("| Endpoint | TCP | Service | HTTP/TLS observation |\n|---|---|---|---|\n")
        for result in results[:200]:
            tcp = "planned" if result.get("planned") else ("reachable" if result.get("tcp", {}).get("reachable") else "not reachable")
            observation = "-"
            if "http" in result:
                observation = result["http"].get("status") or result["http"].get("error", "-")
            elif "tls" in result:
                observation = result["tls"].get("version") or result["tls"].get("error", "-")
            elif "ssh" in result:
                observation = result["ssh"].get("banner") or result["ssh"].get("error", "-")
            elif "smtp" in result:
                observation = "; ".join(result["smtp"].get("ehlo", [])[:2]) or result["smtp"].get("error", "-")
            observation = str(observation).replace("|", "\\|").replace("\n", " ")
            service = f"{result['nmap']['service']} {result['nmap']['version']}".strip().replace("|", "\\|")
            handle.write(f"| `{result['host']}:{result['port']}` | {tcp} | {service} | {observation} |\n")
        if len(results) > 200:
            handle.write(f"\nOnly the first 200 of {len(results)} prober records are shown.\n")
        handle.write("\n## Evidence artifacts\n\n")
        handle.write(f"- Command timeline: `{run_dir / 'commands.log'}`\n")
        handle.write(f"- Command results: `{run_dir / 'summary.tsv'}`\n")
        handle.write(f"- Service data: `{run_dir / 'triage.jsonl'}`\n")
        handle.write(f"- Per-host Nmap artifacts: `{run_dir / 'hosts'}`\n")
        handle.write("\nThe Nmap follow-up uses a fixed non-authenticated allowlist; it does not include `vuln`, brute-force, default-credential, or exploit scripts.\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Standalone safe service prober and evidence collector.")
    parser.add_argument("--version", action="version", version=f"full-service-evidence {TOOL_VERSION}")
    parser.add_argument("--input", type=Path, default=Path("nmap.out"), help="Nmap grepable output or prior report JSONL")
    parser.add_argument("--out", type=Path, default=Path("runs"), help="parent directory for a timestamped run")
    parser.add_argument("--scope", choices=("p1", "focus", "all"), default="p1", help="p1 is smallest; focus adds broader legacy/database groups; all includes every host")
    parser.add_argument("--target", action="append", help="restrict to one or more comma-separated approved hosts")
    parser.add_argument("--targets", type=Path, help="restrict to approved hosts, one host per line")
    parser.add_argument("--ports", type=parse_port_list, help="restrict selected hosts to these already-known TCP ports")
    parser.add_argument("--mode", choices=("triage", "evidence", "full"), default="full", help="triage = socket/app probes; evidence = Nmap only; full = both")
    parser.add_argument("--full", action="store_true", help="compatibility shortcut for --scope all --mode full")
    parser.add_argument("--no-app-probes", action="store_true", help="skip HTTP HEAD, SMTP EHLO, TLS, MySQL, and passive banner reads")
    parser.add_argument("--timeout", type=float, default=3.0, help="socket timeout seconds (default: 3)")
    parser.add_argument("--http-host", help="approved HTTP Host header for all web probes")
    parser.add_argument("--sni", help="approved TLS SNI name for all TLS probes")
    parser.add_argument("--nmap-bin", default="nmap", help="Nmap executable (default: nmap)")
    parser.add_argument("--host-timeout", default="4m", help="Nmap host timeout (default: 4m)")
    parser.add_argument("--script-timeout", default="35s", help="Nmap NSE timeout (default: 35s)")
    parser.add_argument("--nmap-command-timeout", type=int, default=300, help="outer Nmap command timeout seconds (default: 300)")
    parser.add_argument("--dry-run", action="store_true", help="write manifest and command plan but make no network connections")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.full:
        args.scope = "all"
        args.mode = "full"
    if args.timeout <= 0 or args.nmap_command_timeout <= 0:
        raise SystemExit("timeout values must be greater than zero")
    if args.http_host and ("\r" in args.http_host or "\n" in args.http_host):
        raise SystemExit("--http-host must not contain newlines")
    if not args.input.is_file():
        raise SystemExit(f"input not found: {args.input}")
    if args.targets is not None and not args.targets.is_file():
        raise SystemExit(f"target file not found: {args.targets}")
    if args.mode in {"evidence", "full"} and not args.dry_run and shutil.which(args.nmap_bin) is None:
        raise SystemExit(f"Nmap executable not found: {args.nmap_bin}")

    try:
        records = parse_input(args.input)
        targets = read_target_file(args.targets, args.target)
    except OSError as exc:
        raise SystemExit(f"unable to read input/targets: {exc}") from exc
    selected, roles = select_records(records, args.scope, targets, args.ports)
    if not selected:
        raise SystemExit("No open TCP records matched the requested scope/filters.")

    run_dir = args.out / f"run-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')}"
    hosts_dir = run_dir / "hosts"
    run_dir.mkdir(parents=True, exist_ok=False)
    write_manifest(run_dir / "manifest.tsv", selected, roles)
    (run_dir / "run.json").write_text(
        json.dumps(
            {
                "tool": "full-service-evidence",
                "version": TOOL_VERSION,
                "started_utc": utc_now(),
                "input": str(args.input),
                "scope": args.scope,
                "mode": args.mode,
                "dry_run": args.dry_run,
                "selected_hosts": len({record.host for record in selected}),
                "selected_services": len(selected),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    logger = RunLogger(run_dir, args.dry_run)
    results: list[dict[str, Any]] = []
    try:
        logger.event("INFO", "-", "run", f"selected_hosts={len({record.host for record in selected})}\tselected_services={len(selected)}")
        if args.mode in {"triage", "full"}:
            for record in selected:
                label = f"triage_tcp_{record.port}"
                logger.event("PROBE_START", record.host, label, f"service={record.service}")
                if args.dry_run:
                    result = {
                        "type": "triage",
                        "tool_version": TOOL_VERSION,
                        "host": record.host,
                        "port": record.port,
                        "planned": True,
                        "nmap": {"service": record.service, "version": record.version, "source_line": record.source_line},
                    }
                else:
                    result = triage_probe(record, args.timeout, not args.no_app_probes, args.http_host, args.sni)
                results.append(result)
                detail = "planned" if args.dry_run else ("reachable" if result.get("tcp", {}).get("reachable") else "not_reachable")
                logger.event("PROBE_END", record.host, label, detail)

        if args.mode in {"evidence", "full"}:
            by_host: dict[str, list[OpenPort]] = defaultdict(list)
            for record in selected:
                by_host[record.host].append(record)
            nmap_path = shutil.which(args.nmap_bin) or args.nmap_bin
            base = [nmap_path, "-n", "-Pn", "-sT", "-sV", "--version-light", "--reason", "--max-retries", "1", "--host-timeout", args.host_timeout]
            script_base = [*base, "--script-timeout", args.script_timeout]
            for host in sorted(by_host, key=host_key):
                host_records = by_host[host]
                host_dir = hosts_dir / host
                ports = csv_ports(record.port for record in host_records)
                logger.execute(host, "baseline_service", host_dir / "01-baseline_service.log", [*base, "-p", ports, host], args.nmap_command_timeout)
                tags = nse_tag_ports(host_records)
                for sequence, tag in enumerate(NSE_SCRIPTS, start=2):
                    tag_ports = tags.get(tag, [])
                    if not tag_ports:
                        continue
                    logger.execute(
                        host,
                        tag,
                        host_dir / f"{sequence:02d}-{tag}.log",
                        [*script_base, "-p", csv_ports(tag_ports), "--script", ",".join(NSE_SCRIPTS[tag]), host],
                        args.nmap_command_timeout,
                    )
    finally:
        logger.close()

    with (run_dir / "triage.jsonl").open("w", encoding="utf-8") as handle:
        for result in results:
            handle.write(json.dumps(result, sort_keys=True) + "\n")
    write_report(run_dir / "report.md", selected, roles, results, run_dir)
    print(f"Completed {'plan' if args.dry_run else 'collection'}: {run_dir}")
    print("Review manifest.tsv, commands.log, summary.tsv, report.md, and hosts/<host>/*.log.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
