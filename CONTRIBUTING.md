# Contributing & Git workflow

## Branches

| Branch | Purpose | Created from | Merges into |
|---|---|---|---|
| `main` | Production-ready releases only | — | — |
| `develop` | Integration of completed phases | `main` | `main` (via `release/*`) |
| `phase/NN-name` | One development phase | latest `develop` | `develop` (`--no-ff`) |
| `feature/HF-XXX-short-name` | One backlog item | its phase branch | phase branch (PR) |
| `fix/HF-XXX-short-description` | Bug fix for a backlog item | phase branch or `develop` | same |
| `hotfix/short-description` | Urgent production fix | `main` | `main` and `develop` |
| `release/X.Y.Z` | Release stabilisation | `develop` | `main` (tag `vX.Y.Z`), back into `develop` |

### Phases

| Branch | Backlog |
|---|---|
| `phase/01-foundation` | HF-001, HF-002, HF-003 |
| `phase/02-core-habit-loop` | HF-004, HF-005, HF-006, HF-007, HF-009 |
| `phase/03-ordering-streak-engine` | HF-008, HF-010, HF-011, HF-012 |
| `phase/04-secondary-features` | HF-013 – HF-017 |
| `phase/05-quality-performance` | HF-018 – HF-021 |
| `phase/06-release-prep` | HF-022, HF-023 |

## Workflow

```sh
# Start a phase
git switch develop && git pull
git switch -c phase/02-core-habit-loop
git push -u origin phase/02-core-habit-loop

# Work on one backlog item
git switch -c feature/HF-004-home-dashboard phase/02-core-habit-loop
# ...commit...
git push -u origin feature/HF-004-home-dashboard
# Open a PR: feature/HF-004-home-dashboard -> phase/02-core-habit-loop

# Phase complete (all items merged, CI green)
git switch develop && git pull
git merge --no-ff phase/02-core-habit-loop -m "merge: phase 02 core habit loop"
git push
```

Delete feature and phase branches only after they're merged.
Never force-push or rewrite shared history.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), scoped with the
backlog ID:

```
feat(HF-004): implement home dashboard
fix(HF-007): prevent duplicate completion taps
test(HF-012): add streak boundary tests
refactor(HF-003): improve repository architecture
docs: update project documentation
chore: configure Flutter linting
```

## Checks (run before every PR — CI runs the same)

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
dart run build_runner build
flutter analyze
flutter test
```

Generated files (`*.g.dart`) are not committed. Run `build_runner` after
cloning.

## Releases

1. `git switch -c release/1.0.0 develop`
2. Final testing, versioning in `pubspec.yaml`, signing config.
3. Merge into `main` (`--no-ff`), tag `v1.0.0`, push the tag.
4. Merge `release/1.0.0` back into `develop`.

Signing keys, keystores and `android/key.properties` are git-ignored and
must never be committed.

## Branch protection (GitHub → Settings → Branches → Add rule)

**`main`:** Require a pull request before merging · Require status checks to
pass (`Format, analyze, test`) · Require branches to be up to date · Do not
allow bypassing the above · Block force pushes and deletions.

**`develop`:** Require a pull request before merging · Require status checks
to pass (`Format, analyze, test`) · Block force pushes and deletions.

The status check only appears in the list after CI has run once on GitHub.
