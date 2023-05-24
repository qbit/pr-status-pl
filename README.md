pr-status-pl
============

Is a tool that queries the `nixpkgs` repository for a given pull request. It determines:
- branches a PR has landed in
- if a PR is against stable or unstable
- determines if a PR is "completed" (made it to release)

The result of the above is fed to the end user in a JSON string.

I use this to track upstream'd PRs and dynamically disable overlays in my configs.
