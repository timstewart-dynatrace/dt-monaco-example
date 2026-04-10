#!/usr/bin/env python3
"""
Clone and prepare Monaco configuration from a source tenant.

Downloads configuration using Monaco CLI and prepares it for deployment
to a target tenant.

Usage:
    python clone-config.py <source-url> <source-token> [--config-types dashboard,alerting-profiles]

Examples:
    python clone-config.py https://tenant.live.dynatrace.com token_xyz
    python clone-config.py https://tenant.live.dynatrace.com token_xyz --config-types dashboard,alerting-profiles
"""

import argparse
import logging
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: 'pyyaml' package not installed")
    print("Run: pip3 install pyyaml")
    sys.exit(1)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def clone_configuration(source_url: str, source_token: str, config_types: str = "") -> bool:
    """Clone configuration from a source tenant."""
    source_url = source_url.rstrip("/")
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = Path(f"config/cloned-{timestamp}")

    logger.info(f"Cloning configuration from {source_url}")
    logger.info(f"Output directory: {output_dir}")

    # Create environments config
    output_dir.mkdir(parents=True, exist_ok=True)
    env_config = {
        "environments": {
            "source": {
                "name": "source",
                "url": source_url,
                "token": source_token,
            }
        }
    }
    env_file = output_dir / "environments.yaml"
    with open(env_file, "w") as f:
        yaml.dump(env_config, f, default_flow_style=False)

    # Build monaco command
    cmd = [
        "monaco", "download",
        "--environment", "source",
        "--config-file", str(env_file),
        "--output-folder", str(output_dir),
    ]

    if config_types:
        for config_type in config_types.split(","):
            config_type = config_type.strip()
            if config_type:
                cmd.extend(["--config-type", config_type])

    logger.info(f"Running: {' '.join(cmd)}")

    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode == 0:
        logger.info("Configuration cloned successfully")
        logger.info(f"Location: {output_dir.resolve()}")
        print()
        print("Next steps:")
        print(f"1. Review the configuration: ls -la {output_dir}")
        print("2. Customize as needed")
        print(f"3. Deploy with: monaco deploy --environment target --config-file {env_file} {output_dir}")
        return True
    else:
        logger.error("Failed to clone configuration")
        if result.stderr:
            logger.error(result.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Clone Monaco configuration from a source tenant"
    )
    parser.add_argument("source_url", help="Source Dynatrace tenant URL")
    parser.add_argument("source_token", help="Source tenant API token")
    parser.add_argument(
        "--config-types",
        default="",
        help="Comma-separated list of config types (e.g., dashboard,alerting-profiles)",
    )

    args = parser.parse_args()

    success = clone_configuration(args.source_url, args.source_token, args.config_types)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
