import { describe, test, expect } from 'vitest';
import trustedMajorsJSON from '../preset/automergeTrustedMajors.json';
import denylistJSON from '../preset/automergeDenylist.json';

const collectPackageNames = (config: {
  packageRules?: { matchPackageNames?: string[] }[];
}): string[] =>
  (config.packageRules ?? []).flatMap((rule) => rule.matchPackageNames ?? []);

const findDuplicates = (values: string[]): string[] => {
  const seen = new Set<string>();
  const duplicates = new Set<string>();
  for (const value of values) {
    if (seen.has(value)) {
      duplicates.add(value);
    }
    seen.add(value);
  }
  return [...duplicates];
};

describe('Automerge lists', () => {
  test('automergeTrustedMajors.json has no duplicate package names', () => {
    expect(findDuplicates(collectPackageNames(trustedMajorsJSON))).toEqual([]);
  });

  test('automergeDenylist.json has no duplicate package names', () => {
    expect(findDuplicates(collectPackageNames(denylistJSON))).toEqual([]);
  });
});
