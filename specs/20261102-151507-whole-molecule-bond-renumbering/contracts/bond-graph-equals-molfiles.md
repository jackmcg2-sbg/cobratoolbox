# Contract: the bond graph equals the molfiles

For `[..., BG, dBTM, ...] = buildAtomAndBondTransitionMultigraph(model, RXNFileDir, options)`:

1. **Reference.** For every metabolite $m$ with atoms in `BG`, let $R_m$ be the first-seen molblock of $m$, the reference (first file in processing order, instance 1).
2. **Equality.** The bonds of `BG` between atoms of $m$, as unordered atom-number pairs with `Weight` as the order, equal the bonds of $R_m$. In particular:
   - no bond joins an atom to itself;
   - no atom has more bonds than in $R_m$;
   - the number of bonds equals the FR-008 ground truth.
3. **Renumbering.** A copy $C$ of $m$ in any RXN file whose (element list, sorted bond list) equals $R_m$'s keeps its atom numbers. A copy that differs is renumbered by one isomorphism $\pi$ of element-labelled molecular graphs (bond order ignored), $C \to R_m$. Every bond $\{a, b\}$ of $C$ is keyed as $\{\pi(a), \pi(b)\}$.
4. **No isomorphism.** A copy with no isomorphism onto $R_m$ raises a visible warning naming $m$ and the reaction, and keeps its raw numbers. Clause 2 then does not hold for $m$, which the FR-008 count check reports.
5. **Bond orders.** Orders in `BG` are those of $R_m$.
6. **Unchanged.** Signature, outputs, options and messages, apart from the new warning in clause 4.
