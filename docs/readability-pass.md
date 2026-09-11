# Blueprint: repo-wide readability pass (behaviour-preserving)

Read every `.m` file in the repo and clean it in place — better names, complete header docs,
consistent conventions, reflowed long lines — under the constraint that **no output changes**.
What makes this worth doing as a distinct pass is that the constraint is **mechanically
checkable here**, so the diff does not need to be trusted, only verified. Everything below is
built around that check.

Every number in this document was measured on the repo as it stands (MATLAB R2024b), not
estimated. Re-measure before trusting any of them after substantial changes.

**Scope, precisely.** `Bill's old code/` and `Bill's old code - revised/` are excluded
entirely — 93 `.m` files of ancestral code, gitignored, kept for reference only. Cleaning code
that exists to be read against the paper's history is wasted effort. That leaves **66 files,
5744 lines** in scope: `+segmentation/` (10 files, 622 lines), `+gtr/` (2, 122),
`pipeline/` (21, 1449), `demo/` (18, 1352), `twin-net/` (11, 847), the three root files
`run_demo.m`/`setup.m`/`config.m` (547), and `experiments/adaptive_hist_exp.m` (805).

---

## 1. The check

`mtree` parses a `.m` file into MATLAB's own syntax tree, and `tree2str` prints it back in a
canonical form: comments stripped, whitespace and bracket spacing normalised, missing `end`
supplied. So

```matlab
canon = @(f) tree2str(mtree(f,'-file'));
```

gives a fingerprint that is blind to exactly the things this pass is allowed to change and
sensitive to everything else. Verified: `tree2str` succeeds on **all 66 in-scope files**, with
no failures.

Worked example, run on `+segmentation/prep_grid.m`. Cleaning it — a `See also` line, units in
the input docs, blank-line grouping, reflowing the two long calls, and renaming `P`→`patches`,
`G`→`achrom`, `Gn`→`achrom_norm`, `psz`→`patch_size`, `m0`→`target_mean`,
`c0`→`target_contrast`, `npx`→`n_grid_rows`, `npy`→`n_grid_cols`, `gx`→`grid_row`,
`gy`→`grid_col`, `p`→`patch`, `image`→`region_image` — leaves a canonical form that becomes
byte-identical to the original after applying the rename map in reverse:

```matlab
c_new = canon(new_file);
for k = 1:size(renames,1)   % renames = {new_name, old_name}
    c_new = regexprep(c_new, ['(?<![A-Za-z0-9_.])' renames{k,1} '(?![A-Za-z0-9_])'], renames{k,2});
end
isequal(canon(old_file), c_new)   % must be true
```

That trial passes (`MATCH: 1`). Note the map above includes both `patch` and `patch_size`, and
both `achrom` and `achrom_norm` — the negative lookahead `(?![A-Za-z0-9_])` is what keeps the
shorter name from eating the longer one, so do not weaken it to a plain `\b`.

Two caveats. `mtree`/`tree2str` are undocumented MATLAB APIs — stable for many releases, but
pin the MATLAB version in the commit message. And the reverse-rename substitution is
scope-blind, so a rename map with a name on both sides (`a→b` and `b→c`) can produce a false
pass; assert the map is a bijection with disjoint domain and range before using it:

```matlab
dom = renames(:,1); ran = renames(:,2);
assert(numel(unique(dom)) == numel(dom));
assert(numel(unique(ran)) == numel(ran));
assert(isempty(intersect(dom, ran)));
```

### 1.1 The second check this repo can afford

Unlike the sibling `camouflage_detection` repo — where ~40 % of files cannot execute at all —
**this repo runs**, so Tier B changes can be backed by real golden outputs rather than by
pattern-matching alone. Verified end to end: `setup` completes; every `cfg.paths.*` folder
resolves against the sibling `vislab-common/data`; `segmentation.prep_grid` on a fixed
`rng(0)` input returns checksum `4096927.5783767` identically across three runs;
`load_dv_handles(cfg, 1, true)` returns its five handles `h,e,c,b,bc`; and
`sample_demo_pairs(cfg, 1)` returns `[64 128 3 7820]` near and far pairs. Build the golden
harness on those entry points.

Two things the harness must respect:

- **Seed explicitly.** `run_demo.m:201` and `experiments/adaptive_hist_exp.m:63,83,294` call
  `rng('shuffle')` deliberately — those paths are *not* reproducible run to run. A golden test
  must call the underlying functions with `rng(cfg.seed)` set by the harness, never go through
  `run_demo`.
- **`parfor` is safe here.** All nine `parfor` loops
  (`+segmentation/content_features.m:40`, `+segmentation/content_similarity_matrix.m:44`,
  `pipeline/s1_learn_color_transform.m:37`, `pipeline/s23_learn_priors_and_pairs.m:41`,
  `demo/plot_stage1b_gradients.m:98`, `twin-net/load_nat_A_pool.m:34`,
  `twin-net/nat_near_far_patches_net.m:30`, `experiments/adaptive_hist_exp.m:308,519`) write
  into a sliced output (`pix_c{f} = …`, `phi(i,:) = row`, `CFv{k} = s`) rather than
  accumulating into a reduction variable, so worker order cannot change a float sum. Checked
  individually. If a future edit turns one into a reduction, that edit is Tier C.

---

## 2. Three tiers of change

| Tier | Change | Canonical diff | Verification |
|---|---|---|---|
| **A** | Comments, header docs, whitespace, reflow, blank-line grouping, file-local renames | empty (after reverse rename) | `isequal` — fully automatic, no execution |
| **B** | Adding a suppressing `;`, preallocation, `find`→logical indexing, deleting a provably unused assignment | non-empty but must match a whitelisted pattern | pattern check **plus** runtime golden output |
| **C** | Bug fixes, signature changes, adding `arguments` blocks, merging duplicate functions, reordering statements, changing accumulation order in a float reduction, anything touching the RNG stream, **deleting commented-out code** | — | **forbidden in this pass** |

Semicolon insertion is Tier B, not A: `tree2str` preserves display-vs-suppress, so the
canonical diff is exactly `X` → `X;` — trivially whitelisted, but not invisible.

Tier C matters most. The tempting changes in this repo are all Tier C: collapsing the two
copies of `local_show_pair` (`demo/plot_stage3.m:43` and `demo/plot_stage6_pairs.m:74`),
collapsing the two near-identical local functions at
`experiments/adaptive_hist_exp.m:544` and `:570`, converting `pair_responses`' ten positional
arguments into an `arguments` block, and turning the three scripts into functions. Every one of
those changes output, call sites, or validation behaviour. Keeping them out is what makes this
diff skimmable instead of line-by-line.

When the pass uncovers a *bug* — and it will — **record it in a findings list and leave the
code broken**. That recording is the main scientific payoff; the tidier code is a side effect.

Statement reordering is Tier C even though it looks cosmetic, purely because the check cannot
distinguish a safe reorder from an unsafe one. If a reorder is genuinely wanted, make it a
separate commit with its own justification.

---

## 3. What is actually wrong with the files

Measured, not assumed. **The headline finding is that the usual targets are already clean, so
do not spend the budget there.**

- **Lint is a non-issue.** `checkcode` reports **11 messages across all 66 files** — `PFBNS` 9,
  `NOCOMMA` 1, `NOPTS` 1 — confined to six files (`+segmentation/content_similarity_matrix.m`
  3, `+segmentation/content_features.m` 2, `demo/plot_stage1b_gradients.m` 2,
  `experiments/adaptive_hist_exp.m` 2, `setup.m` 1, `twin-net/train_net.m` 1). **62 of 66 files
  are lint-clean.** For comparison, `camouflage_detection` has 283 warnings. There is no
  mechanical-warning tranche to do here; the `PFBNS` ones ("parfor variable may be
  broadcast") are performance notes, not defects, and are Tier C anyway.
- **Formatting is nearly clean.** Zero tab-indented files. Every file has a header comment on
  line 1–3. The one real formatting defect is line length: **37 files carry at least one line
  over 100 characters**, worst `demo/plot_stage1b_gradients.m:128` (159 chars),
  `pipeline/pair_responses.m:52` (152), `config.m:65` (147),
  `experiments/adaptive_hist_exp.m:311` (144). Two files hold a third of the total:
  `experiments/adaptive_hist_exp.m` (62 long lines) and `twin-net/train_net.m` (31).
- **Header docs are half-finished.** All 66 files open with a comment, but only **34 carry an
  `Inputs`/`Output` block**; the other 32 stop at a one-line summary. **Zero files have a
  `See also` line.** There is **no `Contents.m` anywhere**, though `vislab-common` ships one per
  package. This is the single largest readability gap and the cheapest to close.
- **Names are the real problem.** The repo speaks in abbreviations, consistently enough to be
  learnable but never defined anywhere. Occurrence counts across the in-scope files: `psz` 321,
  `ecc` 173, `dv` 112, `col` 94, `pimg` 65, `ngrps` 50, `itype` 44, `nsmp` 33, `b0` 24,
  `qbs` 24, `qbd` 23, `ptch` 19, `nh` 17, `ne` 15. Add the single-letter assignments — `n` 16,
  `Y` 12, `p` 9, `c0` 9, `R` 8, `m0` 6, `s`/`r`/`x` 6 each, `CF` 4, `fv` 4 — and the bare loop
  counters `i` (49 uses) and `j` (19).
- **Names diverge across call boundaries.** `segmentation.prep_grid` returns `[P, G, Gn]`
  (`+segmentation/prep_grid.m:1`) but `segmentation.content_features` receives the same three
  as `(P, G, E, …)` (`+segmentation/content_features.m:1`) — the third argument changes name
  between producer and consumer for no reason. Look for this pattern specifically; it is worse
  than a merely short name.
- **Two naming conventions coexist.** The repo is snake_case except `twin-net/`, which is
  camelCase in both file and identifier names: `getTwinBatchPairs.m`, `getTwinBatch_nat_live.m`
  (both at once), `forwardTwin.m`, `predictTwin.m`, `poolStats.m`, `modelLoss.m`, and inside
  them `fcParams`, `miniBatchSize`, `pairLabels`, `A_pool`. File renames are Tier C; the
  in-file identifiers are Tier A and can be unified now.
- **Three builtin shadows**: `image` is a parameter name in `+segmentation/prep_grid.m`,
  `+segmentation/content_similarity_matrix.m` and `+segmentation/neighbor_similarity_matrix.m`
  (29 uses). Also two uses of `diff` as a variable. Rename all of them.
- **Commented-out code is present but small.** 1748 of 5744 lines are full-line comments (33 %
  of non-blank lines), of which **113 lines across 45 files look like commented-out code**
  (heuristic: comment body parses as a statement). Worst:
  `demo/plot_stage1b_gradients.m` 12, `experiments/adaptive_hist_exp.m` 9,
  `pipeline/s7_segment_gtr.m` 6, `pipeline/s5_train_decision_vars.m` 5. **This pass does not
  remove any of it** (Tier C) — the measurement is a diagnostic and a flag that a separate pass
  could act on.
- **No `arguments` blocks, no `inputParser`, no `validateattributes` anywhere.** Adding them is
  Tier C (it changes validation behaviour). Leave it. The long positional signatures —
  `pipeline/pair_responses.m:1` with 10 arguments, `+segmentation/content_features.m:1` and
  `+segmentation/content_dv_pair.m:1` with 9 — can only be improved *in the header doc* during
  this pass.

---

## 4. The style target already exists

Do not invent a style guide. The sibling `vislab-common/+vislab/` is the same author's cleaned
code and is the normative reference — and it is a closer reference here than in any other
project, because this repo calls `vislab.nat_stat_bayes.*` and `vislab.lib.*` on nearly every
page.

`vislab-common/+vislab/+lib/watson_otf.m` is the exemplar: `FUNCTION_NAME` summary line,
fully-qualified call signature, `Inputs`/`Output` blocks **with units**, a note on the domain
where the result is undefined, `See also`, then a body with descriptive names (`cutoff`,
`diffraction` rather than `u0`, `D`) and short end-of-line comments only where the *why* is
non-obvious.

Within this repo, `+segmentation/prep_grid.m` and `pipeline/pair_responses.m` are the closest
existing approximations — use them as the local model for what a finished file looks like, then
fix their names.

**Verified: no in-scope file shares a name with anything in `vislab-common` or in
`Bill's old code*/`.** So unlike `camouflage_detection` — where `+lib/ptch_norm.m` is a
superseded copy of a shared-library file and must not be cleaned — there is no
already-superseded-elsewhere trap here. Every in-scope file is the live copy.

Also worth adding while reading each package: a `Contents.m` for `+segmentation/` and `+gtr/`,
following `vislab-common/+vislab/+nat_stat_bayes/Contents.m`. This repo has none.

---

## 5. Renaming: three zones

The rename map is the pass's most valuable artifact and its main divergence risk, so build it
**first, once, repo-wide**, and commit it before touching any file.

1. **File-local variables — free.** Everything in the occurrence list above that does not cross
   a function boundary: `psz`→`patch_size`, `pimg`→`region_image`, `nsmp`→`n_samples`,
   `ngrps`→`n_groups`, `ptch`→`patches`, `c0`/`m0`→`target_contrast`/`target_mean`, `i`/`j`→
   `row`/`col` or a domain name, and the three `image` shadows. Because these are file-local,
   the `canon` check makes them completely safe — this is where most of the value is.
2. **Cross-file vocabulary — repo-wide, or not at all.** Two sub-vocabularies:
   - The `cfg` struct: **54 distinct `cfg.*` field paths** defined in `config.m` and read
     everywhere. Renaming any of them touches `config.m` plus every reader, and silently
     breaks any saved artifact or external script that builds a `cfg` by hand. Do it as its own
     tranche with its own whitelisted diff pattern, or defer it.
   - Function arguments that are named consistently across the repo (`ecc`, `itype`, `psz`,
     `dv`, `col`). Renaming these is high value precisely because they are everywhere — but
     for the same reason a half-done rename is worse than none. All-or-nothing per name.
3. **Serialised variable names — forbidden.** These are the names inside `.mat` files and must
   not change: `coeff`, `ea`, `Na`, `ptchn`, `ptchf`, `pcnt`, `color`, `bin_bounds`, `n_bins`,
   `eccs`, `dbnd`, `near`, `far`, `same`, `diff`, `same_brod`, `diff_brod`, `net`, `fcParams`,
   `lms`. Five shipped artifacts in `data/models/` depend on them
   (`AHEO_bins.mat`, `decision_bounds_ecc_1.mat`, `decision_bounds_ecc_1_color.mat`,
   `net_on_nat.mat`, `priors_abr_mo13_mo23_cs33_otf_ecc_1.mat`), as do the shared transforms in
   `vislab-common/data/`. The generated `data/stimuli/` files are regenerable, but the shipped
   models are not — they are the reason someone can run the demo without the 19 GB natural-image
   set. A local variable that *holds* one of these can be renamed; the string in the
   `save`/`load` call cannot.

   Note that `diff` appears on this list **and** in the builtin-shadow list. Inside
   `twin-net/texture_same_diff_patches_net.m:68` it is a save name and is frozen; the two other
   uses as a plain variable are free. Check which you are looking at.

**Units are the other half of naming.** State them in every header. The ones that matter:
`cfg.optics.ppd = 60` pixels/deg for *all* images (`config.m:28`), so `cfg.patch.size = 64`
pixels is a ~1-deg patch at eccentricity 1 and `cfg.patch.image_size = 640` is a ~10-deg GTR
image (`config.m:47-48`); `ecc` is an integer eccentricity *divisor*, not degrees — patch
geometry is divided by it (`config.m:46`); `cfg.optics.pupil_diameter` is mm and
`cfg.optics.wavelength` is nm (`config.m:32-33`); `cfg.dv.edge_thresh = 50` is a gradient
threshold in image units (`config.m:66`). The `psz` in a function signature is always pixels —
say so once per file rather than making the reader infer it 321 times.

---

## 6. Sequencing

The work is concentrated very differently from what the file count suggests: **18 files are
under 30 lines**, while the five files of ≥200 lines (`experiments/adaptive_hist_exp.m` 805,
`twin-net/train_net.m` 389, `demo/plot_stage1b_gradients.m` 284, `run_demo.m` 236,
`pipeline/s4_optimize_bins.m` 235) hold **34 % of all code**. Batch the small ones; budget real
time for the large ones.

Order (check off each step as it's completed):

- [x] **0. Build the rename map.** Write `canon.m`, the tier-A/B checker, and the bijection
      assertion. Capture golden outputs for Tier B on the entry points verified above
      (`segmentation.prep_grid`, `load_dv_handles`, `sample_demo_pairs`, `pair_responses`,
      `segmentation.content_similarity_matrix`), each under an explicit `rng(cfg.seed)`.
- [x] **1. `+segmentation/` (10 files, 622 lines) + `+gtr/` (2, 122).** Highest reuse, cleanest
      code, smallest files — this is where the rename conventions get established and where a
      mistake is cheapest to walk back. Add both `Contents.m` files here.
- [x] **2. `pipeline/` (21 files, 1449 lines).** The stage functions `s1`→`s7` plus their
      helpers. Clean the helpers before the stage files that call them, so the stage file's
      header can cite settled names.
- [x] **3. `demo/` (18 files, 1352 lines).** Plotting code; mostly independent of each other.
      Note the duplicated `local_show_pair` (`plot_stage3.m:43`, `plot_stage6_pairs.m:74`) —
      clean both copies **identically**, or you manufacture a divergence that a later merge has
      to untangle.
- [x] **4. `twin-net/` (11 files, 847 lines).** Do the camelCase→snake_case identifier
      unification as one decision applied across all 11 at once, not file by file.
- [ ] **5. Root: `config.m`, `setup.m`, `run_demo.m` (547 lines).** Last, because `config.m`'s
      field names are the zone-2 vocabulary every earlier tranche has been citing.
- [ ] **6. `experiments/adaptive_hist_exp.m` (805 lines).** Alone, last, and possibly not at
      all — it is untracked, it holds 62 of the repo's long lines, and it is exploratory.
      Decide whether it is being kept before spending a session on it.

One commit per tranche, or per ~10 files for the large ones, each stating the checker result.
Small commits matter here because the reviewer's only question per hunk is "could this have
changed a number?", and that is answerable only if the hunks are small.

**Housekeeping to do first, separately, before any of this:** `git status` currently shows
`demo/plot_stage8_natural-LA-CPSA96551WN.m` — a OneDrive filename-conflict copy — still in the
index though deleted on disk, alongside `demo/pair_responses.m` (moved to `pipeline/`) and
seven untracked new files. Resolve the index before starting, or the readability diff will be
impossible to read.

---

## 7. Which agent/model to run each step with

Default to **Sonnet, medium effort**, for the pass as a whole: the `isequal`-on-`canon` check is
what proves correctness, not the model's judgement, so there is little to buy by spending Opus
on routine files.

| Step | Model / effort | Why |
|---|---|---|
| 0. Rename map + `canon`/checker + golden harness | **Opus, medium** | Every other step trusts this being right; a bug here invalidates every downstream `isequal` result silently. The bijection assertion in particular is the one thing standing between a scope-blind regex and a false pass. |
| 1. `+segmentation/` + `+gtr/` | **Opus, medium** | Small, but this is where the naming conventions are set and where the cross-boundary divergence (`prep_grid`'s `Gn` vs `content_features`' `E`) has to be resolved once for the whole repo. |
| 2. `pipeline/` (21 files) | Sonnet, medium | Mechanical once the map exists. Watch the helper-before-caller ordering. |
| 3. `demo/` (18 files) | Sonnet, medium | Plotting code, no callers outside itself — except the duplicated `local_show_pair`, which must be cleaned identically in both files. Diff the two copies against each other afterwards. |
| 4. `twin-net/` (11 files) | Sonnet, medium | Mechanical, but the camelCase unification is one decision applied 11 times; if a Sonnet pass drifts between files, that is exactly the inconsistency this pass exists to remove. Spot-check all 11 together. |
| 5. Root three files | **Opus, medium** | `config.m` is the 54-field public vocabulary; `setup.m` does network installs; `run_demo.m` is the user-facing entry point. All three are read far more often than they are edited. |
| 6. `experiments/adaptive_hist_exp.m` | Sonnet, medium | One large exploratory file, no callers. |
| **Escalation rule, any step:** if a file's `isequal(canon(old), canon(new))` check fails and the cause is not obvious from the diff — **stop, do not retry with a bigger prompt, hand that one file to Opus at medium** (high only if Opus-medium also cannot explain the mismatch). Do not lower the bar by loosening the check instead. | | |

This table is the thing to consult before assigning each tranche, whether that is one session
working through the list in order or several agents working in parallel.

---

## 8. What "done" looks like

A tranche is finished when all of these hold:

- [ ] `isequal(canon(old), canon_with_renames_reversed(new))` is true for every Tier-A file in
      the tranche, and every Tier-B file's canonical diff matches a whitelisted pattern **and**
      reproduces its golden output bit-for-bit.
- [ ] Every file in the tranche has a header matching the `watson_otf.m` shape: summary line,
      fully-qualified call signature, `Inputs`/`Output` with **units**, `See also`.
- [ ] No line exceeds 100 characters.
- [ ] No identifier from the zone-3 frozen list has been renamed, and no `save`/`load` string
      literal has changed.
- [ ] Each package touched has a `Contents.m`.
- [ ] Bugs found are written down and **not fixed**.

---

## 9. Findings log (filled in during implementation)

### Step 0 — tooling

- `canon`/`check_tier_a`/`assert_rename_bijection` built in `tools/` and verified against the
  worked `prep_grid.m` example from section 1 — round-trips clean. MATLAB R2024b, confirmed at
  `/c/Program Files/MATLAB/R2024b/bin/matlab`.
- `tools/golden_harness.m` captures/replays all five entry points under `rng(cfg.seed)`. One thing
  the blueprint doesn't mention: `sum()` over a cell array from `cellfun` only collapses one
  dimension, so a naive checksum on a 2-D patch grid silently returns a row vector instead of a
  scalar — worth calling out since it would have made a real Tier-B diff look like a false match
  (a scalar-vs-vector `isequal` would still have caught it, but only by luck of shape, not value).
  Fixed with an explicit `'all'` reduction. Golden values for `cfg.seed=0`, `ecc=1`,
  256x256x3 synthetic image: `prep_grid` checksum `2.5339e+07`, `sample_demo_pairs` size
  `[64 128 3 7820]` (matches the blueprint's own reported number, cross-check passed),
  `pair_responses` checksum `2.2431e+05` with 7819/7820 pairs kept, `content_similarity_matrix`
  checksum `1.4421e+03`.
- Housekeeping (section 6) was narrowed to just the two files the blueprint names
  (`demo/plot_stage8_natural-LA-CPSA96551WN.m` deletion staged, `pair_responses.m` move staged) —
  the rest of `git status` is unrelated in-progress work (colour extension, Bill's revisions) and
  was left untouched.

### Step 1 — `+segmentation/` + `+gtr/`

All 12 files passed `check_tier_a` with file-local rename maps (see the tranche's own commit /
session log for the full per-file map); both `Contents.m` files added. Bugs/couplings surfaced
by close reading, **not fixed**, flagged for a separate pass:

- `+segmentation/group_patches.m:112` discards `assign_isolated_patches`'s third output
  (`ngrps`) and recomputes group growth separately in the caller — two code paths compute the
  same count for the same event; confirm they can't diverge.
- `+segmentation/neighbor_similarity_matrix.m` header asserts `cfg.gtr.power_suppress` and
  `cfg.dv.power_suppress` are "both 16 since Geisler unified b0" — nothing in code enforces this;
  editing one without the other would silently desync the border/content combination from
  `content_similarity_matrix.m`.
- `+segmentation/assign_isolated_patches.m:10-15` documents its own deliberate behaviour change
  from the original `iso_patch.m` (`i~=j` → `other_idx~=patch_idx`), already flagged in-file as
  changing the reproduced paper numbers — resurfaced here so it isn't missed in a skim.
- `+segmentation/merge_similar_regions.m` merges exactly one region pair per call by design;
  `group_patches.m` calls it once per pass, so there is no iterative multi-merge unless a caller
  loops it.

Naming decision made for this tranche (binding for later tranches that touch these functions):
`content_features.m`'s third parameter is named `edge_channel`, not `achrom_norm`, even though
its value often equals `prep_grid`'s `achrom_norm` output — its own header already documents that
the caller may pass either the raw or the contrast-normalized achromatic channel, so forcing the
same name as `achrom_norm` would assert something not always true. `psz`→`patch_size` and the
`image`-builtin-shadow fix were applied repo-wide within this tranche's 12 files; `cfg.dv.sd1
/nsd1/sd2/nsd2` local aliases were deliberately left as-is because they mirror `cfg.dv.*` field
names 1:1 and renaming only the local copy would introduce a mismatch — defer to the zone-2
`cfg` tranche (section 5.2) if that ever happens.

### Step 2 — `pipeline/` (21 files)

All 21 files passed `check_tier_a`; the golden harness (`tools/golden_harness.m`) was re-run in
replay mode against the untouched `tools/golden_ref.mat` afterward and still matches bit-for-bit
— direct runtime confirmation that this tranche changed nothing observable, on top of the
structural `canon` check. `psz`→`patch_size` applied throughout, matching tranche 1.
`pair_responses.m`'s parameters were renamed `nh`→`spot_llr_dims`, `ne`→`edge_llr_dims`,
`b0`→`power_suppress`, `thresh`→`edge_thresh`, `psz`→`patch_size` — this is now the settled
vocabulary for that concept repo-wide; the `demo/` tranche should reuse these same names for its
own local variables of the same meaning, for consistency (not required for correctness, since
MATLAB calls are positional, but avoids reintroducing a producer/consumer naming split).

Two lines could not be brought under 100 characters without a Tier-C change: `s4_optimize_bins.m
:49` and `s5_train_decision_vars.m:70`, both containing the identical 97-character error string
`'patch_pairs_ecc%d.mat does not match cfg.features.color=%d -- rerun
s23_learn_priors_and_pairs.'`. Splitting the string literal itself would change a single string
token into a horzcat expression in the AST, which `canon` would (correctly) flag as a real change
— so these two 110-character lines are left as a documented exception rather than forced under
the limit by weakening the check.

Bugs/inconsistencies noticed, **not fixed**:

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

### Step 3 — `demo/` (18 files)

**Important process note, worth recording for any future tranche:** this repo's working tree
already carried a large, legitimate, *uncommitted* "color extension" work-in-progress mixed into
`demo/` (and into some already-"finished" `pipeline/` files too) before this tranche started --
`cfg.features.color`, `cfg.features.dv_dims`, a `col` output threaded through
`compute_demo_responses`/`plot_stage5`/`plot_stage5_intermediate`/`run_demo.m`, `'color'` fields
added to `save`/`load` calls, a `bc_noshift`->`'bc'` value change in `plot_stage7.m` /
`plot_stage8_natural.m`, and a new `imresize(pimg, 0.5)` call, plus four new well-written files
(`overlay_region_boundaries.m`, `patch_to_rgb_display.m`, `plot_stage6_pairs.m`,
`sample_texture_pairs.m`). Confirmed with the user this is their own pre-existing feature work,
not something this pass should touch, question, or revert. The practical consequence: `git diff
HEAD` and `check_tier_a` against the last commit are **not valid verification baselines** for this
tranche, since HEAD predates that WIP -- comparing against it produces large false "diffs" that
are pre-existing content, not this tranche's edits. Verification instead used a pre-edit backup
copy of each file's current on-disk content (in the scratchpad), diffed against the post-edit
file with `check_tier_a`. Any later tranche touching a file with uncommitted pre-existing changes
should do the same rather than trusting a HEAD-relative diff.

All 18 files verified: 9 already had complete headers/renames from an earlier session and needed
only a final line-length pass (or no change); 9 needed line-length reflow this round
(`plot_stage2.m`, `plot_stage3.m`, `plot_stage5.m`, `plot_stage5_intermediate.m`, `plot_stage6.m`,
`plot_stage6_pairs.m`, `plot_stage7.m`, `plot_stage8_natural.m`, `sample_demo_pairs.m`). One line
could not be brought under 100 characters without turning a string literal into a horzcat
expression (a real AST change): `plot_stage6_pairs.m:87` (123 chars) -- documented exception,
same rationale as the two `pipeline/` exceptions from Step 2. `local_show_pair`
(`plot_stage3.m`/`plot_stage6_pairs.m`) confirmed byte-identical between both copies, including
its added `cfg` parameter (needed for `patch_to_rgb_display`, part of the pre-existing color WIP,
not a Tier-A rename). No frozen zone-3 name or `save`/`load` string literal was touched.

Bug found, **not fixed**:

- `plot_stage7.m`'s header documents `method` as `'nc'` or `'bc'`, but the code
  (`plot_stage7.m` and identically `plot_stage8_natural.m`) does
  `struct('nc', 'c_shft', 'ncb', 'bc').(method)`, which only has fields `nc` and `ncb` -- passing
  the documented `'bc'` value would error. Currently unreachable (`run_demo.m` only ever passes
  `'ncb'`), but the header disagrees with the code it describes.

### Step 4 — `twin-net/` (11 files)

CamelCase -> snake_case identifier unification applied as one consistent decision across all 11
files, verified against `git show HEAD:<file>` with `check_tier_a` (no pre-existing WIP
contamination in this tranche, unlike `demo/` -- `git status` showed only the unrelated
`net_plan.md` dirty beforehand). Representative renames: `psz`->`patch_size` (reusing the
tranche-1/2 name), `miniBatchSize`->`mini_batch_size`, `pairLabels`->`pair_labels`,
`learningRate`->`learning_rate`, `gradDecay(Sq)`->`grad_decay(_sq)`, `numIterations`->
`n_iterations`, `XVal1/2`/`YVal`/etc. snake-cased on the compound suffix only (kept the `X`/`Y`
math-convention capitals). File names and top-level function names are untouched (Tier C) --
`forwardTwin.m`, `predictTwin.m`, `poolStats.m`, `modelLoss.m`, `getTwinBatchPairs.m`,
`getTwinBatch_nat_live.m` keep their camelCase spelling since it must match the filename.
Deep Learning Toolbox name-value keys (`WeightsInitializer`, `DilationFactor`, etc.) are fixed API
and untouched.

**`fcParams` deliberately left untouched everywhere** (camelCase, including its own struct field
names `FcWeights`/`FcBias`): it's a zone-3 frozen name, saved into `data/models/net_on_nat.mat` at
`train_net.m:389` (`save(netfile,'net','fcParams')`). Checked every `save`/`load` call in the
tranche; only frozen names (`near`, `far`, `same`, `diff`, `same_brod`, `diff_brod`, `net`,
`fcParams`) ever appear as string literals, and none were renamed. `A_pool` was checked and is
*not* a save/load key anywhere in this tranche, so it isn't zone-3 frozen, but it was left as-is
anyway (already acceptable snake_case-with-domain-capital, parallel to `Na`/`ea`) since renaming
it wasn't needed for the camelCase->snake_case goal.

Zero lines over 100 characters after reflow -- no documented exceptions needed this time. No new
bugs found (the tranche's one pre-existing `NOPTS` lint hit in `train_net.m`, a missing semicolon
on a console-echoing line, is unchanged from the original; adding the `;` would be Tier B).
