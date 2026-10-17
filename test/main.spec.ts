import { describe, test, expect } from 'vitest';
import baseJSON from '../base.json';
import applicationJSON from '../application.json';
import applicationLegacyJSON from '../applicationLegacy.json';
import libraryJSON from '../library.json';
import digestJSON from '../preset/digest.json';
import groupExpoJSON from '../preset/groupExpo.json';

describe('Configuration snapshot', () => {
  test('base.json', () => {
    expect(baseJSON).toMatchSnapshot();
  });
  test('application.json', () => {
    expect(applicationJSON).toMatchSnapshot();
  });
  test('applicationLegacy.json', () => {
    expect(applicationLegacyJSON).toMatchSnapshot();
  });
  test('library.json', () => {
    expect(libraryJSON).toMatchSnapshot();
  });
});

describe('Minimum release age', () => {
  test('does not require timestamps for lock file maintenance', () => {
    expect(digestJSON.packageRules).toContainEqual({
      matchUpdateTypes: ['digest', 'pinDigest', 'lockFileMaintenance'],
      minimumReleaseAgeBehaviour: 'timestamp-optional',
    });
  });
});

describe('Expo', () => {
  test('does not update React Native packages locked by the Expo SDK', () => {
    expect(groupExpoJSON.packageRules).toContainEqual(
      expect.objectContaining({
        matchPackageNames: ['@react-native/**'],
        enabled: false,
      }),
    );
  });

  test('does not update jest-expo, locked by the Expo SDK', () => {
    expect(groupExpoJSON.packageRules).toContainEqual(
      expect.objectContaining({
        description: 'Ne pas mettre à jour les deps verrouillées par Expo',
        matchPackageNames: expect.arrayContaining(['jest-expo']),
        enabled: false,
      }),
    );
  });
});
