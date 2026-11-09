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

export const matchesPackage = ({ matchPackageNames, matchPackagePrefixes, matchPackagePatterns }: PackageMatchers, packageName: string) =>
  (!matchPackageNames || matchPackageNames.some((pattern) => matchesName(pattern, packageName))) &&
  (!matchPackagePrefixes || matchPackagePrefixes.some((prefix) => packageName.startsWith(prefix))) &&
  (!matchPackagePatterns || matchPackagePatterns.some((pattern) => new RegExp(pattern).test(packageName)));

const matchesUpdateType = ({ matchUpdateTypes }: { matchUpdateTypes?: string[] }, updateType?: string) =>
  !matchUpdateTypes || (updateType !== undefined && matchUpdateTypes.includes(updateType));

export const effectiveMinimumReleaseAge = (rules: Rule[], packageName: string, updateType?: string) =>
  rules
    .filter((rule) => 'minimumReleaseAge' in rule && matchesPackage(rule as PackageMatchers, packageName))
    .filter((rule) => matchesUpdateType(rule, updateType))
    .at(-1)?.minimumReleaseAge;

const mentionsNamespace = (pattern: string, namespace: string) =>
  pattern.startsWith(namespace) || (pattern.startsWith('/') && pattern.includes(namespace.slice(0, -1)));

// Vrai si une règle vise un paquet du namespace, quelle que soit la forme du motif (nom exact, glob, regex).
export const targetsNamespace = (
  { matchPackageNames = [], matchPackagePrefixes = [], matchPackagePatterns = [] }: PackageMatchers,
  namespace: string,
) =>
  [...matchPackageNames, ...matchPackagePrefixes].some((pattern) => mentionsNamespace(pattern, namespace)) ||
  matchPackagePatterns.some((pattern) => pattern.includes(namespace.slice(0, -1)));
