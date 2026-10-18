# Releasing

## Standard: every finished milestone is released

Nothing sits on `main` unreleased for long. When a milestone is done, the agent cuts the release itself, without waiting to be asked:

- **Minor release (0.N.0)**: a completed roadmap milestone (an E-layer such as E4 or E5, an age step, a sandbox phase, a multiplayer step), or about 40 merged commits, whichever comes first.
- **Patch release (0.N.P)**: fixes only, cut as soon as a player-visible bug is fixed on `main`.
- Each release carries the changelog section, the tag, the GitHub release and the portable zip. The README benchmark table must say which version it was measured on.
- The performance pass is the last step of every release (scaled below), and a deeper pass is done once before 1.0.
- The agent says in one line what it released and what is left for the owner (see "Manual steps").

### Fast path (aim: one session, about 6 PRs or fewer)
1. Confirm no open feature PRs, `main` green, `[Unreleased]` complete (cut it from the merged PR titles if not).
2. Perf, scaled: run `tests/stageprof.gd` headless on the last release tag and on `main`, and fix any stage that regressed more than 15%. Run the standard windowed benchmark on the owner's device when it is linked; if it is not, say so in the release notes and keep the previous table, labelled with its version.
3. Verify with the CI list plus `python3 scripts/check_repo.py` and `gdlint scripts tests`.
4. One release PR: `python3 scripts/bump.py X.Y.Z`, the README benchmark table if measured, `docs/ACTIVE_CONTEXT.md`. Squash-merge once checks pass.
5. Tag the merge commit and push the tag. The agent proxy blocks tag pushes, so the owner double-clicks `scripts/release-tag.bat` whenever convenient (it tags every release bump on origin/main since the last tag, oldest first, and pushes them; it does nothing when all are tagged). Manual equivalent: `git fetch origin && git tag vX.Y.Z <merge sha> && git push origin vX.Y.Z`. That is the only manual step: `build.yml` exports `Murmur.exe`, zips it and creates the GitHub release with the zip and generated notes.
6. Update `docs/PLAN.md` (release done, next milestone).

## Full procedure

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
