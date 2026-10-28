# frozen_string_literal: true

require_relative "release_age_gate"

module AutomergeRenovate
  # Attend que Renovate ait rebasé une PR (nouveau commit de tête) et que ses checks soient terminés,
  # pour pouvoir la redécider dans le même run plutôt qu'à la maintenance suivante.
  class RebaseWaiter
    # Renovate rebase en quelques minutes, la CI en prend une dizaine : au-delà, la PR attendra le run suivant.
    SECONDS_PER_MINUTE = 60
    TIMEOUT_MINUTES = 15
    POLL_INTERVAL_SECONDS = 15
    POLL_ATTEMPTS = TIMEOUT_MINUTES * SECONDS_PER_MINUTE / POLL_INTERVAL_SECONDS

    def initialize(gh:, sleeper: ->(seconds) { sleep(seconds) })
      @gh = gh
      @sleeper = sleeper
    end

    # Retourne la PR relue, ou nil si elle n'est pas prête à temps.
    def call(repo, pr)
      POLL_ATTEMPTS.times do |attempt|
        @sleeper.call(POLL_INTERVAL_SECONDS) unless attempt.zero?
        current = @gh.pr(repo, pr["number"])
        return current if rebased?(pr, current) && checks_settled?(current)
      end
      nil
    end

    private

    def rebased?(pr, current)
      current["headRefOid"] != pr["headRefOid"]
    end

    # Juste après le push, GitHub n'a encore rattaché aucun check au commit : une liste vide
    # passerait pour verte.
    def checks_settled?(pr)
      checks = pr["statusCheckRollup"].to_a
      checks.any? && checks.none? { |check| pending?(check) }
    end

    # Le check d'ancienneté de Renovate se compte en jours : il ne se terminera pas pendant l'attente.
    def pending?(check)
      return false if ReleaseAgeGate.check?(check)
      return check["state"] == "PENDING" if check.key?("state")

      check["status"] != "COMPLETED"
    end
  end
end
