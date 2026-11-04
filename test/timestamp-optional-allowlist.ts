import type { AllowlistEntry } from './timestamp-optional';

// Règles autorisées à porter minimumReleaseAgeBehaviour=timestamp-optional.
// Chaque entrée dit pourquoi elle existe et quel ticket doit la retirer.
export const timestampOptionalAllowlist: AllowlistEntry[] = [
  // npm fournit des dates pour @alveole/* et les majeures Expo. À retirer par #3948.
  { preset: 'preset/groupAlveole.json', groupName: '[NPM] Alveole' },
  { preset: 'preset/groupExpo.json', matchUpdateTypes: ['major'] },
  // Images officielles datées ; seules nos images *-ci GHCR n'ont pas de date, exemptées par #3949. À retirer par #3947.
  { preset: 'preset/groupNode.json', groupName: 'Node (CI and Lang)' },
  { preset: 'preset/groupRuby.json', groupName: 'Ruby (CI and Lang)' },
  // Lock file maintenance sans date exploitable : exception temporaire jusqu'au déploiement chez Mend de
  // https://github.com/renovatebot/renovate/issues/47542 (pnpm) et https://github.com/renovatebot/renovate/issues/47500 (npm).
  { preset: 'preset/digest.json', matchUpdateTypes: ['lockFileMaintenance'] },
];
