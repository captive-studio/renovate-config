import { configDefaults, defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Les worktrees d'agents (.claude/worktrees) contiennent des copies des tests :
    // sans cette exclusion, Vitest les exécute en double et provoque des timeouts.
    exclude: [...configDefaults.exclude, '.claude/**'],
  },
});
