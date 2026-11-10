# The paper's example with a transport reaction

Test data for `testConservedReactingMoieties.m` (feature
20261106-092213-paper-reacting-bond-incidence, US1 AS1, research R6).

- `ACONTm.rxn`, `r0317.rxn` and `r0426.rxn` are unchanged copies of `../rxnFilesConsistentArms`.
- `CITICITtm.rxn` is hand-written: cit[c] + icit[m] -> cit[m] + icit[c], a VMH
  citrate/isocitrate antiporter. Its `cit` and `icit` molblocks are copies of the
  consistent-arm `ACONTm.rxn` blocks, with the identifier changed for the `[c]` copies. The
  atom map is the identity: atom k of each reactant maps to atom k of the same metabolite
  among the products (map numbers 1-18 for citrate, 19-36 for isocitrate, V2000 characters
  61-63).

`CITICITtm` moves every atom of citrate and isocitrate but breaks and forms no bond, so under
the paper's rule (Rahou et al. 2026, Sec. 6.1, eq. 32) it belongs to no condensed reacting
bond. The earlier end-atom rule marked it on condensed reacting bonds 1, 2, 5 and 6.
