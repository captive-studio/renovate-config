# frozen_string_literal: true

require_relative "adf_to_text"
require_relative "jira_http"

module AutomergeRenovate
  # Client Jira minimal : dernier ticket de maintenance par JQL, ou ticket précis par clé.
  class JiraClient
    PROJECT = "FAC"
    SUMMARY_FILTER = "Maintenance Renovate"
    FIELDS = %w[summary description].freeze

    def initialize(site:, email:, token:, http: nil)
      @http = http || JiraHttp.new(site: site, email: email, token: token)
    end

    def find_latest_ticket
      response = @http.post("/rest/api/3/search/jql", jql: jql, maxResults: 1, fields: FIELDS)
      to_ticket(response["issues"].first)
    end

    def find_ticket(key)
      to_ticket(@http.get("/rest/api/3/issue/#{key}", {}))
    end

    private

    def jql
      %(project = #{PROJECT} AND summary ~ "#{SUMMARY_FILTER}" ORDER BY created DESC)
    end

    def to_ticket(issue)
      { key: issue["key"], description: AdfToText.convert(issue["fields"]["description"]) }
    end
  end
end
