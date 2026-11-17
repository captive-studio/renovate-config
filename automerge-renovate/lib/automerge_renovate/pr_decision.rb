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
    # Renovate n'a pas su mettre à jour le lockfile : relancer la CI n'y changera rien.
    ARTIFACTS_SKIP = {
      action: :skip, reason: "artefacts Renovate en échec",
      needs_investigation: true, rerunnable: false,
    }.freeze
    UNKNOWN_STATE_SKIP = {
      action: :skip, reason: "état de fusion pas encore calculé par GitHub",
    }.freeze
    ARTIFACTS_CONTEXT = "renovate/artifacts"
    MERGEABLE_STATES = %w[CLEAN HAS_HOOKS].freeze

    def initialize(pr, merge_settings)
      @pr = pr
      @merge_settings = merge_settings
    end

    def call
      return automerge_disabled_skip unless automerge_enabled?
      return UNKNOWN_STATE_SKIP if merge_state_status == "UNKNOWN"
      return REBASE_REQUESTED if RebaseNeed.new(@pr).needed?
      return ARTIFACTS_SKIP if artifacts_failed?
      return RED_CHECKS_SKIP if checks.red_checks.any?
      return RELEASE_AGE_SKIP if ReleaseAgeGate.new(@pr["statusCheckRollup"]).pending?
      return PENDING_CHECKS_SKIP unless checks_green?
      return blocked_skip unless MERGEABLE_STATES.include?(merge_state_status)

      merge_or_skip
    end

    private

    def merge_state_status
      @pr["mergeStateStatus"]
    end

    def artifacts_failed?
      @pr["statusCheckRollup"].to_a.any? do |check|
        check["context"] == ARTIFACTS_CONTEXT && check["state"] == "FAILURE"
      end
    end

    # Checks verts mais GitHub refuse le merge (revue requise, PR en brouillon…) : un rebase n'y peut rien.
    def blocked_skip
      { action: :skip, reason: "fusion bloquée par GitHub (#{merge_state_status})" }
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
