# frozen_string_literal: true

require_relative "rebase_checkbox"

module AutomergeRenovate
  # Applique une décision (merge, rebase demandé) via gh, et convertit un échec gh en skip.
  class DecisionExecutor
    # Le merge GitHub n'est pas toujours effectif dès la réponse de `gh pr merge` : la PR suivante
    # du même repo doit voir la base à jour (mergeStateStatus, behind_by) avant d'être décidée.
    MERGE_POLL_ATTEMPTS = 10
    MERGE_POLL_INTERVAL_SECONDS = 2

    def initialize(gh:, sleeper: ->(seconds) { sleep(seconds) })
      @gh = gh
      @sleeper = sleeper
    end

    def call(repo, pr, decision)
      number = pr["number"]
      case decision[:action]
      when :merge
        @gh.merge(repo, number, decision[:strategy])
        wait_until_merged(repo, number)
      when :rebase_requested
        @gh.update_body(repo, number, RebaseCheckbox.new(pr["body"]).check)
      end
      decision
    rescue RuntimeError => e
      { action: :skip, reason: e.message }
    end

    private

    def wait_until_merged(repo, number)
      MERGE_POLL_ATTEMPTS.times do
        return if @gh.merged?(repo, number)

        @sleeper.call(MERGE_POLL_INTERVAL_SECONDS)
      end
    end
  end
end
