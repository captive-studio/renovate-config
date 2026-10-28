# frozen_string_literal: true

require_relative "pr_decision"
require_relative "decision_executor"
require_relative "failed_checks_rerunner"
require_relative "branch_gap"
require_relative "rebase_waiter"
require_relative "release_age_gate"

module AutomergeRenovate
  class Runner
    # Chaque merge remet les autres PR du repo en retard : on garde une marge si une autre PR
    # est fusionnée pendant qu'on attend le rebase de celle-ci.
    MAX_REBASES = 3

    def initialize(gh:, rebase_waiter: RebaseWaiter.new(gh: gh))
      @gh = gh
      @rebase_waiter = rebase_waiter
      @executor = DecisionExecutor.new(gh: gh)
      @rerunner = FailedChecksRerunner.new(gh: gh)
      @branch_gap = BranchGap.new(gh: gh)
    end

    def run(repos, on_repo: ->(_repo) { }, on_result: ->(_result) { }, on_wait: ->(_number) { })
      @on_wait = on_wait
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
      pr, decision = decide_until_rebased(repo, pr, merge_settings)
      decision = @rerunner.call(repo, pr, decision)
      { repo: repo, number: pr["number"], url: pr["url"] }.merge(decision)
    end

    # Une PR dont on demande le rebase est attendue puis redécidée, pour que toutes les PR prêtes
    # d'un repo soient fusionnées dans le même run, et pas une seule par run.
    def decide_until_rebased(repo, pr, merge_settings)
      decision = decide(repo, pr, merge_settings)
      MAX_REBASES.times do
        break unless awaitable_rebase?(pr, decision)

        @on_wait.call(pr["number"])
        rebased = @rebase_waiter.call(repo, pr)
        break unless rebased

        pr = rebased
        decision = decide(repo, pr, merge_settings)
      end
      [ pr, decision ]
    end

    def decide(repo, pr, merge_settings)
      pr = @branch_gap.call(repo, pr)
      decision = PrDecision.new(pr, merge_settings).call
      @executor.call(repo, pr, decision)
    end

    # Inutile de bloquer le run pour une PR qui ne sera pas fusionnable à l'issue du rebase : automerge
    # désactivé (décision humaine), ou version encore trop récente pour Renovate (attente en jours).
    def awaitable_rebase?(pr, decision)
      decision[:action] == :rebase_requested && !decision[:needs_decision] &&
        !ReleaseAgeGate.new(pr["statusCheckRollup"]).pending?
    end
  end
end
