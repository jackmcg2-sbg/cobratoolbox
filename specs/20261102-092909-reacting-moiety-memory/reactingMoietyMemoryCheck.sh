#!/usr/bin/env bash
# Non-CI check of feature 20261102-092909-reacting-moiety-memory (tasks.md T010, T017, T018).
# Every MATLAB run goes in its own memory-capped user scope, one at a time; the start and end
# of each run, its exit code and the scope's memory.peak are appended to $WORK/jobs.txt.
#
# usage: WORK=<folder outside the repository> reactingMoietyMemoryCheck.sh selfcheck|equality|memory
#   $WORK/ckpt/<order>-n<size>/checkpoint_build.mat  copies of the memory scan's checkpoints
#   $WORK/base/src/analysis/topology/reactingMoieties  git archive of the base commit 8a927a4c6
# Caps: 8G per run, 16G for n = 1,000; each must stay at or below available memory - 8 GB.
set -uo pipefail
mode=$1
feature=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$feature/../.." && pwd)
work=${WORK:?set WORK to a folder outside the repository}
baseDir=$work/base/src/analysis/topology/reactingMoieties
newDir=$repo/src/analysis/topology/reactingMoieties

run_matlab() { # tag cap command
    local tag=$1 cap=$2 cmd=$3 out=$work/runs/$1
    local needGiB=$(( ${cap%G} + 8 )) availableGiB
    availableGiB=$(free -g | awk '/^Mem:/ {print $7}')
    if (( availableGiB < needGiB )); then
        echo "not starting $tag: ${availableGiB} GB available, cap $cap needs ${needGiB} GB" >&2
        return 1
    fi
    mkdir -p "$out"
    echo "$(date '+%F %T') start $tag cap=$cap" >> "$work/jobs.txt"
    systemd-run --user --scope -q --unit="rmcheck-$tag-$$" -p MemoryMax=$cap -p MemorySwapMax=0 \
        -p OOMPolicy=continue -- bash -c '
        out=$1
        cg=/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)
        matlab -batch "$2" > "$out/matlab.stdout" 2>&1
        echo $? > "$out/exit_code"
        cat "$cg/memory.peak" > "$out/memory.peak"' _ "$out" "addpath('$feature'); $cmd"
    echo "$(date '+%F %T') end $tag exit=$(cat "$out/exit_code") peak_MiB=$(( $(cat "$out/memory.peak") / 1048576 ))" >> "$work/jobs.txt"
    [[ $(cat "$out/exit_code") == 0 ]]
}

identify() { # tag cap rmDir checkpointName saveOutputs
    run_matlab "$1" "$2" "reactingMoietyMemoryCheck('identify', '$3', '$work/ckpt/$4/checkpoint_build.mat', '$work/runs/$1', $5)"
}

compare() { # tag referenceTag newTag
    run_matlab "$1" 6G "reactingMoietyMemoryCheck('compare', '$work/runs/$2', '$work/runs/$3')" &&
        grep -q '^RM ALL EQUAL 1' "$work/runs/$1/matlab.stdout"
    local equal=$?
    echo "$1: $(grep '^RM ALL EQUAL' "$work/runs/$1/matlab.stdout")"
    return $equal
}

case $mode in
    selfcheck)
        identify self-a 8G "$baseDir" random-n100 true && identify self-b 8G "$baseDir" random-n100 true &&
            compare self-compare self-a self-b ;;
    equality)
        status=0
        for name in random-n100 random-n250 random-n500 random-n1000 bfs-n500; do
            cap=8G; [[ $name == random-n1000 ]] && cap=16G
            identify "eq-base-$name" $cap "$baseDir" "$name" true &&
                identify "eq-new-$name" $cap "$newDir" "$name" true &&
                compare "eq-compare-$name" "eq-base-$name" "eq-new-$name" || status=1
        done
        exit $status ;;
    memory)
        for run in 1 2; do
            identify "mem-base-$run" 16G "$baseDir" random-n1000 false || exit 1
            identify "mem-new-$run" 16G "$newDir" random-n1000 false || exit 1
        done
        for tag in mem-base-1 mem-new-1 mem-base-2 mem-new-2; do
            echo "$tag $(tr '\n' ' ' < "$work/runs/$tag/metrics.txt")"
        done ;;
    *)
        echo "unknown mode $mode" >&2; exit 2 ;;
esac
