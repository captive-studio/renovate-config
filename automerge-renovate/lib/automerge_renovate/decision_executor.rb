# frozen_string_literal: true

require_relative "rebase_checkbox"

module AutomergeRenovate
  # Applique une décision (merge, rebase demandé) via gh, et convertit un échec gh en skip.
  class DecisionExecutor
    # Le merge GitHub n'est pas toujours effectif dès la réponse de `gh pr merge` : la PR suivante
    # du même repo doit voir la base à jour (mergeStateStatus) avant d'être décidée.
    MERGE_POLL_ATTEMPTS = 10
    MERGE_POLL_INTERVAL_SECONDS = 2
    MERGE_CONFLICT_ERROR = "merge conflicts"

    def initialize(gh:, sleeper: ->(seconds) { sleep(seconds) })
      @gh = gh
      @sleeper = sleeper
    end

    def call(repo, pr, decision)
      number = pr["number"]
      case decision[:action]
      when :merge
        return merge(repo, pr, decision)
      when :rebase_requested
        request_rebase(repo, pr)
      end
      decision
    rescue RuntimeError => e
      { action: :skip, reason: e.message }
    end

    private

    # GitHub peut refuser pour conflit une PR qu'il disait CLEAN, quand une PR du même repo vient
    # d'être fusionnée : seul Renovate peut alors régénérer la branche.
    def merge(repo, pr, decision)
      @gh.merge(repo, pr["number"], decision[:strategy])
      wait_until_merged(repo, pr["number"])
      decision
    rescue RuntimeError => e
      raise unless e.message.include?(MERGE_CONFLICT_ERROR)

      @gh.update_body(repo, pr["number"], RebaseCheckbox.new(pr["body"]).check)
      { action: :rebase_requested }
    end

    # Un simple retard se rebase tout de suite côté GitHub ; Renovate ne repasse qu'à son prochain run.
    # Un conflit (lockfile, souvent) demande à Renovate de régénérer la branche.
    def request_rebase(repo, pr)
      if pr["mergeStateStatus"] == "DIRTY"
        @gh.update_body(repo, pr["number"], RebaseCheckbox.new(pr["body"]).check)
      else
        @gh.update_branch(repo, pr["number"])
      end
    end

    def wait_until_merged(repo, number)
      MERGE_POLL_ATTEMPTS.times do
        return if @gh.merged?(repo, number)

        @sleeper.call(MERGE_POLL_INTERVAL_SECONDS)
      end
    end
  end
end
