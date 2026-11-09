import { describe, test, expect } from 'vitest';
import { effectiveMinimumReleaseAge, resolvedPackageRules, targetsNamespace } from './resolved-config';

const presets = ['base.json', 'recommended.json', 'application.json', 'library.json'];
const images = ['actions-runner', 'node-ci', 'ruby-ci'];

describe('Our GHCR images in the resolved configuration', () => {
  test.each(presets.flatMap((preset) => images.map((image) => [preset, image])))(
    '%s does not delay ghcr.io/captive-studio/%s',
    (preset, image) => {
      expect(effectiveMinimumReleaseAge(resolvedPackageRules(preset), `ghcr.io/captive-studio/${image}`)).toBeNull();
    },
  );
});

describe('Third-party digest pinning in the resolved configuration', () => {
  test.each(presets)('%s does not delay pinning the digest of a third-party image', (preset) => {
    expect(effectiveMinimumReleaseAge(resolvedPackageRules(preset), 'docker.io/library/ruby', 'pinDigest')).toBeNull();
  });
});

describe('Rules targeting a package namespace', () => {
  test.each([['@babel/core'], ['@babel/**'], ['@babel/*'], ['/^@babel\\//']])('a rule matching %s targets @babel/', (pattern) => {
    expect(targetsNamespace({ matchPackageNames: [pattern] }, '@babel/')).toBe(true);
  });
});
