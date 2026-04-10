#!/usr/bin/env python3
"""
Dynatrace SaaS-to-SaaS Configuration Export Script (Reference Copy)

Exports Dynatrace SaaS tenant configurations for migration using Monaco CLI.
Downloads Monaco binary, generates a scoped API token, exports all configurations,
and packages them into an archive compatible with SaaS Upgrade Assistant.

Usage:
    export ENV_TOKEN="dt0c01.your_tenant.token_here"
    python s2s-export.py <tenant-id> [--env-url-base live.dynatrace.com]

Note: This is a reference copy. The primary version lives in
      monaco_s2s_sua_migration/scripts/python/s2s-export.py
"""

import argparse
import hashlib
import json
import logging
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import time
from datetime import datetime
from pathlib import Path

try:
    import requests
except ImportError:
    print("Error: 'requests' package not installed")
    print("Run: pip3 install requests")
    sys.exit(1)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

MONACO_VERSION = "2.12.0"

MONACO_TOKEN_SCOPES = [
    "attacks.read", "entities.read", "extensionConfigurations.read",
    "extensionEnvironment.read", "extensions.read", "geographicRegions.read",
    "javaScriptMappingFiles.read", "networkZones.read", "settings.read",
    "slo.read", "syntheticExecutions.read", "syntheticLocations.read",
    "DataExport", "DssFileManagement", "ExternalSyntheticIntegration",
    "ReadConfig", "ReadSyntheticData", "RumJavaScriptTagManagement",
]


def get_platform_suffix() -> str:
    """Determine the Monaco binary platform suffix for the current system."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    platform_map = {
        ("darwin", "x86_64"): "darwin-amd64",
        ("darwin", "amd64"): "darwin-amd64",
        ("darwin", "arm64"): "darwin-arm64",
        ("linux", "x86_64"): "linux-amd64",
        ("linux", "amd64"): "linux-amd64",
        ("linux", "i386"): "linux-386",
        ("linux", "i686"): "linux-386",
        ("windows", "amd64"): "windows-amd64.exe",
        ("windows", "x86_64"): "windows-amd64.exe",
    }

    suffix = platform_map.get((system, machine))
    if not suffix:
        logger.error(f"Unsupported platform: {system}/{machine}")
        sys.exit(1)
    return suffix


def download_monaco(platform_suffix: str) -> Path:
    """Download Monaco binary and verify its checksum."""
    binary_name = f"monaco-{platform_suffix}"
    binary_url = (
        f"https://github.com/Dynatrace/dynatrace-configuration-as-code/"
        f"releases/download/v{MONACO_VERSION}/{binary_name}"
    )
    checksum_url = f"{binary_url}.sha256"

    logger.info(f"Downloading Monaco v{MONACO_VERSION} binary...")
    response = requests.get(binary_url, stream=True, timeout=120)
    response.raise_for_status()
    with open(binary_name, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    logger.info("Downloading checksum...")
    checksum_response = requests.get(checksum_url, timeout=30)
    checksum_response.raise_for_status()
    expected_checksum = checksum_response.text.strip().split()[0]

    logger.info("Verifying checksum...")
    sha256 = hashlib.sha256()
    with open(binary_name, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)
    actual_checksum = sha256.hexdigest()

    if actual_checksum != expected_checksum:
        os.remove(binary_name)
        logger.error(f"Checksum verification failed")
        sys.exit(1)

    logger.info("Checksum verified.")

    monaco_binary = Path("monaco.exe" if platform.system().lower() == "windows" else "monaco")
    shutil.move(binary_name, str(monaco_binary))
    if platform.system().lower() != "windows":
        monaco_binary.chmod(0o755)

    return monaco_binary


def generate_monaco_token(tenant_url: str, env_token: str) -> str:
    """Generate a scoped Monaco API token."""
    logger.info("Generating Monaco API token...")
    headers = {
        "Accept": "application/json; charset=utf-8",
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Api-Token {env_token}",
    }
    payload = {"name": "rs-monaco-test", "scopes": MONACO_TOKEN_SCOPES}

    response = requests.post(
        f"{tenant_url}/api/v2/apiTokens", headers=headers, json=payload, timeout=30
    )
    response.raise_for_status()
    token = response.json().get("token")
    if not token:
        logger.error("Failed to generate Monaco API token")
        sys.exit(1)

    logger.info("Monaco token generated successfully.")
    return token


def create_manifest(tenant_id: str, tenant_url: str) -> None:
    """Create the manifest.yaml file for Monaco."""
    content = f"""manifestVersion: 1.0

projects:
- name: saas
  path: saas/{tenant_id}

environmentGroups:
- name: saas
  environments:
  - name: {tenant_id}
    url:
      value: {tenant_url}
    auth:
      token:
        name: MONACO_TOKEN
"""
    with open("manifest.yaml", "w") as f:
        f.write(content)


def run_monaco_download(monaco_binary: Path, tenant_id: str) -> None:
    """Run Monaco to download configurations."""
    logger.info("Running Monaco to download configurations...")
    cmd = [str(monaco_binary), "download", "--environment", tenant_id, "--output-folder", tenant_id]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        logger.error(f"Monaco download failed: {result.stderr}")
        sys.exit(1)
    logger.info("Monaco download completed.")


def package_export(tenant_id: str) -> str:
    """Package the exported configuration into a tar.gz archive."""
    now = datetime.now()
    directory_name = f"configurationExport-{now.strftime('%Y-%m-%d_%H-%M-%S')}"
    export_dir = Path(directory_name)
    export_dir.mkdir(parents=True, exist_ok=True)

    current_timestamp_ms = int(time.time() * 1000)
    metadata = {
        "clusterUuid": tenant_id,
        "productVersion": "1.288.0.20240229-161733",
        "monacoVersion": MONACO_VERSION,
        "exportTimestamp": str(current_timestamp_ms),
        "environments": [{"name": tenant_id, "uuid": tenant_id}],
    }
    with open(export_dir / "exportMetadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    export_subdir = export_dir / "export"
    export_subdir.mkdir(parents=True, exist_ok=True)

    tenant_dir = Path(tenant_id)
    if tenant_dir.exists():
        for item in tenant_dir.iterdir():
            shutil.move(str(item), str(export_subdir))

    archive_name = f"{directory_name}.tar.gz"
    logger.info(f"Archiving to {archive_name}...")
    with tarfile.open(archive_name, "w:gz") as tar:
        tar.add(directory_name, arcname=directory_name)

    logger.info(f"Archive created: {archive_name}")
    return archive_name


def cleanup(tenant_id: str) -> None:
    """Clean up temporary files."""
    logger.info("Cleaning up temporary files...")
    for path in ["monaco", "monaco.exe", "manifest.yaml"]:
        if os.path.exists(path):
            os.remove(path)
    for path in Path(".").glob("monaco-*"):
        path.unlink()
    tenant_dir = Path(tenant_id)
    if tenant_dir.exists():
        shutil.rmtree(str(tenant_dir))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export Dynatrace SaaS tenant configuration for migration"
    )
    parser.add_argument("tenant_id", help="Dynatrace tenant ID")
    parser.add_argument(
        "--env-url-base", default="live.dynatrace.com",
        help="Environment URL base (default: live.dynatrace.com)",
    )
    args = parser.parse_args()

    env_token = os.environ.get("ENV_TOKEN")
    if not env_token:
        logger.error("ENV_TOKEN environment variable is not set")
        return 1

    tenant_id = args.tenant_id
    tenant_url = f"https://{tenant_id}.{args.env_url_base}"

    try:
        platform_suffix = get_platform_suffix()
        monaco_binary = download_monaco(platform_suffix)
        monaco_token = generate_monaco_token(tenant_url, env_token)
        os.environ["MONACO_TOKEN"] = monaco_token
        create_manifest(tenant_id, tenant_url)
        run_monaco_download(monaco_binary, tenant_id)
        archive_name = package_export(tenant_id)
        cleanup(tenant_id)
        logger.info(f"Export completed successfully! Archive: {archive_name}")
        return 0
    except requests.exceptions.HTTPError as e:
        logger.error(f"API error: {e}")
        cleanup(tenant_id)
        return 1
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        cleanup(tenant_id)
        return 1


if __name__ == "__main__":
    sys.exit(main())
