import { describe, test, expect } from 'vitest';
import baseJSON from '../base.json';
import applicationJSON from '../application.json';
import applicationLegacyJSON from '../applicationLegacy.json';
import libraryJSON from '../library.json';
import digestJSON from '../preset/digest.json';
import minimumReleaseAgeJSON from '../preset/minimumReleaseAge.json';
import expoJSON from '../preset/expo.json';
import ghcrJSON from '../preset/ghcr.json';
import setupRubyJSON from '../preset/setupRuby.json';
import { resolvedPackageRules, targetsNamespace } from './resolved-config';

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

  test.each([[['lockFileMaintenance']], [['digest', 'pinDigest']]])(
    'does not require timestamps for %j, whose branch check never gets one',
    (matchUpdateTypes) => {
      expect(digestJSON.packageRules).toContainEqual(
        expect.objectContaining({ matchUpdateTypes, minimumReleaseAgeBehaviour: 'timestamp-optional' }),
      );
    },
  );

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

describe('setup-ruby', () => {
  test('follows ruby/setup-ruby without delay, in a single PR, so it knows a Ruby before .ruby-version moves to it', () => {
    expect(setupRubyJSON.packageRules).toEqual([
      { matchDepNames: ['ruby/setup-ruby'], minimumReleaseAge: null, separateMultipleMinor: false, automerge: true },
    ]);
  });

  test('is applied after the release age delay and the minor split it overrides', () => {
    const extendsList = baseJSON.extends;
    const index = (preset: string) => extendsList.findIndex((entry) => entry.endsWith(preset));
    expect(index('//preset/setupRuby')).toBeGreaterThan(index('//preset/minimumReleaseAge'));
    expect(index('//preset/setupRuby')).toBeGreaterThan(index(':separateMultipleMinorReleases'));
  });
});

describe('Internal checks', () => {
  test('does not open a branch while an internal check such as the release age is pending', () => {
    expect(baseJSON).toHaveProperty('internalChecksFilter', 'strict');
  });
});

describe('GHCR', () => {
  test('exempts only our own GHCR images from the release age delay', () => {
    expect(ghcrJSON.packageRules.map(({ description: _, ...rule }) => rule)).toEqual([
      { matchPackageNames: ['ghcr.io/captive-studio/**'], minimumReleaseAge: null },
    ]);
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

  test('groups Expo SDK minor/patch updates, jest-expo included', () => {
    expect(expoJSON.packageRules).toContainEqual(
      expect.objectContaining({
        matchPackageNames: expect.arrayContaining(['jest-expo']),
        matchUpdateTypes: ['minor', 'patch'],
        groupName: 'Expo SDK',
        enabled: true,
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

describe('Expo rules stay out of the common presets', () => {
  test.each(['application.json', 'library.json'])('%s does not disable any @babel/* package', (file) => {
    expect(resolvedPackageRules(file).filter((rule) => rule.enabled === false && targetsNamespace(rule, '@babel/'))).toEqual([]);
  });

  test.each(['application.json', 'library.json'])('%s does not set a rangeStrategy on @react-navigation/*', (file) => {
    expect(resolvedPackageRules(file).filter((rule) => 'rangeStrategy' in rule && targetsNamespace(rule, '@react-navigation/'))).toEqual([]);
  });
});
