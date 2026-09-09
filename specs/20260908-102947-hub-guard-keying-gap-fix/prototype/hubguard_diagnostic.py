import sys, csv, itertools
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
    parsed = get_parsed(fn)
    # first instance (j starts at 1) matching this met
    for (id_, j), d in parsed.items():
        if id_ == met:
            return d
    return None

summary = Counter()
details = []
errors = []

for row in fails:
    met = row['metabolite']
    stratum = row['stratum']
    true_bond_count = int(row['true_bond_count'])
    fns = files_by_met.get(met, [])
    if not fns:
        summary['no_files_in_manifest'] += 1
        continue
    try:
        instances = []
        for fn in fns:
            d = get_instance_data(fn, met)
            if d is None:
                continue
            instances.append((fn, d))
        if not instances:
            summary['no_parseable_instance'] += 1
            continue

        per_instance_info = []
        for fn, d in instances:
            atom_numbers = [a['metNr'] for a in d['atoms']]
            elements = [a['element'] for a in d['atoms']]
            heads = [b['head'] for b in d['bonds']]
            tails = [b['tail'] for b in d['bonds']]
            btypes = [b['type'] for b in d['bonds']]
            canon_map, eq_classes, unsafe = identify_atom_equivalence_classes(atom_numbers, elements, heads, tails, btypes)
            non_singleton = [c for c in eq_classes if len(c) > 1]
            # is every non-singleton class's hub(s) fully blocking substitution for ALL its members?
            fully_guard_blocked = []
            partially_blocked = []
            not_blocked = []
            for cls in non_singleton:
                canon = min(cls)
                unsafe_set = set(unsafe.get(canon, []))
                # find each member's neighbours; a member m (!=canon) is "blocked" for a given
                # bond to neighbour n if n in unsafe_set (substitution refused)
                idx_of = {a: i for i, a in enumerate(atom_numbers)}
                blocked_count = 0
                total_bonds_for_class = 0
                for h, t in zip(heads, tails):
                    if h in cls or t in cls:
                        other = t if h in cls else h
                        member = h if h in cls else t
                        if member == canon:
                            continue  # canonical member's own bonds aren't substituted anyway
                        total_bonds_for_class += 1
                        if other in unsafe_set:
                            blocked_count += 1
                if total_bonds_for_class > 0 and blocked_count == total_bonds_for_class:
                    fully_guard_blocked.append(cls)
                elif blocked_count > 0:
                    partially_blocked.append(cls)
                else:
                    not_blocked.append(cls)

            charge_total = sum(d['charges'].values())
            elem_counts = Counter(elements)
            per_instance_info.append({
                'fn': fn, 'n_atoms': len(atom_numbers), 'n_bonds': len(heads),
                'n_nonsingleton_classes': len(non_singleton),
                'fully_guard_blocked': len(fully_guard_blocked),
                'partially_blocked': len(partially_blocked),
                'not_blocked': len(not_blocked),
                'charge_total': charge_total,
                'elem_counts': dict(elem_counts),
            })

        # cross-instance structural consistency check: same atom count, same
        # element histogram, same total charge across every instance?
        first = per_instance_info[0]
        structurally_consistent = all(
            (pi['n_atoms'], pi['n_bonds'], pi['charge_total'], pi['elem_counts']) ==
            (first['n_atoms'], first['n_bonds'], first['charge_total'], first['elem_counts'])
            for pi in per_instance_info
        )

        any_fully_blocked = any(pi['fully_guard_blocked'] > 0 for pi in per_instance_info)
        any_not_blocked_nonsingleton = any(pi['not_blocked'] > 0 for pi in per_instance_info)

        if not structurally_consistent:
            cause = 'protonation_or_structural_mismatch'
        elif any_fully_blocked and not any_not_blocked_nonsingleton:
            cause = 'hub_guard_fully_explains'
        elif any_fully_blocked and any_not_blocked_nonsingleton:
            cause = 'hub_guard_plus_other'
        elif per_instance_info[0]['n_nonsingleton_classes'] == 0:
            cause = 'no_symmetry_found_but_still_fails'
        else:
            cause = 'other_unexplained'

        summary[cause] += 1
        details.append({'met': met, 'stratum': stratum, 'cause': cause,
                         'true_bond_count': true_bond_count,
                         'n_instances': len(instances),
                         'structurally_consistent': structurally_consistent,
                         'per_instance': per_instance_info})
    except Exception as e:
        errors.append((met, str(e)))
        summary['script_error'] += 1

print("=== Cause breakdown across", len(fails), "crit1-failing metabolites ===")
for cause, n in summary.most_common():
    print(f"  {cause:40s} {n:4d}  ({100*n/len(fails):.1f}%)")

print("\n=== errors (script-level, not algorithm fallback) ===")
for met, e in errors[:20]:
    print(f"  {met}: {e}")
print(f"  ... {len(errors)} total")

import json
with open('/tmp/figwork/hubguard_diagnostic_details.json', 'w') as f:
    json.dump(details, f, indent=1)
print(f"\nWrote {len(details)} detail records to hubguard_diagnostic_details.json")
