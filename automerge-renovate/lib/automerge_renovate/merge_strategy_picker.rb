# frozen_string_literal: true

module AutomergeRenovate
  # Choisit la première stratégie de merge autorisée par le repo (rebase > squash > merge).
  class MergeStrategyPicker
    def initialize(settings)
      @settings = settings
    end

    PREFERENCE = {
      rebase: "allow_rebase_merge",
      squash: "allow_squash_merge",
      merge: "allow_merge_commit",
    }.freeze

    def pick
      PREFERENCE.find { |_strategy, key| @settings[key] }&.first
    end
  end
end
