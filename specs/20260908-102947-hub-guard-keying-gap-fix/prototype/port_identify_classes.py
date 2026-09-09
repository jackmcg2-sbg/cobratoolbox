"""Faithful Python port of identifyAtomEquivalenceClasses.m (feature 020),
built to mirror the MATLAB source line-for-line (no VF2-timeout shortcuts,
no heuristics) -- used only to inspect WHY the algorithm produces a given
answer on a concrete metabolite instance, not as a replacement validator.

Automorphism check uses exact brute-force permutation search restricted to
same-WL-color nodes (exact, not networkx VF2 with a timeout) -- fine at
these molecule sizes (<40 atoms) and removes any risk of repeating the
earlier preliminary Python port's timeout-fallback mistake.
"""
import itertools
from collections import defaultdict

def identify_atom_equivalence_classes(atom_numbers, elements, head_atoms, tail_atoms, btypes):
    p = len(atom_numbers)
    idx_of = {a: i for i, a in enumerate(atom_numbers)}
    adj = defaultdict(dict)  # adj[i][j] = bond type
    for h, t, bt in zip(head_atoms, tail_atoms, btypes):
        hi, ti = idx_of[h], idx_of[t]
        adj[hi][ti] = bt
        adj[ti][hi] = bt

    color = list(elements)
    for _ in range(p + 1):
        new_color = []
        for k in range(p):
            sig_parts = sorted(f"{bt}:{color[n]}" for n, bt in adj[k].items())
            new_color.append(color[k] + '|' + ','.join(sig_parts))
        old_groups = len(set(color))
        # re-hash to compact labels (order doesn't matter for group count / partition)
        uniq = {c: i for i, c in enumerate(sorted(set(new_color)))}
        new_color_id = [str(uniq[c]) for c in new_color]
        new_groups = len(set(new_color_id))
        color = new_color_id
        if old_groups == new_groups:
            break

    groups = defaultdict(list)
    for i, c in enumerate(color):
        groups[c].append(i)
    local_groups = list(groups.values())

    def pair_is_automorphic(a, b):
        # exact brute-force: is there a permutation of {0..p-1} preserving
        # adjacency (element + bond type) that sends a->b? Restrict search
        # to color-respecting permutations for tractability.
        by_color = defaultdict(list)
        for i in range(p):
            by_color[color[i]].append(i)
        color_list = list(by_color.keys())
        # backtracking search for an automorphism with node a mapped to b
        mapping = {}
        used = set()

        def edges_ok(i, j):
            # check all edges from i to already-mapped nodes match under mapping
            for n, bt in adj[i].items():
                if n in mapping:
                    if adj[j].get(mapping[n]) != bt:
                        return False
            for n2, bt2 in adj[j].items():
                inv = {v: k for k, v in mapping.items()}
                if n2 in inv:
                    if adj[i].get(inv[n2]) != bt2:
                        return False
            return True

        order = sorted(range(p), key=lambda i: -len(adj[i]))
        # force a->b first
        if a in order:
            order.remove(a)
        order = [a] + order

        def backtrack(pos):
            if pos == len(order):
                return True
            i = order[pos]
            forced = b if i == a else None
            candidates = [forced] if forced is not None else by_color[color[i]]
            for j in candidates:
                if j in used:
                    continue
                if not edges_ok(i, j):
                    continue
                mapping[i] = j
                used.add(j)
                if backtrack(pos + 1):
                    return True
                del mapping[i]
                used.discard(j)
            return False

        return backtrack(0)

    for members in local_groups:
        if len(members) > 1:
            for a, b in itertools.combinations(members, 2):
                if not pair_is_automorphic(a, b):
                    raise RuntimeError('collisionCheckFailed')

    equivalence_classes = []
    canonical_map = {}
    unsafe_by_class = {}
    for members in local_groups:
        class_atom_numbers = sorted(atom_numbers[i] for i in members)
        equivalence_classes.append(class_atom_numbers)
        canon = min(class_atom_numbers)
        for i in members:
            canonical_map[atom_numbers[i]] = canon
        if len(members) > 1:
            neighbor_count = defaultdict(int)
            for i in members:
                for n in adj[i]:
                    neighbor_count[atom_numbers[n]] += 1
            unsafe_by_class[canon] = [a for a, c in neighbor_count.items() if c >= 2]

    def simulate_safe(atom_raw, other_raw):
        if atom_raw not in canonical_map:
            return atom_raw
        rep = canonical_map[atom_raw]
        if rep == atom_raw:
            return atom_raw
        if other_raw in unsafe_by_class.get(rep, []):
            return atom_raw
        return rep

    num_bonds = len(head_atoms)
    added = True
    guard_iter = 0
    while added and guard_iter <= num_bonds:
        guard_iter += 1
        added = False
        eff_keys = []
        for h, t in zip(head_atoms, tail_atoms):
            eh = simulate_safe(h, t)
            et = simulate_safe(t, h)
            eff_keys.append(tuple(sorted((eh, et))))
        counts = defaultdict(int)
        for k in eff_keys:
            counts[k] += 1
        for (h, t), k in zip(zip(head_atoms, tail_atoms), eff_keys):
            if counts[k] > 1:
                rh = canonical_map[h]
                rt = canonical_map[t]
                if rh != h:
                    lst = unsafe_by_class.setdefault(rh, [])
                    if t not in lst:
                        lst.append(t); added = True
                if rt != t:
                    lst = unsafe_by_class.setdefault(rt, [])
                    if h not in lst:
                        lst.append(h); added = True

    return canonical_map, equivalence_classes, unsafe_by_class


def safe_canonicalize_one_atom(atom_raw, other_raw, rank_map, unsafe_map):
    if atom_raw not in rank_map:
        return atom_raw
    rep = rank_map[atom_raw]
    if rep == atom_raw:
        return atom_raw
    if other_raw in unsafe_map.get(rep, []):
        return atom_raw
    return rep


def canonical_bond_key(met, h, eh, t, et):
    a = (met, h, eh)
    b = (met, t, et)
    return (a, b) if a <= b else (b, a)
