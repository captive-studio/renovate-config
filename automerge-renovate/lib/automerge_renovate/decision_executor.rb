# frozen_string_literal: true

require_relative "rebase_checkbox"

module AutomergeRenovate
  # Applique une décision (merge, rebase demandé) via gh, et convertit un échec gh en skip.
  class DecisionExecutor
    def initialize(gh:)
      @gh = gh
    end

    def call(repo, pr, decision)
      number = pr["number"]
      case decision[:action]
      when :merge
        @gh.merge(repo, number, decision[:strategy])
      when :rebase_requested
        @gh.update_body(repo, number, RebaseCheckbox.new(pr["body"]).check)
      end
      decision
    rescue RuntimeError => e
      { action: :skip, reason: e.message }
    end
  end
end
