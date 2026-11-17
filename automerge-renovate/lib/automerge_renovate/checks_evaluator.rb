# frozen_string_literal: true

module AutomergeRenovate
  class ChecksEvaluator
    GREEN_CONCLUSIONS = %w[SUCCESS SKIPPED NEUTRAL].freeze

    def initialize(checks)
      @checks = checks
    end

    PENDING_STATES = %w[PENDING EXPECTED].freeze

    # Un StatusContext porte un state, un CheckRun un status (QUEUED, IN_PROGRESS…) jusqu'à sa conclusion.
    def self.pending?(check)
      return false if check["conclusion"]
      return PENDING_STATES.include?(check["state"]) if check.key?("state")

      check["status"] != "COMPLETED"
    end

    def all_green?
      red_checks.empty? && pending_checks.empty?
    end

    def pending_checks
      @checks.select { |check| self.class.pending?(check) }
    end

    def red_checks
      @checks.reject do |check|
        self.class.pending?(check) || GREEN_CONCLUSIONS.include?(status_of(check))
      end
    end

    private

    def status_of(check)
      check["conclusion"] || check["state"]
    end
  end
end
