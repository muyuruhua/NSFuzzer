#!/bin/bash
# ============================================================================
# monitor.sh — NSFuzz 运行中容器实时监控
#
# 用法:
#   ./monitor.sh                     # 监控所有运行中的 NSFuzz 容器
#   ./monitor.sh exim               # 只监控 exim
#   ./monitor.sh exim,kamailio -i 60
#   ./monitor.sh -o /tmp/nsfuzz-monitor --csv
#   ./monitor.sh -1                 # 单次采集后退出
#
# 说明:
#   - 只读采集容器内 fuzzer_stats / plot_data / ipsm.dot
#   - 不修改容器内任何状态
#   - 适配 NSFuzz 五个 fuzzer: aflnet, aflnwe, stateafl, nsfuzz, nsfuzz-v
# ============================================================================

set -euo pipefail

# ─── 颜色 ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'

# ─── 默认参数 ───────────────────────────────────────────────────────────────
INTERVAL=30
ONCE=0
OUT_DIR=""
CSV_MODE=0
FILTER="" # 目标过滤器，空=全部

# NSFuzz 支持的 fuzzer 后缀（用于从 out-dir 反推 fuzzer/target）
KNOWN_FUZZERS=("nsfuzz-v" "stateafl" "aflnet" "aflnwe" "nsfuzz")

usage() {
    echo "Usage: $0 [TARGET[,TARGET...]] [-i interval_sec] [-o output_dir] [-1] [--csv] [-h]"
    echo ""
    echo "  TARGET     目标名 (exim, kamailio, pure-ftpd, ...)，多个用逗号分隔"
    echo "             不指定则监控所有运行中的 NSFuzz 容器"
    echo "  -i SEC     采集间隔秒数 (默认 30)"
    echo "  -o DIR     输出目录 (默认仅终端输出)"
    echo "  -1         单次采集后退出"
    echo "  --csv      同时生成 CSV 时间序列文件"
    echo "  -h         显示帮助"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 exim"
    echo "  $0 exim,kamailio -i 60"
    echo "  $0 exim -1"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) INTERVAL="$2"; shift 2 ;;
        -o) OUT_DIR="$2"; shift 2 ;;
        -1) ONCE=1; shift ;;
        --csv) CSV_MODE=1; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *)
            if [[ -z "$FILTER" ]]; then
                FILTER="$1"
            else
                FILTER="${FILTER},$1"
            fi
            shift ;;
    esac
done

if [[ -n "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
    CSV_MODE=1
fi

# ─── 基础函数 ───────────────────────────────────────────────────────────────
read_host_cpu_stat() {
    awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8, $9, $10, $11}' /proc/stat
}

calc_host_cpu_usage() {
    local prev=($1)
    local curr=($2)

    local prev_user=${prev[0]} prev_nice=${prev[1]} prev_system=${prev[2]} prev_idle=${prev[3]}
    local prev_iowait=${prev[4]} prev_irq=${prev[5]} prev_softirq=${prev[6]} prev_steal=${prev[7]}

    local curr_user=${curr[0]} curr_nice=${curr[1]} curr_system=${curr[2]} curr_idle=${curr[3]}
    local curr_iowait=${curr[4]} curr_irq=${curr[5]} curr_softirq=${curr[6]} curr_steal=${curr[7]}

    local prev_idle_all=$((prev_idle + prev_iowait))
    local curr_idle_all=$((curr_idle + curr_iowait))
    local prev_non_idle=$((prev_user + prev_nice + prev_system + prev_irq + prev_softirq + prev_steal))
    local curr_non_idle=$((curr_user + curr_nice + curr_system + curr_irq + curr_softirq + curr_steal))
    local prev_total=$((prev_idle_all + prev_non_idle))
    local curr_total=$((curr_idle_all + curr_non_idle))

    local totald=$((curr_total - prev_total))
    local idled=$((curr_idle_all - prev_idle_all))
    local userd=$(((curr_user + curr_nice) - (prev_user + prev_nice)))
    local systemd=$((curr_system - prev_system))
    local iowaitd=$((curr_iowait - prev_iowait))

    if [[ "$totald" -le 0 ]]; then
        echo "0.00 0.00 0.00 0.00"
        return
    fi

    awk -v totald="$totald" -v idled="$idled" -v userd="$userd" -v systemd="$systemd" -v iowaitd="$iowaitd" 'BEGIN {
        total_pct=(totald-idled)*100/totald;
        user_pct=userd*100/totald;
        system_pct=systemd*100/totald;
        iowait_pct=iowaitd*100/totald;
        printf "%.2f %.2f %.2f %.2f", total_pct, user_pct, system_pct, iowait_pct;
    }'
}

get_host_mem_stats() {
    awk '
        /^MemTotal:/ {mem_total=$2}
        /^MemAvailable:/ {mem_avail=$2}
        /^SwapTotal:/ {swap_total=$2}
        /^SwapFree:/ {swap_free=$2}
        END {
            mem_used=mem_total-mem_avail;
            swap_used=swap_total-swap_free;
            mem_used_pct=(mem_total>0)?(mem_used*100/mem_total):0;
            swap_used_pct=(swap_total>0)?(swap_used*100/swap_total):0;
            printf "%.0f %.0f %.2f %.0f %.0f %.2f",
                   mem_used/1024, mem_total/1024, mem_used_pct,
                   swap_used/1024, swap_total/1024, swap_used_pct;
        }
    ' /proc/meminfo
}

get_host_loadavg() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

get_host_uptime_human() {
    awk '{
        total=int($1);
        d=int(total/86400);
        h=int((total%86400)/3600);
        m=int((total%3600)/60);
        if (d>0) printf "%dd %02dh %02dm", d, h, m;
        else printf "%02dh %02dm", h, m;
    }' /proc/uptime
}

print_system_overview() {
    local prev_cpu curr_cpu cpu_stats mem_stats load_stats
    local cpu_total cpu_user cpu_system cpu_iowait
    local mem_used mem_total mem_used_pct swap_used swap_total swap_used_pct
    local load1 load5 load15 uptime_human process_count docker_running top_cpu top_mem
    local host_name cpu_line mem_line swap_line docker_line

    prev_cpu="$(read_host_cpu_stat)"
    sleep 1
    curr_cpu="$(read_host_cpu_stat)"
    cpu_stats="$(calc_host_cpu_usage "$prev_cpu" "$curr_cpu")"
    mem_stats="$(get_host_mem_stats)"
    load_stats="$(get_host_loadavg)"

    read -r cpu_total cpu_user cpu_system cpu_iowait <<< "$cpu_stats"
    read -r mem_used mem_total mem_used_pct swap_used swap_total swap_used_pct <<< "$mem_stats"
    read -r load1 load5 load15 <<< "$load_stats"

    uptime_human="$(get_host_uptime_human)"
    process_count="$(ps -e --no-headers | wc -l | tr -d ' ')"
    docker_running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    top_cpu=$(ps -eo comm,%cpu --sort=-%cpu --no-headers 2>/dev/null | head -1 | awk '{printf "%s (%s%%)", $1, $2}')
    top_mem=$(ps -eo comm,%mem --sort=-%mem --no-headers 2>/dev/null | head -1 | awk '{printf "%s (%s%%)", $1, $2}')
    host_name="$(hostname)"

    cpu_line="${cpu_total}%  [user ${cpu_user}% | sys ${cpu_system}% | io ${cpu_iowait}%]"
    mem_line="${mem_used_pct}%  (${mem_used}/${mem_total} MB)"
    swap_line="${swap_used_pct}%  (${swap_used}/${swap_total} MB)"
    docker_line="${docker_running} running"

    [[ -z "$top_cpu" ]] && top_cpu="-"
    [[ -z "$top_mem" ]] && top_mem="-"

    echo -e "${BOLD}  🖥️  系统资源总览:${RST}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..92})${RST}"
    printf "  ${DIM}Host:${RST} %-12s  ${DIM}Uptime:${RST} %-12s  ${DIM}Load:${RST} %s\n" \
        "$host_name" "$uptime_human" "${load1} / ${load5} / ${load15}"
    printf "  ${DIM}CPU:${RST}  %-34s  ${DIM}Memory:${RST} %s\n" \
        "$cpu_line" "$mem_line"
    printf "  ${DIM}Proc:${RST} %-12s  ${DIM}Docker:${RST} %-12s  ${DIM}Swap:${RST} %s\n" \
        "$process_count" "$docker_line" "$swap_line"
    printf "  ${DIM}Top CPU:${RST} %s\n" "$top_cpu"
    printf "  ${DIM}Top MEM:${RST} %s\n" "$top_mem"
    echo ""
}

# 从容器自动探测 out-* 目录
# 支持层级:
# /home/ubuntu/experiments/out-*
# /home/ubuntu/experiments/*/out-*
# /home/ubuntu/experiments/*/*/out-*
# /home/ubuntu/experiments/*/*/*/out-*
detect_outdir() {
    local cid="$1"
    docker exec "$cid" bash -c '
        d=$(ls -d /home/ubuntu/experiments/out-* 2>/dev/null | head -1)
        if [ -z "$d" ]; then d=$(ls -d /home/ubuntu/experiments/*/out-* 2>/dev/null | head -1); fi
        if [ -z "$d" ]; then d=$(ls -d /home/ubuntu/experiments/*/*/out-* 2>/dev/null | head -1); fi
        if [ -z "$d" ]; then d=$(ls -d /home/ubuntu/experiments/*/*/*/out-* 2>/dev/null | head -1); fi
        echo "$d"
    ' 2>/dev/null || echo ""
}

# 解析 out-<target>-<fuzzer>
# target 可能带连字符（如 pure-ftpd），因此从尾部匹配 fuzzer 后缀
fuzzer_label() {
    local outdir="$1"
    local base rest
    base=$(basename "$outdir")
    rest="${base#out-}"

    local f
    for f in "${KNOWN_FUZZERS[@]}"; do
        if [[ "$rest" == *-"$f" ]]; then
            echo "$f" | tr '[:lower:]' '[:upper:]'
            return
        fi
    done

    echo "UNKNOWN"
}

target_label() {
    local outdir="$1"
    local base rest
    base=$(basename "$outdir")
    rest="${base#out-}"

    local f
    for f in "${KNOWN_FUZZERS[@]}"; do
        if [[ "$rest" == *-"$f" ]]; then
            echo "${rest%-$f}"
            return
        fi
    done

    # 回退：去掉最后一段
    echo "${rest%-*}"
}

get_ipsm_stats() {
    local cid="$1" dot_path="$2"
    local nodes edges
    nodes=$(docker exec "$cid" grep -c '\[color=blue\]' "$dot_path" 2>/dev/null || echo "0")
    edges=$(docker exec "$cid" grep -c '\->' "$dot_path" 2>/dev/null || echo "0")
    echo "${nodes} ${edges}"
}

calc_runtime_min() {
    local start_ts="$1"
    local now
    now=$(date +%s)
    echo $(( (now - start_ts) / 60 ))
}

target_matches_filter() {
    local target="$1"
    [[ -z "$FILTER" ]] && return 0
    local f
    for f in $(echo "$FILTER" | tr ',' ' '); do
        [[ "$target" == "$f" ]] && return 0
    done
    return 1
}

discover_containers() {
    local cids=()
    local all_running
    all_running=$(docker ps -q 2>/dev/null)

    if [[ -z "$all_running" ]]; then
        echo ""
        return
    fi

    for cid in $all_running; do
        local outdir t f
        outdir=$(detect_outdir "$cid")
        [[ -z "$outdir" ]] && continue

        t=$(target_label "$outdir")
        f=$(fuzzer_label "$outdir")

        # 仅保留 NSFuzz 五类 fuzzer
        case "$f" in
            AFLNET|AFLNWE|STATEAFL|NSFUZZ|NSFUZZ-V)
                if target_matches_filter "$t"; then
                    cids+=("$cid")
                fi
                ;;
            *) ;;
        esac
    done

    echo "${cids[*]:-}"
}

collect_one() {
    local cid="$1"
    local outdir
    outdir=$(detect_outdir "$cid")
    [[ -z "$outdir" ]] && return 1

    local stats_file="${outdir}/fuzzer_stats"
    local dot_file="${outdir}/ipsm.dot"
    local target fuzzer

    target=$(target_label "$outdir")
    fuzzer=$(fuzzer_label "$outdir")

    local stats_blob
    stats_blob=$(docker exec "$cid" cat "$stats_file" 2>/dev/null || echo "")
    [[ -z "$stats_blob" ]] && return 1

    local start_time bitmap paths_total paths_favored execs_done execs_per_sec
    local unique_crashes unique_hangs cycles_done pending_total stability

    start_time=$(echo "$stats_blob"    | grep -m1 '^start_time'      | sed 's/.*: *//' | tr -d '[:space:]')
    bitmap=$(echo "$stats_blob"        | grep -m1 '^bitmap_cvg'      | sed 's/.*: *//' | tr -d '[:space:]')
    paths_total=$(echo "$stats_blob"   | grep -m1 '^paths_total'     | sed 's/.*: *//' | tr -d '[:space:]')
    paths_favored=$(echo "$stats_blob" | grep -m1 '^paths_favored'   | sed 's/.*: *//' | tr -d '[:space:]')
    execs_done=$(echo "$stats_blob"    | grep -m1 '^execs_done'      | sed 's/.*: *//' | tr -d '[:space:]')
    execs_per_sec=$(echo "$stats_blob" | grep -m1 '^execs_per_sec'   | sed 's/.*: *//' | tr -d '[:space:]')
    unique_crashes=$(echo "$stats_blob"| grep -m1 '^unique_crashes'  | sed 's/.*: *//' | tr -d '[:space:]')
    unique_hangs=$(echo "$stats_blob"  | grep -m1 '^unique_hangs'    | sed 's/.*: *//' | tr -d '[:space:]')
    cycles_done=$(echo "$stats_blob"   | grep -m1 '^cycles_done'     | sed 's/.*: *//' | tr -d '[:space:]')
    pending_total=$(echo "$stats_blob" | grep -m1 '^pending_total'   | sed 's/.*: *//' | tr -d '[:space:]')
    stability=$(echo "$stats_blob"     | grep -m1 '^stability'       | sed 's/.*: *//' | tr -d '[:space:]')

    local ipsm_info nodes edges
    ipsm_info=$(get_ipsm_stats "$cid" "$dot_file")
    nodes=$(echo "$ipsm_info" | awk '{print $1}')
    edges=$(echo "$ipsm_info" | awk '{print $2}')

    local runtime_min="?"
    if [[ -n "$start_time" && "$start_time" =~ ^[0-9]+$ ]]; then
        runtime_min=$(calc_runtime_min "$start_time")
    fi

    local last_plot_ts
    last_plot_ts=$(docker exec "$cid" tail -1 "${outdir}/plot_data" 2>/dev/null | awk -F',' '{print $1}' | tr -d '[:space:]')
    local last_update_ago="?"
    if [[ -n "$last_plot_ts" && "$last_plot_ts" =~ ^[0-9]+$ ]]; then
        last_update_ago=$(( $(date +%s) - last_plot_ts ))
    fi

    echo "${cid}|${target}|${fuzzer}|${runtime_min}|${bitmap}|${paths_total}|${paths_favored}|${execs_done}|${execs_per_sec}|${unique_crashes}|${unique_hangs}|${cycles_done}|${pending_total}|${stability}|${nodes}|${edges}|${last_update_ago}"
}

print_header() {
    local now count filter_info
    now=$(date '+%Y-%m-%d %H:%M:%S')
    count="$1"
    filter_info="all targets"
    [[ -n "$FILTER" ]] && filter_info="$FILTER"

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════════════════════╗${RST}"
    echo -e "${BOLD}║  📊 NSFuzz Monitor — ${now}  (${count} containers, ${filter_info})${RST}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════════════════════╝${RST}"
}

print_table() {
    local -a data=("$@")

    if [[ ${#data[@]} -eq 0 ]]; then
        echo -e "${RED}  No active NSFuzz containers found.${RST}"
        return
    fi

    local sorted
    sorted=$(printf '%s\n' "${data[@]}" | sort -t'|' -k2,2 -k3,3 -k4,4rn)

    local prev_target=""

    while IFS='|' read -r cid target fuzzer runtime bitmap paths_total paths_fav execs execs_sec \
                          crashes hangs cycles pending stab nodes edges last_upd; do

        if [[ "$target" != "$prev_target" ]]; then
            prev_target="$target"
            echo ""
            echo -e "${CYAN}${BOLD}  ┌─ ${target^^} ─────────────────────────────────────────────────────────────────┐${RST}"
            printf "  ${DIM}%-10s %-12s %6s %8s %7s %6s %8s %7s %5s %5s %6s %6s${RST}\n" \
                "FUZZER" "CID" "T(min)" "Bitmap" "Paths" "Favrd" "Execs" "Exec/s" "Crash" "Hangs" "Nodes" "Edges"
            echo -e "  ${DIM}$(printf '─%.0s' {1..110})${RST}"
        fi

        local fc="$RST"
        case "$fuzzer" in
            NSFUZZ) fc="$GREEN" ;;
            NSFUZZ-V) fc="$YELLOW" ;;
            AFLNET) fc="$CYAN" ;;
        esac

        local alive_mark="●"
        if [[ "$last_upd" =~ ^[0-9]+$ ]] && (( last_upd > 120 )); then
            alive_mark="○"
        fi

        printf "  ${fc}%-10s${RST} %-12s %6s %8s %7s %6s %8s %7s %5s %5s %6s %6s  %s\n" \
            "$fuzzer" "${cid:0:12}" "$runtime" "$bitmap" "$paths_total" "$paths_fav" \
            "$execs" "$execs_sec" "$crashes" "$hangs" "$nodes" "$edges" "$alive_mark"

    done <<< "$sorted"

    echo ""

    # ─── 按 target + fuzzer 分组的均值汇总 ───────────────────────────────────
    echo -e "${BOLD}  📈 Summary (mean across runs):${RST}"
    printf "  ${DIM}%-10s %5s %10s %8s %7s %8s %5s %5s %6s %6s${RST}\n" \
        "FUZZER" "N" "AvgTime" "Bitmap" "Paths" "Execs" "Crash" "Hangs" "Nodes" "Edges"
    echo -e "  ${DIM}$(printf '─%.0s' {1..95})${RST}"

    local -A sum_bitmap sum_paths sum_execs sum_crashes sum_hangs sum_nodes sum_edges sum_runtime count_by_key

    while IFS='|' read -r cid target fuzzer runtime bitmap paths_total paths_fav execs execs_sec \
                          crashes hangs cycles pending stab nodes edges last_upd; do
        local key="${target}::${fuzzer}"
        local bval _paths _execs _crashes _hangs _nodes _edges _runtime

        bval=$(echo "$bitmap" | tr -d '%' | tr -cd '0-9.')
        [[ -z "$bval" ]] && bval="0"

        _paths="${paths_total%%.*}"; _paths="${_paths//[^0-9]/}"; [[ -z "$_paths" ]] && _paths=0
        _execs="${execs%%.*}"; _execs="${_execs//[^0-9]/}"; [[ -z "$_execs" ]] && _execs=0
        _crashes="${crashes%%.*}"; _crashes="${_crashes//[^0-9]/}"; [[ -z "$_crashes" ]] && _crashes=0
        _hangs="${hangs%%.*}"; _hangs="${_hangs//[^0-9]/}"; [[ -z "$_hangs" ]] && _hangs=0
        _nodes="${nodes%%.*}"; _nodes="${_nodes//[^0-9]/}"; [[ -z "$_nodes" ]] && _nodes=0
        _edges="${edges%%.*}"; _edges="${_edges//[^0-9]/}"; [[ -z "$_edges" ]] && _edges=0
        _runtime="${runtime%%.*}"; _runtime="${_runtime//[^0-9]/}"; [[ -z "$_runtime" ]] && _runtime=0

        sum_bitmap[$key]=$(awk "BEGIN{print ${sum_bitmap[$key]:-0} + ${bval}}")
        sum_paths[$key]=$(( ${sum_paths[$key]:-0} + _paths ))
        sum_execs[$key]=$(( ${sum_execs[$key]:-0} + _execs ))
        sum_crashes[$key]=$(( ${sum_crashes[$key]:-0} + _crashes ))
        sum_hangs[$key]=$(( ${sum_hangs[$key]:-0} + _hangs ))
        sum_nodes[$key]=$(( ${sum_nodes[$key]:-0} + _nodes ))
        sum_edges[$key]=$(( ${sum_edges[$key]:-0} + _edges ))
        sum_runtime[$key]=$(( ${sum_runtime[$key]:-0} + _runtime ))
        count_by_key[$key]=$(( ${count_by_key[$key]:-0} + 1 ))
    done <<< "$sorted"

    local key
    for key in $(printf '%s\n' "${!count_by_key[@]}" | sort); do
        local n tgt fzr avg_bmp avg_paths avg_execs avg_crashes avg_hangs avg_nodes avg_edges avg_runtime fc
        n=${count_by_key[$key]}
        tgt="${key%%::*}"
        fzr="${key##*::}"

        avg_bmp=$(awk "BEGIN{printf \"%.2f%%\", ${sum_bitmap[$key]} / ${n}}")
        avg_paths=$(( ${sum_paths[$key]} / n ))
        avg_execs=$(( ${sum_execs[$key]} / n ))
        avg_crashes=$(( ${sum_crashes[$key]} / n ))
        avg_hangs=$(( ${sum_hangs[$key]} / n ))
        avg_nodes=$(( ${sum_nodes[$key]} / n ))
        avg_edges=$(( ${sum_edges[$key]} / n ))
        avg_runtime=$(( ${sum_runtime[$key]} / n ))

        fc="$RST"
        case "$fzr" in
            NSFUZZ) fc="$GREEN" ;;
            NSFUZZ-V) fc="$YELLOW" ;;
            AFLNET) fc="$CYAN" ;;
        esac

        printf "  ${fc}%-10s${RST} %5s %10s %8s %7s %8s %5s %5s %6s %6s  ${DIM}[%s]${RST}\n" \
            "$fzr" "$n" "$avg_runtime" "$avg_bmp" "$avg_paths" "$avg_execs" \
            "$avg_crashes" "$avg_hangs" "$avg_nodes" "$avg_edges" "$tgt"
    done

    echo ""
}

write_csv() {
    local -a data=("$@")
    local csv_file="${OUT_DIR:-/tmp}/nsfuzz_monitor_$(date +%Y%m%d).csv"
    local ts human_ts
    ts=$(date +%s)
    human_ts=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ ! -f "$csv_file" ]]; then
        echo "timestamp,human_time,container_id,target,fuzzer,runtime_min,bitmap_pct,paths_total,paths_favored,execs_done,execs_per_sec,unique_crashes,unique_hangs,cycles_done,pending_total,stability,ipsm_nodes,ipsm_edges,last_update_ago" > "$csv_file"
    fi

    for line in "${data[@]}"; do
        IFS='|' read -r cid target fuzzer runtime bitmap paths_total paths_fav execs execs_sec \
                       crashes hangs cycles pending stab nodes edges last_upd <<< "$line"

        local bval stab_val
        bval=$(echo "$bitmap" | tr -d '%')
        stab_val=$(echo "$stab" | tr -d '%')

        echo "${ts},${human_ts},${cid:0:12},${target},${fuzzer},${runtime},${bval},${paths_total},${paths_fav},${execs},${execs_sec},${crashes},${hangs},${cycles},${pending},${stab_val},${nodes},${edges},${last_upd}" >> "$csv_file"
    done

    echo -e "  ${DIM}📁 CSV → ${csv_file}${RST}"
}

main() {
    local filter_msg="all targets"
    [[ -n "$FILTER" ]] && filter_msg="filter: $FILTER"
    echo -e "${BOLD}🔍 Discovering NSFuzz containers (${filter_msg})...${RST}"

    while true; do
        local container_list
        container_list=$(discover_containers)

        if [[ -z "$container_list" ]]; then
            echo -e "${RED}No running NSFuzz containers found for [${filter_msg}]. Waiting...${RST}"
            if [[ $ONCE -eq 1 ]]; then exit 1; fi
            sleep "$INTERVAL"
            continue
        fi

        local -a results=()
        local count=0

        for cid in $container_list; do
            local row
            row=$(collect_one "$cid" 2>/dev/null || echo "")
            if [[ -n "$row" ]]; then
                results+=("$row")
                ((count++)) || true
            fi
        done

        clear 2>/dev/null || printf '\033c'
        print_header "$count"
        print_system_overview
        print_table "${results[@]}"

        if [[ $CSV_MODE -eq 1 && ${#results[@]} -gt 0 ]]; then
            write_csv "${results[@]}"
        fi

        echo -e "  ${DIM}Next refresh in ${INTERVAL}s ... (Ctrl+C to quit)${RST}"

        if [[ $ONCE -eq 1 ]]; then
            exit 0
        fi

        sleep "$INTERVAL"
    done
}

trap 'echo -e "\n${YELLOW}Monitor stopped.${RST}"; exit 0' INT TERM
main
