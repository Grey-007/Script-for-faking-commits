#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Configuration: date range (inclusive)
# -------------------------------------------------------------------
START_DATE="2025-12-07"
END_DATE="2026-03-04"
MIN_COMMITS_PER_DAY=10
MAX_COMMITS_PER_DAY=20
COMMIT_MESSAGE="auto commit"

# -------------------------------------------------------------------
# Preflight checks
# -------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed or not in PATH." >&2
  exit 1
fi

if ! command -v date >/dev/null 2>&1; then
  echo "Error: date command is not available." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: current directory is not a git repository." >&2
  exit 1
fi

# -------------------------------------------------------------------
# Detect GNU date vs BSD date (macOS)
# -------------------------------------------------------------------
if date --version >/dev/null 2>&1; then
  DATE_FLAVOR="gnu"
else
  DATE_FLAVOR="bsd"
fi

# -------------------------------------------------------------------
# Date helper functions (UTC for consistency and DST safety)
# -------------------------------------------------------------------
date_to_epoch_utc() {
  local ymd="$1"
  if [[ "$DATE_FLAVOR" == "gnu" ]]; then
    TZ=UTC date -d "${ymd} 00:00:00" +%s
  else
    TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "${ymd} 00:00:00" +%s
  fi
}

epoch_to_git_timestamp_utc() {
  local epoch="$1"
  if [[ "$DATE_FLAVOR" == "gnu" ]]; then
    TZ=UTC date -d "@${epoch}" "+%Y-%m-%d %H:%M:%S %z"
  else
    TZ=UTC date -r "${epoch}" "+%Y-%m-%d %H:%M:%S %z"
  fi
}

# -------------------------------------------------------------------
# Convert start/end dates to epoch seconds
# -------------------------------------------------------------------
start_epoch="$(date_to_epoch_utc "$START_DATE")"
end_epoch="$(date_to_epoch_utc "$END_DATE")"

if (( start_epoch > end_epoch )); then
  echo "Error: START_DATE must be earlier than or equal to END_DATE." >&2
  exit 1
fi

# -------------------------------------------------------------------
# Generate commits for each day in the range:
# - random number of commits between 10 and 20
# - random times within each day
# - sorted times to ensure chronological validity
# -------------------------------------------------------------------
current_epoch="$start_epoch"

while (( current_epoch <= end_epoch )); do
  commits_today=$(( RANDOM % (MAX_COMMITS_PER_DAY - MIN_COMMITS_PER_DAY + 1) + MIN_COMMITS_PER_DAY ))

  # Generate random offsets (0..86399) for this day and sort them.
  # Sorting guarantees non-decreasing commit timestamps within the day.
  tmp_offsets_file="$(mktemp)"
  for ((i = 0; i < commits_today; i++)); do
    echo $(( RANDOM % 86400 ))
  done | sort -n > "$tmp_offsets_file"

  # Create empty commits with both author and committer dates set.
  while IFS= read -r offset; do
    commit_epoch=$(( current_epoch + offset ))
    commit_ts="$(epoch_to_git_timestamp_utc "$commit_epoch")"

    GIT_AUTHOR_DATE="$commit_ts" \
    GIT_COMMITTER_DATE="$commit_ts" \
      git commit --allow-empty -m "$COMMIT_MESSAGE" >/dev/null
  done < "$tmp_offsets_file"

  rm -f "$tmp_offsets_file"

  # Move to next day (UTC)
  current_epoch=$(( current_epoch + 86400 ))
done

# -------------------------------------------------------------------
# Final instruction
# -------------------------------------------------------------------
echo "Done. Commits generated from ${START_DATE} to ${END_DATE}."
echo "Now run:"
echo "git push origin main"
