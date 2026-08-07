# frozen_string_literal: true

module AutomergeRenovate
  # Répond à « la branche de cette PR doit-elle être régénérée par Renovate ? »
  class RebaseNeed
    # Statuts que Renovate corrige en régénérant la branche : retard sur la base, ou conflit.
    REBASABLE_STATUSES = %w[BEHIND DIRTY].freeze

    def initialize(pr)
      @pr = pr
    end

    # GitHub ne renvoie BEHIND que si la branche de base exige d'être à jour ; sans ce réglage,
    # le retard réel ne se lit que dans le compte de commits d'écart.
    def needed?
      REBASABLE_STATUSES.include?(@pr["mergeStateStatus"]) || @pr["behindBy"].to_i.positive?
    end
  end
end
