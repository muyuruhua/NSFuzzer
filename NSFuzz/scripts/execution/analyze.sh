#!/bin/bash

# ============================================================================
# NSFuzz Result Analysis Script
# Strictly modeled after ChatAFL-master/analyze.sh
#
# Generates coverage and state graphs from NSFuzz fuzzing results.
#
# Usage:
#   ./analyze.sh <subject names> [time in minutes] [results-dir]
#
# Examples:
#   ./analyze.sh bftpd-nsfuzz
#   ./analyze.sh bftpd-nsfuzz 1440
#   ./analyze.sh bftpd-nsfuzz,kamailio 1440
#   ./analyze.sh bftpd-nsfuzz 1440 bftpd-nsfuzz
#   ./analyze.sh kamailio 1440 kamailio
#
# NSFuzz result directory convention:
#   scripts/execution/<subject-dir>/out-<subject>-<fuzzer>_<N>.tar.gz
#   e.g., bftpd-nsfuzz/out-bftpd-nsfuzz_1.tar.gz
#         kamailio/out-kamailio-aflnet_1.tar.gz
# ============================================================================

FILTER=$1
TIME=${2:-1440}
EXPLICIT_DIR=${3:-""}   # Optional: explicit results directory name

reset="\e[0m"
green="\e[0;92m"
yellow="\e[0;33m"
function warn  { echo -e "${yellow}[!] $1$reset"; }
function info  { echo -e "${green}[+]$reset $1"; }

if [ -z "$FILTER" ]; then
    echo "Usage: analyze.sh <subject names> <time in minutes> [results-dir]"
    echo "  subject names: comma-separated, e.g., bftpd-nsfuzz,kamailio,lightftp-nsfuzz"
    echo "  time: cutoff time in minutes (default: 1440)"
    echo "  results-dir: optional, e.g., bftpd-nsfuzz or kamailio"
    echo ""
    echo "Available result directories:"
    BASE_DIR=$(cd "$(dirname "$0")" && pwd)
    find "$BASE_DIR" -maxdepth 1 -type d -name "*" ! -name "." | while read d; do
        cnt=$(find "$d" -maxdepth 1 -name "*.tar.gz" 2>/dev/null | wc -l)
        if [ "$cnt" -gt 0 ]; then
            echo "  $(basename "$d")  ($cnt archives)"
        fi
    done
    exit 1
fi

PFBENCH=$(cd "$(dirname "$0")" && pwd)
ANALYSIS_DIR=$(cd "$(dirname "$0")/../analysis" && pwd 2>/dev/null || echo "$PFBENCH/../analysis")
RESULT_OWNER="${SUDO_USER:-$USER}"
RESULT_GROUP="$(id -gn "${RESULT_OWNER}")"

fix_result_permissions() {
    local path="$1"
    [[ -e "$path" ]] || return 0
    chown -R "${RESULT_OWNER}:${RESULT_GROUP}" "$path" 2>/dev/null || true
    chmod -R u+rwX "$path" 2>/dev/null || true
}

# Pre-flight permission check
if [ ! -w "$PFBENCH" ]; then
    warn "No write permission in $PFBENCH directory"
    warn "Please run with sudo or fix directory permissions:"
    warn "  sudo chown -R \$USER:\$USER $PFBENCH"
    warn "  Or run: sudo ./analyze.sh $FILTER $TIME"
    exit 1
fi

# ============================================================================
# Embedded helper: profuzzbench_generate_csv.sh logic
# Adapted for NSFuzz plot_data format (11 columns, no n_nodes/n_edges)
# ============================================================================

#remove space(s)
strim() {
    trimmedStr=$1
    echo "${trimmedStr##*( )}"
}

#original format: time,l_per,l_abs,b_per,b_abs
#converted format: time,subject,fuzzer,run,cov_type,cov
convert_cov() {
    local fuzzer=$1
    local subject=$2
    local run_index=$3
    local ifile=$4
    local ofile=$5

    {
        read  # ignore the header
        while read -r line; do
            time=$(strim "$(echo "$line" | cut -d',' -f1)")
            l_per=$(strim "$(echo "$line" | cut -d',' -f2)")
            l_abs=$(strim "$(echo "$line" | cut -d',' -f3)")
            b_per=$(strim "$(echo "$line" | cut -d',' -f4)")
            b_abs=$(strim "$(echo "$line" | cut -d',' -f5)")
            echo "$time,$subject,$fuzzer,$run_index,l_per,$l_per" >> "$ofile"
            echo "$time,$subject,$fuzzer,$run_index,l_abs,$l_abs" >> "$ofile"
            echo "$time,$subject,$fuzzer,$run_index,b_per,$b_per" >> "$ofile"
            echo "$time,$subject,$fuzzer,$run_index,b_abs,$b_abs" >> "$ofile"
        done
    } < "$ifile"
}

# NSFuzz plot_data format:
# # unix_time, cycles_done, cur_path, paths_total, pending_total, pending_favs,
#   map_size, unique_crashes, unique_hangs, max_depth, execs_per_sec
# (11 columns, NO n_nodes/n_edges)
#
# For state analysis, we extract paths_total (col 4) and unique_crashes (col 8)
# as proxy metrics. If ipsm.dot exists, we can also count IPSM nodes/edges.
#
# However, to stay compatible with profuzzbench_state.py which expects
# "nodes" and "edges" state_types, we extract from ipsm.dot if available,
# otherwise we skip state data for this run.
convert_state_from_plot_data() {
    local fuzzer=$1
    local subject=$2
    local run_index=$3
    local ifile=$4
    local ofile=$5
    local ipsm_dot=$6  # path to ipsm.dot (may not exist)

    # If ipsm.dot exists, count final state nodes and edges
    local ipsm_nodes=0
    local ipsm_edges=0
    if [ -f "$ipsm_dot" ]; then
        # Count unique state node declarations:
        # Lines with "[color=" but without "->" and not the generic "node"/"edge" attributes
        ipsm_nodes=$(grep '\[color=' "$ipsm_dot" | grep -v '\->' | grep -cv '^\s*\(node\|edge\)\s')
        # Count state transition edges: lines with "->"
        ipsm_edges=$(grep -c '\->' "$ipsm_dot" 2>/dev/null)
    fi

    {
        read  # ignore the header
        while read -r line; do
            time=$(strim "$(echo "$line" | cut -d',' -f1)")
            # Use ipsm final counts as constant state values for all time points
            # This is the best we can do without time-series state data
            echo "$time,$subject,$fuzzer,$run_index,nodes,$ipsm_nodes" >> "$ofile"
            echo "$time,$subject,$fuzzer,$run_index,edges,$ipsm_edges" >> "$ofile"
        done
    } < "$ifile"
}

# ============================================================================
# Main analysis loop
# ============================================================================

cd "$PFBENCH"

for SUBJECT in $(echo "$FILTER" | tr "," "\n"); do
    echo ""
    echo "========================================"
    echo "Analyzing $SUBJECT"
    echo "========================================"

    # Determine results directory
    if [ -n "$EXPLICIT_DIR" ]; then
        RESULTS_DIR="$EXPLICIT_DIR"
        info "Using explicitly specified directory: $RESULTS_DIR"
    else
        # NSFuzz convention: results stored in a directory matching the subject name
        # e.g., bftpd-nsfuzz/, kamailio/, lightftp-nsfuzz/
        RESULTS_DIR="$SUBJECT"
    fi

    # Remove leading './' if present
    RESULTS_DIR=${RESULTS_DIR#./}

    # Check if results directory exists and has content
    if [ ! -d "$RESULTS_DIR" ] || [ -z "$(ls -A "$RESULTS_DIR" 2>/dev/null)" ]; then
        warn "No results for subject $SUBJECT (checked $PFBENCH/$RESULTS_DIR)."
        warn "Please check whether the fuzzing has completed via the following command:"
        warn "  docker ps -a | grep $SUBJECT"
        docker ps -a | grep "$SUBJECT" 2>/dev/null || true
        warn ""
        warn "If the containers' status is 'Up ..', please wait for the fuzzing to complete."
        warn "Once the fuzzing completes, the containers' status will change to 'Exited ..'"
        continue
    fi

    # Check write permission in results directory before analysis
    if [ ! -w "$RESULTS_DIR" ]; then
        warn "No write permission in $RESULTS_DIR"
        warn "Attempting to fix permissions..."
        sudo chown -R "$USER:$(id -gn)" "$RESULTS_DIR" 2>/dev/null || {
            warn "Failed to fix permissions. Please run:"
            warn "  sudo chown -R \$USER:\$USER $RESULTS_DIR"
            continue
        }
        info "Permissions fixed successfully"
    fi

    # Validate results directory contains actual fuzzing data
    TAR_COUNT=$(find "$RESULTS_DIR" -maxdepth 1 -name "*.tar.gz" 2>/dev/null | wc -l)
    if [ "$TAR_COUNT" -eq 0 ]; then
        warn "No .tar.gz files found in $RESULTS_DIR (empty or incomplete results)"
        warn "Skipping analysis for this directory"
        continue
    fi

    info "Found results directory: $RESULTS_DIR (contains $TAR_COUNT result archives)"

    # ── Extract fuzzers and replication count from archive names ──
    # NSFuzz archive naming: out-<subject>-<fuzzer>_<N>.tar.gz
    # Examples:
    #   out-bftpd-nsfuzz_1.tar.gz       → fuzzer=nsfuzz, run=1
    #   out-kamailio-aflnet_1.tar.gz    → fuzzer=aflnet, run=1
    #   out-kamailio-nsfuzz-v_1.tar.gz  → fuzzer=nsfuzz-v, run=1
    #   out-lightftp-nsfuzz_10.tar.gz   → fuzzer=nsfuzz, run=10
    cd "$PFBENCH/$RESULTS_DIR"

    info "Extracting fuzzer names and replication count..."

    # Extract unique fuzzer names and max run number from .tar.gz filenames
    # Pattern: out-<anything>-<fuzzer>_<number>.tar.gz
    # We need to handle multi-part subject names like "forked-daapd" and fuzzer names like "nsfuzz-v"
    FUZZERS=$(ls *.tar.gz 2>/dev/null | \
        perl -n -l -e '
            if (/^out-(.+?)_(\d+)\.tar\.gz$/) {
                my $prefix = $1;
                # The fuzzer is the last component after the subject name
                # Known fuzzers: aflnet, aflnwe, stateafl, nsfuzz, nsfuzz-v
                if ($prefix =~ /-(nsfuzz-v|nsfuzz|aflnet|aflnwe|stateafl)$/) {
                    print $1;
                }
            }
        ' | sort | uniq)

    REPS=$(ls *.tar.gz 2>/dev/null | \
        perl -n -l -e 'print $1 if /^out-.+?_(\d+)\.tar\.gz$/' | sort -n | tail -n 1)

    if [ -z "$FUZZERS" ] || [ -z "$REPS" ]; then
        warn "Cannot extract fuzzer names or replication count from $RESULTS_DIR"
        warn "Archive files found:"
        ls *.tar.gz 2>/dev/null | head -10
        cd "$PFBENCH"
        continue
    fi

    FUZZERS_DISPLAY=$(echo "$FUZZERS" | tr '\n' ',' | sed 's/,$//')
    info "Subject: $SUBJECT, Fuzzers: $FUZZERS_DISPLAY, Replications: $REPS"

    # Determine the original subject name (without fuzzer suffix)
    # e.g., "bftpd-nsfuzz" dir with "out-bftpd-nsfuzz_1.tar.gz" → original subject is "bftpd"
    # e.g., "kamailio" dir with "out-kamailio-aflnet_1.tar.gz" → original subject is "kamailio"
    # We extract from the first .tar.gz by removing the fuzzer suffix
    FIRST_TAR=$(ls *.tar.gz 2>/dev/null | head -1)
    ORIGINAL_SUBJECT=$(echo "$FIRST_TAR" | \
        perl -n -l -e '
            if (/^out-(.+?)_\d+\.tar\.gz$/) {
                my $prefix = $1;
                $prefix =~ s/-(nsfuzz-v|nsfuzz|aflnet|aflnwe|stateafl)$//;
                print $prefix;
            }
        ')

    if [ -z "$ORIGINAL_SUBJECT" ]; then
        ORIGINAL_SUBJECT="$SUBJECT"
    fi

    info "Original subject name: $ORIGINAL_SUBJECT"

    # ── Clean up previous analysis ──
    rm -f results.csv states.csv 2>/dev/null
    ls | grep "^out-" | grep -v "tar.gz" | grep -v "sv_range" | grep -v ".json" | xargs rm -rf 2>/dev/null

    # ── Generate CSV data ──
    # Initialize CSV files with headers
    echo "time,subject,fuzzer,run,cov_type,cov" > results.csv
    echo "time,subject,fuzzer,run,state_type,state" > states.csv

    for FUZZER in $FUZZERS; do
        info "Analyzing fuzzer: $FUZZER"

        for i in $(seq 1 "$REPS"); do
            TARFILE="out-${ORIGINAL_SUBJECT}-${FUZZER}_${i}.tar.gz"
            OUTDIR_NAME="out-${ORIGINAL_SUBJECT}-${FUZZER}"

            if [ ! -f "$TARFILE" ]; then
                warn "Archive not found: $TARFILE (run $i), skipping"
                continue
            fi

            printf "\nProcessing ${OUTDIR_NAME}-${i} ..."

            # Clean up any previous extraction
            rm -rf "${OUTDIR_NAME}" "${OUTDIR_NAME}-${i}" 2>/dev/null

            # Extract relevant files from the archive
            tar -axf "$TARFILE" "${OUTDIR_NAME}/cov_over_time.csv" 2>/dev/null
            tar -axf "$TARFILE" "${OUTDIR_NAME}/plot_data" 2>/dev/null
            tar -axf "$TARFILE" "${OUTDIR_NAME}/ipsm.dot" 2>/dev/null
            tar -axf "$TARFILE" "${OUTDIR_NAME}/fuzzer_stats" 2>/dev/null

            # Rename to include run index
            mv "${OUTDIR_NAME}" "${OUTDIR_NAME}-${i}" 2>/dev/null

            # Convert coverage data
            if [ -f "${OUTDIR_NAME}-${i}/cov_over_time.csv" ]; then
                convert_cov "$FUZZER" "$ORIGINAL_SUBJECT" "$i" \
                    "${OUTDIR_NAME}-${i}/cov_over_time.csv" \
                    "$PWD/results.csv"
            else
                warn "No cov_over_time.csv in $TARFILE"
            fi

            # Convert state data
            if [ -f "${OUTDIR_NAME}-${i}/plot_data" ]; then
                convert_state_from_plot_data "$FUZZER" "$ORIGINAL_SUBJECT" "$i" \
                    "${OUTDIR_NAME}-${i}/plot_data" \
                    "$PWD/states.csv" \
                    "${OUTDIR_NAME}-${i}/ipsm.dot"
            else
                warn "No plot_data in $TARFILE"
            fi
        done

        # Clean up extracted directories for this fuzzer
        ls | grep "^out-${ORIGINAL_SUBJECT}-${FUZZER}" | grep -v "tar.gz" | grep -v ".json" | xargs rm -rf 2>/dev/null
        printf "\n\n"
    done

    # ── Summary statistics from fuzzer_stats ──
    STATS_CSV="fuzzer_summary.csv"
    echo "fuzzer,run,runtime_min,execs_done,execs_per_sec,paths_total,paths_favored,unique_crashes,unique_hangs,variable_paths,bitmap_cvg" > "$STATS_CSV"
    _stats_has_data=0
    for _SF in $FUZZERS; do
        for _SR in $(seq 1 "$REPS"); do
            _starf="out-${ORIGINAL_SUBJECT}-${_SF}_${_SR}.tar.gz"
            [[ ! -f "$_starf" ]] && continue
            _sstats=$(tar -xzOf "$_starf" --wildcards "*/fuzzer_stats" 2>/dev/null || true)
            [[ -z "$_sstats" ]] && continue
            _sst=$(echo "$_sstats"   | grep -m1 '^start_time'      | sed 's/.*: *//' | tr -d '[:space:]')
            _slu=$(echo "$_sstats"   | grep -m1 '^last_update'     | sed 's/.*: *//' | tr -d '[:space:]')
            _sexe=$(echo "$_sstats"  | grep -m1 '^execs_done'      | sed 's/.*: *//' | tr -d '[:space:]')
            _seps=$(echo "$_sstats"  | grep -m1 '^execs_per_sec'   | sed 's/.*: *//' | tr -d '[:space:]')
            _spt=$(echo "$_sstats"   | grep -m1 '^paths_total'     | sed 's/.*: *//' | tr -d '[:space:]')
            _spf=$(echo "$_sstats"   | grep -m1 '^paths_favored'   | sed 's/.*: *//' | tr -d '[:space:]')
            _suc=$(echo "$_sstats"   | grep -m1 '^unique_crashes'  | sed 's/.*: *//' | tr -d '[:space:]')
            _suh=$(echo "$_sstats"   | grep -m1 '^unique_hangs'    | sed 's/.*: *//' | tr -d '[:space:]')
            _svp=$(echo "$_sstats"   | grep -m1 '^variable_paths'  | sed 's/.*: *//' | tr -d '[:space:]')
            _sbcvg=$(echo "$_sstats" | grep -m1 '^bitmap_cvg'      | sed 's/.*: *//' | tr -d '[:space:]')
            _srmin=0
            [[ -n "$_sst" && -n "$_slu" ]] && _srmin=$(( (_slu - _sst) / 60 ))
            echo "${_SF},${_SR},${_srmin},${_sexe:-0},${_seps:-0},${_spt:-0},${_spf:-0},${_suc:-0},${_suh:-0},${_svp:-0},${_sbcvg:-0}" >> "$STATS_CSV"
            _stats_has_data=1
        done
    done
    if [[ $_stats_has_data -eq 1 ]]; then
        info "Fuzzer summary → ${RESULTS_DIR}/fuzzer_summary.csv"
    else
        rm -f "$STATS_CSV"
    fi

    # ── IPSM State Model Summary ──
    IPSM_CSV="ipsm_summary.csv"
    echo "fuzzer,run,ipsm_nodes,ipsm_edges" > "$IPSM_CSV"
    _ipsm_has_data=0
    for _IF in $FUZZERS; do
        for _IR in $(seq 1 "$REPS"); do
            _itarf="out-${ORIGINAL_SUBJECT}-${_IF}_${_IR}.tar.gz"
            [[ ! -f "$_itarf" ]] && continue
            _idot=$(tar -xzOf "$_itarf" --wildcards "*/ipsm.dot" 2>/dev/null || true)
            [[ -z "$_idot" ]] && continue
            # Count state nodes: lines with [color=...] but no -> and not generic node/edge attrs
            _inodes=$(echo "$_idot" | grep '\[color=' | grep -v '\->' | grep -cv '^\s*\(node\|edge\)\s')
            # Count state transition edges: lines with ->
            _iedges=$(echo "$_idot" | grep -c '\->')
            echo "${_IF},${_IR},${_inodes},${_iedges}" >> "$IPSM_CSV"
            _ipsm_has_data=1
        done
    done
    if [[ $_ipsm_has_data -eq 1 ]]; then
        info "IPSM state model summary → ${RESULTS_DIR}/ipsm_summary.csv"
    else
        rm -f "$IPSM_CSV"
    fi

    # ── State Variable Range Summary ──
    SV_CSV="sv_range_summary.csv"
    echo "fuzzer,run,sv_range_file,num_variables" > "$SV_CSV"
    _sv_has_data=0
    for _VF in $FUZZERS; do
        for _VR in $(seq 1 "$REPS"); do
            _vfile="out-${ORIGINAL_SUBJECT}-${_VF}_sv_range_${_VR}.json"
            [[ ! -f "$_vfile" ]] && continue
            # Count number of top-level keys in JSON (state variables)
            _vcount=$(python3 -c "import json; f=open('$_vfile'); d=json.load(f); print(len(d))" 2>/dev/null || echo "0")
            echo "${_VF},${_VR},${_vfile},${_vcount}" >> "$SV_CSV"
            _sv_has_data=1
        done
    done
    if [[ $_sv_has_data -eq 1 ]]; then
        info "State variable range summary → ${RESULTS_DIR}/sv_range_summary.csv"
    else
        rm -f "$SV_CSV"
    fi

    # ── Generate plots ──
    info "Generating plots..."

    # Check if python3 and required packages are available
    PYBIN=""
    for _pycandidate in python3 \
        /home/*/miniconda3/bin/python3 \
        /home/*/.conda/bin/python3 \
        /home/*/anaconda3/bin/python3 \
        /opt/conda/bin/python3; do
        if command -v "$_pycandidate" &>/dev/null 2>&1 || [[ -x "$_pycandidate" ]]; then
            if $_pycandidate -c "import pandas; import matplotlib" 2>/dev/null; then
                PYBIN="$_pycandidate"
                break
            fi
        fi
    done

    if [ -z "$PYBIN" ]; then
        warn "Cannot find python3 with pandas and matplotlib."
        warn "Skipping plot generation. Please install: pip install pandas matplotlib"
        warn "CSV files have been generated successfully — you can plot manually."
    else
        info "Using Python: $PYBIN"

        # Generate coverage plot using inline Python
        $PYBIN - <<'COVERAGE_PLOT_EOF' "$PWD/results.csv" "$ORIGINAL_SUBJECT" "$REPS" "$TIME" "60" "${ORIGINAL_SUBJECT}_coverage" $FUZZERS
import sys
import argparse
from pandas import read_csv
from matplotlib import pyplot as plt
import pandas as pd

# Suppress matplotlib GUI
import matplotlib
matplotlib.use('Agg')

args = sys.argv[1:]
csv_file = args[0]
put = args[1]
runs = int(args[2])
cut_off = int(args[3])
step = int(args[4])
out_file = args[5]
fuzzers = args[6:]

df = read_csv(csv_file)
mean_list = []

for subject in [put]:
    for fuzzer in fuzzers:
        fuzzer_lower = fuzzer.lower()
        for cov_type in ['b_abs', 'b_per', 'l_abs', 'l_per']:
            df1 = df[(df['subject'] == subject) &
                     (df['fuzzer'] == fuzzer_lower) &
                     (df['cov_type'] == cov_type)]
            if df1.empty:
                continue
            mean_list.append((subject, fuzzer_lower, cov_type, 0, 0.0))
            for time in range(1, cut_off + 1, step):
                cov_total = 0
                run_count = 0
                for run in range(1, runs + 1):
                    df2 = df1[df1['run'] == run]
                    try:
                        start = df2.iloc[0, 0]
                        df3 = df2[df2['time'] <= start + time*60]
                        cov_total += df3.tail(1).iloc[0, 5]
                        run_count += 1
                    except Exception:
                        pass
                mean_list.append((subject, fuzzer_lower, cov_type, time, cov_total / max(run_count, 1)))

mean_df = pd.DataFrame(mean_list, columns=['subject', 'fuzzer', 'cov_type', 'time', 'cov'])

COLOR_PALETTE = ['#1f77b4', '#ff7f0e', '#d62728', '#9467bd', '#8c564b',
                 '#e377c2', '#7f7f7f', '#bcbd22', '#17becf']
LINE_STYLES = ['-', '--', '-.', ':', '-', '--', '-.', ':']
MARKERS     = ['o', 's',  '^',  'D', 'v', 'P',  'X',  '*']
fuzzer_colors = {f.lower(): COLOR_PALETTE[i % len(COLOR_PALETTE)] for i, f in enumerate(fuzzers)}
fuzzer_styles = {f.lower(): LINE_STYLES[i % len(LINE_STYLES)] for i, f in enumerate(fuzzers)}
fuzzer_markers = {f.lower(): MARKERS[i % len(MARKERS)] for i, f in enumerate(fuzzers)}
marker_every = max(1, cut_off // (step * 10))

fig, axes = plt.subplots(2, 2, figsize=(20, 10))
fig.suptitle("Code coverage analysis — %s" % put)

for key, grp in mean_df.groupby(['fuzzer', 'cov_type']):
    c = fuzzer_colors.get(key[0], None)
    ls = fuzzer_styles.get(key[0], '-')
    mk = fuzzer_markers.get(key[0], None)
    if key[1] == 'b_abs':
        axes[0, 0].plot(grp['time'], grp['cov'], color=c, linestyle=ls, marker=mk, markevery=marker_every, markersize=5, linewidth=2)
        axes[0, 0].set_xlabel('Time (in min)')
        axes[0, 0].set_ylabel('#edges')
    if key[1] == 'b_per':
        axes[1, 0].plot(grp['time'], grp['cov'], color=c, linestyle=ls, marker=mk, markevery=marker_every, markersize=5, linewidth=2)
        axes[1, 0].set_xlabel('Time (in min)')
        axes[1, 0].set_ylabel('Edge coverage (%)')
    if key[1] == 'l_abs':
        axes[0, 1].plot(grp['time'], grp['cov'], color=c, linestyle=ls, marker=mk, markevery=marker_every, markersize=5, linewidth=2)
        axes[0, 1].set_xlabel('Time (in min)')
        axes[0, 1].set_ylabel('#lines')
    if key[1] == 'l_per':
        axes[1, 1].plot(grp['time'], grp['cov'], color=c, linestyle=ls, marker=mk, markevery=marker_every, markersize=5, linewidth=2)
        axes[1, 1].set_xlabel('Time (in min)')
        axes[1, 1].set_ylabel('Line coverage (%)')

for i, ax in enumerate(fig.axes):
    lines = ax.get_lines()
    if lines:
        all_y = [y for line in lines for y in line.get_ydata()]
        ymin, ymax = min(all_y), max(all_y)
        if i < 2:  # absolute plots
            margin = max((ymax - ymin) * 0.1, 10)
            ax.set_ylim([max(0, ymin - margin), ymax + margin])
    ax.legend(fuzzers, loc='upper left')
    ax.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig(out_file + '.png', dpi=150)
print("Coverage plot saved: %s.png" % out_file)
COVERAGE_PLOT_EOF

        # Generate state plot using inline Python (IPSM nodes & edges from ipsm.dot)
        $PYBIN - <<'STATE_PLOT_EOF' "$PWD/states.csv" "$ORIGINAL_SUBJECT" "$REPS" "$TIME" "60" "${ORIGINAL_SUBJECT}_states" $FUZZERS
import sys
from pandas import read_csv
from matplotlib import pyplot as plt
import pandas as pd

import matplotlib
matplotlib.use('Agg')

args = sys.argv[1:]
csv_file = args[0]
put = args[1]
runs = int(args[2])
cut_off = int(args[3])
step = int(args[4])
out_file = args[5]
fuzzers = args[6:]

df = read_csv(csv_file)
mean_list = []

for subject in [put]:
    for fuzzer in fuzzers:
        fuzzer_lower = fuzzer.lower()
        for data_type in ['nodes', 'edges']:
            df1 = df[(df['subject'] == subject) &
                     (df['fuzzer'] == fuzzer_lower) &
                     (df['state_type'] == data_type)]
            if df1.empty:
                continue
            mean_list.append((subject, fuzzer_lower, data_type, 0, 0.0))
            for time in range(1, cut_off + 1, step):
                cov_total = 0
                run_count = 0
                for run in range(1, runs + 1):
                    df2 = df1[df1['run'] == run]
                    try:
                        start = df2.iloc[0, 0]
                        df3 = df2[df2['time'] <= start + time*60]
                        cov_total += df3.tail(1).iloc[0, 5]
                        run_count += 1
                    except Exception:
                        pass
                mean_list.append((subject, fuzzer_lower, data_type, time, cov_total / max(run_count, 1)))

mean_df = pd.DataFrame(mean_list, columns=['subject', 'fuzzer', 'data_type', 'time', 'data'])
mean_df.to_csv("mean_plot_data.csv", index=False)

COLOR_PALETTE = ['#1f77b4', '#ff7f0e', '#d62728', '#9467bd', '#8c564b',
                 '#e377c2', '#7f7f7f', '#bcbd22', '#17becf']
LINE_STYLES = ['-', '--', '-.', ':', '-', '--', '-.', ':']
MARKERS     = ['o', 's',  '^',  'D', 'v', 'P',  'X',  '*']
fuzzer_colors = {f.lower(): COLOR_PALETTE[i % len(COLOR_PALETTE)] for i, f in enumerate(fuzzers)}
fuzzer_styles = {f.lower(): LINE_STYLES[i % len(LINE_STYLES)] for i, f in enumerate(fuzzers)}
fuzzer_markers = {f.lower(): MARKERS[i % len(MARKERS)] for i, f in enumerate(fuzzers)}
marker_every = max(1, cut_off // (step * 10))

fig, axes = plt.subplots(1, 2, figsize=(20, 10))
fig.suptitle("State coverage analysis — %s (IPSM)" % put)

for key, grp in mean_df.groupby(['fuzzer', 'data_type']):
    c = fuzzer_colors.get(key[0], None)
    ls = fuzzer_styles.get(key[0], '-')
    mk = fuzzer_markers.get(key[0], None)
    if key[1] == 'nodes':
        axes[0].plot(grp['time'], grp['data'], color=c, linestyle=ls, marker=mk, markevery=marker_every, markersize=5, linewidth=2)
        axes[0].set_xlabel('Time (in min)')
        axes[0].set_ylabel('#IPSM nodes')
    if key[1] == 'edges':
        axes[1].plot(grp['time'], grp['data'], color=c, linestyle=ls, marker=mk, markevery=marker_every, markersize=5, linewidth=2)
        axes[1].set_xlabel('Time (in min)')
        axes[1].set_ylabel('#IPSM edges')

for ax in fig.axes:
    lines = ax.get_lines()
    if lines:
        all_y = [y for line in lines for y in line.get_ydata()]
        ymin, ymax = min(all_y), max(all_y)
        margin = max((ymax - ymin) * 0.15, 1)
        ax.set_ylim([max(0, ymin - margin), ymax + margin])
    ax.legend(fuzzers, loc='upper left')
    ax.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig(out_file + '.png', dpi=150)
print("State plot saved: %s.png" % out_file)
STATE_PLOT_EOF
    fi

    # ── Add timestamp to generated plots ──
    TIMESTAMP=$(date "+%b-%d_%H-%M-%S")

    if [ -f "${ORIGINAL_SUBJECT}_coverage.png" ]; then
        mv "${ORIGINAL_SUBJECT}_coverage.png" "cov_over_time_${ORIGINAL_SUBJECT}_${TIMESTAMP}.png"
        info "Generated coverage plot: cov_over_time_${ORIGINAL_SUBJECT}_${TIMESTAMP}.png"
    fi

    if [ -f "${ORIGINAL_SUBJECT}_states.png" ]; then
        mv "${ORIGINAL_SUBJECT}_states.png" "state_over_time_${ORIGINAL_SUBJECT}_${TIMESTAMP}.png"
        info "Generated state plot: state_over_time_${ORIGINAL_SUBJECT}_${TIMESTAMP}.png"
    fi

    cd "$PFBENCH"

    # ── Copy results to a timestamped output folder ──
    RES_FOLDER=$(date "+res_${SUBJECT}_%b-%d_%H-%M-%S")

    info "Results from analysis for ${SUBJECT} are stored in ../$RES_FOLDER"
    mkdir -p "../$RES_FOLDER"
    fix_result_permissions "../$RES_FOLDER"

    # Copy plots
    cp -r "$RESULTS_DIR"/cov_over_time_*.png "../$RES_FOLDER" 2>/dev/null || true
    cp -r "$RESULTS_DIR"/state_over_time_*.png "../$RES_FOLDER" 2>/dev/null || true

    # Copy CSV files
    cp -r "$RESULTS_DIR"/results.csv "../$RES_FOLDER" 2>/dev/null || true
    cp -r "$RESULTS_DIR"/states.csv "../$RES_FOLDER" 2>/dev/null || true
    cp -r "$RESULTS_DIR"/mean_plot_data.csv "../$RES_FOLDER" 2>/dev/null || true
    cp -r "$RESULTS_DIR"/fuzzer_summary.csv "../$RES_FOLDER" 2>/dev/null || true
    cp -r "$RESULTS_DIR"/ipsm_summary.csv "../$RES_FOLDER" 2>/dev/null || true
    cp -r "$RESULTS_DIR"/sv_range_summary.csv "../$RES_FOLDER" 2>/dev/null || true

    # Copy original result archives
    cp -r "$RESULTS_DIR" "../$RES_FOLDER/"
    fix_result_permissions "../$RES_FOLDER"

    info "Done analyzing $SUBJECT"
    echo ""
done

info "All analyses complete."
