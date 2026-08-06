# frozen_string_literal: true

module AutomergeRenovate
  # Erreur de base de l'outil, pour distinguer nos échecs métier des exceptions Ruby.
  class Error < StandardError; end

  # L'API Jira a répondu autre chose qu'un succès (token expiré, droits manquants, endpoint inconnu).
  class HttpError < Error; end

  # La recherche JQL n'a remonté aucun ticket de maintenance à traiter.
  class TicketNotFoundError < Error; end
end
