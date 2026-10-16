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

test('CLI --help documents --no-browser option', () => {
  const output = execFileSync('node', [cliPath, '--help'], { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
  assert.match(output, /--no-browser/);
});

test('formatClickableUrl and openBrowser logic', async () => {
  try {
    const { formatClickableUrl, openBrowser } = await import('../src/server.js');
    const url = 'http://127.0.0.1:8080';

    // Non-TTY stream returns plain URL
    const fakeStream = { isTTY: false };
    assert.strictEqual(formatClickableUrl(url, null, fakeStream), url);

    // TTY stream returns OSC 8 escape sequence when NO_COLOR is not set
    const fakeTTY = { isTTY: true };
    const savedNoColor = process.env.NO_COLOR;
    delete process.env.NO_COLOR;
    try {
      const osc8 = formatClickableUrl(url, null, fakeTTY);
      assert.match(osc8, /\u001b\]8;;/);
    } finally {
      if (savedNoColor !== undefined) process.env.NO_COLOR = savedNoColor;
    }

    // openBrowser returns false when noBrowser is true
    assert.strictEqual(openBrowser(url, true), false);
  } catch (err) {
    if (err.code === 'ERR_MODULE_NOT_FOUND') {
      // Package hono is uninstalled in raw template directory prior to scaffolding
      return;
    }
    throw err;
  }
});
