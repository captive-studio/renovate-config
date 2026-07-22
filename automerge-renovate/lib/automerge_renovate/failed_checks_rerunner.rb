# frozen_string_literal: true

require_relative "checks_evaluator"
require_relative "github_actions_run_ids"

module AutomergeRenovate
  # Redéclenche les jobs GitHub Actions en échec sur les PR classées "à investiguer".
  class FailedChecksRerunner
    def initialize(gh:)
      @gh = gh
    end

    def call(repo, pr, decision)
      return decision unless decision[:needs_investigation]

      run_ids = run_ids_for(pr)
      return decision.merge(rerun_triggered: false) if run_ids.empty?

      run_ids.each { |run_id| @gh.rerun_failed_jobs(repo, run_id) }
      decision.merge(rerun_triggered: true)
    rescue RuntimeError
      decision.merge(rerun_triggered: false)
    end

    private

    def run_ids_for(pr)
      red_checks = ChecksEvaluator.new(pr["statusCheckRollup"]).red_checks
      GithubActionsRunIds.from(red_checks)
    end
  end
end
