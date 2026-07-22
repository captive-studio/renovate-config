# frozen_string_literal: true

module AutomergeRenovate
  # Détecte si Renovate a activé l'automerge sur une PR, d'après le corps de la PR.
  class AutomergeStatus
    def initialize(body)
      @body = body
    end

    def enabled?
      @body.include?("🚦 **Automerge**: Enabled.")
    end
  end
end
