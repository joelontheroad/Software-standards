#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 [Author/Organization]
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Node CLI entry point adhering to POSIX standards, stream discipline, and signal handling.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';
import {
  loadPreset,
  resetAllConfiguration,
  getPresetsDir,
} from './config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '../package.json'), 'utf-8'));

// Signal handler: Cleanly exit on SIGINT with POSIX status code 130
process.on('SIGINT', () => {
  process.stderr.write('\n[mytool-node] Interrupted by user. Exiting.\n');
  process.exit(130);
});

/**
 * Display command-line usage information and options reference on stderr.
 */
function printHelp() {
  process.stderr.write(`
mytool-node v${pkg.version} (${pkg.license})
A standard-compliant open-source Node utility.

Usage:
  mytool [options] [command]

Options:
  -h, --help        Show usage summary
  -v, --version     Show program version and license information
  --json            Output structured results in machine-readable JSON format
  --reset-config    Purge all user-saved presets and restore factory defaults

Commands:
  serve [--port N]  Launch local web interface strictly bound to localhost (127.0.0.1)
  preset list       List all locally saved presets
  preset show       Display current preset configuration
`);
}

/**
 * Primary CLI dispatcher evaluating command-line arguments and routing commands.
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.includes('-h') || args.includes('--help')) {
    printHelp();
    process.exit(0);
  }

  if (args.includes('-v') || args.includes('--version')) {
    process.stdout.write(`mytool-node ${pkg.version} (${pkg.license})\nSource: ${pkg.repository.url}\n`);
    process.exit(0);
  }

  if (args.includes('--reset-config')) {
    resetAllConfiguration();
    process.stderr.write('[mytool-node] Local configuration reset to factory defaults.\n');
    process.exit(0);
  }

  const isJson = args.includes('--json');
  const command = args[0];

  if (!command) {
    printHelp();
    process.exit(2);
  }

  if (command === 'serve') {
    // Lazy load server module to keep basic CLI startup fast (<200ms)
    const { runLocalServer } = await import('./server.js');
    const portIndex = args.indexOf('--port');
    const port = portIndex !== -1 ? parseInt(args[portIndex + 1], 10) : 8080;
    runLocalServer(port, '127.0.0.1');
    return;
  }

  if (command === 'preset') {
    const action = args[1];
    if (action === 'list') {
      const presetsDir = getPresetsDir();
      const files = fs.readdirSync(presetsDir).filter(f => f.endsWith('.yaml')).map(f => path.basename(f, '.yaml'));
      if (isJson) {
        process.stdout.write(JSON.stringify({ presets: files }, null, 2) + '\n');
      } else {
        files.forEach(f => process.stdout.write(`- ${f}\n`));
      }
      process.exit(0);
    }

    if (action === 'show' || !action) {
      const preset = loadPreset('default');
      if (isJson) {
        process.stdout.write(JSON.stringify(preset, null, 2) + '\n');
      } else {
        process.stdout.write(YAML.stringify(preset) + '\n');
      }
      process.exit(0);
    }
  }

  printHelp();
  process.exit(2);
}

main().catch((err) => {
  process.stderr.write(`Error: ${err.message}\n`);
  process.exit(1);
});
