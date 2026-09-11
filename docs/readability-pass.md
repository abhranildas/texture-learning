# Bugs found during the readability pass (not fixed)

- `+segmentation/group_patches.m:112` discards `assign_isolated_patches`'s third output
  (`ngrps`) and recomputes group growth separately in the caller — two code paths compute the
  same count for the same event; confirm they can't diverge.
- `+segmentation/neighbor_similarity_matrix.m` header asserts `cfg.gtr.power_suppress` and
  `cfg.dv.power_suppress` are "both 16 since Geisler unified b0" — nothing in code enforces this;
  editing one without the other would silently desync the border/content combination from
  `content_similarity_matrix.m`. Same coupling recurs in `config.m` (`cfg.dv.power_suppress` /
  `cfg.gtr.power_suppress`), nothing enforces it there either.
- `+segmentation/assign_isolated_patches.m:10-15` documents its own deliberate behaviour change
  from the original `iso_patch.m` (`i~=j` → `other_idx~=patch_idx`), already flagged in-file as
  changing the reproduced paper numbers — resurfaced here so it isn't missed in a skim.
- `+segmentation/merge_similar_regions.m` merges exactly one region pair per call by design;
  `group_patches.m` calls it once per pass, so there is no iterative multi-merge unless a caller
  loops it.
- `pipeline/s4_optimize_bins.m` (`eval_r`, ~line 245) rejects outliers with `rv < -25` only — no
  upper-bound check — while `pair_responses.m`'s outlier rejection for the same kind of LLR
  quantity is two-sided (`all(check>lo) && all(check<hi)`). Comment marks it "as in the original,"
  so likely long-standing, but the asymmetry is worth confirming with Geisler.
- `pipeline/self_sup_decision.m`'s `'bc_noshift'` method branch is unreachable: neither
  `s6_selfsup_discrimination.m` (`{'bc','bc_shft','c_shft'}`) nor `s7_segment_gtr.m`
  (`'c_shft'`/`'bc'`) ever passes it. Dead code unless called directly from outside the pipeline.
- Three bugs already flagged in-file by a previous author (not new, resurfaced for visibility):
  `neighbor_far_responses.m`'s header documents a fixed stateful-renormalization bug in the
  original code; `s7_segment_gtr.m`'s header documents an ecc-dependent neighbour-distance fix;
  `s6_selfsup_discrimination.m`'s header documents a `pd`/`eccb` inconsistency.
- `plot_stage7.m`'s header documents `method` as `'nc'` or `'bc'`, but the code
  (`plot_stage7.m` and identically `plot_stage8_natural.m`) does
  `struct('nc', 'c_shft', 'ncb', 'bc').(method)`, which only has fields `nc` and `ncb` — passing
  the documented `'bc'` value would error. Currently unreachable (`run_demo.m` only ever passes
  `'ncb'`), but the header disagrees with the code it describes.
- `run_demo.m`'s "missing artifacts" error text tells the user to set a `run_training_stages`
  variable that doesn't exist anywhere in the repo — the actual switch is `demo_type = 'full'`.
- `run_demo.m`'s `try/catch err/rethrow(err)` around the `s7_segment_gtr` call is a no-op (catches
  and immediately rethrows).
- `setup.m`'s `ensure_addon_on_path` guards an optional 5th argument that both call sites always
  pass — dead defensiveness, not a bug.
- Zone-2 `cfg.*` rename candidates spotted for whenever that tranche happens (not touched):
  `cfg.gtr.szp`, `cfg.gtr.dcrit`, `cfg.gtr.n_regions` (comment still calls it `ntexr`),
  `cfg.natural.max_val`.
