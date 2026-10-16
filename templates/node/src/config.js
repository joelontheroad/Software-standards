// SPDX-FileCopyrightText: 2026 [Author/Organization]
// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * Configuration and preset management adhering to XDG specs and Node security standards.
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import YAML from 'yaml';
import { z } from 'zod';

export const APP_NAME = 'mytool-node';

/**
 * Zod schema defining valid preset attributes and boundary constraints.
 */
export const PresetSchema = z.object({
  name: z.string().default('default'),
  theme: z.enum(['auto', 'light', 'dark']).default('auto'),
  max_items: z.number().int().min(1).max(1000).default(50),
  enable_cache: z.boolean().default(true),
});

/**
 * Scrub local username and home directory from log strings to protect user privacy.
 *
 * @param {string} inputPath - The raw filesystem path string.
 * @returns {string} Sanitized path string with home directory replaced by '~<USER>'.
 */
export function sanitizeLogPath(inputPath) {
  const homeDir = os.homedir();
  if (homeDir && inputPath.startsWith(homeDir)) {
    return inputPath.replace(homeDir, '~<USER>');
  }
  return inputPath;
}

/**
 * Return the platform-appropriate configuration directory (XDG compliant).
 * Creates the directory with mode 0700 if it does not already exist.
 *
 * @returns {string} Absolute path to the application configuration directory.
 */
export function getConfigDir() {
  const base = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
  const targetDir = path.join(base, APP_NAME);

  // SECURITY: Enforce POSIX mode 0700 (rwx------) to restrict multi-user local access
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true, mode: 0o700 });
  }
  return targetDir;
}

/**
 * Return the presets subfolder within the application configuration directory.
 *
 * @returns {string} Absolute path to the presets directory.
 */
export function getPresetsDir() {
  const presetsDir = path.join(getConfigDir(), 'presets');
  if (!fs.existsSync(presetsDir)) {
    fs.mkdirSync(presetsDir, { recursive: true, mode: 0o700 });
  }
  return presetsDir;
}

/**
 * Safely resolve a preset file path, preventing directory traversal attacks (CWE-22).
 *
 * @param {string} presetName - Identifier of the preset (with or without '.yaml' extension).
 * @returns {string} Canonicalized absolute path to the resolved preset file.
 * @throws {Error} If the target path attempts to escape the allowed presets directory.
 */
export function safeResolvePresetPath(presetName) {
  let cleanName = presetName.trim();
  if (!cleanName.endsWith('.yaml')) {
    cleanName += '.yaml';
  }

  const baseDir = path.resolve(getPresetsDir());
  const targetPath = path.resolve(baseDir, cleanName);

  // SECURITY: Prevent path traversal escaping base directory (CWE-22)
  if (!targetPath.startsWith(baseDir)) {
    throw new Error(`Access denied: Preset '${presetName}' escapes allowed directory`);
  }

  return targetPath;
}

/**
 * Load and validate a YAML preset file using safe deserialization (CWE-502).
 * If missing, generates and saves the default factory preset.
 *
 * @param {string} [presetName='default'] - Name of the preset to load.
 * @returns {import('zod').infer<typeof PresetSchema>} Validated preset configuration object.
 */
export function loadPreset(presetName = 'default') {
  const presetPath = safeResolvePresetPath(presetName);

  if (!fs.existsSync(presetPath)) {
    const defaultPreset = PresetSchema.parse({ name: presetName });
    savePreset(defaultPreset);
    return defaultPreset;
  }

  const fileContent = fs.readFileSync(presetPath, { encoding: 'utf-8' });
  const rawData = YAML.parse(fileContent) || {};
  return PresetSchema.parse(rawData);
}

/**
 * Save a preset to disk with secure POSIX permissions (mode 0600).
 *
 * @param {unknown} presetData - Raw or partial preset data to validate and persist.
 * @returns {string} Absolute path of the written preset YAML file.
 */
export function savePreset(presetData) {
  const validated = PresetSchema.parse(presetData);
  const presetPath = safeResolvePresetPath(validated.name);

  const yamlContent =
    `# Preset: ${validated.name}\n` +
    `# Auto-generated configuration file adhering to open-source standards.\n` +
    YAML.stringify(validated);

  // SECURITY: Write file with mode 0600 (rw-------) to protect user settings
  fs.writeFileSync(presetPath, yamlContent, { encoding: 'utf-8', mode: 0o600 });
  return presetPath;
}

/**
 * Purge all user-saved presets and restore factory defaults.
 */
export function resetAllConfiguration() {
  const configDir = getConfigDir();
  if (fs.existsSync(configDir)) {
    fs.rmSync(configDir, { recursive: true, force: true });
  }
  loadPreset('default');
}
