import { describe, test, expect } from 'vitest';
import { unlistedTimestampOptionalRules } from './timestamp-optional';
import { publishedPresets } from './published-presets';
import { timestampOptionalAllowlist } from './timestamp-optional-allowlist';

describe('timestamp-optional guard', () => {
  test('reports a timestamp-optional rule missing from the allowlist', () => {
    const rule = { matchUpdateTypes: ['patch'], minimumReleaseAgeBehaviour: 'timestamp-optional' };
    expect(unlistedTimestampOptionalRules({ 'base.json': { packageRules: [rule] } }, [])).toEqual([
      { preset: 'base.json', rule },
    ]);
  });

  test('ignores a timestamp-optional rule listed in the allowlist', () => {
    const rule = { matchUpdateTypes: ['patch'], minimumReleaseAgeBehaviour: 'timestamp-optional' };
    const allowlist = [{ preset: 'base.json', matchUpdateTypes: ['patch'] }];
    expect(unlistedTimestampOptionalRules({ 'base.json': { packageRules: [rule] } }, allowlist)).toEqual([]);
  });

  test('published presets use timestamp-optional only where allowlisted', () => {
    expect(unlistedTimestampOptionalRules(publishedPresets(), timestampOptionalAllowlist)).toEqual([]);
  });
});
