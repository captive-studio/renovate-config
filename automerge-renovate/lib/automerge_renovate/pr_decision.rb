# frozen_string_literal: true

require_relative "automerge_status"
require_relative "checks_evaluator"
require_relative "merge_strategy_picker"

module AutomergeRenovate
  # Décide de l'action à appliquer à une PR Renovate donnée (merge, rebase, ou skip + raison).
  class PrDecision
    def initialize(pr, merge_settings)
      @pr = pr
      @merge_settings = merge_settings
    end

    def call
      merge_state_status = @pr["mergeStateStatus"]

      unless automerge_enabled?
        if checks_green?
          return { action: :skip, reason: "automerge désactivé", needs_decision: true }
        end

        return { action: :skip, reason: "automerge désactivé", needs_decision_red: true }
      end

      return { action: :rebase_requested } if merge_state_status == "BEHIND"
      unless checks_green?
        return { action: :skip, reason: "checks non verts", needs_investigation: true }
      end
      return { action: :rebase_requested } unless merge_state_status == "CLEAN"

      strategy = MergeStrategyPicker.new(@merge_settings).pick
      return { action: :skip, reason: "aucune stratégie de merge autorisée" } unless strategy

      { action: :merge, strategy: strategy }
    end

    private

    def automerge_enabled?
      AutomergeStatus.new(@pr["body"]).enabled?
    end

    def checks_green?
      ChecksEvaluator.new(@pr["statusCheckRollup"]).all_green?
    end
  end
end
