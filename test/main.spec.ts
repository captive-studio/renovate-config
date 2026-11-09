import { describe, test, expect } from 'vitest';
import baseJSON from '../base.json';
import applicationJSON from '../application.json';
import applicationLegacyJSON from '../applicationLegacy.json';
import libraryJSON from '../library.json';
import digestJSON from '../preset/digest.json';
import minimumReleaseAgeJSON from '../preset/minimumReleaseAge.json';
import groupExpoJSON from '../preset/groupExpo.json';
import expoJSON from '../preset/expo.json';
import ghcrJSON from '../preset/ghcr.json';

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
  test('does not delay digest updates of our captive-studio images', () => {
    expect(digestJSON.packageRules).toContainEqual(
      expect.objectContaining({
        matchUpdateTypes: ['digest', 'pinDigest'],
        matchPackageNames: ['captive-studio/**', 'ghcr.io/captive-studio/**'],
        minimumReleaseAge: null,
      }),
    );
  });

  test('does not require timestamps for lock file maintenance', () => {
    expect(digestJSON.packageRules).toContainEqual(
      expect.objectContaining({
        matchUpdateTypes: ['lockFileMaintenance'],
        minimumReleaseAgeBehaviour: 'timestamp-optional',
      }),
    );
  });

  test.each([
    ['patch', '2 days'],
    ['minor', '2 days'],
    ['major', '7 days'],
  ])('delays %s updates of every dependency by %s, strictly', (updateType, minimumReleaseAge) => {
    expect(minimumReleaseAgeJSON.packageRules).toContainEqual({
      matchUpdateTypes: [updateType],
      minimumReleaseAge,
    });
  });
});

describe('GHCR', () => {
  test('exempts only our own GHCR images from the release age delay', () => {
    expect(ghcrJSON.packageRules.map(({ description: _, ...rule }) => rule)).toEqual([
      { matchPackageNames: ['ghcr.io/captive-studio/**'], minimumReleaseAge: null },
    ]);
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

  test.each(['jest-expo', 'babel-preset-expo'])('does not update %s, locked by the Expo SDK', (packageName) => {
    expect(groupExpoJSON.packageRules).toContainEqual(
      expect.objectContaining({
        description: 'Ne pas mettre à jour les deps verrouillées par Expo',
        matchPackageNames: expect.arrayContaining([packageName]),
        enabled: false,
      }),
    );
  });
});

describe('Expo preset', () => {
  test('does not update React Native packages locked by the Expo SDK', () => {
    expect(expoJSON.packageRules).toContainEqual(
      expect.objectContaining({
        matchPackageNames: ['@react-native/**'],
        enabled: false,
      }),
    );
  });

  test.each(['jest-expo', 'babel-preset-expo'])('does not update %s, locked by the Expo SDK', (packageName) => {
    expect(expoJSON.packageRules).toContainEqual(
      expect.objectContaining({
        description: 'Ne pas mettre à jour les deps verrouillées par Expo',
        matchPackageNames: expect.arrayContaining([packageName]),
        enabled: false,
      }),
    );
  });
});
