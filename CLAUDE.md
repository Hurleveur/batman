# batman

- Bump `version` in `.claude-plugin/plugin.json` on every commit that changes hook or skill behavior. **Why:** the installed cache path and `~/.claude/plugins/installed_plugins.json` are keyed by this string (`cache/batman/batman/<version>/`) — push without bumping and `claude plugin update` may see no version change and skip pulling the fix into a fresh cache dir.
- Bumping the version does not itself update the installed copy — still run `claude plugin update` (or reinstall) after pushing. The cache under `~/.claude/plugins/cache/` is a pulled copy, not a live link to this repo.
