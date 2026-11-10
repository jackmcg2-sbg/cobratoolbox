# Contract: reacting-bond incidence from bond changes

## `[arm, moietyFormulae, reacting] = identifyConservedReactingMoieties(model, BG, dATM, options, dBTM)`

### New input

- **`dBTM`**: trailing, optional. The directed bond transition multigraph, as the eighth output of `buildAtomAndBondTransitionMultigraph` built from the same model and RXN files as `BG` and `dATM`.
  - It is read only in full mode with `reactingBondIncidence = 'bondChange'`. Otherwise it is ignored and may be absent.
  - **Used fields**: `Edges.HeadMet`, `Edges.TailMet`, `Edges.HeadBondIndex`, `Edges.TailBondIndex` and `Edges.rxns`.
  - **Broken bond**: an edge whose `TailMet` is in `model.rxns`; the bond is `HeadBondIndex`.
  - **Formed bond**: an edge whose `HeadMet` is in `model.rxns`; the bond is `TailBondIndex`.

### New option

- **`options.reactingBondIncidence`**: `'bondChange'` (default) or `'endAtom'`. It is matched case-sensitively.
  - **`'bondChange'`**: $\text{CRB2R}_{b,R} = 1$ exactly when reaction $R$ breaks or forms a bonding interaction of a reacting bond merged into condensed edge $b$. This is Rahou et al. 2026, §6.1, eq. 32.
  - **`'endAtom'`**: today's rule, unchanged. $\text{CRB2R}_{b,R} = 1$ when an atom transition of $R$ has either end atom of the first reacting bond kept for condensed edge $b$ as its head or tail. All `reacting` outputs are `isequaln` to those of `ad0d11d60` on the same inputs, apart from the two new fields below.
  - **Anything else**: error `identifyConservedReactingMoieties:invalidReactingBondIncidence`, naming the option and its two values.

### Errors

- **Full mode, `'bondChange'`, `dBTM` absent or empty**: error `identifyConservedReactingMoieties:missingBondTransitions`. The message says to pass the builder's `dBTM` output as the fifth input, or to set `options.reactingBondIncidence = 'endAtom'` for the earlier rule.
- **Errors raised today** keep their identifier and message.

### Outputs

- **`reacting.CRB2R`**: `nCRB × n` sparse double, `nCRB = numedges(reacting.Condensed_RBG)`. Its rows are in `Condensed_RBG` edge order, its columns in `model.rxns` order, and its entries are 0 or 1.
- **`reacting.unchangedReactingBonds`** (new, both rules): an `nCRB × 1` logical, true where the row of `CRB2R` is empty. These rows are left out of the set-cover constraints, as today.
- **`reacting.offGraphBondChanges`** (new, `'bondChange'` only; `0` under `'endAtom'`): the number of broken or formed bonding interactions whose bond is on no `Condensed_RBG` edge. When it is not zero, one warning `identifyConservedReactingMoieties:offGraphBondChanges` gives the count (VII-B).
- **Unchanged**: `Condensed_RBG`, and the meaning of `selectedReactions`, `selectedReactionNames`, `ReactMoietyMatrix`, `ReactMoietySets` and `ReactMoietyGraphs` (all derived from `CRB2R` as today). Their values change with `CRB2R`.
- **`conservedMoietiesOnly = true`**: `reacting` is `struct('computed', false)` as today, with no new fields. `dBTM` is not needed.
- **`arm` and `moietyFormulae`**: unchanged under both rules.

## Unchanged surfaces

- `buildAtomAndBondTransitionMultigraph`: signature, outputs and messages. `dBTM` is already its eighth output.
- `identifyConservedReactingSubgraphs`, `buildReactingMoietyTables`, `displayReactingMoieties`: unchanged.
- The positions of `model`, `BG`, `dATM` and `options`.
