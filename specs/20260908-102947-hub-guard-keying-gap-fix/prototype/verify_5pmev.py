import sys
sys.path.insert(0, '/tmp/figwork')
from parse_rxn import read_ab_rxn_file
from port_identify_classes import identify_atom_equivalence_classes, safe_canonicalize_one_atom, canonical_bond_key

DATA_DIR = "/mnt/user-data/uploads/reconXmoieties/chempy_results/old/vmh2_reconx_for_atom_mapping/rxnfiles/atomMapped"

def get_instance(path, met, inst=1):
    r = read_ab_rxn_file(path)
    return r[(met, inst)]

inst1 = get_instance(f"{DATA_DIR}/MEVK1x.rxn", "5pmev[x]")
inst2 = get_instance(f"{DATA_DIR}/PMEVKx.rxn", "5pmev[x]")

def process(inst, label):
    atom_numbers = [a['metNr'] for a in inst['atoms']]
    elements = [a['element'] for a in inst['atoms']]
    heads = [b['head'] for b in inst['bonds']]
    tails = [b['tail'] for b in inst['bonds']]
    btypes = [b['type'] for b in inst['bonds']]
    canon_map, eq_classes, unsafe = identify_atom_equivalence_classes(atom_numbers, elements, heads, tails, btypes)
    non_singleton = [c for c in eq_classes if len(c) > 1]
    print(f"--- {label}: {len(atom_numbers)} atoms, {len(heads)} bonds ---")
    print(f"  non-singleton classes: {non_singleton}")
    print(f"  unsafe neighbours by canonical rep: {unsafe}")
    elem_of = {a['metNr']: a['element'] for a in inst['atoms']}
    keys = []
    for h, t in zip(heads, tails):
        eh_atom = safe_canonicalize_one_atom(h, t, canon_map, unsafe)
        et_atom = safe_canonicalize_one_atom(t, h, canon_map, unsafe)
        key = canonical_bond_key('5pmev[x]', eh_atom, elem_of[h], et_atom, elem_of[t])
        keys.append(key)
    uniq_keys = set(keys)
    print(f"  raw bond count = {len(heads)}, canonicalized distinct-key count (single instance) = {len(uniq_keys)}")
    return uniq_keys

k1 = process(inst1, "instance 1 (MEVK1x)")
k2 = process(inst2, "instance 2 (PMEVKx)")

union = k1 | k2
print(f"\nfixedUnionCount (union across both instances) = {len(union)}")
print(f"true_bond_count (recorded, single-instance raw) = 23")
print(f"crit1_pass = {len(union) == 23}")
