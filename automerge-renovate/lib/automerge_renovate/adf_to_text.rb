# frozen_string_literal: true

module AutomergeRenovate
  # Convertit une description Jira au format ADF (Atlassian Document Format) en texte
  # exploitable par RepoUrlExtractor. Les chaînes déjà en texte brut passent inchangées.
  module AdfToText
    CARD_TYPES = %w[inlineCard blockCard].freeze

    def self.convert(node)
      return node unless node.is_a?(Hash)

      return text_node(node) if node["type"] == "text"
      return card_node(node) if CARD_TYPES.include?(node["type"])

      children_text(node)
    end

    def self.children_text(node)
      (node["content"] || []).map { |child| convert(child) }.join("\n")
    end

    def self.card_node(node)
      href = node["attrs"]["url"]
      "[#{href}](#{href})"
    end

    def self.text_node(node)
      link = node["marks"]&.find { |mark| mark["type"] == "link" }
      return node["text"] unless link

      href = link["attrs"]["href"]
      "[#{href}](#{href})"
    end
  end
end
