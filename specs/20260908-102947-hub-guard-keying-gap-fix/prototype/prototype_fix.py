"""Prototype fix: instead of leaving a guard-blocked class's atoms raw
(which reintroduces file-specific numbering instability), key each blocked
bond by (other-endpoint-identity, class-id, bond-type, RANK-within-class)
where rank is the member's position in the class's own sorted atom-number
list (1st, 2nd, ...). This keeps every real bond distinct (preserves true
multiplicity, same as today) while making the key deterministic and
cross-file-stable, since it depends only on class membership and size, not
on which raw atom number a given file happened to assign.

Tests this against every one of the 93 real crit1 failures to see what
fraction it actually resolves, before proposing it as a spec change.
"""
import sys, csv
from collections import defaultdict, Counter
sys.path.insert(0, '/tmp/figwork')
from parse_rxn import read_ab_rxn_file
from port_identify_classes import identify_atom_equivalence_classes

CORPUS = '/tmp/hubguard_corpus'
RESULTS_CSV = '/mnt/user-data/uploads/reconXmoieties/experiments/moietySizing/results/outputs/stratifiedSample/matlab_validation_results_20260908.csv'
MANIFEST_CSV = '/mnt/user-data/uploads/reconXmoieties/experiments/moietySizing/results/outputs/stratifiedSample/instance_manifest_20260908.csv'

with open(RESULTS_CSV) as f:
    results = list(csv.DictReader(f))
fails = [r for r in results if r['crit1_pass'] == 'false']
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


def proposed_bond_keys(atom_numbers, elements, heads, tails, btypes):
    """Returns the set of bond keys under the PROPOSED rank-based scheme."""
    canon_map, eq_classes, unsafe = identify_atom_equivalence_classes(atom_numbers, elements, heads, tails, btypes)
    elem_of = dict(zip(atom_numbers, elements))
    class_of = {}
    rank_of = {}
    class_id_of_canon = {}
    for cls in eq_classes:
        canon = min(cls)
        class_id_of_canon[canon] = tuple(sorted(cls))  # class identity = its member set shape... but for
        # cross-file stability we can't use the raw member set (differs per file); use (element, size) as class "shape id"
        for rank, member in enumerate(sorted(cls), start=1):
            class_of[member] = canon
            rank_of[member] = rank

    def endpoint_token(atom, other):
        canon = canon_map[atom]
        cls = None
        # find this atom's class members via canon map reverse (cheap: canon==atom for singleton)
        if canon == atom:
            return ('atom', atom, elem_of[atom])  # singleton: identity doesn't need cross-file stability beyond element+topology (existing behaviour)
        unsafe_set = set(unsafe.get(canon, []))
        if other not in unsafe_set:
            return ('atom', canon, elem_of[atom])  # safe to substitute as today
        # blocked: use (class-shape, rank) instead of raw atom number
        class_size = None
        for c in eq_classes:
            if atom in c:
                class_size = len(c)
                break
        return ('class', elem_of[atom], class_size, rank_of[atom])

    keys = []
    for h, t, bt in zip(heads, tails, btypes):
        eh = endpoint_token(h, t)
        et = endpoint_token(t, h)
        a, b = (eh, bt), (et, bt)
        key = tuple(sorted([eh, et])) + (bt,)
        keys.append(key)
    return set(keys)


import json
with open('/tmp/figwork/hubguard_diagnostic_details.json') as f:
    details = json.load(f)

resolved = 0
still_fail = 0
still_fail_list = []
for d in details:
    met = d['met']
    true_bond_count = d['true_bond_count']
    fns = files_by_met.get(met, [])
    union = set()
    for fn in fns:
        inst = get_instance_data(fn, met)
        if inst is None:
            continue
        atom_numbers = [a['metNr'] for a in inst['atoms']]
        elements = [a['element'] for a in inst['atoms']]
        heads = [b['head'] for b in inst['bonds']]
        tails = [b['tail'] for b in inst['bonds']]
        btypes = [b['type'] for b in inst['bonds']]
        keys = proposed_bond_keys(atom_numbers, elements, heads, tails, btypes)
        union |= keys
    if len(union) == true_bond_count:
        resolved += 1
    else:
        still_fail += 1
        still_fail_list.append((met, true_bond_count, len(union)))

print(f"Resolved by proposed rank-based keying: {resolved}/{len(details)} ({100*resolved/len(details):.1f}%)")
print(f"Still failing: {still_fail}")
for m, tb, u in still_fail_list[:20]:
    print(f"  {m}: true={tb} proposed_union={u}")
