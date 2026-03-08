# generate_fake_commits.sh

`generate_fake_commits.sh` generates empty Git commits with randomized dates and times across a configured date range.

## What It Does

- Walks day-by-day from `START_DATE` to `END_DATE` (inclusive)
- Uses separate commit count ranges for weekdays vs weekends
- Applies a random break-day probability (zero commits for that day)
- Generates realistic intra-day commit timing patterns (focus windows + occasional bursts)
- Randomly picks commit messages from a configurable message list
- Creates empty commits with `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE` set per commit

## Requirements

- Bash (`/usr/bin/env bash`)
- Git installed and available in `PATH`
- Run from inside a Git repository
- Linux or macOS (`GNU date` and `BSD date` are both supported)

## Configuration

Edit these variables at the top of [`generate_fake_commits.sh`](/home/grey/Script-for-faking-commits/generate_fake_commits.sh):

```bash
START_DATE="2025-12-07"
END_DATE="2026-03-04"

WEEKDAY_MIN=5
WEEKDAY_MAX=15
WEEKEND_MIN=0
WEEKEND_MAX=6

BREAK_DAY_PERCENT=15

COMMIT_MESSAGES=(
  "fix bug"
  "refactor code"
  "update config"
  "improve ui"
  "cleanup"
  "optimize logic"
  "add feature"
  "update docs"
  "minor changes"
)
```

### Config Notes

- `START_DATE`, `END_DATE`: inclusive range in `YYYY-MM-DD`
- `WEEKDAY_MIN`, `WEEKDAY_MAX`: commit range for Monday-Friday
- `WEEKEND_MIN`, `WEEKEND_MAX`: commit range for Saturday-Sunday
- `BREAK_DAY_PERCENT`: chance (0-100) that a day gets zero commits regardless of weekday/weekend limits
- `COMMIT_MESSAGES`: commit message pool used randomly for each generated commit

## Usage

Make executable once:

```bash
chmod +x generate_fake_commits.sh
```

Run:

```bash
./generate_fake_commits.sh
```

Script output includes:

- total generated commits
- number of active days (days with at least one commit)
- date range summary
- push reminder

## Push Commits

```bash
git push origin main
```

If your remote branch has diverged:

```bash
git push --force-with-lease origin main
```

## Verify Output

Check commit count by generated messages:

```bash
git log --grep='fix bug\|refactor code\|update config\|improve ui\|cleanup\|optimize logic\|add feature\|update docs\|minor changes' --oneline | wc -l
```

Inspect recent commit dates:

```bash
git log --pretty=format:'%h %ad %s' --date=iso -n 30
```

## Troubleshooting

- `Error: git is not installed or not in PATH.`
  - Install Git and verify with `git --version`
- `Error: date command is not available.`
  - Ensure `date` is available in your shell
- `Error: current directory is not a git repository.`
  - Run the script inside a Git repo
- `Error: START_DATE must be earlier than or equal to END_DATE.`
  - Fix the date range order in config
