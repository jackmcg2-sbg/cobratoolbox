# Consistent-arm copy of the paper's example network

Test data for `testConservedReactingMoieties.m` (feature
20261102-151507-whole-molecule-bond-renumbering, US3). The network is the example of Rahou et
al., *J. Theor. Biol.* 621 (2026) 112348, §3.1.1: `ACONTm` (𝒴₁), `r0426` (𝒴₂) and `r0317`
(𝒴₃), the same reactions as `../rxnFiles`.

Citrate's two CH2 arms are symmetry-equivalent. In `../rxnFiles`, `ACONTm` moves the
hydroxyl to citrate's C7 and H8 off C7, while `r0317` and `r0426` take the water hydrogen
from the other arm (C13) and form the double bond towards it. Here both dehydrations use the
C7 arm and H8, as `ACONTm` does.

- `ACONTm.rxn` is an unchanged copy.
- `r0317.rxn` and `r0426.rxn` differ from `../rxnFiles` only in the atom-map numbers (V2000
  characters 61–63) of their `HC00342[m]` and `h2o[m]` product blocks.

With this mapping the paper's §4.1 rule, the authors' original code and this toolbox give the
reacting moiety graph of the paper's Fig. 11 (reconXmoieties exploration
`specs/20261030-121933-reacting-moiety-memory`, E32).
