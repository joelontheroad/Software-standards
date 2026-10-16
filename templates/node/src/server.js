// SPDX-FileCopyrightText: 2026 [Author/Organization]
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Lightweight local web server using Hono adhering to localhost binding, W3C CSP, and launch token auth.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
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
 * Launch the local HTTP server strictly bound to localhost.
 *
 * @param {number} [port=8080] - Port number to bind.
 * @param {string} [host='127.0.0.1'] - Host interface to bind.
 */
export function runLocalServer(port = 8080, host = '127.0.0.1') {
  const token = crypto.randomBytes(32).toString('hex');
  const { app } = createApp(token);

  // Print launch token exclusively to stderr to leave stdout clean for piping
  process.stderr.write(`\n[mytool-node] Local server running at: http://${host}:${port}/?token=${token}\n`);
  process.stderr.write(`[mytool-node] Bound strictly to localhost for privacy and security. Press Ctrl+C to exit.\n\n`);

  serve({
    fetch: app.fetch,
    port,
    hostname: host,
  });
}
