# Releasing

Order matters. Performance is always the last step before a release.

1. **Feature freeze.** `main` green in CI, `[Unreleased]` in `CHANGELOG.md` complete.
2. **Performance pass.** Profile (`godot --headless --path client -s tests/stageprof.gd`), fix the top stages, then re-run the standard benchmark (windowed, F9 or `--benchmark`: 8 towns, 8x, all overlays, spectator, fixed seed; see README "Standard benchmark"). Update the README table with the measured numbers and hardware. No release with a regression against the previous table.
3. **Verify.** Every headless test (`smoke netcache rivers spectate mining war ai farms pmine growth net cmd netsync mp pvp`, plus any new ones; CI runs the same list) and `python3 scripts/check_repo.py`.
4. **Bump.** `python3 scripts/bump.py X.Y.Z` (updates `VERSION`, `project.godot`, cuts the changelog), commit `Release vX.Y.Z` via a PR, squash-merge.
5. **Tag.** `git tag vX.Y.Z` on the merge commit and push the tag.
6. **Build.** Automatic: `.github/workflows/build.yml` exports `Murmur.exe` (embedded pack, build stamp) and zips it with `scripts/PORTABLE.txt` on every push to `main` (artifact) and on tag push (attached to the release). Nothing to stage by hand.
7. **Publish.** GitHub release for the tag, notes from the changelog section, zip attached.

## Manual steps (the agent session cannot do these)
The agent proxy blocks tag pushes and release creation. After the release PR merges: `git fetch origin && git tag vX.Y.Z <merge sha> && git push origin vX.Y.Z`, then create the GitHub release in the web UI (notes from the changelog, the build workflow attaches the portable zip when the tag lands).
