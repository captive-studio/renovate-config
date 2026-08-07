# frozen_string_literal: true

require_relative "automerge_status"
require_relative "checks_evaluator"
require_relative "merge_strategy_picker"
require_relative "rebase_need"

module AutomergeRenovate
  # Décide de l'action à appliquer à une PR Renovate donnée (merge, rebase, ou skip + raison).
  class PrDecision
    REBASE_REQUESTED = { action: :rebase_requested }.freeze
    RED_CHECKS_SKIP = {
      action: :skip, reason: "checks non verts", needs_investigation: true,
    }.freeze

    def initialize(pr, merge_settings)
      @pr = pr
      @merge_settings = merge_settings
    end

    def call
      return rebase_decision if rebase_needed?
      return automerge_disabled_skip unless automerge_enabled?
      return RED_CHECKS_SKIP unless checks_green?
      return REBASE_REQUESTED unless merge_state_status == "CLEAN"

      merge_or_skip
    end

    private

    def merge_state_status
      @pr["mergeStateStatus"]
    end

    def rebase_needed?
      RebaseNeed.new(@pr).needed?
    end

    # Une PR à rebaser dont l'automerge est désactivé reste une décision humaine : on la rebase
    # pour la rendre décidable, sans la sortir de la liste.
    def rebase_decision
      return REBASE_REQUESTED if automerge_enabled?

      REBASE_REQUESTED.merge(needs_decision: true)
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
