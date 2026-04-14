#!/bin/bash
# ============================================================================
# NSFuzz Per-Run Summary Script
# Strictly modeled after ChatAFL-master/run_summary.sh
#
# Generates a run_summary.csv containing per-run metrics (runtime, coverage,
# state nodes/edges) from NSFuzz fuzzing result archives.
#
# Usage:
#   ./run_summary.sh <results-dir>
#
# Examples:
#   ./run_summary.sh bftpd-nsfuzz
#   ./run_summary.sh kamailio
#   ./run_summary.sh /absolute/path/to/results-dir
#   ./run_summary.sh ../execution/lightftp-nsfuzz
#
# The output file (run_summary.csv) is written into the results directory.
# ============================================================================
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./run_summary.sh <results-dir>"
  echo "Example: ./run_summary.sh bftpd-nsfuzz"
  echo "         ./run_summary.sh kamailio"
  echo "         ./run_summary.sh /path/to/results-dir"
  exit 1
fi

RAW_RESULTS_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate the results directory ──
# Search multiple candidate paths following NSFuzz directory conventions:
#   1) The argument as-is (absolute or relative path)
#   2) Under the script's own directory (scripts/execution/<dir>)
#   3) Under a sibling execution directory (scripts/execution/<dir>)
#   4) Under the parent execution directory (../execution/<dir>)
RESULTS_DIR=""
for candidate in \
  "$RAW_RESULTS_DIR" \
  "$SCRIPT_DIR/$RAW_RESULTS_DIR" \
  "$SCRIPT_DIR/../execution/$RAW_RESULTS_DIR" \
  "../execution/$RAW_RESULTS_DIR"; do
  if [[ -d "$candidate" ]]; then
    RESULTS_DIR="$candidate"
    break
  fi
done

if [[ -z "$RESULTS_DIR" ]]; then
  echo "Error: results directory not found: $RAW_RESULTS_DIR"
  echo ""
  echo "Available result directories in $(realpath "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR"):"
  find "$SCRIPT_DIR" -maxdepth 1 -type d ! -name "." | while read -r d; do
    cnt=$(find "$d" -maxdepth 1 -name "*.tar.gz" 2>/dev/null | wc -l)
    if [[ "$cnt" -gt 0 ]]; then
      echo "  $(basename "$d")  ($cnt archives)"
    fi
  done
  exit 1
fi

OUTPUT_FILE="$(cd "$RESULTS_DIR" && pwd)/run_summary.csv"

# ── Locate run_summary.py ──
# Search in the analysis scripts directory following NSFuzz project structure:
#   scripts/analysis/run_summary.py (relative to scripts/execution/)
SUMMARY_PY=""
for candidate in \
  "$SCRIPT_DIR/../analysis/run_summary.py" \
  "$SCRIPT_DIR/../../scripts/analysis/run_summary.py" \
  "$SCRIPT_DIR/run_summary.py"; do
  if [[ -f "$candidate" ]]; then
    SUMMARY_PY="$candidate"
    break
  fi
done

if [[ -z "$SUMMARY_PY" ]]; then
  echo "Error: cannot find scripts/analysis/run_summary.py"
  exit 1
fi

python3 "$SUMMARY_PY" "$RESULTS_DIR" -o "$OUTPUT_FILE"
