# frozen_string_literal: true

require_relative "pr_decision"
require_relative "decision_executor"
require_relative "failed_checks_rerunner"

module AutomergeRenovate
  class Runner
    def initialize(gh:)
      @gh = gh
      @executor = DecisionExecutor.new(gh: gh)
      @rerunner = FailedChecksRerunner.new(gh: gh)
    end

    def run(repos, on_repo: ->(_repo) { }, on_result: ->(_result) { })
      repos.flat_map { |repo| run_repo(repo, on_repo, on_result) }
    end

    private

    def run_repo(repo, on_repo, on_result)
      on_repo.call(repo)
      merge_settings = @gh.merge_settings(repo)
      @gh.open_renovate_prs(repo).map do |pr|
        result = handle(repo, pr, merge_settings)
        on_result.call(result)
        result
      end
    end

    def handle(repo, pr, merge_settings)
      decision = PrDecision.new(pr, merge_settings).call
      decision = @executor.call(repo, pr, decision)
      decision = @rerunner.call(repo, pr, decision)
      { repo: repo, number: pr["number"], url: pr["url"] }.merge(decision)
    end
  end
end
