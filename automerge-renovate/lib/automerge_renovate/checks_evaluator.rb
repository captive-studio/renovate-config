# frozen_string_literal: true

module AutomergeRenovate
  class ChecksEvaluator
    GREEN_CONCLUSIONS = %w[SUCCESS SKIPPED NEUTRAL].freeze

    def initialize(checks)
      @checks = checks
    end

    def all_green?
      red_checks.empty?
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
