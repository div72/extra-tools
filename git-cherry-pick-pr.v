import net.http
import net.urllib
import os
import x.json2

const api_base = "https://api.github.com"

fn get_remote_info(remote string) (string, string) {
        url := os.execute('git remote get-url ${remote}').output.trim_space()

        if url.contains('@') {
                // SSH url.
                parts := url.split(':')[1].split('/')
                return parts[0], parts[1].trim_string_right('.git')
        }

        parts := url.split('/')
        return parts[3], parts[4].trim_string_right('.git')
}

fn main() {
    upstream_owner, upstream_repo := get_remote_info("upstream")
    origin_owner, origin_repo := get_remote_info("origin")
    fork_owner, fork_repo := get_remote_info("fork")

    pr := json2.raw_decode(http.get_text(api_base + '/repos/${upstream_owner}/${upstream_repo}/pulls/${os.args[1]}'))?.as_map()

    commit_count := pr["commits"].int()
    mut commits := []string{cap: commit_count}

    mut params := urllib.new_values()
    params.set("per_page", "100")
    for page in 0..(commit_count + 99) / 100 {
        params.set("page", page.str())
        commits_json := json2.raw_decode(http.get_text(pr["commits_url"].str() + '?' + params.encode()))?.arr()
        for commit in commits_json {
            commits << commit.as_map()["sha"].str()
        }
    }
    params.del("per_page")
    params.del("page")

    target_branch := os.execute("git symbolic-ref --short HEAD").output.trim_space()
    os.execute_or_panic("git checkout -b port_pr_${os.args[1]}")
    // TODO: Assumes already fetched. This could break otherwise.
    for commit in commits {
        os.execute_or_panic("git cherry-pick ${commit}")
    }
    os.execute_or_panic("git push fork port_pr_${os.args[1]}")

    params.set("title", pr["title"].str())
    mut body_lines := []string{}
    for line in pr["body"].str().split_into_lines() {
        body_lines << ("> " + line)
    }
    body_lines << ""
    body_lines << "`https://github.com/${upstream_owner}/${upstream_repo}/pull/${os.args[1]}`"
    params.set("body", body_lines.join("\n"))
    params.set("expand", "1")

    link := "https://github.com/${origin_owner}/${origin_repo}/compare/${target_branch}...${fork_owner}:port_pr_${os.args[1]}?${params.encode()}"
    os.open_uri(link)?
}
