#!/usr/bin/env bash
# Non-CI check of feature 20261106-092213-paper-reacting-bond-incidence (tasks.md T002,
# T022-T024). Every MATLAB run goes in its own memory-capped user scope, one at a time; the
# start and end of each run, its exit code and the scope's memory.peak are appended to
# $WORK/jobs.txt.
#
# usage: WORK=<folder outside the repository> paperIncidenceCheck.sh rebuild|endAtom|bondChange|report <baselineRunDir> [rxnDir]
#   rebuild     $WORK/vmh_with_dBTM.mat from a copy of <baselineRunDir>/checkpoint_build.mat (T002)
#   endAtom     identification under 'endAtom', compared with <baselineRunDir> (T023, equality control)
#   bondChange  identification under 'bondChange' (T024)
#   report      the US3 metrics into paperIncidenceResults.md (T024)
# Nothing is written to <baselineRunDir> or rxnDir. A run with cap C starts only when C + MARGIN_GB
# (default 8) GB is available (waiting up to 3 h).
set -uo pipefail
mode=$1
baseline=$(cd "$2" && pwd)
rxnDir=${3:-$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["rxnDir"])' "$baseline/provenance.json")}
feature=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$feature/../.." && pwd)
work=${WORK:?set WORK to a folder outside the repository}
newDir=$repo/src/analysis/topology/reactingMoieties
baselineReacting=$baseline/moieties_Qconserved_graphsOn_reacting/reacting.mat
baselineConserved=$baseline/moieties_Qconserved_graphsOn_reacting/conserved_moieties.mat
setup="cd('$HOME/cobratoolbox'); initCobraToolbox(false); changeCobraSolver('gurobi', 'MILP', 0); addpath('$newDir'); addpath('$feature'); cd('$work'); assert(startsWith(which('identifyConservedReactingMoieties'), '$newDir'));"

run_matlab() { # tag cap timeLimit command
    local tag=$1 cap=$2 limit=$3 cmd=$4 out=$work/runs/$1
    local needGiB=$(( ${cap%G} + ${MARGIN_GB:-8} )) availableGiB waited=0
    availableGiB=$(free -g | awk '/^Mem:/ {print $7}')
    while (( availableGiB < needGiB && waited < 10800 )); do
        sleep 60; waited=$(( waited + 60 ))
        availableGiB=$(free -g | awk '/^Mem:/ {print $7}')
    done
    if (( availableGiB < needGiB )); then
        echo "$(date '+%F %T') not starting $tag: ${availableGiB} GB available after 3 h, cap $cap needs ${needGiB} GB" | tee -a "$work/jobs.txt" >&2
        return 1
    fi
    (( waited > 0 )) && echo "$(date '+%F %T') $tag waited ${waited} s for memory" >> "$work/jobs.txt"
    mkdir -p "$out"
    echo "$(date '+%F %T') start $tag cap=$cap" >> "$work/jobs.txt"
    systemd-run --user --scope -q --unit="paperinc-$tag-$$" -p MemoryMax=$cap -p MemorySwapMax=0 \
        -p OOMPolicy=continue -- bash -c '
        out=$1
        cg=/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)
        timeout "$3" /usr/bin/time -v -o "$out/time.txt" matlab -batch "$2" > "$out/matlab.stdout" 2>&1
        echo $? > "$out/exit_code"
        cat "$cg/memory.peak" > "$out/memory.peak"; cat "$cg/memory.events" > "$out/memory.events"' \
        _ "$out" "$setup $cmd" "$limit"
    echo "$(date '+%F %T') end $tag exit=$(cat "$out/exit_code") peak_MiB=$(( $(cat "$out/memory.peak") / 1048576 ))" >> "$work/jobs.txt"
    [[ $(cat "$out/exit_code") == 0 ]]
}

mkdir -p "$work/runs"
case $mode in
    rebuild)
        [[ -f $work/checkpoint_build.mat ]] || cp "$baseline/checkpoint_build.mat" "$work/checkpoint_build.mat" || exit 1
        run_matlab rebuild 24G 4h "rebuildWithBondTransitions('$work/checkpoint_build.mat', '$rxnDir', '$work/vmh_with_dBTM.mat')" &&
            grep '^REBUILD' "$work/runs/rebuild/matlab.stdout" ;;
    endAtom)
        # T023: equality control against the baseline run, which used the end-atom rule
        grep -q '^REBUILD EQUAL 1' "$work/runs/rebuild/matlab.stdout" || { echo "no equal rebuild in $work" >&2; exit 1; }
        run_matlab identify-endAtom 24G 4h "paperIncidenceCheck('identify', '$work/vmh_with_dBTM.mat', 'endAtom', '$work/runs/identify-endAtom/out')" || exit 1
        run_matlab compare-endAtom 16G 1h "paperIncidenceCheck('compare', '$baselineReacting', '$baselineConserved', '$work/runs/identify-endAtom/out')" || exit 1
        grep '^PI' "$work/runs/compare-endAtom/matlab.stdout"
        grep -q '^PI ALL EQUAL 1' "$work/runs/compare-endAtom/matlab.stdout" ;;
    bondChange)
        # T024: the paper's rule, then the report
        grep -q '^PI ALL EQUAL 1' "$work/runs/compare-endAtom/matlab.stdout" || { echo "the equality control has not passed" >&2; exit 1; }
        run_matlab identify-bondChange 24G 4h "paperIncidenceCheck('identify', '$work/vmh_with_dBTM.mat', 'bondChange', '$work/runs/identify-bondChange/out')" || exit 1
        grep '^PI' "$work/runs/identify-bondChange/matlab.stdout" ;;
    report)
        run_matlab report 16G 1h "paperIncidenceCheck('report', '$baselineReacting', '$work/runs/identify-endAtom/out', '$work/runs/identify-bondChange/out', '$feature/paperIncidenceResults.md')" &&
            grep '^PI' "$work/runs/report/matlab.stdout" ;;
    *)
        echo "unknown mode $mode" >&2; exit 2 ;;
esac
