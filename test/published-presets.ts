import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = join(import.meta.dirname, '..');
const notPresets = new Set(['package.json', 'renovate.json']);

const jsonFilesIn = (directory: string) =>
  readdirSync(join(root, directory))
    .filter((file) => file.endsWith('.json') && !notPresets.has(file))
    .map((file) => join(directory, file));

// Renovate tolère les virgules finales (JSON5) ; JSON.parse non.
export const parsePreset =(file: string) => JSON.parse(readFileSync(join(root, file), 'utf8').replace(/,(\s*[\]}])/g, '$1'));

export const publishedPresets = () =>
  Object.fromEntries([...jsonFilesIn('.'), ...jsonFilesIn('preset')].map((file) => [file, parsePreset(file)]));
