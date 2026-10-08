# Releasing

Order matters. Performance is always the last step before a release.

1. **Feature freeze.** `main` green in CI, `[Unreleased]` in `CHANGELOG.md` complete.
2. **Performance pass.** Profile (`godot --headless --path client -s tests/stageprof.gd`), fix the top stages, then re-run the standard benchmark (windowed, F9 or `--benchmark`: 8 towns, 8x, all overlays, spectator, fixed seed; see README "Standard benchmark"). Update the README table with the measured numbers and hardware. No release with a regression against the previous table.
3. **Verify.** Every headless test (`smoke netcache rivers spectate mining war ai farms pmine`, plus any new ones) and `python3 scripts/check_repo.py`.
4. **Bump.** `python3 scripts/bump.py X.Y.Z` (updates `VERSION`, `project.godot`, cuts the changelog), commit `Release vX.Y.Z` via a PR, squash-merge.
5. **Tag.** `git tag vX.Y.Z` on the merge commit and push the tag.
6. **Build.** Portable Windows build: stage the exported game with `client/scripts/*.gd` and `*.uid` into `game/scripts/` of the portable folder, zip as `dist/Murmur-portable.zip` (git-ignored).
7. **Publish.** GitHub release for the tag, notes from the changelog section, zip attached.
