#!/usr/bin/env bash
# Non-CI check of feature 20261103-115636-conserved-bond-group-pruning (tasks.md T005-T007,
# T017-T019). Every MATLAB run goes in its own memory-capped user scope, one at a time; the
# start and end of each run, its exit code and the scope's memory.peak are appended to
# $WORK/jobs.txt.
#
# usage: WORK=<folder outside the repository> conservedBondGroupCheck.sh selfcheck|base|conserved|equality|memory|full
#   $WORK/ckpt/<name>/checkpoint_build.mat  checkpoints built with the fixed builder (rebuildCheckpoint.m)
#   $WORK/base/src/analysis/topology/reactingMoieties  git archive of the base commit 3c7ee7186
#   $WORK/probe  (full mode only) an instrumented copy of this repository's
#                identifyConservedReactingMoieties.m, with rmProbe.m beside it
# Each cap must stay at or below the available memory minus 8 GB at its start.
set -uo pipefail
mode=$1
feature=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$feature/../.." && pwd)
work=${WORK:?set WORK to a folder outside the repository}
baseDir=$work/base/src/analysis/topology/reactingMoieties
newDir=$repo/src/analysis/topology/reactingMoieties
equalityCases="random-n100 random-n250 random-n500 random-n1000 random-n2000 bfs-n500 bfs-n2000"

run_matlab() { # tag cap timeLimit command [env]
    local tag=$1 cap=$2 limit=$3 cmd=$4 extraEnv=${5:-} out=$work/runs/$1
    local needGiB=$(( ${cap%G} + 8 )) availableGiB
    availableGiB=$(free -g | awk '/^Mem:/ {print $7}')
    if (( availableGiB < needGiB )); then
        echo "$(date '+%F %T') not starting $tag: ${availableGiB} GB available, cap $cap needs ${needGiB} GB" | tee -a "$work/jobs.txt" >&2
        return 1
    fi
    mkdir -p "$out"
    echo "$(date '+%F %T') start $tag cap=$cap" >> "$work/jobs.txt"
    systemd-run --user --scope -q --unit="cbcheck-$tag-$$" -p MemoryMax=$cap -p MemorySwapMax=0 \
        -p OOMPolicy=continue -- bash -c '
        out=$1
        cg=/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)
        env $4 timeout "$3" /usr/bin/time -v -o "$out/time.txt" matlab -batch "$2" > "$out/matlab.stdout" 2>&1
        echo $? > "$out/exit_code"
        cat "$cg/memory.peak" > "$out/memory.peak"; cat "$cg/memory.events" > "$out/memory.events"' \
        _ "$out" "addpath('$feature'); $cmd" "$limit" "RM_PROBE_LOG=$out/probes.tsv $extraEnv"
    echo "$(date '+%F %T') end $tag exit=$(cat "$out/exit_code") peak_MiB=$(( $(cat "$out/memory.peak") / 1048576 ))" >> "$work/jobs.txt"
    [[ $(cat "$out/exit_code") == 0 ]]
}

cap_for() { case $1 in random-n2000|bfs-n2000) echo 12G ;; *) echo 8G ;; esac; }

identify() { # tag cap rmDir caseName saveOutputs [probeDir]
    run_matlab "$1" "$2" 6h "conservedBondGroupCheck('identify', '$3', '$work/ckpt/$4/checkpoint_build.mat', '$work/runs/$1/out', $5, '${6:-}')"
}

compare() { # tag referenceTag newTag
    run_matlab "$1" 8G 2h "conservedBondGroupCheck('compare', '$work/runs/$2/out', '$work/runs/$3/out')" &&
        grep -q '^RM ALL EQUAL 1' "$work/runs/$1/matlab.stdout"
    local equal=$?
    echo "$1: $(grep '^RM ALL EQUAL' "$work/runs/$1/matlab.stdout")"
    return $equal
}

case $mode in
    selfcheck)
        identify self-a 8G "$baseDir" random-n100 true && identify self-b 8G "$baseDir" random-n100 true &&
            compare self-compare self-a self-b ;;
    base)
        status=0
        for name in $equalityCases; do
            identify "base-$name" "$(cap_for $name)" "$baseDir" "$name" true || status=1
        done
        exit $status ;;
    conserved)
        run_matlab conserved-full 16G 6h "conservedBondGroupCheck('conserved', '$newDir', '$work/ckpt/full/checkpoint_build.mat', '$work/runs/conserved-full/out')" ;;
    equality)
        status=0
        for name in $equalityCases; do
            if [[ ! -f $work/runs/base-$name/out/outputs.mat ]]; then
                echo "eq-$name: no base outputs, left out"; continue
            fi
            identify "new-$name" "$(cap_for $name)" "$newDir" "$name" true &&
                compare "eq-compare-$name" "base-$name" "new-$name" || status=1
        done
        exit $status ;;
    memory)
        for run in 1 2; do
            identify "mem-base-n1000-$run" 8G "$baseDir" random-n1000 false || exit 1
            identify "mem-new-n1000-$run" 8G "$newDir" random-n1000 false || exit 1
        done
        identify mem-base-n2000 12G "$baseDir" random-n2000 false || exit 1
        identify mem-new-n2000 12G "$newDir" random-n2000 false || exit 1
        for tag in mem-base-n1000-1 mem-new-n1000-1 mem-base-n1000-2 mem-new-n1000-2 mem-base-n2000 mem-new-n2000; do
            echo "$tag $(tr '\n' ' ' < "$work/runs/$tag/out/metrics.txt")"
        done ;;
    full)
        identify full 24G "$newDir" full true "$work/probe" &&
            run_matlab full-compare 16G 2h "conservedBondGroupCheck('compareConserved', '$work/runs/conserved-full/out', '$work/runs/full/out')" &&
            grep '^CB' "$work/runs/full-compare/matlab.stdout" ;;
    *)
        echo "unknown mode $mode" >&2; exit 2 ;;
esac
