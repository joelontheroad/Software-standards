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

// Zod Schema Definition
export const PresetSchema = z.object({
  name: z.string().default('default'),
  theme: z.enum(['auto', 'light', 'dark']).default('auto'),
  max_items: z.number().int().min(1).max(1000).default(50),
  enable_cache: z.boolean().default(true),
});

export function sanitizeLogPath(inputPath) {
  const homeDir = os.homedir();
  if (homeDir && inputPath.startsWith(homeDir)) {
    return inputPath.replace(homeDir, '~<USER>');
  }
  return inputPath;
}

export function getConfigDir() {
  const base = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
  const targetDir = path.join(base, APP_NAME);

  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true, mode: 0o700 });
  }
  return targetDir;
}

export function getPresetsDir() {
  const presetsDir = path.join(getConfigDir(), 'presets');
  if (!fs.existsSync(presetsDir)) {
    fs.mkdirSync(presetsDir, { recursive: true, mode: 0o700 });
  }
  return presetsDir;
}

export function safeResolvePresetPath(presetName) {
  let cleanName = presetName.trim();
  if (!cleanName.endsWith('.yaml')) {
    cleanName += '.yaml';
  }

  const baseDir = path.resolve(getPresetsDir());
  const targetPath = path.resolve(baseDir, cleanName);

  // Prevent path traversal escaping base directory (CWE-22)
  if (!targetPath.startsWith(baseDir)) {
    throw new Error(`Access denied: Preset '${presetName}' escapes allowed directory`);
  }

  return targetPath;
}

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

export function savePreset(presetData) {
  const validated = PresetSchema.parse(presetData);
  const presetPath = safeResolvePresetPath(validated.name);

  const yamlContent =
    `# Preset: ${validated.name}\n` +
    `# Auto-generated configuration file adhering to open-source standards.\n` +
    YAML.stringify(validated);

  // Secure write with mode 0600 (rw-------)
  fs.writeFileSync(presetPath, yamlContent, { encoding: 'utf-8', mode: 0o600 });
  return presetPath;
}

export function resetAllConfiguration() {
  const configDir = getConfigDir();
  if (fs.existsSync(configDir)) {
    fs.rmSync(configDir, { recursive: true, force: true });
  }
  loadPreset('default');
}
