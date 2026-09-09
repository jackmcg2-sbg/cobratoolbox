"""Prototype fix v2: build every atom's cross-file-stable identity from its
FINAL WL colour-refinement signature (a pure graph invariant, identical
across independently-generated files of the same molecule) instead of the
file's raw row-order atom number -- even for atoms with no symmetry, since
v1 showed raw atomNr can itself shift file-to-file when a tie-break earlier
in RDT's own traversal order cascades into later atoms' numbering. Atoms
sharing a colour (a genuine symmetric class) get a within-class RANK
appended as a tie-break, so bonds to a shared hub stay distinct (preserving
true multiplicity) while still being deterministic per file.
"""
import sys, csv
from collections import defaultdict, Counter
sys.path.insert(0, '/tmp/figwork')
from parse_rxn import read_ab_rxn_file

CORPUS = '/tmp/hubguard_corpus'
RESULTS_CSV = '/mnt/user-data/uploads/reconXmoieties/experiments/moietySizing/results/outputs/stratifiedSample/matlab_validation_results_20260908.csv'
MANIFEST_CSV = '/mnt/user-data/uploads/reconXmoieties/experiments/moietySizing/results/outputs/stratifiedSample/instance_manifest_20260908.csv'

def wl_colors(atom_numbers, elements, heads, tails, btypes):
    p = len(atom_numbers)
    idx_of = {a: i for i, a in enumerate(atom_numbers)}
    adj = defaultdict(dict)
    for h, t, bt in zip(heads, tails, btypes):
        hi, ti = idx_of[h], idx_of[t]
        adj[hi][ti] = bt
        adj[ti][hi] = bt
    color = list(elements)
    final_color_strings = list(elements)  # human/graph-meaningful label, kept separately from the compact id
    for _ in range(p + 1):
        new_color = []
        for k in range(p):
            sig = sorted(f"{bt}:{color[n]}" for n, bt in adj[k].items())
            new_color.append(color[k] + '|' + ','.join(sig))
        old_groups = len(set(color))
        # compact re-hash each round (mirrors the MATLAB fix for the same OOM issue:
        # carrying the raw concatenated string forward blows up multiplicatively)
        uniq = {c: i for i, c in enumerate(sorted(set(new_color)))}
        new_color_id = [str(uniq[c]) for c in new_color]
        new_groups = len(set(new_color_id))
        final_color_strings = new_color  # keep the last round's full descriptive string for the return value
        color = new_color_id
        if old_groups == new_groups:
            break
    # Use the compact colour-class id (stable partition identity) rather than the
    # full descriptive string as the returned "colour" -- the class PARTITION is
    # the cross-file-invariant thing, not the literal string (which embeds
    # round-order bookkeeping); two atoms get the same returned colour iff they
    # are in the same final WL equivalence class, which is what we need.
    return {atom_numbers[i]: color[i] for i in range(p)}


def proposed_bond_keys_v2(atom_numbers, elements, heads, tails, btypes):
    colors = wl_colors(atom_numbers, elements, heads, tails, btypes)
    by_color = defaultdict(list)
    for a in atom_numbers:
        by_color[colors[a]].append(a)
    rank_of = {}
    for c, members in by_color.items():
        for rank, m in enumerate(sorted(members), start=1):
            rank_of[m] = rank
    elem_of = dict(zip(atom_numbers, elements))

    def token(atom):
        return (colors[atom], rank_of[atom])

    keys = set()
    for h, t, bt in zip(heads, tails, btypes):
        eh, et = token(h), token(t)
        key = tuple(sorted([eh, et])) + (bt,)
        keys.add(key)
    return keys


with open(RESULTS_CSV) as f:
    results = list(csv.DictReader(f))
with open(MANIFEST_CSV) as f:
    manifest = list(csv.DictReader(f))
files_by_met = defaultdict(list)
for r in manifest:
    files_by_met[r['metabolite']].append(r['file'])
for m in files_by_met:
    files_by_met[m] = sorted(set(files_by_met[m]))

file_cache = {}
def get_parsed(fn):
    if fn not in file_cache:
        file_cache[fn] = read_ab_rxn_file(f'{CORPUS}/{fn}')
    return file_cache[fn]

def get_instance_data(fn, met):
    for (id_, j), d in get_parsed(fn).items():
        if id_ == met:
            return d
    return None

fails = [r for r in results if r['crit1_pass'] == 'false']
resolved, still_fail = 0, []
for row in fails:
    met = row['metabolite']
    true_bond_count = int(row['true_bond_count'])
    fns = files_by_met.get(met, [])
    union = set()
    ok = True
    for fn in fns:
        inst = get_instance_data(fn, met)
        if inst is None:
            continue
        atom_numbers = [a['metNr'] for a in inst['atoms']]
        elements = [a['element'] for a in inst['atoms']]
        heads = [b['head'] for b in inst['bonds']]
        tails = [b['tail'] for b in inst['bonds']]
        btypes = [b['type'] for b in inst['bonds']]
        keys = proposed_bond_keys_v2(atom_numbers, elements, heads, tails, btypes)
        if len(keys) != len(heads):
            ok = False  # within-file undercounting -- shouldn't happen but flag it
        union |= keys
    if len(union) == true_bond_count:
        resolved += 1
    else:
        still_fail.append((met, true_bond_count, len(union), ok))

print(f"Resolved by v2 (WL-colour + rank keying): {resolved}/{len(fails)} ({100*resolved/len(fails):.1f}%)")
print(f"Still failing: {len(still_fail)}")
for m, tb, u, ok in still_fail[:30]:
    print(f"  {m}: true={tb} proposed_union={u} within_file_ok={ok}")
