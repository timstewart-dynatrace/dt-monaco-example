#!/usr/bin/env python3
"""
Dynatrace Monaco Configuration Migration Script

This script clones and migrates Dynatrace configuration from a source tenant
to a target tenant using Monaco.

Usage:
    python migrate.py [OPTIONS]

Examples:
    # Using environment variables
    python migrate.py

    # Using command-line arguments
    python migrate.py \\
        --source https://source.live.dynatrace.com \\
        --target https://target.live.dynatrace.com \\
        --source-token YOUR_TOKEN \\
        --target-token YOUR_TOKEN

    # Dry run (preview changes)
    python migrate.py --dry-run

    # Specific configuration types
    python migrate.py --config-types dashboards,alerting-profiles
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import yaml
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'migration_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class MonacoMigration:
    """Handle configuration migration between Dynatrace tenants using Monaco."""

    # Supported configuration types in Monaco
    SUPPORTED_CONFIG_TYPES = [
        'alerting-profiles',
        'app-detection-rule',
        'auto-tag',
        'calculated-metrics-log',
        'calculated-metrics-service',
        'calculated-synthetic-events',
        'credential',
        'custom-app-configs',
        'custom-app-crashes-allowlist',
        'dashboard',
        'extension',
        'host-monitoring-advanced-configuration',
        'kubernetes-app',
        'log-custom-source',
        'log-events-to-metric-v2',
        'log-processing-rule',
        'management-zone',
        'notification',
        'request-naming',
        'service-detection-rule',
        'settings',
        'synthetic-location',
        'synthetic-monitor',
    ]

    def __init__(self,
                 source_url: str,
                 target_url: str,
                 source_token: str,
                 target_token: str,
                 config_dir: str = 'config',
                 dry_run: bool = False,
                 config_types: Optional[List[str]] = None):
        """
        Initialize the migration handler.

        Args:
            source_url: Source Dynatrace tenant URL
            target_url: Target Dynatrace tenant URL
            source_token: API token for source tenant
            target_token: API token for target tenant
            config_dir: Directory to store configuration
            dry_run: If True, preview changes without applying them
            config_types: List of specific config types to migrate (all if None)
        """
        self.source_url = source_url.rstrip('/')
        self.target_url = target_url.rstrip('/')
        self.source_token = source_token
        self.target_token = target_token
        self.config_dir = Path(config_dir)
        self.dry_run = dry_run
        self.config_types = config_types or self.SUPPORTED_CONFIG_TYPES
        self.backup_dir = self.config_dir / f'backups/{datetime.now().strftime("%Y%m%d_%H%M%S")}'

        # Validate configuration types
        invalid_types = set(self.config_types) - set(self.SUPPORTED_CONFIG_TYPES)
        if invalid_types:
            raise ValueError(f'Invalid configuration types: {invalid_types}')

    def verify_monaco_installed(self) -> bool:
        """Check if Monaco is installed and accessible."""
        try:
            result = subprocess.run(['monaco', '--version'], capture_output=True, text=True)
            logger.info(f'Monaco version: {result.stdout.strip()}')
            return result.returncode == 0
        except FileNotFoundError:
            logger.error('Monaco CLI not found. Please install Monaco first.')
            logger.error('See README.md for installation instructions.')
            return False

    def verify_api_connection(self) -> bool:
        """Verify connection to both Dynatrace tenants."""
        logger.info('Verifying API connections...')

        # Check source tenant
        if not self._verify_tenant_connection(self.source_url, self.source_token, 'source'):
            return False

        # Check target tenant
        if not self._verify_tenant_connection(self.target_url, self.target_token, 'target'):
            return False

        logger.info('✓ API connections verified successfully')
        return True

    def _verify_tenant_connection(self, url: str, token: str, tenant_name: str) -> bool:
        """Verify connection to a specific tenant."""
        try:
            import requests
            headers = {'Authorization': f'Api-Token {token}'}
            response = requests.get(f'{url}/api/v2/environments', headers=headers, timeout=10)

            if response.status_code == 200:
                logger.info(f'✓ {tenant_name} tenant connection verified')
                return True
            else:
                logger.error(f'✗ {tenant_name} tenant returned status {response.status_code}')
                return False
        except Exception as e:
            logger.error(f'✗ Error connecting to {tenant_name} tenant: {e}')
            return False

    def create_environments_yaml(self) -> Path:
        """Create environments.yaml configuration file for Monaco."""
        self.config_dir.mkdir(parents=True, exist_ok=True)

        environments_config = {
            'environments': {
                'source': {
                    'name': 'source',
                    'url': self.source_url,
                    'token': self.source_token,
                },
                'target': {
                    'name': 'target',
                    'url': self.target_url,
                    'token': self.target_token,
                }
            }
        }

        env_file = self.config_dir / 'environments.yaml'
        with open(env_file, 'w') as f:
            yaml.dump(environments_config, f, default_flow_style=False)

        logger.info(f'Created environments configuration: {env_file}')
        return env_file

    def download_configuration(self, environment: str, target_dir: Optional[Path] = None) -> bool:
        """
        Download configuration from a tenant using Monaco.

        Args:
            environment: Environment name ('source' or 'target')
            target_dir: Directory to save configuration (uses config_dir if None)

        Returns:
            True if successful, False otherwise
        """
        if target_dir is None:
            target_dir = self.config_dir

        target_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f'Downloading configuration from {environment} environment...')

        try:
            cmd = [
                'monaco',
                'download',
                '--environment', environment,
                '--config-file', str(self.config_dir / 'environments.yaml'),
                '--output-folder', str(target_dir)
            ]

            # Add specific config types if specified
            if self.config_types != self.SUPPORTED_CONFIG_TYPES:
                for config_type in self.config_types:
                    cmd.extend(['--config-type', config_type])

            logger.debug(f'Running command: {" ".join(cmd)}')
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)

            if result.returncode == 0:
                logger.info(f'✓ Configuration downloaded successfully from {environment}')
                return True
            else:
                logger.error(f'✗ Error downloading configuration: {result.stderr}')
                return False

        except Exception as e:
            logger.error(f'✗ Exception during download: {e}')
            return False

    def validate_configuration(self, config_dir: Path) -> bool:
        """
        Validate configuration files.

        Args:
            config_dir: Directory containing configuration files

        Returns:
            True if validation passes, False otherwise
        """
        logger.info('Validating configuration...')

        try:
            # Check if config files exist
            yaml_files = list(config_dir.glob('**/*.yaml')) + list(config_dir.glob('**/*.yml'))
            if not yaml_files:
                logger.warning('No configuration files found')
                return True

            # Validate YAML syntax
            for yaml_file in yaml_files:
                try:
                    with open(yaml_file, 'r') as f:
                        yaml.safe_load(f)
                    logger.debug(f'✓ Valid YAML: {yaml_file}')
                except yaml.YAMLError as e:
                    logger.error(f'✗ Invalid YAML in {yaml_file}: {e}')
                    return False

            logger.info('✓ Configuration validation passed')
            return True

        except Exception as e:
            logger.error(f'✗ Error during validation: {e}')
            return False

    def deploy_configuration(self, config_dir: Path, environment: str) -> bool:
        """
        Deploy configuration to a tenant using Monaco.

        Args:
            config_dir: Directory containing configuration files
            environment: Target environment name

        Returns:
            True if successful, False otherwise
        """
        logger.info(f'Deploying configuration to {environment} environment...')

        if self.dry_run:
            logger.info('[DRY RUN] Configuration would be deployed (not actually deploying)')
            return True

        try:
            cmd = [
                'monaco',
                'deploy',
                '--environment', environment,
                '--config-file', str(self.config_dir / 'environments.yaml'),
                config_dir,
            ]

            logger.debug(f'Running command: {" ".join(cmd)}')
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)

            if result.returncode == 0:
                logger.info(f'✓ Configuration deployed successfully to {environment}')
                return True
            else:
                logger.error(f'✗ Error deploying configuration: {result.stderr}')
                return False

        except Exception as e:
            logger.error(f'✗ Exception during deployment: {e}')
            return False

    def backup_target_configuration(self) -> Optional[Path]:
        """Create a backup of the target tenant configuration before migration."""
        logger.info('Creating backup of target configuration...')

        self.backup_dir.mkdir(parents=True, exist_ok=True)

        if self.download_configuration('target', self.backup_dir):
            logger.info(f'✓ Backup created at: {self.backup_dir}')
            return self.backup_dir
        else:
            logger.warning('Failed to create backup (continuing with migration)')
            return None

    def migrate(self) -> bool:
        """Execute the complete migration process."""
        logger.info('=' * 60)
        logger.info('Starting Dynatrace Configuration Migration')
        logger.info('=' * 60)

        if self.dry_run:
            logger.info('[DRY RUN MODE] No changes will be applied')

        # Step 1: Verify Monaco installation
        if not self.verify_monaco_installed():
            return False

        # Step 2: Create environments configuration
        try:
            self.create_environments_yaml()
        except Exception as e:
            logger.error(f'Failed to create environments configuration: {e}')
            return False

        # Step 3: Verify API connections
        if not self.verify_api_connection():
            return False

        # Step 4: Backup target configuration
        if not self.dry_run:
            self.backup_target_configuration()

        # Step 5: Download source configuration
        source_config_dir = self.config_dir / 'source'
        if not self.download_configuration('source', source_config_dir):
            return False

        # Step 6: Validate configuration
        if not self.validate_configuration(source_config_dir):
            logger.error('Configuration validation failed')
            return False

        # Step 7: Deploy to target
        if not self.deploy_configuration(source_config_dir, 'target'):
            return False

        logger.info('=' * 60)
        logger.info('✓ Migration completed successfully!')
        logger.info('=' * 60)
        return True


def main() -> None:
    """Parse arguments and execute migration."""
    parser = argparse.ArgumentParser(
        description='Migrate Dynatrace configuration between tenants using Monaco'
    )

    parser.add_argument('--source', help='Source Dynatrace tenant URL',
                        default=os.getenv('SOURCE_TENANT_URL'))
    parser.add_argument('--target', help='Target Dynatrace tenant URL',
                        default=os.getenv('TARGET_TENANT_URL'))
    parser.add_argument('--source-token', help='Source tenant API token',
                        default=os.getenv('SOURCE_TENANT_TOKEN'))
    parser.add_argument('--target-token', help='Target tenant API token',
                        default=os.getenv('TARGET_TENANT_TOKEN'))
    parser.add_argument('--config-dir', default='config',
                        help='Directory to store configuration (default: config)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Preview changes without applying them')
    parser.add_argument('--config-types',
                        help='Comma-separated list of configuration types to migrate (all if not specified)')
    parser.add_argument('--list-types', action='store_true',
                        help='List all available configuration types and exit')

    args = parser.parse_args()

    # Handle --list-types flag
    if args.list_types:
        print('\nAvailable Configuration Types:\n')
        print(f"{'Type':<45} {'Description'}")
        print('-' * 85)
        config_descriptions = {
            'alerting-profiles': 'Alert notification rules',
            'app-detection-rule': 'Application detection rules',
            'auto-tag': 'Auto-tagging rules',
            'calculated-metrics-log': 'Calculated metrics for logs',
            'calculated-metrics-service': 'Calculated metrics for services',
            'calculated-synthetic-events': 'Calculated synthetic events',
            'credential': 'Stored credentials',
            'custom-app-configs': 'Custom app configurations',
            'custom-app-crashes-allowlist': 'Custom app crash allowlists',
            'dashboard': 'Gen3 dashboards',
            'extension': 'Extensions',
            'host-monitoring-advanced-configuration': 'Host monitoring advanced config',
            'kubernetes-app': 'Kubernetes app monitoring',
            'log-custom-source': 'Custom log sources',
            'log-events-to-metric-v2': 'Log event to metric rules',
            'log-processing-rule': 'Log processing rules',
            'management-zone': 'Management zones',
            'notification': 'Notification configurations',
            'request-naming': 'Request naming rules',
            'service-detection-rule': 'Service detection rules',
            'settings': 'Settings (various)',
            'synthetic-location': 'Synthetic test locations',
            'synthetic-monitor': 'Synthetic monitors',
        }
        for config_type in MonacoMigration.SUPPORTED_CONFIG_TYPES:
            desc = config_descriptions.get(config_type, 'Configuration type')
            print(f'{config_type:<45} {desc}')
        print()
        return 0

    # Validate required arguments
    if not all([args.source, args.target, args.source_token, args.target_token]):
        logger.error('Missing required arguments')
        logger.error('Please provide source and target URLs and API tokens via arguments or .env file')
        parser.print_help()
        return 1

    # Parse config types
    config_types = None
    if args.config_types:
        config_types = [ct.strip() for ct in args.config_types.split(',')]

    try:
        migration = MonacoMigration(
            source_url=args.source,
            target_url=args.target,
            source_token=args.source_token,
            target_token=args.target_token,
            config_dir=args.config_dir,
            dry_run=args.dry_run,
            config_types=config_types
        )

        success = migration.migrate()
        return 0 if success else 1

    except Exception as e:
        logger.error(f'Fatal error: {e}', exc_info=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
