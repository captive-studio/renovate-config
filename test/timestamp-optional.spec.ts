import { describe, test, expect } from 'vitest';
import { unlistedTimestampOptionalRules } from './timestamp-optional';
import { publishedPresets } from './published-presets';
import { timestampOptionalAllowlist } from './timestamp-optional-allowlist';

describe('timestamp-optional guard', () => {
  const rule = { matchUpdateTypes: ['patch'], minimumReleaseAgeBehaviour: 'timestamp-optional' };

  test('reports a timestamp-optional rule missing from the allowlist', () => {
    expect(unlistedTimestampOptionalRules({ 'base.json': { packageRules: [rule] } }, [])).toEqual([
      { preset: 'base.json', rule },
    ]);
  });

  test('ignores a timestamp-optional rule listed in the allowlist', () => {
    const allowlist = [{ preset: 'base.json', matchUpdateTypes: ['patch'] }];
    expect(unlistedTimestampOptionalRules({ 'base.json': { packageRules: [rule] } }, allowlist)).toEqual([]);
  });

  test('published presets use timestamp-optional only where allowlisted', () => {
    expect(unlistedTimestampOptionalRules(publishedPresets(), timestampOptionalAllowlist)).toEqual([]);
  });
});
