import type { AllowlistEntry } from './timestamp-optional';

// Règles autorisées à porter minimumReleaseAgeBehaviour=timestamp-optional.
// Chaque entrée dit pourquoi elle existe et quel ticket doit la retirer.
export const timestampOptionalAllowlist: AllowlistEntry[] = [
  // Contournement de l'incident Flux (5915d6c) : une source sans date passe sans délai.
  // npm et les registres officiels fournissent des dates, le mode optionnel n'y sert à rien. À retirer par #3948.
  { preset: 'base.json', matchUpdateTypes: ['major'] },
  { preset: 'base.json', matchUpdateTypes: ['minor'] },
  { preset: 'base.json', matchUpdateTypes: ['patch'] },
  // npm fournit des dates pour @alveole/* et les majeures Expo. À retirer par #3948.
  { preset: 'preset/groupAlveole.json', groupName: '[NPM] Alveole' },
  { preset: 'preset/groupExpo.json', matchUpdateTypes: ['major'] },
  // Images officielles datées ; seules nos images *-ci GHCR n'ont pas de date, exemptées par #3949. À retirer par #3947.
  { preset: 'preset/groupNode.json', groupName: 'Node (CI and Lang)' },
  { preset: 'preset/groupRuby.json', groupName: 'Ruby (CI and Lang)' },
  // GHCR n'expose pas de dates (renovatebot/renovate#39064), exemption trop large de ghcr.io/**.
  // À remplacer par #3949 par minimumReleaseAge: null sur ghcr.io/captive-studio/** uniquement.
  { preset: 'preset/ghcr.json', matchPackageNames: ['ghcr.io/**'] },
  // Digests et lock file maintenance sans date exploitable. À réduire par #3950 à la seule lockFileMaintenance,
  // exception temporaire jusqu'au déploiement de renovatebot/renovate#47542 (pnpm) et #47500 (npm) chez Mend.
  { preset: 'preset/digest.json', matchUpdateTypes: ['digest', 'pinDigest', 'lockFileMaintenance'] },
];
