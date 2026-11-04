import { isDeepStrictEqual } from 'node:util';

export type Rule =Record<string, unknown>;
type Preset = { packageRules?: Rule[] };
export type AllowlistEntry = { preset: string } & Rule;

const isAllowed = (preset: string, rule: Rule, allowlist: AllowlistEntry[]) =>
  allowlist.some(({ preset: allowedPreset, ...criteria }) =>
    allowedPreset === preset && Object.entries(criteria).every(([key, value]) => isDeepStrictEqual(rule[key], value)),
  );

export const unlistedTimestampOptionalRules = (presets: Record<string, Preset>, allowlist: AllowlistEntry[]) =>
  Object.entries(presets).flatMap(([preset, { packageRules = [] }]) =>
    packageRules
      .filter((rule) => rule.minimumReleaseAgeBehaviour === 'timestamp-optional')
      .filter((rule) => !isAllowed(preset, rule, allowlist))
      .map((rule) => ({ preset, rule })),
  );
