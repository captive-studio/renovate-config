# frozen_string_literal: true

require "json"
require "open3"

module AutomergeRenovate
  class GhCli
    FIELDS = "number,body,mergeStateStatus,statusCheckRollup,url,baseRefName,headRefName,headRefOid"

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

    def rerun_failed_jobs(repo, run_id)
      run("run", "rerun", run_id.to_s, "--repo", repo, "--failed")
    end

    def run(*args)
      out, err, status = Open3.capture3("gh", *args)
      raise "gh #{command_name(args)} failed: #{err}" unless status.success?

      out.dup.force_encoding("UTF-8")
    end

    private

    # Les valeurs d'options (un body de PR entier, par exemple) noieraient le message d'erreur.
    def command_name(args)
      args.take_while { |arg| !arg.start_with?("--") }.join(" ")
    end
  end
end
