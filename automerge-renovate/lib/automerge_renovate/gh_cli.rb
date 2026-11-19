# frozen_string_literal: true

require "json"
require "open3"

module AutomergeRenovate
  class GhCli
    FIELDS = "number,body,mergeStateStatus,statusCheckRollup,url,baseRefName,headRefName,headRefOid"
    # Coupures réseau passagères : sans réessai, un seul timeout interrompt tout le run.
    TRANSIENT_ERROR = /dial tcp|i\/o timeout|connection reset|TLS handshake timeout/
    RETRIES = 2
    RETRY_DELAY = 5

    def initialize(sleeper: ->(seconds) { sleep(seconds) })
      @sleeper = sleeper
    end

    def open_renovate_prs(repo)
      output = run("pr", "list", "--repo", repo, "--author", "app/renovate",
                    "--state", "open", "--json", FIELDS)
      JSON.parse(output)
    end

    def merge_settings(repo)
      JSON.parse(run("api", "repos/#{repo}"))
        .slice("allow_rebase_merge", "allow_squash_merge", "allow_merge_commit")
    end

    def behind_by(repo, base, head)
      JSON.parse(run("api", "repos/#{repo}/compare/#{base}...#{head}")).fetch("behind_by")
    end

    def merge(repo, number, strategy)
      run("pr", "merge", number.to_s, "--repo", repo, "--#{strategy}")
    end

    def merged?(repo, number)
      payload = run("pr", "view", number.to_s, "--repo", repo, "--json", "state")
      JSON.parse(payload).fetch("state") == "MERGED"
    end

    def pr(repo, number)
      JSON.parse(run("pr", "view", number.to_s, "--repo", repo, "--json", FIELDS))
    end

    # `gh pr edit` interroge les Projects classic, retirés par GitHub : il échoue sur les versions de gh
    # antérieures au correctif. L'API REST ne dépend pas de la version installée.
    def update_body(repo, number, body)
      run("api", "repos/#{repo}/pulls/#{number}",
          "--method", "PATCH", "--raw-field", "body=#{body}")
    end

    def update_branch(repo, number)
      run("pr", "update-branch", number.to_s, "--repo", repo, "--rebase")
    end

    def rerun_failed_jobs(repo, run_id)
      run("run", "rerun", run_id.to_s, "--repo", repo, "--failed")
    end

    def run(*args)
      attempts = 0
      loop do
        out, err, status = Open3.capture3("gh", *args)
        break out.dup.force_encoding("UTF-8") if status.success?

        attempts += 1
        retryable = attempts <= RETRIES && err.match?(TRANSIENT_ERROR)
        raise "gh #{command_name(args)} failed: #{err}" unless retryable

        @sleeper.call(RETRY_DELAY * attempts)
      end
    end

    private

    # Les valeurs d'options (un body de PR entier, par exemple) noieraient le message d'erreur.
    def command_name(args)
      args.take_while { |arg| !arg.start_with?("--") }.join(" ")
    end
  end
end
