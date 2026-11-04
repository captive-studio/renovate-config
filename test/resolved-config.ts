import type { Rule } from './timestamp-optional';
import { parsePreset } from './published-presets';

const localPreset = /^github>captive-studio\/renovate-config(?:\/\/|:)(.+)$/;

const localFile = (preset: string) => {
  const match = localPreset.exec(preset);
  return match ? [`${match[1]}.json`] : [];
};

// Règles dans l'ordre où Renovate les applique : celles des extends d'abord, puis celles du preset lui-même.
// Les presets externes sont ignorés.
export const resolvedPackageRules = (file: string): Rule[] => {
  const { extends: presets = [], packageRules = [] } = parsePreset(file);
  return [...(presets as string[]).flatMap(localFile).flatMap(resolvedPackageRules), ...packageRules];
};

const matchesName = (pattern: string, packageName: string) =>
  pattern.endsWith('/**') ? packageName.startsWith(pattern.slice(0, -2)) : pattern === packageName;

type PackageMatchers = { matchPackageNames?: string[]; matchPackagePrefixes?: string[]; matchPackagePatterns?: string[] };

const matchesPackage = ({ matchPackageNames, matchPackagePrefixes, matchPackagePatterns }: PackageMatchers, packageName: string) =>
  (!matchPackageNames || matchPackageNames.some((pattern) => matchesName(pattern, packageName))) &&
  (!matchPackagePrefixes || matchPackagePrefixes.some((prefix) => packageName.startsWith(prefix))) &&
  (!matchPackagePatterns || matchPackagePatterns.some((pattern) => new RegExp(pattern).test(packageName)));

export const effectiveMinimumReleaseAge = (rules: Rule[], packageName: string) =>
  rules.filter((rule) => 'minimumReleaseAge' in rule && matchesPackage(rule as PackageMatchers, packageName)).at(-1)?.minimumReleaseAge;
