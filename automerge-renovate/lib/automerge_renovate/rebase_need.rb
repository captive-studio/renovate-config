# frozen_string_literal: true

module AutomergeRenovate
  # Répond à « la branche de cette PR doit-elle être régénérée par Renovate ? »
  class RebaseNeed
    # Statuts que Renovate corrige en régénérant la branche : retard sur la base, ou conflit.
    REBASABLE_STATUSES = %w[BEHIND DIRTY].freeze

    def initialize(pr)
      @pr = pr
    end

    # Seuls cas où GitHub refuse de fusionner la PR telle quelle : sans exigence de branche à jour,
    # une PR en retard se fusionne directement, rebaser ne ferait que relancer sa CI.
    def needed?
      REBASABLE_STATUSES.include?(@pr["mergeStateStatus"])
    end
  end
end
