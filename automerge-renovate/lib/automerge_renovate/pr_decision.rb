# frozen_string_literal: true

require_relative "automerge_status"
require_relative "checks_evaluator"
require_relative "merge_strategy_picker"

module AutomergeRenovate
  # Décide de l'action à appliquer à une PR Renovate donnée (merge, rebase, ou skip + raison).
  class PrDecision
    # Statuts que Renovate corrige en régénérant la branche : retard sur la base, ou conflit.
    REBASABLE_STATUSES = %w[BEHIND DIRTY].freeze
    REBASE_REQUESTED = { action: :rebase_requested }.freeze
    RED_CHECKS_SKIP = {
      action: :skip, reason: "checks non verts", needs_investigation: true,
    }.freeze

    def initialize(pr, merge_settings)
      @pr = pr
      @merge_settings = merge_settings
    end

    def call
      return automerge_disabled_skip unless automerge_enabled?
      return REBASE_REQUESTED if REBASABLE_STATUSES.include?(merge_state_status)
      return RED_CHECKS_SKIP unless checks_green?
      return REBASE_REQUESTED unless merge_state_status == "CLEAN"

      merge_or_skip
    end

    private

    def merge_state_status
      @pr["mergeStateStatus"]
    end

    def automerge_disabled_skip
      flag = checks_green? ? :needs_decision : :needs_decision_red
      { action: :skip, reason: "automerge désactivé", flag => true }
    end

    def merge_or_skip
      strategy = MergeStrategyPicker.new(@merge_settings).pick
      return { action: :skip, reason: "aucune stratégie de merge autorisée" } unless strategy

      { action: :merge, strategy: strategy }
    end

    def automerge_enabled?
      AutomergeStatus.new(@pr["body"]).enabled?
    end

    def checks_green?
      ChecksEvaluator.new(@pr["statusCheckRollup"]).all_green?
    end
  end
end
