# frozen_string_literal: true

require_relative "automerge_status"
require_relative "checks_evaluator"
require_relative "merge_strategy_picker"
require_relative "rebase_need"
require_relative "release_age_gate"

module AutomergeRenovate
  # Décide de l'action à appliquer à une PR Renovate donnée (merge, rebase, ou skip + raison).
  class PrDecision
    REBASE_REQUESTED = { action: :rebase_requested }.freeze
    RED_CHECKS_SKIP = {
      action: :skip, reason: "checks non verts", needs_investigation: true,
    }.freeze
    PENDING_CHECKS_SKIP = { action: :skip, reason: "checks en cours" }.freeze
    RELEASE_AGE_SKIP = { action: :skip, reason: "version trop récente (minimumReleaseAge)" }.freeze

    def initialize(pr, merge_settings)
      @pr = pr
      @merge_settings = merge_settings
    end

    def call
      return automerge_disabled_skip unless automerge_enabled?
      return REBASE_REQUESTED if rebase_needed?
      return RED_CHECKS_SKIP if checks.red_checks.any?
      return RELEASE_AGE_SKIP if ReleaseAgeGate.new(@pr["statusCheckRollup"]).pending?
      return PENDING_CHECKS_SKIP unless checks_green?
      return REBASE_REQUESTED unless merge_state_status == "CLEAN"

      merge_or_skip
    end

    private

    def merge_state_status
      @pr["mergeStateStatus"]
    end

    def rebase_needed?
      RebaseNeed.new(@pr).needed? && !mergeable_while_behind?
    end

    # Sans exigence de branche à jour, GitHub fusionne une branche en retard (CLEAN) : une PR verte
    # est fusionnée tout de suite plutôt qu'après un rebase et une nouvelle CI.
    def mergeable_while_behind?
      merge_state_status == "CLEAN" && checks_green?
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
      checks.all_green?
    end

    def checks
      ChecksEvaluator.new(@pr["statusCheckRollup"].to_a)
    end
  end
end
