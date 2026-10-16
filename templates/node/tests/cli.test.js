// SPDX-FileCopyrightText: 2026 [Author/Organization]
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Node test suite using node:test verifying CLI commands, exit codes, and path safety.
 */

import test from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { safeResolvePresetPath, sanitizeLogPath } from '../src/config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const cliPath = path.resolve(__dirname, '../src/index.js');

test('CLI --version displays AGPLv3 notice and source URL', () => {
  const output = execFileSync('node', [cliPath, '--version'], { encoding: 'utf-8' });
  assert.match(output, /AGPL-3\.0/);
  assert.match(output, /Source:/);
});

test('CLI --help exits cleanly with code 0', () => {
  const output = execFileSync('node', [cliPath, '--help'], { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
  assert.match(output, /Usage:/);
});

test('Path traversal prevention rejects escaping paths', () => {
  assert.throws(
    () => {
      safeResolvePresetPath('../../etc/passwd');
    },
    /escapes allowed directory/
  );
});

test('Sanitize log path scrubs home directory', () => {
  const home = os.homedir();
  const testPath = path.join(home, 'secret', 'project');
  const sanitized = sanitizeLogPath(testPath);
  assert.ok(!sanitized.includes(home));
  assert.ok(sanitized.startsWith('~<USER>'));
});
