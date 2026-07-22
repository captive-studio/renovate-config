# frozen_string_literal: true

module AutomergeRenovate
  # Compte les résultats par action (merge, rebase_requested, skip) pour le récapitulatif final.
  class ActionTally
    LABELS = {
      merge: "fusionnée(s)",
      rebase_requested: "rebase demandé(s)",
      skip: "ignorée(s)",
    }.freeze

    def initialize(results)
      @results = results
    end

    def to_s
      LABELS.map { |action, label| "#{count(action)} #{label}" }.join(", ")
    end

    private

    def count(action)
      @results.count { |result| result[:action] == action }
    end
  end
end
