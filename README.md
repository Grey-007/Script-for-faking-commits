# generate_fake_commits.sh

`generate_fake_commits.sh` creates empty Git commits with randomized times to populate a GitHub contribution graph.

## What It Does

- Iterates through each day in a configured date range (inclusive).
- Creates a random number of commits per day.
- Uses random times within each day.
- Sets both `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE` for each commit.
- Creates empty commits with:
  - `git commit --allow-empty -m "auto commit"`

## Requirements

- Bash (`/usr/bin/env bash`)
- Git installed and available in `PATH`
- A valid Git repository (run from inside the repo)
- Linux or macOS (`GNU date` and `BSD date` are both supported)

## Configuration

Edit these variables at the top of `generate_fake_commits.sh`:

```bash
START_DATE="2025-12-07"
END_DATE="2026-03-04"
MIN_COMMITS_PER_DAY=10
MAX_COMMITS_PER_DAY=20
COMMIT_MESSAGE="auto commit"
```

### Variable Details

- `START_DATE`: first day to generate commits (`YYYY-MM-DD`)
- `END_DATE`: last day to generate commits (`YYYY-MM-DD`)
- `MIN_COMMITS_PER_DAY`: minimum commits generated for each day
- `MAX_COMMITS_PER_DAY`: maximum commits generated for each day
- `COMMIT_MESSAGE`: commit message used for every generated commit

## Setup

From repository root:

```bash
chmod +x generate_fake_commits.sh
```

## Usage

Run:

```bash
./generate_fake_commits.sh
```

After completion, push history:

```bash
git push origin main
```

## Safety Notes

- This rewrites local branch history by adding many commits.
- If you previously pushed different history, you may need:

```bash
git push --force-with-lease origin main
```

- Use a test branch first if you are unsure:

```bash
git checkout -b chore/fake-graph
./generate_fake_commits.sh
git push origin chore/fake-graph
```

## Verify Result

Count generated commits by message:

```bash
git log --grep='^auto commit$' --oneline | wc -l
```

Check recent commit dates:

```bash
git log --pretty=format:'%h %ad %s' --date=iso -n 20
```

## Remove Generated Commits

If generated commits are at the tip of your branch, remove them by resetting to the last real commit:

```bash
git reset --hard <last_real_commit_hash>
```

Then update remote if already pushed:

```bash
git push --force-with-lease origin main
```

## Troubleshooting

- `Error: current directory is not a git repository.`
  - Run the script inside a Git repo.
- `Error: git is not installed or not in PATH.`
  - Install Git and verify `git --version` works.
- Date parsing failures
  - Ensure dates use `YYYY-MM-DD` format.
