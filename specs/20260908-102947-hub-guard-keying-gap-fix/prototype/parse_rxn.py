"""Faithful re-implementation of readABRXNFile.m's parsing convention
(row-position-based metNr/headAtoms/tailAtoms, NOT the AAM map-number
column), so we can inspect real molblocks exactly as
identifyAtomEquivalenceClasses.m would see them."""
import re, sys

def read_ab_rxn_file(path):
    with open(path) as f:
        text = f.read()
    blocks = re.split(r'\$MOL\r?\n', text)
    header = blocks[0]
    header_lines = re.split(r'\r?\n', header)
    rxn_formula_full = header_lines[3]
    left, right = re.split(r'<=>|->', rxn_formula_full)
    def parse_side(s):
        parts = [p.strip() for p in s.strip().split('+')]
        out = []
        for p in parts:
            toks = p.split(None, 1)
            if len(toks) == 1:
                out.append((toks[0], -1))
            else:
                out.append((toks[1].strip(), -float(toks[0])))
        return out
    leftside = parse_side(left)
    rightside = parse_side(right)
    umets = [m for m, s in leftside] + [m for m, s in rightside]
    svec = [s for m, s in leftside] + [-s for m, s in rightside]
    # NOTE sign convention matches MATLAB: left side negative stoich, right positive.
    svec = [s for m, s in leftside] + [s for m, s in rightside]
    for i in range(len(rightside)):
        pass
    # redo faithfully: left side already stored as -1 or -str2double(w1)
    # right side should be +1 or +str2double(w1)
    svec = []
    for m, s in leftside:
        svec.append(s)  # already negative
    for m, s in rightside:
        svec.append(-s)  # parse_side stored as -val for uniformity; flip back to positive
    counter = 0  # blocks[0] is header, blocks[1..] are $MOL blocks in order
    result = {}  # (met, instance) -> dict(atoms=[...], bonds=[...])
    for i, id_ in enumerate(umets):
        s = svec[i]
        rbool = s < 0
        for j in range(1, int(abs(s)) + 1):
            counter += 1
            mol_str = blocks[counter]
            mol_lines = re.split(r'\r?\n', mol_str)
            n_atoms = int(mol_lines[3][0:3])
            n_bonds = int(mol_lines[3][3:6])
            atoms = []
            for k in range(4, 4 + n_atoms):
                line = mol_lines[k]
                element = line[30:33].strip()
                aam = line[60:].split()[0]
                atoms.append({'metNr': k - 3, 'element': element, 'aam': int(float(aam))})
            charges = {}
            bonds = []
            for l in range(4 + n_atoms, 4 + n_atoms + n_bonds):
                line = mol_lines[l]
                head = int(line[0:3])
                tail = int(line[3:6])
                btype = int(line[7:9])
                bonds.append({'head': head, 'tail': tail, 'type': btype})
            # scan for M  CHG lines anywhere in this molblock
            for line in mol_lines:
                m = re.match(r'M\s+CHG\s+(\d+)\s+(.*)', line)
                if m:
                    n = int(m.group(1))
                    nums = list(map(int, m.group(2).split()))
                    for x in range(n):
                        charges[nums[2*x]] = nums[2*x+1]
            result[(id_, j)] = {'atoms': atoms, 'bonds': bonds, 'charges': charges, 'isSubstrate': rbool}
    return result

if __name__ == '__main__':
    path = sys.argv[1]
    met = sys.argv[2] if len(sys.argv) > 2 else None
    r = read_ab_rxn_file(path)
    for (id_, j), d in r.items():
        if met and id_ != met:
            continue
        print(f"=== {id_} instance {j} (isSubstrate={d['isSubstrate']}) : {len(d['atoms'])} atoms, {len(d['bonds'])} bonds ===")
        for a in d['atoms']:
            chg = d['charges'].get(a['metNr'], 0)
            print(f"  metNr={a['metNr']:3d} elem={a['element']:2s} aam={a['aam']:3d} chg={chg}")
        for b in d['bonds']:
            print(f"  bond {b['head']:3d} - {b['tail']:3d}  type={b['type']}")
