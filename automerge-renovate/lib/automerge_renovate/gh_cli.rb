# frozen_string_literal: true

require "json"
require "open3"

module AutomergeRenovate
  class GhCli
    FIELDS = "number,body,mergeStateStatus,statusCheckRollup,url"

    def open_renovate_prs(repo)
      output = run("pr", "list", "--repo", repo, "--author", "app/renovate",
                    "--state", "open", "--json", FIELDS)
      JSON.parse(output)
    end

    def merge_settings(repo)
      JSON.parse(run("api", "repos/#{repo}"))
        .slice("allow_rebase_merge", "allow_squash_merge", "allow_merge_commit")
    end

    def merge(repo, number, strategy)
      run("pr", "merge", number.to_s, "--repo", repo, "--#{strategy}")
    end

    def update_body(repo, number, body)
      run("pr", "edit", number.to_s, "--repo", repo, "--body", body)
    end

    def rerun_failed_jobs(repo, run_id)
      run("run", "rerun", run_id.to_s, "--repo", repo, "--failed")
    end

    def run(*args)
      out, err, status = Open3.capture3("gh", *args)
      raise "gh #{args.join(" ")} failed: #{err}" unless status.success?

      out.dup.force_encoding("UTF-8")
    end
  end
end
