#!/usr/bin/env python3
from __future__ import annotations

import ipaddress
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
STATIC_LIST = "openclash/custom/lenovo_intranet_ips.list"
ALLOWED_FILES = {
    ".gitignore", ".gitattributes", "README.md", STATIC_LIST,
    ".github/workflows/sync-rules.yml", ".github/workflows/validate.yml",
    ".githooks/pre-commit", "requirements-validation.txt",
    "scripts/download_upstream.ps1", "scripts/validate_public.py",
    "scripts/test_validate_public.py",
}
RULE_TYPES = {"DOMAIN", "DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "IP-CIDR", "IP-CIDR6", "PROCESS-NAME"}
SECRET_FIELD = re.compile(
    r"(?im)^\s*(?:-\s*)?(?:proxies|proxy-providers|proxy-groups|secret|password|"
    r"passwd|token|uuid|private-key|private_key|client-key|authentication)\s*:"
)
SECRET_VALUE = re.compile(
    r"(?i)(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|AGE-SECRET-KEY-1[0-9A-Z]+|"
    r"(?:ss|ssr|vless|vmess|trojan|hysteria2?)://|"
    r"https?://[^\s/]+:[^\s/@]+@|[?&](?:token|access_token|password|secret|key)=[^\s&#]+|"
    r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}))"
)


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, (str, int, float, bool, type(None))) or key in result:
            raise ValueError("Duplicate or unsupported YAML mapping key")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def is_rule_path(path: str) -> bool:
    parts = PurePosixPath(path).parts
    return (len(parts) == 3 and parts[0] == "rule_provider"
            and parts[1] in {"custom", "upstream"} and parts[2].endswith(".yaml"))


def validate_file(path: str, data: bytes) -> set[str]:
    if path not in ALLOWED_FILES and not is_rule_path(path):
        raise ValueError("File is outside the public release allowlist")
    if len(data) > 8 * 1024 * 1024:
        raise ValueError("File exceeds the public file size limit")
    text = data.decode("utf-8-sig")
    if SECRET_FIELD.search(text) or SECRET_VALUE.search(text):
        raise ValueError("Configuration or credential pattern detected; value suppressed")
    if is_rule_path(path):
        document = yaml.load(text, Loader=UniqueKeyLoader)
        if not isinstance(document, dict) or set(document) != {"payload"}:
            raise ValueError("Rule provider must contain only payload")
        payload = document["payload"]
        if not isinstance(payload, list) or not payload:
            raise ValueError("Rule payload must be a nonempty list")
        networks = set()
        for rule in payload:
            if not isinstance(rule, str):
                raise ValueError("Rule entry must be text")
            fields = [field.strip() for field in rule.split(",")]
            if len(fields) not in {2, 3} or fields[0] not in RULE_TYPES or not fields[1]:
                raise ValueError("Unsupported rule syntax")
            if len(fields) == 3 and (fields[2] != "no-resolve" or fields[0] not in {"IP-CIDR", "IP-CIDR6"}):
                raise ValueError("Unexpected rule option")
            if fields[0] in {"IP-CIDR", "IP-CIDR6"}:
                network = ipaddress.ip_network(fields[1], strict=False)
                expected = 4 if fields[0] == "IP-CIDR" else 6
                if network.version != expected:
                    raise ValueError("CIDR address family mismatch")
                if path == "rule_provider/custom/Lenovo.yaml":
                    if network.version != 4 or network.prefixlen != 32:
                        raise ValueError("Lenovo static exceptions must be IPv4 /32")
                    networks.add(str(network.network_address))
        return networks
    if path == STATIC_LIST:
        addresses = []
        for line in text.splitlines():
            token = line.split("#", 1)[0].strip()
            if not token:
                continue
            network = ipaddress.ip_network(token, strict=False)
            if network.version != 4 or network.prefixlen != 32:
                raise ValueError("Static list entries must be IPv4 /32")
            addresses.append(str(network.network_address))
        if len(addresses) != len(set(addresses)):
            raise ValueError("Duplicate static IP exception")
        return set(addresses)
    return set()


def main() -> int:
    staged = "--staged" in sys.argv[1:]
    command = ["git", "ls-files", "-z"]
    if not staged:
        command.extend(["--cached", "--others", "--exclude-standard"])
    paths = sorted(set(subprocess.check_output(command, cwd=ROOT).decode().split("\0")) - {""})
    entries = {}
    checked = 0
    errors = []
    for path in paths:
        try:
            if staged:
                metadata = subprocess.check_output(["git", "ls-files", "-s", "--", path], cwd=ROOT).decode()
                if not metadata.startswith(("100644 ", "100755 ")):
                    raise ValueError("Public files must be regular files")
                data = subprocess.check_output(["git", "show", ":" + path], cwd=ROOT)
            else:
                source = ROOT / path
                if not source.exists() and not source.is_symlink():
                    continue
                if source.is_symlink() or not source.is_file():
                    raise ValueError("Public files must be regular files")
                data = source.read_bytes()
            entries[path] = validate_file(path, data)
            checked += 1
        except (ValueError, yaml.YAMLError, OSError, subprocess.CalledProcessError):
            errors.append(path)
    if STATIC_LIST not in entries or "rule_provider/custom/Lenovo.yaml" not in entries:
        errors.append("missing Lenovo rule/list")
    elif entries[STATIC_LIST] != entries["rule_provider/custom/Lenovo.yaml"]:
        errors.append("Lenovo rule/list IP mismatch")
    if errors:
        print("Public validation failed (contents suppressed): " + ", ".join(errors), file=sys.stderr)
        return 1
    print(f"Public validation passed: {checked} files; Lenovo rule/list match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())