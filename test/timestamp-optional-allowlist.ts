import type { AllowlistEntry } from './timestamp-optional';

// Règles autorisées à porter minimumReleaseAgeBehaviour=timestamp-optional.
// Chaque entrée dit pourquoi elle existe et quel ticket doit la retirer.
export const timestampOptionalAllowlist: AllowlistEntry[] = [
  // Lock file maintenance sans date exploitable : exception temporaire jusqu'au déploiement chez Mend de
  // https://github.com/renovatebot/renovate/issues/47542 (pnpm) et https://github.com/renovatebot/renovate/issues/47500 (npm).
  { preset: 'preset/digest.json', matchUpdateTypes: ['lockFileMaintenance'] },
];
