# Non-isomorphic copy fixture

Test data for `testBuildAtomAndBondTransitionMultigraph.m` (feature
20261102-151507-whole-molecule-bond-renumbering, FR-003). `ACONTm.rxn` is an unchanged copy
of `../rxnFiles/ACONTm.rxn`. `r0317.rxn` is a copy of `../rxnFiles/r0317.rxn` in which one
bond line of citrate's molblock (line 41) reads `7 14` instead of `13 14`, so its citrate is
not isomorphic to `ACONTm.rxn`'s (C7 carries three hydrogens, C13 one). The builder must
warn and keep that copy's raw numbering.
