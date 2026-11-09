import type { AllowlistEntry } from './timestamp-optional';

// Règles autorisées à porter minimumReleaseAgeBehaviour=timestamp-optional.
// Chaque entrée dit pourquoi elle existe et quel ticket doit la retirer.
export const timestampOptionalAllowlist: AllowlistEntry[] = [
  // Lock file maintenance sans date exploitable : exception temporaire, tickets Renovate dans la description de la règle.
  { preset: 'preset/digest.json', matchUpdateTypes: ['lockFileMaintenance'] },
  // Digests : le check de branche ignore la date du tag, exception temporaire jusqu'à renovatebot/renovate#46645.
  { preset: 'preset/digest.json', matchUpdateTypes: ['digest', 'pinDigest'] },
];
