# frozen_string_literal: true

module AutomergeRenovate
  # Répond à « Renovate retient-il encore cette PR le temps que sa version prenne de l'ancienneté ? »
  # (minimumReleaseAge). Cette attente se compte en jours : inutile de l'attendre pendant un run.
  class ReleaseAgeGate
    CONTEXT = "renovate/stability-days"

    def self.check?(check)
      check["context"] == CONTEXT
    end

    def initialize(checks)
      @checks = checks.to_a
    end

    def pending?
      @checks.any? { |check| self.class.check?(check) && check["state"] == "PENDING" }
    end
  end
end
