# frozen_string_literal: true

require_relative "pr_decision"
require_relative "decision_executor"
require_relative "failed_checks_rerunner"
require_relative "rebase_waiter"
require_relative "release_age_gate"

module AutomergeRenovate
  class Runner
    # Chaque merge remet les autres PR du repo en retard : on garde une marge si une autre PR
    # est fusionnée pendant qu'on attend le rebase de celle-ci.
    MAX_REBASES = 3
    # GitHub calcule l'état de fusion à la demande : UNKNOWN se résout en quelques secondes.
    UNKNOWN_POLL_ATTEMPTS = 5
    UNKNOWN_POLL_INTERVAL_SECONDS = 2

    # wait: false rend la main dès le rebase demandé, sans attendre la CI : la PR sera reprise au run suivant.
    def initialize(gh:, rebase_waiter: RebaseWaiter.new(gh: gh), wait: true,
                   sleeper: ->(seconds) { sleep(seconds) })
      @gh = gh
      @sleeper = sleeper
      @wait = wait
      @rebase_waiter = rebase_waiter
      @executor = DecisionExecutor.new(gh: gh)
      @rerunner = FailedChecksRerunner.new(gh: gh)
    end

    def run(repos, on_repo: ->(_repo) { }, on_result: ->(_result) { }, on_wait: ->(_number) { },
            on_decision: ->(_pr, _decision) { })
      @on_wait = on_wait
      @on_decision = on_decision
      repos.flat_map { |repo| run_repo(repo, on_repo, on_result) }
    end

    private

    def run_repo(repo, on_repo, on_result)
      on_repo.call(repo)
      merge_settings = @gh.merge_settings(repo)
      merged = false
      @gh.open_renovate_prs(repo).map do |pr|
        # La liste date du début du repo : après une fusion, l'état des PR suivantes a changé.
        pr = @gh.pr(repo, pr["number"]) if merged
        result = handle(repo, pr, merge_settings)
        merged ||= result[:action] == :merge
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
      pr, decision = decide(repo, pr, merge_settings)
      MAX_REBASES.times do
        break unless @wait && awaitable_rebase?(pr, decision)

        @on_wait.call(pr["number"])
        rebased = @rebase_waiter.call(repo, pr)
        break unless rebased

        pr, decision = decide(repo, rebased, merge_settings)
      end
      [ pr, decision ]
    end

    def decide(repo, pr, merge_settings)
      pr = resolve_unknown_state(repo, pr)
      decision = PrDecision.new(pr, merge_settings).call
      @on_decision.call(pr, decision)
      [ pr, @executor.call(repo, pr, decision) ]
    end

    def resolve_unknown_state(repo, pr)
      UNKNOWN_POLL_ATTEMPTS.times do
        return pr unless pr["mergeStateStatus"] == "UNKNOWN"

        @sleeper.call(UNKNOWN_POLL_INTERVAL_SECONDS)
        pr = @gh.pr(repo, pr["number"])
      end
      pr
    end

    # Inutile de bloquer le run pour une PR qui ne sera pas fusionnable à l'issue du rebase : automerge
    # désactivé (décision humaine), ou version encore trop récente pour Renovate (attente en jours).
    def awaitable_rebase?(pr, decision)
      decision[:action] == :rebase_requested && !decision[:needs_decision] &&
        !ReleaseAgeGate.new(pr["statusCheckRollup"]).pending? &&
        !regenerated_by_renovate?(pr)
    end

    # Une PR en conflit est régénérée par Renovate à son prochain passage, sans délai garanti :
    # on coche la case et on la reprend au run suivant plutôt que de bloquer celui-ci.
    def regenerated_by_renovate?(pr)
      pr["mergeStateStatus"] == "DIRTY"
    end
  end
end
