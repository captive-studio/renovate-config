# frozen_string_literal: true

module AutomergeRenovate
  class ChecksEvaluator
    GREEN_CONCLUSIONS = %w[SUCCESS SKIPPED NEUTRAL].freeze
    PENDING_STATUSES = %w[PENDING IN_PROGRESS QUEUED WAITING].freeze

    def initialize(checks)
      @checks = checks
    end

    def all_green?
      red_checks.empty?
    end

    def any_red?
      @checks.any? do |check|
        s = status_of(check)
        s && !GREEN_CONCLUSIONS.include?(s) && !PENDING_STATUSES.include?(s)
      end
    end

    def red_checks
      @checks.reject { |check| GREEN_CONCLUSIONS.include?(status_of(check)) }
    end

    private

    def status_of(check)
      check["conclusion"] || check["state"]
    end
  end
end
