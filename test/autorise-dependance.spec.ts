import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, cpSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Chaque test spawn un vrai sous-processus (bash + prettier + renovate-config-validator) :
// sous contention CPU (ex: run-p avec d'autres suites), 5000ms est parfois trop juste.
vi.setConfig({ testTimeout: 15000 });

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const CLI = join(ROOT, 'bin', 'autorise-dependance');
const PRESET = join(ROOT, 'preset');
const GEMS = 'automergeRecommendedGems.json';
const NPM = 'automergeRecommendedNPM.json';
const NPM_MINOR_DESC = 'Automerge des packages de confiance, sauf en majeure';
const NPM_MAJOR_DESC = 'Automerge des packages de confiance, y compris en majeure';

type Rule = {
  description?: string;
  matchManagers?: string[];
  matchPackageNames?: string[];
  matchUpdateTypes?: string[];
  matchCurrentVersion?: string;
  allowedVersions?: string;
  automerge?: boolean;
};
type Config = { packageRules: Rule[] };

let tmp: string;

/** Joue la CLI avec une suite de réponses (une par ligne) sur les copies temporaires. */
function run(...answers: string[]): void {
  execFileSync('bash', [CLI], {
    input: answers.map((line) => `${line}\n`).join(''),
    env: { ...process.env, ADD_DEPENDENCY_PRESET_DIR: tmp, CI: '1', NO_COLOR: '1' },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
}

const readConfig = (file: string): Config => JSON.parse(readFileSync(join(tmp, file), 'utf8'));
const rawOf = (file: string): string => readFileSync(join(tmp, file), 'utf8');
const ruleFor = (cfg: Config, name: string): Rule[] =>
  cfg.packageRules.filter((r) => (r.matchPackageNames ?? []).includes(name));
const namesOfRule = (cfg: Config, desc: string): string[] =>
  cfg.packageRules.find((r) => r.description === desc)?.matchPackageNames ?? [];

beforeEach(() => {
  tmp = mkdtempSync(join(tmpdir(), 'renovate-cli-'));
  cpSync(join(PRESET, GEMS), join(tmp, GEMS));
  cpSync(join(PRESET, NPM), join(tmp, NPM));
});

afterEach(() => {
  rmSync(tmp, { recursive: true, force: true });
});

describe('CLI autorise-dependance — gems Ruby', () => {
  test('gem déjà couverte en major (tous) → exit early, fichier inchangé', () => {
    run('1', 'faraday', '1'); // ajoute major tous
    const before = rawOf(GEMS);
    run('1', 'faraday'); // plus aucun niveau actionnable
    expect(rawOf(GEMS)).toBe(before);
  });

  test('gem déjà couverte sans restriction (shoulda-matchers) → exit early', () => {
    const before = rawOf(GEMS);
    run('1', 'shoulda-matchers');
    expect(rawOf(GEMS)).toBe(before);
  });

  test('minor sur une gem exclue, on retire l’exclusion (oui)', () => {
    const wildcardBefore = readConfig(GEMS).packageRules[0].matchPackageNames;
    expect(wildcardBefore).toContain('!materialize-sass');

    run('1', 'materialize-sass', '1', '1'); // minor puis oui

    const wildcardAfter = readConfig(GEMS).packageRules[0].matchPackageNames;
    expect(wildcardAfter).not.toContain('!materialize-sass');
    expect(wildcardAfter).toContain('!rails');
  });

  test('minor sur une gem exclue, on garde l’exclusion (non) → inchangé', () => {
    const before = rawOf(GEMS);
    run('1', 'rails', '1', '2'); // minor puis non
    expect(rawOf(GEMS)).toBe(before);
  });

  test('major toutes versions : ajoute une règle major dédiée', () => {
    run('1', 'faraday', '1'); // major auto, puis tous

    const rules = ruleFor(readConfig(GEMS), 'faraday');
    expect(rules).toHaveLength(1);
    expect(rules[0]).toMatchObject({
      matchManagers: ['bundler'],
      matchUpdateTypes: ['major'],
      automerge: true,
    });
  });

  test('major ciblé (7.x → 8.x) : règle avec matchCurrentVersion + allowedVersions', () => {
    run('1', 'sidekiq', '2', '7', '8'); // major auto, puis ciblé / 7 / 8

    const rules = ruleFor(readConfig(GEMS), 'sidekiq');
    expect(rules).toHaveLength(1);
    expect(rules[0]).toMatchObject({
      matchManagers: ['bundler'],
      matchCurrentVersion: '/^7\\./',
      allowedVersions: '>=8.0.0 <9.0.0',
      automerge: true,
    });
  });

  test('major ciblé : idempotent (même montée → une seule règle)', () => {
    run('1', 'sidekiq', '2', '7', '8');
    const before = rawOf(GEMS);
    run('1', 'sidekiq', '2', '7', '8');
    expect(rawOf(GEMS)).toBe(before);
    expect(ruleFor(readConfig(GEMS), 'sidekiq')).toHaveLength(1);
  });

  test('major toutes versions : idempotent (deux passages → une seule règle)', () => {
    run('1', 'faraday', '1');
    const before = rawOf(GEMS);
    run('1', 'faraday'); // déjà couvert → exit early
    expect(rawOf(GEMS)).toBe(before);
    expect(ruleFor(readConfig(GEMS), 'faraday')).toHaveLength(1);
  });
});

describe('CLI autorise-dependance — packages npm', () => {
  test('package déjà en liste major → exit early, fichier inchangé', () => {
    const before = rawOf(NPM);
    run('2', 'uuid');
    expect(rawOf(NPM)).toBe(before);
  });

  test('minor : ajout à la liste de confiance « sauf en majeure »', () => {
    expect(namesOfRule(readConfig(NPM), NPM_MINOR_DESC)).not.toContain('lodash-es');

    run('2', 'lodash-es', '1'); // minor (choix 1 sur minor + major)

    expect(namesOfRule(readConfig(NPM), NPM_MINOR_DESC)).toContain('lodash-es');
  });

  test('déjà en liste minor seulement : propose major, pas minor', () => {
    expect(namesOfRule(readConfig(NPM), NPM_MAJOR_DESC)).not.toContain('vue');

    run('2', 'vue', '1'); // major auto, puis tous

    expect(namesOfRule(readConfig(NPM), NPM_MINOR_DESC)).toContain('vue');
    expect(namesOfRule(readConfig(NPM), NPM_MAJOR_DESC)).toContain('vue');
  });

  test('major toutes versions : ajout à la liste « y compris en majeure »', () => {
    expect(namesOfRule(readConfig(NPM), NPM_MAJOR_DESC)).not.toContain('date-fns');

    run('2', 'date-fns', '1'); // déjà en minor → major auto, puis tous

    expect(namesOfRule(readConfig(NPM), NPM_MAJOR_DESC)).toContain('date-fns');
  });

  test('major toutes versions : idempotent sur un package déjà présent → exit early', () => {
    const before = rawOf(NPM);
    run('2', 'uuid');
    expect(rawOf(NPM)).toBe(before);
  });

  test('major ciblé (4.x → 5.x) : nouvelle règle dédiée', () => {
    run('2', 'some-lib', '2', '2', '4', '5'); // major (2) puis ciblé (2) / 4 / 5

    const rules = ruleFor(readConfig(NPM), 'some-lib');
    expect(rules).toHaveLength(1);
    expect(rules[0]).toMatchObject({
      matchManagers: ['npm'],
      matchCurrentVersion: '/^4\\./',
      allowedVersions: '>=5.0.0 <6.0.0',
      automerge: true,
    });
  });
});

describe('CLI autorise-dependance — intégrité du fichier', () => {
  test('après écriture, le JSON reste valide et conserve les règles existantes', () => {
    const countBefore = readConfig(GEMS).packageRules.length;
    run('1', 'faraday', '1');
    const after = readConfig(GEMS);
    expect(after.packageRules.length).toBe(countBefore + 1);
    expect(after.packageRules[0].matchPackageNames).toContain('!rails');
  });
});
