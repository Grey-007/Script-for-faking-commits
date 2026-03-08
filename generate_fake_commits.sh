#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Configuration: date range (inclusive)
# -------------------------------------------------------------------
START_DATE="2025-12-07"
END_DATE="2026-03-04"

# Weekday and weekend commit limits
WEEKDAY_MIN=5
WEEKDAY_MAX=15
WEEKEND_MIN=0
WEEKEND_MAX=6

# Random break-day probability (percent chance of zero commits)
BREAK_DAY_PERCENT=15

# Commit messages used for fake commits
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
# Detect GNU date (Linux) vs BSD date (macOS)
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

epoch_to_iso_weekday_utc() {
  local epoch="$1"
  if [[ "$DATE_FLAVOR" == "gnu" ]]; then
    TZ=UTC date -d "@${epoch}" "+%u"
  else
    TZ=UTC date -r "${epoch}" "+%u"
  fi
}

# -------------------------------------------------------------------
# Random time generation helpers
# Most commits are in 10:00-13:00 and 16:00-22:00.
# Rare commits happen outside those windows.
# -------------------------------------------------------------------
random_time_of_day() {
  local bucket=$(( RANDOM % 100 ))

  if (( bucket < 45 )); then
    # Morning focus block: 10:00-12:59
    echo $(( 10 * 3600 + RANDOM % (3 * 3600) ))
  elif (( bucket < 90 )); then
    # Afternoon/evening focus block: 16:00-21:59
    echo $(( 16 * 3600 + RANDOM % (6 * 3600) ))
  elif (( bucket < 95 )); then
    # Rare early-hours work: 00:00-09:59
    echo $(( RANDOM % (10 * 3600) ))
  else
    # Rare late-night work: 22:00-23:59
    echo $(( 22 * 3600 + RANDOM % (2 * 3600) ))
  fi
}

random_commit_message() {
  local idx=$(( RANDOM % ${#COMMIT_MESSAGES[@]} ))
  echo "${COMMIT_MESSAGES[$idx]}"
}

# -------------------------------------------------------------------
# Build chronological commit offsets for one day.
# Natural behavior:
# - Occasional short bursts: 5-20 minute gaps
# - Otherwise spaced: 30-90 minute gaps
# -------------------------------------------------------------------
generate_day_offsets() {
  local commit_count="$1"
  local day_end=86399

  # No commits today
  if (( commit_count <= 0 )); then
    return 0
  fi

  local -a offsets
  local current
  local burst_remaining=0

  # First commit starts at a weighted realistic hour
  current="$(random_time_of_day)"
  offsets+=("$current")

  for ((i = 1; i < commit_count; i++)); do
    local gap_min=30
    local gap_max=90

    if (( burst_remaining > 0 )); then
      # Continue a burst window (quick follow-up commits)
      gap_min=5
      gap_max=20
      burst_remaining=$(( burst_remaining - 1 ))
    elif (( RANDOM % 100 < 20 )) && (( commit_count - i >= 2 )); then
      # Start a new burst occasionally (2-4 short-gap transitions)
      burst_remaining=$(( RANDOM % 3 + 1 ))
      gap_min=5
      gap_max=20
      burst_remaining=$(( burst_remaining - 1 ))
    fi

    local gap_minutes=$(( RANDOM % (gap_max - gap_min + 1) + gap_min ))
    current=$(( current + gap_minutes * 60 ))

    # Keep times within the day while preserving chronology.
    if (( current > day_end )); then
      local commits_left=$(( commit_count - i ))
      local latest_allowed=$(( day_end - commits_left * 300 ))
      local low=$(( offsets[i - 1] + 60 ))

      if (( latest_allowed < low )); then
        current=$low
      else
        current=$(( RANDOM % (latest_allowed - low + 1) + low ))
      fi
    fi

    # Guarantee chronological ordering within the day.
    if (( current <= offsets[i - 1] )); then
      current=$(( offsets[i - 1] + 60 ))
    fi

    if (( current > day_end )); then
      current=$day_end
    fi

    offsets+=("$current")
  done

  printf '%s\n' "${offsets[@]}"
}

# -------------------------------------------------------------------
# Convert date range to epoch seconds and validate
# -------------------------------------------------------------------
start_epoch="$(date_to_epoch_utc "$START_DATE")"
end_epoch="$(date_to_epoch_utc "$END_DATE")"

if (( start_epoch > end_epoch )); then
  echo "Error: START_DATE must be earlier than or equal to END_DATE." >&2
  exit 1
fi

# -------------------------------------------------------------------
# Generate commits day-by-day
# -------------------------------------------------------------------
current_epoch="$start_epoch"
total_commits=0
active_days=0

day_seconds=86400

while (( current_epoch <= end_epoch )); do
  weekday="$(epoch_to_iso_weekday_utc "$current_epoch")" # 1=Mon ... 7=Sun
  commits_today=0

  # Random break days simulate vacations/off-days.
  if (( RANDOM % 100 < BREAK_DAY_PERCENT )); then
    commits_today=0
  else
    if (( weekday >= 6 )); then
      # Weekend activity is lighter and can be zero.
      commits_today=$(( RANDOM % (WEEKEND_MAX - WEEKEND_MIN + 1) + WEEKEND_MIN ))
    else
      # Weekday activity is higher.
      commits_today=$(( RANDOM % (WEEKDAY_MAX - WEEKDAY_MIN + 1) + WEEKDAY_MIN ))
    fi
  fi

  if (( commits_today > 0 )); then
    active_days=$(( active_days + 1 ))

    # Build ordered commit times for the day.
    while IFS= read -r offset; do
      commit_epoch=$(( current_epoch + offset ))
      commit_ts="$(epoch_to_git_timestamp_utc "$commit_epoch")"
      commit_msg="$(random_commit_message)"

      GIT_AUTHOR_DATE="$commit_ts" \
      GIT_COMMITTER_DATE="$commit_ts" \
        git commit --allow-empty -m "$commit_msg" >/dev/null

      total_commits=$(( total_commits + 1 ))
    done < <(generate_day_offsets "$commits_today")
  fi

  current_epoch=$(( current_epoch + day_seconds ))
done

# -------------------------------------------------------------------
# Summary and next step
# -------------------------------------------------------------------
echo "Done. Generated ${total_commits} commits across ${active_days} active days."
echo "Date range: ${START_DATE} to ${END_DATE}"
echo "Reminder: git push origin main"
