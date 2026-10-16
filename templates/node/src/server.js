// SPDX-FileCopyrightText: 2026 [Author/Organization]
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Lightweight local web server using Hono adhering to localhost binding, W3C CSP, launch token auth, and browser automation.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { loadPreset, savePreset } from './config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Instantiate and configure an authenticated, security-hardened Hono application instance.
 *
 * @param {string} [authToken] - Optional pre-shared 256-bit hexadecimal launch token.
 * @returns {{ app: Hono, serverToken: string }} Configured Hono app and active token.
 */
export function createApp(authToken) {
  const app = new Hono();
  const serverToken = authToken || crypto.randomBytes(32).toString('hex');

  // W3C CSP & Security Headers Middleware
  app.use('*', async (c, next) => {
    await next();
    // SECURITY: Disallow framing, MIME-sniffing, and external CDNs
    c.header(
      'Content-Security-Policy',
      "default-src 'self'; script-src 'self' 'unsafe-inline'; " +
      "style-src 'self' 'unsafe-inline'; img-src 'self' data:; " +
      "object-src 'none'; frame-ancestors 'none';"
    );
    c.header('X-Content-Type-Options', 'nosniff');
    c.header('X-Frame-Options', 'DENY');
    c.header('Referrer-Policy', 'no-referrer');
  });

  /**
   * Verify the ephemeral launch token from query parameters, authorization header, or cookie.
   *
   * @param {import('hono').Context} c - Hono request context.
   * @returns {boolean} True if the client presents a valid token, False otherwise.
   */
  function isAuthorized(c) {
    const queryToken = c.req.query('token');
    const authHeader = c.req.header('Authorization');
    const bearerToken = authHeader && authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    const cookieHeader = c.req.header('Cookie') || '';
    const sessionCookie = cookieHeader.split(';').map(s => s.trim()).find(s => s.startsWith('mytool_session='));
    const cookieToken = sessionCookie ? sessionCookie.split('=')[1] : null;

    const candidate = queryToken || bearerToken || cookieToken;
    if (!candidate) return false;
    try {
      // SECURITY: timingSafeEqual prevents timing side-channel attacks on the launch token
      return crypto.timingSafeEqual(Buffer.from(candidate), Buffer.from(serverToken));
    } catch {
      return false;
    }
  }

  // Root Web Page
  app.get('/', (c) => {
    const queryToken = c.req.query('token');
    if (queryToken && crypto.timingSafeEqual(Buffer.from(queryToken), Buffer.from(serverToken))) {
      c.header('Set-Cookie', `mytool_session=${queryToken}; HttpOnly; SameSite=Strict; Path=/`);
    } else if (!isAuthorized(c)) {
      return c.html('<h3>401 Unauthorized</h3><p>Please use the authenticated launch URL printed in terminal.</p>', 401);
    }

    const htmlPath = path.join(__dirname, 'web', 'index.html');
    const htmlContent = fs.readFileSync(htmlPath, 'utf-8');
    return c.html(htmlContent);
  });

  // REST API Endpoints
  app.get('/api/preset', (c) => {
    if (!isAuthorized(c)) return c.json({ error: 'Unauthorized' }, 401);
    return c.json(loadPreset('default'));
  });

  app.post('/api/preset', async (c) => {
    if (!isAuthorized(c)) return c.json({ error: 'Unauthorized' }, 401);
    try {
      const body = await c.req.json();
      const savedPath = savePreset(body);
      return c.json({ status: 'ok', path: savedPath });
    } catch (err) {
      return c.json({ error: err.message }, 400);
    }
  });

  return { app, serverToken };
}

/**
 * Format a URL as an OSC 8 clickable terminal hyperlink with plain-text fallback.
 *
 * @param {string} url - Destination URL.
 * @param {string} [text=null] - Optional display text.
 * @param {NodeJS.WriteStream} [stream=process.stderr] - Target output stream.
 * @returns {string} OSC 8 formatted ANSI string or plain URL string.
 */
export function formatClickableUrl(url, text = null, stream = process.stderr) {
  const display = text || url;
  if (process.env.NO_COLOR || !stream.isTTY) {
    return text ? `${display} (${url})` : display;
  }
  // Terminal OSC 8 escape sequence: \x1b]8;;<URL>\x1b\\<TEXT>\x1b]8;;\x1b\\
  return `\u001b]8;;${url}\u001b\\${display}\u001b]8;;\u001b\\`;
}

/**
 * Open a URL in the user's default browser unless suppressed or running headless.
 *
 * @param {string} url - Destination URL.
 * @param {boolean} [noBrowser=false] - Whether automatic opening is suppressed.
 * @returns {boolean} True if browser launch was dispatched, False otherwise.
 */
export function openBrowser(url, noBrowser = false) {
  if (noBrowser || process.env.CI === 'true') return false;
  // Suppress launch in headless Linux environments lacking a display server
  if (process.platform === 'linux' && !process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) {
    return false;
  }

  let cmd;
  let args;
  if (process.platform === 'darwin') {
    cmd = 'open';
    args = [url];
  } else if (process.platform === 'win32') {
    cmd = 'cmd.exe';
    args = ['/c', 'start', '""', url];
  } else {
    cmd = 'xdg-open';
    args = [url];
  }

  try {
    const child = spawn(cmd, args, { stdio: 'ignore', detached: true });
    child.unref();
    return true;
  } catch (err) {
    process.stderr.write(`[mytool-node] Notice: Could not launch browser: ${err.message}\n`);
    return false;
  }
}

/**
 * Launch the local HTTP server strictly bound to localhost.
 *
 * @param {number} [port=8080] - Port number to bind.
 * @param {string} [host='127.0.0.1'] - Host interface to bind.
 * @param {boolean} [noBrowser=false] - Suppress automatic browser launch.
 */
export function runLocalServer(port = 8080, host = '127.0.0.1', noBrowser = false) {
  const token = crypto.randomBytes(32).toString('hex');
  const { app } = createApp(token);

  const launchUrl = `http://${host}:${port}/?token=${token}`;
  const clickableUrl = formatClickableUrl(launchUrl, null, process.stderr);

  // Print launch token exclusively to stderr to leave stdout clean for piping
  process.stderr.write(`\n[mytool-node] Local server running at: ${clickableUrl}\n`);
  process.stderr.write(`[mytool-node] Bound strictly to localhost for privacy and security. Press Ctrl+C to exit.\n\n`);

  // Automatically launch browser window unless suppressed or running headless
  openBrowser(launchUrl, noBrowser);

  serve({
    fetch: app.fetch,
    port,
    hostname: host,
  });
}
