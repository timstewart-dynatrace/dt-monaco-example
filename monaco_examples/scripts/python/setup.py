#!/usr/bin/env python3
"""
Quick Setup Script for Dynatrace Monaco Configuration Migration

Checks dependencies, collects configuration, creates .env file,
and verifies tenant connections.

Usage:
    python setup.py
"""

import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import requests
    from dotenv import load_dotenv
except ImportError:
    print("Error: Required packages not installed")
    print("Run: pip3 install requests python-dotenv")
    sys.exit(1)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def check_command(name: str) -> bool:
    """Check if a command is available on the system."""
    found = shutil.which(name) is not None
    status = "found" if found else "NOT FOUND"
    level = "INFO" if found else "WARNING"
    print(f"  {'[OK]' if found else '[!!]'} {name} - {status}")
    return found


def verify_connection(url: str, token: str, name: str) -> bool:
    """Verify connection to a Dynatrace tenant."""
    try:
        headers = {"Authorization": f"Api-Token {token}"}
        response = requests.get(f"{url}/api/v2/environments", headers=headers, timeout=10)
        if response.status_code == 200:
            print(f"  [OK] {name} tenant")
            return True
        else:
            print(f"  [!!] {name} tenant (HTTP {response.status_code})")
            return False
    except Exception as e:
        print(f"  [!!] {name} tenant ({e})")
        return False


def main() -> int:
    print()
    print("=" * 60)
    print("  Dynatrace Monaco Configuration Migration - Setup Wizard")
    print("=" * 60)
    print()

    # Step 1: Check dependencies
    print("[1/4] Checking dependencies...")
    all_ok = True
    all_ok = check_command("python3") and all_ok
    all_ok = check_command("curl") and all_ok
    monaco_ok = check_command("monaco")
    if not monaco_ok:
        print("  [!!] Monaco not in PATH (you'll need to install it)")
        all_ok = False

    if not all_ok:
        print()
        print("[!] Some dependencies are missing. See README.md for installation steps.")

    # Step 2: Collect configuration
    print()
    print("[2/4] Collecting configuration details...")
    print()

    env_file = Path(".env")
    skip_config = False

    if env_file.exists():
        print("[!] .env file already exists. Using existing configuration.")
        load_dotenv()
        source_url = os.getenv("SOURCE_TENANT_URL", "")
        source_token = os.getenv("SOURCE_TENANT_TOKEN", "")
        target_url = os.getenv("TARGET_TENANT_URL", "")
        target_token = os.getenv("TARGET_TENANT_TOKEN", "")
        skip_config = True
    else:
        try:
            source_url = input("Source Dynatrace Tenant URL (https://...): ").strip()
            source_token = input("Source API Token: ").strip()
            print()
            target_url = input("Target Dynatrace Tenant URL (https://...): ").strip()
            target_token = input("Target API Token: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nSetup cancelled.")
            return 1

    # Step 3: Verify connections
    print()
    print("[3/4] Verifying connections...")
    verify_connection(source_url, source_token, "Source")
    verify_connection(target_url, target_token, "Target")

    # Step 4: Create .env file
    if not skip_config:
        print()
        print("[4/4] Creating configuration file...")

        from datetime import datetime
        env_content = f"""# Dynatrace Monaco Configuration
# Created: {datetime.now().isoformat()}

# Source Tenant
SOURCE_TENANT_URL={source_url}
SOURCE_TENANT_TOKEN={source_token}

# Target Tenant
TARGET_TENANT_URL={target_url}
TARGET_TENANT_TOKEN={target_token}
"""
        env_file.write_text(env_content)
        print("  [OK] Created .env file (keep this secure!)")

    # Monaco installation hint
    if not monaco_ok:
        print()
        print("[!] Monaco CLI not found. Install it:")
        print()
        print("  # macOS")
        print("  brew install dynatrace-oss/dynatrace/monaco")
        print()
        print("  # Linux/macOS manual")
        print("  curl -L https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-linux-amd64 -o monaco")
        print("  chmod +x monaco && sudo mv monaco /usr/local/bin/")
        print()
        print("  # Windows")
        print('  Invoke-WebRequest -URI https://github.com/Dynatrace/dynatrace-configuration-as-code/releases/latest/download/monaco-windows-amd64.exe -OutFile monaco.exe')
        print()

    # Install Python dependencies if needed
    requirements = Path("requirements.txt")
    if requirements.exists():
        try:
            import yaml  # noqa: F401
        except ImportError:
            print()
            print("[!] Installing Python dependencies...")
            subprocess.run([sys.executable, "-m", "pip", "install", "-r", str(requirements)], check=True)
            print("[OK] Dependencies installed")

    # Summary
    print()
    print("=" * 60)
    print("  Setup Complete!")
    print("=" * 60)
    print()
    print("Next Steps:")
    print()
    print("1. Verify your configuration:")
    print("   source .env  # or load in your shell")
    print()
    print("2. Test connectivity (optional):")
    print("   python scripts/python/verify_migration.py")
    print()
    print("3. Run a dry-run to preview changes:")
    print("   python scripts/python/migrate.py --dry-run")
    print()
    print("4. Start migration:")
    print("   python scripts/python/migrate.py")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
