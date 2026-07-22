# frozen_string_literal: true

require "net/http"
require "json"

module AutomergeRenovate
  # Transport HTTP authentifié (Basic Auth) vers l'API REST Jira.
  class JiraHttp
    def initialize(site:, email:, token:)
      @site = site
      @email = email
      @token = token
    end

    def get(path, params)
      uri = URI::HTTPS.build(host: @site, path: path, query: URI.encode_www_form(params))
      perform(Net::HTTP::Get.new(uri))
    end

    def post(path, body)
      uri = URI::HTTPS.build(host: @site, path: path)
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)
      perform(req)
    end

    private

    def perform(req)
      req.basic_auth(@email, @token)
      req["Accept"] = "application/json"
      uri = req.uri
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
      JSON.parse(response.body)
    end
  end
end
