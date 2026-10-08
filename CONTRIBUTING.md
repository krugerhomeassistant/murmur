# Contributing

Branch from `main`, keep changes small, open a pull request. `main` always runs.

## Develop

Open `client/` in Godot 4.7 (or `Open Murmur in Godot.bat`) and press Play.

## Checks (same as CI)

```bash
python3 scripts/check_repo.py                       # prints REPO_OK
cd client && gdlint scripts tests                  # pip install gdtoolkit==4.5.0
# each test prints NAME_OK; CI runs: smoke netcache rivers spectate mining war ai farms pmine growth net cmd netsync mp pvp
godot --headless --path client -s tests/smoke.gd
```

## Workflow

1. `git switch -c feat/<short-name>` (or `fix/`, `chore/`, `docs/`).
2. Commit with imperative, scoped messages (`feat: ports and ships`, `fix: bridge cost`).
3. Note user-visible changes under `## [Unreleased]` in `CHANGELOG.md` as you go.
4. Update `docs/PLAN.md` (tick tasks), `docs/WIKI.md` (rules and features) and `docs/LESSONS_LEARNED.md` (problems and fixes).
5. Open a PR into `main`; CI must pass; squash-merge.

## Releasing (maintainers)

1. `python scripts/bump.py X.Y.Z` (updates `VERSION`, `project.godot` and the changelog).
2. `git commit -am "Release vX.Y.Z" && git push`; tag `vX.Y.Z` on `main`.
3. Run the performance pass first (see `docs/RELEASING.md`), then build the portable zip and attach it to the GitHub release.
