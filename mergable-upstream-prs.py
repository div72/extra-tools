#!/usr/bin/env python3

import subprocess
import sys

from typing import List

UPSTREAM_URL: str = "https://github.com/bitcoin/bitcoin"


def main():
    if len(sys.argv) != 2:
        print(f"USAGE: {sys.argv[0]} <previous head>", file=sys.stderr)
        sys.exit(1)

    subprocess.check_call(["git", "fetch", UPSTREAM_URL])
    commits: List[str] = list(reversed(list(map(lambda b: b.decode()[1:-1], subprocess.check_output(["git", "log", "--merges", "--format='%h'", f"{sys.argv[1]}..FETCH_HEAD"]).splitlines()))))

    successful_commits: List[str] = []
    failed_commits: List[str] = []

    previous_branch: str = subprocess.check_output(["git", "symbolic-ref", "--short", "HEAD"]).decode().rstrip()
    subprocess.check_call(["git", "checkout", "-b", "mergability-test-branch"])
    for i, commit in enumerate(commits):
        try:
            subprocess.check_call(["git", "cherry-pick", "-m", "1", commit], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            successful_commits.append(commit)
        except subprocess.CalledProcessError:
            subprocess.run(["git", "cherry-pick", "--abort"])
            failed_commits.append(commit)
        print(f"{str(i).rjust(len(str(len(commits))), '0')}/{len(commits)}\r", end="")
    print()

    subprocess.check_call(["git", "checkout", previous_branch])
    subprocess.check_call(["git", "branch", "-D", "mergability-test-branch"])

    print(f"Failed to apply {len(failed_commits)} merges:")
    for commit in failed_commits:
        print("\t", commit)

    print()

    print(f"Successfuly applied {len(successful_commits)} merges:")
    for commit in successful_commits:
        msg: str = subprocess.check_output(["git", "log", "-1", "--format='%s'", commit]).decode()
        pr_number: str = (msg.split(" ")[1]).split("#")[1][:-1]
        print("\t", commit, f"({UPSTREAM_URL}/pull/{pr_number})")

    if commits:
        print()
        print("Last commit:", commits[-1])
        subprocess.check_call(["git", "prune"])


if __name__ == "__main__":
    main()

