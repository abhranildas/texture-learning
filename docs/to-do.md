# Repository to-do

Two things live here: bugs found while doing a Tier-A-only readability pass over the codebase
(found, not fixed), and the tracked status of Bill's 2026 code revisions.

## Bugs found during the readability pass (not fixed)

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

## Bill's 2026 revisions: what changed, what's already here, what's left

Bill revised his original working codebase (`Bill's old code/` → `Bill's old code - revised/`) and sent a six-point note describing the changes. This document:

1. **Section 1** — verifies each point against the actual code, and records the changes he *didn't* mention.
2. **Section 2** — a checklist of which changes are already in this refactored repo, with an executable blueprint under every pending item.
3. **Section 3** — whether anything lands in the sibling `texture-segmentation` repo.

Every claim below cites the file and line it came from. Line numbers in `Bill's old code/` and `Bill's old code - revised/` refer to those folders as shipped.

---

### Section 1 — What Bill changed

#### 1.0 Orientation: the file-level diff

| | Old | Revised |
|---|---|---|
| Discrimination | `self_sup_train_bnd_bc.m`, `self_sup_train_bnd_bc_shft.m`, `self_sup_train_bnd_c_shft.m` | **`self_sup_tex_discrim.m`** (one script) |
| Segmentation | `tex_grp_s_p_ms_SS_ncbm.m`, `tex_grp_s_p_ms_SS_ncm.m` | **`self_sup_tex_segment.m`** (one script) |
| DV training | `nat_near_far_dv_2.m` | same name, substantially extended |
| New core code | — | `Rb12.m`, `mk_phi_c.m`, `load_b0_nat.m`, `opt_b0_nat.m`, `test_b0_nat.m`, `find_border.m` |
| New non-core code | — | `pertex_resize.m`, `ave_LL_nat.m`, `plotbnds_all.m`, `self_sup_figs.m`, `sep_joined_plots.m`, `proximity_proxy_figs.m` |
| Changed helpers | — | `aply_otf.m`, `cdfs_of_features.m`, `iso_patch.m`, `mk_groups.m`, `mk_masks.m`, `mk_phi.m`, `opt_bins_nat.m`, `Rb.m`, `Re.m`, `Rh.m`, `test_bnds_nat.m`, `nat_near_far_patches.m` |

The four new flags appear only in the three driver scripts. They are declared at `self_sup_tex_discrim.m:51-54` and `self_sup_tex_segment.m:47-49`:

```matlab
contentflg = 1;  % 1 = use content for self-supervised learning
mutsimflg  = 1;  % 1 = use mutual similarity
borderflg  = 2;  % border cues: 0 = none, 1 = near & far, 2 = near only
centerflg  = 1;  % 1 = use center patch for border cues
```

---

#### 1.1 Two consolidated final routines — **confirmed**

`self_sup_tex_discrim.m` descends from `self_sup_train_bnd_bc.m` (379 inserted / 168 deleted lines); `self_sup_tex_segment.m` descends from `tex_grp_s_p_ms_SS_ncbm.m` (299 / 179). Both gained a header block documenting their outputs, and both replaced the ad-hoc `plotflg`/`shftflg`/`pltbnd` switches with the four named flags above plus `gtrflg` (`self_sup_tex_discrim.m:72`, `self_sup_tex_segment.m:50`).

Bill's consolidation is *not* the same as this repo's consolidation. This repo already merged the three discrimination variants into `s6_selfsup_discrimination` and the two segmentation variants into `s7_segment_gtr`, keeping each old variant reachable as a `method` string. Bill instead **dropped the old per-image learning rules** and replaced them with a single new one (see §1.4). So the *structure* matches; the *content of the learning step* does not.

---

#### 1.2 The third patch `ptch12`, centred on the border — **confirmed**

For each **neighbouring** pair, a third patch of the same size (`psz × psz`) is cut straddling the shared border, and the border cue is computed from it alone.

Geometry (`self_sup_tex_discrim.m:578, 638`), with `pszh = psz/2` (`:65`) and `x`,`y` the top-left corner of **patch 2**:

```matlab
% dir = 1 (patch2 below patch1):   rows straddle the border, cols follow patch2
ptch12 = pimg(x-pszh : x+pszh-1, y : y+psz-1, :);
% dir = 2 (patch2 right of patch1): cols straddle the border, rows follow patch1
ptch12 = pimg(x : x+psz-1, y-pszh : y+pszh-1, :);
```

It is then mean-normalized and rotated to ABR exactly like the two ordinary patches (`ptch_norm(..., ntype=3, ncolr=3)` then `rot`), and its achromatic channel `ptch12a` is passed to the **new** function `Rb12.m`:

```matlab
if centerflg == 0
  Rbout = Rb(ptch1a, ptch2a, psz, dir, sdg, nsdg, showflag);   % original: two patches
elseif centerflg == 1
  Rbout = Rb12(ptch12a, psz, dir, sdg, nsdg, showflag);        % new: one centred patch
end
rbn(scnt) = dvbfun(Rbout(1:2)');
```
(`self_sup_tex_discrim.m:612-617, 673-678`; `self_sup_tex_segment.m:592-596, 649-653, 913-918`.)

`Rb12.m` is `Rb.m` with three differences:

| | `Rb.m` (revised) | `Rb12.m` |
|---|---|---|
| Input | two `psz × psz` patches, joined internally to `2·psz` | one `psz × psz` border-centred patch |
| Border row index | `psz : psz+1` (`Rb.m:46`) | `pszh : pszh+1` (`Rb12.m:40`) |
| Off-border rows | `1:psz-1` and `psz+1:psz2` (`Rb.m:49-50`) | `1:pszh-1` and `pszh+1:psz` (`Rb12.m:43-44`) |
| Third output | `Rbout(3) = Rcc(ptch1,ptch2,0)` (`Rb.m:54`) | never set — stays 0 |

Both compute `Rbout(1)` = log ratio of horizontal to vertical steerable-filter energy at the border, and `Rbout(2)` = mean of that log ratio away from the border. Only `Rbout(1:2)` is consumed, so dropping `Rcc` is harmless here.

**Three details that matter for reimplementation:**

- **`ptch12` is *not* contrast-normalized.** The two ordinary patches are (`cntrst_norm`) before the border/edge cues; the corresponding line for `ptch12` is deliberately commented out (`self_sup_tex_discrim.m:668, 785`). So `centerflg = 1` feeds a non-contrast-normalized patch to the border DV where `centerflg = 0` feeds contrast-normalized ones.
- **Far pairs never use `ptch12`.** Distant pairs are not adjacent, so there is no border patch; `self_sup_tex_discrim.m:734, 790` call plain `Rb` unconditionally. `centerflg` therefore changes only the *near* pairs.
- **The border DV itself is still trained with two-patch `Rb`.** `nat_near_far_dv_2.m:125, 165` use `Rb`, never `Rb12`. So under `centerflg = 1` the bound `dbndb` is trained on one statistic and applied to a different one. **Worth asking Bill whether this is intended.**

---

#### 1.3 Two ways to learn border DVs (`borderflg`) — **confirmed**

Both live in `nat_near_far_dv_2.m`, and both bounds are saved, as Bill says.

**Way 1 (`borderflg = 1`, the original)** — `nat_near_far_dv_2.m:321-364`. Far pairs are the *spliced* pairs built by `nat_near_far_patches.m` (a reference patch joined to a distant patch). The border bound separates near from far:

```matlab
resultsb = classify_normals([rb1s(1:ns),rb2s(1:ns)], [rb1d(1:nd),rb2d(1:nd)], ...);
dbndb = resultsb.samp_opt_bd;                  % → dbndbNO<lev>.mat  (or dbndcbNO with colour)
% then border+content, also near-vs-far:
resultsbc = classify_normals([rcs,rbs], [rcd,rbd], ...);   % → dbndbcNO<lev>.mat
```

**Way 2 (`borderflg = 2`, new)** — `nat_near_far_dv_2.m:366-425`. The content DV is trained first (`dbndc`, `:295-311`), then applied to the **near pairs only**; near pairs whose content DV is positive become the "same" class and the rest the "different" class:

```matlab
for i = 1:ns
    rcs(i) = dvcfun([rps(i),rhs(i),res(i)]');
    if rcs(i) > 0                       % content says "same"
        hicnt = hicnt + 1;  rb1sh(hicnt) = rb1s(i);  rb2sh(hicnt) = rb2s(i);
    else                                % content says "different"
        locnt = locnt + 1;  rb1sl(locnt) = rb1s(i);  rb2sl(locnt) = rb2s(i);
    end
end
nm = min(hicnt, locnt);                 % balance the two classes
resultsb2 = classify_normals([rb1sh(1:nm),rb2sh(1:nm)], [rb1sl(1:nm),rb2sl(1:nm)], ...);
dbndb = resultsb2.samp_opt_bd;          % → dbndb2NO<lev>.mat (dbndcb2NO with colour)
```

The border+content bound is then retrained with the new border DV, but still near-vs-far (`:408-425` → `dbndbc2NO<lev>.mat`).

Rationale: way 1's far pairs are artificial splices, so the border cue can learn to detect the splice seam rather than a real texture border. Way 2 uses only genuine adjacent pairs and gets its labels from the (already trained) content DV.

`borderflg` is used **nowhere else** — in the driver scripts it only picks which `.mat` to load (`self_sup_tex_discrim.m:302-321`, `self_sup_tex_segment.m:308-325`, `find_border.m:270-287`). Note the saved variable is called `dbndb`/`dbndbc` in both files, so the loader is unchanged; only the filename differs. `borderflg = 0` loads the same files as `borderflg = 1` and only matters inside the `contentflg == 0` branch (§1.4).

---

#### 1.4 Content-only self-supervised learning (`contentflg`) — **confirmed, and it is the biggest change**

**What the old discrimination script did** (`self_sup_train_bnd_bc.m:658-694`): for every GTR image it *refit the whole border+content quadratic bound* on that image's own near/far pairs, then swept (criterion `gc`, mutual-similarity weight `wm`).

**What the revised script does** (`self_sup_tex_discrim.m:804-921`): no per-image bound fitting at all. The pre-trained `dvbcfun` is loaded once (`:326`), and the per-image step is a two-phase grid search.

*Phase 1* — sweep `(gc, wm)` using the **content-only** DV, and take the cell that maximizes near/far accuracy:

```matlab
if contentflg == 1
  qbn = rcn(i);  qbf = rcf(i);              % content only
elseif contentflg == 0 && borderflg > 0
  qbn = rbcn(i); qbf = rbcf(i);             % border + content (old behaviour)
elseif contentflg == 0 && borderflg == 0
  qbn = rcn(i);  qbf = rcf(i);              % no border cue available
end
...
[pcnfmx, I] = max(pcnf(:,:,trl), [], 'all');
[row, col]  = ind2sub(size(pcnf), I);
wmopt(trl)  = msmn + (col-1)*dms;
gcopt(trl)  = gcmn + (row-1)*dgc;
```
(`self_sup_tex_discrim.m:811-820, 869-872`.)

*Phase 2* — apply the pre-trained border+content DV at the learned `wmopt`, with the criterion shifted by a fixed offset:

```matlab
if contentflg == 1
  dgcopt = 1.1;                             %*******
  gcopt(trl) = gcopt(trl) + dgcopt;
  for i = 1:ncnt
    qbn = dvbcfun([rcn(i),rbn(i)]');
    qbf = dvbcfun([rcf(i),rbf(i)]');
    ... score against gcopt(trl), wmopt(trl) ...
  end
  pc1(trl) = (ncd+ncs)/(2*ncnt);            % all pairs
  pcn(trl) = (ncsn+ncdn)/(scntn+dcntn);     % near pairs only
end
```
(`self_sup_tex_discrim.m:875-921`.) The two summary numbers are `pcavmx0` (phase 1, content-only) and `pcavmx1` (phase 2, content+border) — exactly as the header block at `:19-22` describes.

So `contentflg = 1` means: **learn the grouping criterion and the mutual-similarity weight from content cues alone, then add the border cue afterwards** — which is Bill's note verbatim.

Two other differences in the same region: the `(gc, wm)` grid was widened from `0:0.4:4` to `0:0.8:16` in both axes (`self_sup_train_bnd_bc.m:391-394` → `self_sup_tex_discrim.m:397-404`), and a NaN guard was added to the content DV (`self_sup_tex_discrim.m:621-623`).

---

#### 1.5 Segmentation always uses `contentflg = 1` — **confirmed**

`self_sup_tex_segment.m:49` declares `contentflg = 1; % this is the default and currently the only option`, and the flag is never branched on. The self-supervised block unconditionally uses the content-only DV (`:796-797`):

```matlab
qbs = rcn(i);
qbd = rcf(i);
```

This replaces the old script's two-step "find the best `rbc` criterion `copt` by 1-D search, then optionally subtract it" logic (`tex_grp_s_p_ms_SS_ncbm.m:658-694`), which is gone. In its place is an explicit NaN sweep over `rbcn`/`rbcf` (`self_sup_tex_segment.m:779-789`) and a plain global argmax over the `(gc, wm)` surface (`:838-843`).

The border cue re-enters at the grouping step: `phi(i,j) = dvbcfun([rb, rc]')` (`self_sup_tex_segment.m:930-934`), and grouping runs at `gcopt + dgcg` with the offset swept (`:966`).

Sweep ranges also changed: merge criterion `mcmx` 1 → 1.4 (`:355`), mutual-similarity max 9.6 → 8 (`:352`), and the criterion offset from `0 : 0.25 : 2` to `-1.25 : 0.25 : 1.25` (`:359`).

---

#### 1.6 Mutual-similarity flag (`mutsimflg`) — **confirmed**

`self_sup_tex_discrim.m:400-404`:

```matlab
if mutsimflg == 1
  msmn = 0; dms = 0.8; msmx = 16; nms = (msmx-msmn)/dms + 1;
else
  msmn = 0; dms = 0.8; msmx = 0;  nms = (msmx-msmn)/dms + 1;   % no mutual sim
end
```

With `mutsimflg = 0` the weight grid collapses to the single value `wm = 0`, so only the criterion `gc` is estimated per image — exactly as Bill describes. It also suppresses the summary surface plots (`:933`). The flag exists **only** in the discrimination script.

---

#### 1.7 Changes Bill did not mention

These came out of the file-by-file diff. They are all real behaviour changes.

**Bug fixes**

| Fix | Where | Effect |
|---|---|---|
| `aply_otf` added the image mean back **twice** | `Bill's old code/aply_otf.m` vs revised `:25` | every OTF-filtered image had inflated DC |
| `Rb` off-border average used `/` (matrix least-squares) not `./` | revised `Rb.m:49-50` (`% probably should be ./ but was /`) | changes `Rbout(2)`, i.e. the border DV |
| `iso_patch` self-exclusion tested `i ~= j` (row vs column) instead of the isolated patch's own linear index | revised `iso_patch.m` (`i1 ~= i0`) | changes isolated-patch assignment in segmentation |
| `Re` used the 1st-derivative magnitude `gmb` where it needed the 2nd-derivative `gm2b` for patch b | revised `Re.m` (~`:156`) | changes the bar-feature count `n2`, hence that LLR |
| `cdfs_of_features` built the 5×5 centre-surround CDF from the 3×3 variable (`csl2` → `csl4`) | revised `cdfs_of_features.m` (~`:466`) | wrong bin bounds for feature 14 |
| `nat_near_far_patches` miscounted the Set-12 pair offsets (`pcnt10` → `pcnt9+pcnt10`) | revised `nat_near_far_patches.m:259-261` (`% this was miscounted`) | Set-12 pairs were mis-sliced |

**Feature-set and parameter changes**

- **Edge/bar DV features changed.** Old: `ne = [5,7,9,10]`, and the DV was fed only `ne(1), ne(3), ne(4)` = dims 5, 9, 10 (dim 7 was computed and silently skipped). New: `ne = [5,9,10,11]` and **all four** are fed to the DV (`self_sup_tex_discrim.m:227-228`, applied as `dvefun(log(Reout(ne(1:sze)))')` at `:610`). So dim 7 (edge mag × ori) is out and dim 11 (bar mag × ori) is in.
- **Power-suppression constant `b0` changed from 16 (or 10) to 5e-5.** Bill replaced the hardcoded value with a lookup, `bopt = load_b0_nat; b0 = bopt(lev);` (`self_sup_tex_discrim.m:219-220`, `self_sup_tex_segment.m:223-224`, `nat_near_far_dv_2.m:44-45`). `load_b0_nat.m` returns 5e-5 for every level. The new scripts `opt_b0_nat.m` + `test_b0_nat.m` are the calibration that produced it: a linear sweep of `b0` over `1e-5 : 1e-5 : 1e-4`, scoring each by `classify_normals` near/far error on the power feature alone.
- **Spot features enabled for colour.** `cstat`/`flist` changed from `[b,0,0,...]`/`[1,0,0,...]` to `[b,b,b,...]`/`[1,1,1,...]`, turning on the B and R chromatic dims, and the spot DV became two-stage (`dvhafun` on the achromatic dims, `dvhbfun` on the chromatic dims, combined by `dvhcfun`) — see `nat_near_far_dv_2.m:182-245` and `self_sup_tex_discrim.m:229-233, 591-599`. `mk_phi_c.m` is the colour twin of `mk_phi.m` for the all-pairs similarity matrix.
- **Outlier rejection changed from a magnitude window to a finiteness test.** Old: keep a pair only if every log response lies in `(-25, 25)`. New: reject only non-finite responses — `if max(isinf(red0)) == 1 || max(isinf(rhd0)) == 1 || isinf(rpd0)` (`nat_near_far_dv_2.m:131`), and the same substitution in `test_bnds_nat.m`.
- **`mk_phi` was parameterized.** Signature gained `ne, nh` (previously hardcoded inside) and a `if isnan(rc), rc = 0; end` guard.
- **`mk_masks` third argument renamed** `ntrl` → `nmaps` (pure clarity; arithmetic unchanged).
- **`nat_near_far_patches.m:31` sets `ppd = 64`** while every other revised script uses 60. This looks like a leftover, not a decision — flag it for Bill.

**New non-core files** — `pertex_resize.m` (one-off 1024→640 resize of the PerTex sheets), `ave_LL_nat.m` (LLR-histogram diagnostic), `find_border.m` (a border-localization prototype: it detects the border column by minimizing the *content* DV along each row; the border DVs it loads are never used in its trial loop), and four figure scripts (`plotbnds_all.m`, `self_sup_figs.m`, `sep_joined_plots.m`, `proximity_proxy_figs.m`) that mostly bar-chart hand-entered manuscript numbers.

---

### Section 2 — Checklist and blueprints for this repo

Legend: **[x]** already incorporated · **[~]** partially · **[ ]** pending. Blueprints follow each pending item. They assume you have read the file being edited and will match its existing docstring and naming style (see the conventions note at the end of this section).

At a glance:

| # | Change | Status | Retrain needed? | Files touched |
|---|---|---|---|---|
| 1 | Two consolidated final routines | **[x]** | — | — |
| 2 | The six bug fixes (§1.7) | **[x]** | — | — |
| 3 | Colour spot cues (two-stage spot DV) | **[x]** | — | — |
| 4 | `ptch12` / `centerflg` border-centred patch | **[ ]** | no | `vislab-common` (new `dv_border_center`), new `+segmentation/prep_border_grid`, `config`, `neighbor_far_responses`, `neighbor_similarity_matrix` |
| 5 | `borderflg = 2` border DV | **[ ]** | **s5** | `s5_train_decision_vars`, `load_dv_handles`, `config` |
| 6 | `contentflg` content-only learning | **[ ]** | no | `self_sup_decision`, `nearfar_score_grid`, `s6_selfsup_discrimination`, `config` |
| 7 | Segmentation always content-only | **[ ]** | no | `s7_segment_gtr` (needs item 6a) |
| 8 | `mutsimflg` | **[~]** | no | `config`, `s6`, `s7` (two lines each) |
| 9 | `b0` 16 → 5e-5 | **[ ]** | **s4 + s5** | `config`, new `experiments/optimize_power_suppress` |
| 10 | Edge DV dims → `[5 9 10 11]` | **[ ]** | **s4 + s5** | `config` only |
| 11 | Outlier rejection → finiteness | **[ ]** | **s5** | `pair_responses` |
| 12 | `find_border.m` prototype | **[ ]** | no | new `experiments/find_border` (optional) |
| 13 | NaN guard on the content DV | **[ ]** | no | `content_dv_pair` |

Items 4, 6, 7, 8 and 13 are additive and safe: with the new flags at their defaults every existing number is unchanged. Items 5, 9, 10 and 11 change the shipped artifacts in `data/models/` and so change published numbers — **get the user's explicit go-ahead before starting any of those.**

---

#### [x] 1. Two consolidated final routines

The project has two end products: a **discrimination** program (given two neighbouring patches of an image, decide whether they are the same texture) and a **segmentation** program (carve a whole image into texture regions). Bill had been keeping three slightly different copies of the first and two of the second, each copy an experiment he had wanted to try. He has now collapsed them into one script each.

Already done, independently. `pipeline/s6_selfsup_discrimination.m` merges the three `self_sup_train_bnd_*` variants behind `method ∈ {'bc','bc_shft','c_shft'}` (`s6_selfsup_discrimination.m:25-30`); `pipeline/s7_segment_gtr.m` merges the two `tex_grp_*` variants behind `method ∈ {'nc','ncb'}` (`s7_segment_gtr.m:34-35`). Shared machinery lives in `pipeline/neighbor_far_responses.m`, `pipeline/self_sup_decision.m`, `pipeline/nearfar_score_grid.m`.

*Caveat:* the consolidation is structural only. Bill's new per-image learning rule is a **new method**, covered by item 4 below.

---

#### [x] 2. Bug fixes from §1.7

While revising, Bill found six genuine mistakes in the old code — a doubled image brightness, a wrong division that silently averaged the wrong thing, a comparison that tested a row index against a column index, and so on — and corrected them. These are not new features; they are the old code doing the wrong arithmetic.

All six are already fixed here, most of them explicitly credited to Bill in July 2026:

| Fix | Where in this repo |
|---|---|
| OTF double mean | `vislab-common/+vislab/+lib/otf_filter.m:9-14, 47-49` (docstring names the bug) |
| `Rb` `./` | `vislab-common/+vislab/+nat_stat_bayes/dv_border.m:23-27, 56-57` |
| `iso_patch` self-index | `+segmentation/assign_isolated_patches.m:10-15, 59` |
| `Re` `gm2b` | structurally impossible now: `edge_features.m` takes **one** patch and derives `counts.n2` from `mag2` (`vislab-common/+vislab/+nat_stat_bayes/edge_features.m:37, 43`) |
| centre-surround `csl2`→`csl4` | `pipeline/finalize_priors.m:21` histograms `S.cs4`, fed by `sample_prior_features.m:66` (`cs_type = 4`) |
| Set-12 pair miscount | structurally impossible: `s23_learn_priors_and_pairs` runs one loop over `list_natural_images(cfg)` with no per-set index arithmetic |

Nothing to do.

---

#### [x] 3. Colour spot cues (two-stage `dvha`/`dvhb`/`dvhc`, `mk_phi_c`)

Originally the model only looked at light-and-dark ("achromatic") information. Bill's revision lets it also use the two colour channels — blue-yellow and red-green — when judging whether two patches match. He does it in two steps: judge on the achromatic information, judge on the colour information, then combine the two judgements.

Already done, and more cleanly than Bill's version — one code path instead of a duplicated `mk_phi`/`mk_phi_c` pair. `config(color)` derives `cfg.features.spot_achr_dims`, `spot_chrom_dims`, `spot_dims`, `dv_dims` from one flag (`config.m:106-114`); `s5_train_decision_vars` trains `dbnd.ha`/`dbnd.hb`/`dbnd.h` when colour is on (`s5_train_decision_vars.m:69-83`); and `load_dv_handles` composes them so `dv.h` has one signature either way (`load_dv_handles.m:11-16, 36-44`). Bounds are stored per-mode via `decision_bounds_filename`.

Nothing to do.

---

#### [ ] 4. `ptch12` / `centerflg` — border cues from a border-centred patch

When the model compares two side-by-side patches it uses two kinds of evidence. The **content** cue asks "do these two patches have similar statistics?". The **border** cue asks a different question: "is there an edge running right along the line where they meet?" — because a real texture boundary usually leaves one. Until now the border cue was measured by gluing the two patches together and looking at the seam. Bill's change instead cuts a **third patch of the same size, centred on that seam**, and measures the border cue from it alone. The point is that the seam then sits in the middle of the measurement window, with equal amounts of each texture on either side, instead of at the edge of two separately-normalized patches.

**Scope.** Three new pieces plus two wiring sites. No change to stage 5 or the patch-pair artifacts, because Bill trains the border bound with two-patch `Rb` regardless of `centerflg` (§1.2).

**Step 4a — new shared-library function.** Create `vislab-common/+vislab/+nat_stat_bayes/dv_border_center.m`:

```matlab
function border = dv_border_center(patch, patch_size, direction, sd, nsd, show)
```

Port `Bill's old code - revised/Rb12.m` line for line, but write it in the style of the neighbouring `dv_border.m`: same docstring layout (`% DV_BORDER_CENTER  One-line summary.`, usage line, prose, `% Inputs` / `% Output`), and use `vislab.lib.steerable_kernels(sd, nsd)` and vectorized `sum(abs(gh), 2)'` rather than the double `for` loop. Concretely:

- `border = zeros(1, 3);` and `pszh = patch_size / 2;`
- `if direction == 1, joined = patch; else, joined = patch'; end`
- `gh = conv2(joined, k_horiz, 'same'); gv = conv2(joined, k_vert, 'same');`
- `sum_h = sum(abs(gh), 2)'; sum_v = sum(abs(gv), 2)';`
- `border(1) = log(sum(sum_h(pszh:pszh+1)) / sum(sum_v(pszh:pszh+1)));`
- `av1 = mean(log(sum_h(1:pszh-1) ./ sum_v(1:pszh-1)));` `av2 = mean(log(sum_h(pszh+1:patch_size) ./ sum_v(pszh+1:patch_size)));` `border(2) = (av1 + av2) / 2;`
- Leave `border(3) = 0` and say so in the docstring (there is no cross-correlation for a single patch); keep the 1×3 shape so callers that slice `border(1:2)` are identical to `dv_border`'s.
- Docstring must state: "(Was Rb12.m.)" and note that `av2`'s range overlaps `border(1)`'s at index `pszh+1` — this reproduces the same overlap in `Rb.m`/`dv_border.m`, so keep it.
- Add the function to `vislab-common/+vislab/+nat_stat_bayes/Contents.m` alongside `dv_border`.

**Step 4b — new border-patch grid.** Create `+segmentation/prep_border_grid.m`, modelled directly on `+segmentation/prep_grid.m`:

```matlab
function [Bd, Br] = prep_border_grid(image, psz, cfg)
% PREP_BORDER_GRID  Prepare the border-centred patch for every neighbouring pair ONCE.
%   [Bd, Br] = segmentation.prep_border_grid(image, psz, cfg)
```

- `pszh = psz / 2; npx = size(image,1)/psz; npy = size(image,2)/psz;`
- `Bd = cell(npx-1, npy);` — the patch straddling the border between grid rows `gx` and `gx+1`. Window: `rows = gx*psz + (-pszh+1 : pszh); cols = (gy-1)*psz + (1:psz);`
- `Br = cell(npx, npy-1);` — the patch straddling the border between grid cols `gy` and `gy+1`. Window: `rows = (gx-1)*psz + (1:psz); cols = gy*psz + (-pszh+1 : pszh);`
- For each: `p = vislab.lib.ptch_norm(image(rows,cols,:), cfg.norm.target_mean, cfg.norm.target_contrast, 3, 3); p = vislab.nat_stat_bayes.apply_color_rotation(p);` and store `p(:,:,1)` (achromatic only — that is all `dv_border_center` needs).
- **Do not contrast-normalize.** Bill's code deliberately does not (§1.2). Say so in the docstring and cite `self_sup_tex_discrim.m:668`.
- Verify the window arithmetic against Bill's indices: for `dir = 1` his patch-2 top row is `x = gx*psz + 1`, and his window is `x-pszh : x+pszh-1`, i.e. `gx*psz + (-pszh+1 : pszh)`. Match.

**Step 4c — config flag.** In `config.m`, in the `% --- decision-variable computation params` block after `cfg.dv.contrast_normalize` (`config.m:69`):

```matlab
cfg.dv.border_center = false;  % true = border cue from a patch centred on the shared border
                               % (Bill 2026 centerflg=1, Rb12); false = the published two-patch Rb
```

Default `false` so existing results are untouched.

**Step 4d — wire into `pipeline/neighbor_far_responses.m`.** This is the delicate one, because **only near pairs get a border patch**.

- After the `prep_grid` call (`:42`), add `if cfg.dv.border_center, [Bd, Br] = segmentation.prep_border_grid(pimg, psz, cfg); end`
- Change the nested helper `pair_cb` (`:79-83`) to take the border patch (or `[]`) explicitly:

```matlab
function [rc, rb] = pair_cb(ra, ca, rb2, cb, dir, bpatch)
    rc = segmentation.content_dv_pair(CF{ra,ca}, CF{rb2,cb}, psz, b0, dv.h, dv.e, dv.c, nh, ne);
    if isempty(bpatch)
        border = vislab.nat_stat_bayes.dv_border(Gn{ra,ca}, Gn{rb2,cb}, psz, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
    else
        border = vislab.nat_stat_bayes.dv_border_center(bpatch, psz, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
    end
    rb = dv.b(border(1:2)');
end
```

- Update the three call sites in the double loop:
  - lower neighbour (`:54`): `pair_cb(i, j, i+1, j, 1, border_patch(Bd, i, j))`
  - right neighbour (`:60`): `pair_cb(i, j, i, j+1, 2, border_patch(Br, i, j))`
  - far pairs (`:68`): `pair_cb(i, j, x2, y2, 2, [])` — **always empty**
- Add a tiny local `function b = border_patch(C, r, c)` that returns `[]` when `~cfg.dv.border_center` (or when `C` is undefined) and `C{r,c}` otherwise. Guarding inside one helper keeps the loop readable and avoids `exist` checks.
- Extend the file's docstring with a sentence: near pairs use the border-centred patch when `cfg.dv.border_center` is true; far pairs always use the two-patch DV because they are not adjacent (cite `self_sup_tex_discrim.m:734`).

**Step 4e — wire into `+segmentation/neighbor_similarity_matrix.m`.** Every pair here is a neighbour, so the flag applies unconditionally.

- After the `prep_grid` call (`:29-30`), add the `prep_border_grid` call under the flag.
- Replace the `dv_border` call (`:57-58`) with a branch. Index the border cell by the **upper/left** patch of the pair, which is *not* guaranteed to be patch `i`:

```matlab
ra = min(patch_x(i), patch_x(j));   ca = min(patch_y(i), patch_y(j));
if cfg.dv.border_center
    if dir == 1, bp = Bd{ra, ca}; else, bp = Br{ra, ca}; end
    border = vislab.nat_stat_bayes.dv_border_center(bp, patch_size, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
else
    border = vislab.nat_stat_bayes.dv_border(E{patch_x(i),patch_y(i)}, E{patch_x(j),patch_y(j)}, ...
        patch_size, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
end
```

  The existing `dir` determination at `:50-54` assumes `j` is below or right of `i`; using `min` makes the border index correct either way. Do not change the `dir` logic itself.

**Step 4f — sanity check (no MATLAB run required from the agent; leave it for the user).** Note in the commit message that with `cfg.dv.border_center = false` every number must be bit-identical to before, and that turning it on changes `dv.b`/`dv.bc` inputs for near pairs only.

**Open question to raise with Bill:** the border bound is trained on two-patch `Rb` statistics but, with `centerflg = 1`, applied to `Rb12` statistics (§1.2). Should `s5_train_decision_vars` also train a centred-border bound? If yes, `pair_responses` can cut the centred window straight out of the joined near-pair tensor (columns `pszh+1 : pszh+psz`, which *is* real adjacent image content for near pairs) — but not out of the far-pair tensors, which are artificial splices.

---

#### [ ] 5. `borderflg = 2` — border DV trained on near pairs split by the content DV

The model gets its training labels for free from **proximity**: two patches that are next to each other in a photograph are probably the same texture, and two far-apart patches are probably different. That gives you "same" and "different" examples without anyone labelling anything.

The problem is how the "different" examples are built. To make a *pair* out of two far-apart patches you have to cut them out and glue them together — and that artificial join leaves a seam. So the border cue, whose whole job is to spot seams, can end up learning to spot the *fake* seam rather than a real texture boundary. Bill's new option avoids far pairs entirely: it uses only genuinely adjacent pairs, and takes their "same"/"different" labels from the content cue (which was trained first). Both versions of the border cue are kept, so you can switch between them.

**Scope.** Stage 5 gains two more bounds; `load_dv_handles` gains a selector. Nothing downstream changes, because the new bounds are exposed under the existing `dv.b` / `dv.bc` names.

**Step 5a — train the two extra bounds in `pipeline/s5_train_decision_vars.m`.** Insert after the existing `dbnd.bc` training (`s5_train_decision_vars.m:99-102`). The variables you need are already in scope: `near`, `far`, `col`, `content_near`, `content_far`, `dvc`, and the local helpers `train_bound` and `apply_dv`.

```matlab
% --- border variant 2 (Bill 2026 borderflg=2): split the NEAR pairs by the sign of the
%     content DV and train the border bound on that split, instead of near-vs-far. Far
%     pairs are artificial splices, so variant 1's border bound can learn the splice seam.
c_near = apply_dv(dvc, content_near);
c_far  = apply_dv(dvc, content_far);
hi = find(c_near > 0);            % content says "same"
lo = find(c_near <= 0);           % content says "different"
nm = min(numel(hi), numel(lo));   % balance the classes (Bill: nm = min(hicnt,locnt))
dbnd.b2 = train_bound(near(hi(1:nm), col.border), near(lo(1:nm), col.border));

dvb2 = quad2fun(dbnd.b2, 0);
bc2_near = [c_near, apply_dv(dvb2, near(:, col.border))];
bc2_far  = [c_far,  apply_dv(dvb2, far(:,  col.border))];
dbnd.bc2 = train_bound(bc2_near, bc2_far);   % still near-vs-far, per Bill
```

Notes for whoever writes this:
- **Class balancing: prefer the repo's mechanism over Bill's.** Bill balances by truncating both classes to `nm = min(hicnt, locnt)` rows. This repo's `train_bound` already passes `'samp_balance', true` to `classify_normals` (`s5_train_decision_vars.m:125-132`), which weights the two classes equally without discarding data. So the leaner version is `dbnd.b2 = train_bound(near(hi, col.border), near(lo, col.border));` with no `nm` truncation. Use that, and note the deviation from Bill in a comment. Keep the truncating version only if the user wants bit-comparability with Bill's numbers.
- `c_near`/`c_far` are new here; `content_near`/`content_far` (the 3-column feature matrices) already exist at `s5_train_decision_vars.m:90-91`, and `apply_dv(dvc, content_near)` is already computed inside `bc_near` at `:100`. Hoist that one expression into `c_near`/`c_far` and reuse it in both `bc_near`/`bc_far` and `bc2_near`/`bc2_far` rather than calling `apply_dv` four times.
- Keep the `[content, border]` column order in `bc2_*`. It must match `dbnd.bc`'s order, which `self_sup_decision.m:54` and `neighbor_similarity_matrix.m:61` rely on.
- Extend the function's docstring output list to mention `b2` and `bc2`.

**Step 5b — config flag.** In `config.m`, next to the new `cfg.dv.border_center`:

```matlab
cfg.dv.border_variant = 1;   % 1 = border bound trained near-vs-far (published);
                             % 2 = trained on near pairs split by the content DV (Bill 2026 borderflg=2)
```

**Step 5c — select in `pipeline/load_dv_handles.m`.** Replace `dv.b = quad2fun(dbnd.b, 0);` (`:47`) and the `load_bc` block (`:49-51`):

```matlab
switch cfg.dv.border_variant
    case 1, bfield = 'b';  bcfield = 'bc';
    case 2, bfield = 'b2'; bcfield = 'bc2';
    otherwise, error('load_dv_handles:badBorderVariant', ...
        'cfg.dv.border_variant must be 1 or 2 (got %d).', cfg.dv.border_variant);
end
if ~isfield(dbnd, bfield)
    error('load_dv_handles:missingBorderVariant', ...
        'Trained bounds have no field "%s" -- retrain stage 5.', bfield);
end
dv.b = quad2fun(dbnd.(bfield), 0);
if load_bc
    dv.bc = quad2fun(dbnd.(bcfield), 0);
end
```

Follow the error style already used for the spot-dim mismatch at `load_dv_handles.m:30-34`. Document in the docstring that `dv.b`/`dv.bc` are the *selected* variant, so `s6`/`s7` need no change.

**Step 5d — do not add a new artifact filename.** Bill made separate `dbndb2NO*.mat` files; here all bounds live in one `dbnd` struct, so `decision_bounds_filename` stays as it is. Existing artifacts in `data/models/` predate `b2`/`bc2` and will trigger the retrain error above — which is the intended behaviour, matching how the `spot_dims` mismatch is handled.

---

#### [ ] 6. `contentflg` — content-only self-supervised learning, border added afterwards

Two things are learned in advance from a big set of photographs and then frozen: how to read the content cue, and how to read the border cue. But two more things have to be settled **separately for each new image**, because they depend on that image: the *threshold* (how similar is similar enough to call two patches the same?) and the *weight on mutual similarity* (a third piece of evidence — two patches look alike if they relate to all the other patches in the image in the same way). These two are also learned from proximity, using the image's own near and far pairs.

The change is what evidence that per-image step is allowed to use. Previously it used content and border together. Now it uses **content alone** to pick the threshold and the weight, and the border cue is folded in only afterwards, with a small fixed nudge to the threshold. Bill also stopped re-fitting the content+border combination on each image, which the old code did — it now stays frozen from the photograph training.

**Scope.** One new `self_sup_decision` method, one new `nearfar_score_grid` output, and a second scoring phase in `s6`. This is the largest pending item; do items 4 and 5 first if you want them in the same run, but they are independent.

**Step 6a — new method in `pipeline/self_sup_decision.m`.** Add a `'c'` case to the `switch` (`self_sup_decision.m:21-48`) — content DV, no shift, no refit:

```matlab
case 'c'    % content-only: no per-image fitting at all (Bill 2026 contentflg=1, phase 1)
    qbs = nan_to_zero(R.rcn);
    qbd = nan_to_zero(R.rcf);
```

The `nan_to_zero` local already exists (`:59`) and matches Bill's guard at `self_sup_tex_discrim.m:621-623`. Add `'c'` to the method list in the docstring.

**Step 6b — near-only accuracy from `pipeline/nearfar_score_grid.m`.** Bill reports two phase-2 numbers: accuracy over all pairs (`pc1`) and over near pairs only (`pcn`, `self_sup_tex_discrim.m:919-920`). The scorer does not currently return the latter. Add a fifth output:

- Change the signature to `function [pc, pcs, pcd, pcnf, pcnear] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec)` and `deal(zeros(ngc, nms))` over five outputs.
- In the local `score` subfunction, add four counters alongside the existing ones — `ncsn` (near "same" called same), `ncdn` (near "different" called different), `scntn`, `dcntn` — and increment them only inside the two `same_near` branches (`:34-40`). Then `pcnear = (ncsn + ncdn) / (scntn + dcntn);`
- Document the new output. All existing callers use `[~,~,~,pcnf]` or the first four outputs, so they keep working unchanged — verify with a grep for `nearfar_score_grid` before finishing.

**Step 6c — criterion offset in `config.m`.** In the `% --- GTR images / segmentation experiments` block (`config.m:71-77`):

```matlab
cfg.gtr.criterion_offset = 1.1;  % added to the learned gcopt before applying the border+content DV
                                 % (Bill 2026 dgcopt; self_sup_tex_discrim.m:878)
```

**Step 6d — the two-phase run in `pipeline/s6_selfsup_discrimination.m`.**

1. Add `'c'` to `mustBeMember` (`:25`) and a `mp` entry (`:26-30`) with Bill's settings: `case 'c', mp = struct('pd',4,'itype',3,'dgc',0.8,'gcmx',16,'dms',0.8,'msmx',16,'load_bc',true);` Note `gcmx`/`msmx` are 16, not 8 — Bill widened the grid (§1.4).
2. Preallocate phase-2 storage before the trial loop: `[pc1, pcn, gcopt, wmopt] = deal(zeros(ntrl, 1));`
3. Inside the trial loop, after the existing `nearfar_score_grid` call (`:64-65`), add the phase-2 block gated on the method:

```matlab
if strcmp(method, 'c')
    % phase 1 gave the best (gc, wm) from content alone; phase 2 applies the trained
    % border+content DV at that operating point, with a fixed criterion offset.
    [~, idx]   = max(pcnf(:,:,trl), [], 'all', 'linear');
    [row, cl]  = ind2sub([ngc, nms], idx);
    gcopt(trl) = gc_vec(row) + cfg.gtr.criterion_offset;
    wmopt(trl) = wm_vec(cl);
    [qbc_n, qbc_f] = self_sup_decision('bc_noshift', R, dv);
    [p, ~, ~, ~, pnear] = nearfar_score_grid(qbc_n, qbc_f, R, gcopt(trl), wmopt(trl));
    pc1(trl) = p;  pcn(trl) = pnear;
end
```

   Passing scalar `gc_vec`/`wm_vec` makes `nearfar_score_grid` return 1×1 values, so no new scoring code is needed. `'bc_noshift'` is exactly Bill's `dvbcfun([rcn,rbn]')` with no shift (`self_sup_decision.m:35-37`, `self_sup_tex_discrim.m:882-883`).

4. After the loop, add the summary fields, named after Bill's variables so his note maps onto them:

```matlab
if strcmp(method, 'c')
    out.pcavmx1 = mean(pc1);    % content+border at the content-learned operating point
    out.pcnavmx = mean(pcn);    % same, near pairs only
    out.gcopt = gcopt;  out.wmopt = wmopt;
end
```

5. Update the function docstring: list `'c'` with a one-line description of the two phases, and cite `self_sup_tex_discrim.m:804-921`.

---

#### [ ] 7. Segmentation always content-only

The segmentation program does the same per-image learning step as item 6 before it starts grouping patches into regions. Bill made it use content-only there too — and unlike the discrimination program it has no switch: that is now simply how it works. The border cue still matters, but only later, when deciding which neighbouring patches to join.

**Depends on item 6a** (the `'c'` method). Once that exists this is small.

**Step 7a — new method token in `pipeline/s7_segment_gtr.m`.** Extend `mustBeMember` (`:34`) and the dispatch table (`:35`):

```matlab
mustBeMember(method, {'nc', 'ncb', 'c'});
ss_method = struct('nc','c_shft', 'ncb','bc', 'c','c').(method);
```

Docstring entry: `'c' - content-only self-supervised learning; the border cue enters only at the grouping step (Bill 2026 self_sup_tex_segment.m default).` Consider making `'c'` the default (`:30`) once the user has compared it against `'ncb'` — **ask first, do not change the default unprompted.**

**Step 7b — sweep ranges under the new method.** Bill widened three sweeps (§1.5). Keep the published ranges for `'nc'`/`'ncb'` and use Bill's for `'c'`, replacing the four hardcoded vectors at `s7_segment_gtr.m:53-57`:

```matlab
gc_vec = 0 : 0.8 : 8;                       % grouping criterion (unchanged)
if strcmp(method, 'c')
    wm_vec  = 0 : 0.8 : 8;                  % Bill 2026: was 9.6
    mc_vec  = 0 : 0.2 : 1.4;                % Bill 2026: was 1
    dgc_vec = -1.25 : 0.25 : 1.25;          % Bill 2026: was 0 : 0.25 : 2
else
    wm_vec  = 0 : 0.8 : 9.6;
    mc_vec  = 0 : 0.2 : 1;
    dgc_vec = 0 : 0.25 : 2;
end
cc_vec = 1.1;
```

**Step 7c — no change to the argmax.** Bill switched to a single global `max(pcnf, [], 'all')` (`self_sup_tex_segment.m:838-843`). The repo's nested `max` (`s7_segment_gtr.m:79-82`) finds the same cell; only tie-breaking differs. Leave it, and add a one-line comment saying so.

---

#### [~] 8. `mutsimflg` — force the mutual-similarity weight to zero

"Mutual similarity" is the extra piece of evidence described in item 6: two patches count as alike if they relate to every *other* patch in the image in the same way. Bill added a switch that forces its weight to zero, so the model ignores it and the per-image learning step has only the threshold left to settle. It is there to measure how much mutual similarity is actually buying you.

Achievable today by editing `wm_vec`, but there is no flag. Two small edits.

**Step 8a — config.** In the `cfg.gtr` block of `config.m`:

```matlab
cfg.gtr.use_mutual_similarity = true;   % false = force wm = 0, so only the criterion is learned
                                        % per image (Bill 2026 mutsimflg = 0)
```

**Step 8b — apply it.** Immediately after `wm_vec` is built, in both stages (`s6_selfsup_discrimination.m:50` and `s7_segment_gtr.m:54`):

```matlab
if ~cfg.gtr.use_mutual_similarity, wm_vec = 0; end
```

Then `nms = numel(wm_vec)` is 1 and everything downstream (`nearfar_score_grid`, `wmopt`, `mu = phi + wmopt*rho`) already handles it — `wmopt` becomes 0, so `mu` reduces to `phi`. No other change needed. Mention the flag in both docstrings.

---

#### [ ] 9. Power-suppression constant `b0`: 16 → 5e-5

One ingredient of the content cue compares the two patches' **spatial-frequency power spectra** — how much coarse versus fine structure each contains. That comparison needs a small constant to stop it blowing up where a patch has almost no power at some frequency. The old value, 16, was a reasonable guess. Bill wrote a short script that simply tries a range of values and keeps whichever one best separates near from far pairs, and it came out roughly 300,000 times smaller: 0.00005. So the constant is now measured rather than assumed.

**Behaviour-changing and invalidates the shipped artifacts.** Do not do this without the user's explicit go-ahead — it requires re-running stages 4 and 5, and it changes every published number.

**Step 9a — collapse to one field and change the value.** `config.m` currently has the same constant twice: `cfg.dv.power_suppress = 16` (`:65`) and `cfg.gtr.power_suppress = 16` (`:77`), the second documented as "matches" the first. Delete `cfg.gtr.power_suppress`, point its three readers at `cfg.dv.power_suppress` (`neighbor_far_responses.m:29`, `neighbor_similarity_matrix.m:24`, and the note at `neighbor_similarity_matrix.m:19-21`), and set:

```matlab
cfg.dv.power_suppress = 5e-5;   % weak Fourier-power suppression (beta). Bill 2026 replaced the
                                % hardcoded 16 with load_b0_nat, which returns 5e-5 at every level.
```

Bill's `load_b0_nat.m` returns the same value for all levels, so no per-eccentricity table is needed — a scalar in `config.m` is the right home and there is no reason to port `load_b0_nat.m` itself.

**Step 9b — port the calibration script.** Bill's `opt_b0_nat.m` + `test_b0_nat.m` are how 5e-5 was derived, so the repo should be able to reproduce it. Put it in `experiments/` (which already holds exploratory scripts), not `pipeline/` — it is a one-off calibration, not a stage. Suggested single file `experiments/optimize_power_suppress.m`:

- Load `data/stimuli/patch_pairs_ecc<ecc>.mat` (`ptchn`, `ptchf`, `pcnt`) the way `s4_optimize_bins.m` does.
- For each candidate `b0` in `1e-5 : 1e-5 : 1e-4`: compute `log(vislab.nat_stat_bayes.dv_power(a1, a2, b0, psz))` for every near and far pair (split the joined tensor as in `pair_responses.m:40-43`), drop non-finite values, then `err = classify_normals(vrn, vrf, 'input_type','samp','plotmode',0).samp_opt_err`.
- Report the minimizing `b0` and `1 - err`, and plot accuracy vs `b0`.
- Reuse `pair_responses` if it can be made to return just the power column cheaply; otherwise a short local loop is fine — do not duplicate the whole response machinery.

**Step 9c — retrain and re-ship.** Run `s4_optimize_bins` then `s5_train_decision_vars` for every eccentricity and both colour modes, and note in the changelog that `data/models/*` no longer matches the preprint.

---

#### [ ] 10. Edge/bar DV features: `[5 9 10]` → `[5 9 10 11]`

Part of the content cue describes each patch by how many edges and bars it contains and at what strengths and orientations. There are several such measurements to choose from, and only some are fed to the model. Bill swapped the choice: he dropped one first-derivative ("edge") measurement and added the matching second-derivative ("bar") one. In the old code that dropped measurement was in fact computed and then silently ignored, so this change also tidies up a loose end.

**Also behaviour-changing; also needs a stage-4 + stage-5 retrain.** Get the user's go-ahead.

The good news is that the plumbing already supports dim 11:

- `edge_features` computes it (`vislab-common/+vislab/+nat_stat_bayes/edge_features.m:51`: `vals{11} = mag2(:) .* ori2(:)`).
- The priors already contain its CDF (`finalize_priors.m:18` saves `Nmo2`/`emo2`), and `s4_optimize_bins`'s `prior_for_dim` already maps `case 11` to it (`s4_optimize_bins.m:160`).

**Step 10a — one config edit.**

```matlab
cfg.features.edge_dims    = [5 9 10 11];  % Bill 2026: dim 7 out, dim 11 (bar mag x ori) in
cfg.features.edge_dv_dims = [5 9 10 11];  % Bill 2026 feeds all four to the edge DV
```

Note that `cfg.features.edge_dims` is currently **dead** — a repo-wide grep shows only `edge_dv_dims` and `dv_dims` are read. Either update both for consistency or delete `edge_dims`; do not leave it stale.

**Step 10b — retrain.** `cfg.features.dv_dims` is derived (`config.m:114`), so `cstat`/`feature_list` pick up dim 11 automatically everywhere. But `data/models/AHEO_bins.mat` has no bin bounds for dim 11 yet, so run `s4_optimize_bins(cfg, cfg.features.dv_dims, ecc, true)` before `s5_train_decision_vars`. Confirm the bin-bounds artifact grew a dim-11 row and that dim 7's row is simply left unused (`s4` does a read-modify-write per dim, so stale rows are harmless).

---

#### [ ] 11. Outlier rejection: magnitude window → finiteness test

When the model is trained on photograph patch pairs, a few pairs produce wild numbers and get thrown out. The old rule threw out any pair whose measurements fell outside ±25 — an arbitrary cutoff that also discarded perfectly valid extreme cases. Bill's new rule throws out only pairs whose numbers are genuinely undefined or infinite, and keeps everything else however large.

Small, but it changes which training pairs survive.

`pipeline/pair_responses.m:26, 55-56` currently keeps a pair only if every spot/edge/power LLR lies in `(-25, 25)`:

```matlab
lo = -25; hi = 25;
...
check = [rh, re, rp];
if all(check > lo) && all(check < hi)
```

Bill's revised rule (`nat_near_far_dv_2.m:131`) keeps everything finite:

```matlab
if all(isfinite(check))
```

Blueprint: replace the two lines, delete the now-unused `lo`/`hi`, and update the docstring sentence "Drops outlier pairs (|.| >= 25 in the spot/edge/power LLRs)" (`pair_responses.m:7`) to describe the new rule, citing Bill's file. Then grep for `-25`/`25` elsewhere in `pipeline/` and `demo/` — the same window may appear in a demo response helper and should change together or be left alone deliberately. This also requires a stage-5 retrain to take effect, so bundle it with items 9 and 10.

---

#### [ ] 12. `find_border.m` — border-localization prototype

A new sketch of a different question. Instead of asking "are these two patches the same texture?", it asks "**where** is the boundary?": it builds a test image made of two textures joined at a random column, slides along each row comparing neighbouring patches, and calls the position of *least* similarity the boundary. It is exploratory — it loads the border cue and then never uses it, judging purely on content.

Not present here in any form. It is a **prototype, not a pipeline stage**: it builds a composite image split at a random column, computes the content DV for every adjacent pair along each row, and calls the column of minimum content DV the border. Notably it loads the border DVs and never uses them.

Blueprint (low priority — ask the user whether they want it at all): port it as `experiments/find_border.m`, reusing `segmentation.prep_grid` + `segmentation.content_features` + `segmentation.content_dv_pair` instead of Bill's per-pair recomputation, and `load_dv_handles` instead of his eight `load`/`quad2fun` blocks. Drop the unused border-DV loading, or actually use it and say so.

---

#### [ ] 13. NaN guard moved from `rho` to the content DV

Occasionally a patch comparison comes out undefined (MATLAB's `NaN`) — say, when a patch is perfectly uniform. If that value is left alone it spreads: the mutual-similarity step averages every patch against every other, so one undefined comparison contaminates a whole row and column. The old code mopped this up late, at the mutual-similarity stage. Bill moved the fix upstream, catching it the moment a single patch comparison goes undefined and treating it as "no evidence either way".

Small, cheap, and it changes which pairs are usable. Bill made two matched edits:

- **Added** `if isnan(rc), rc = 0; end` to the content similarity, in both `mk_phi.m` and `mk_phi_c.m`, and to the per-pair content DV in the discrimination script (`self_sup_tex_discrim.m:621-623`).
- **Removed** the old blanket `rho(isnan(rho)) = 0;` from the segmentation script (present in `tex_grp_s_p_ms_SS_ncbm.m`, gone from `self_sup_tex_segment.m`) — i.e. he moved the guard upstream, from the mutual-similarity matrix to the quantity that actually goes NaN.

In this repo neither guard exists. A repo-wide grep for `isnan` finds hits **only** in `pipeline/self_sup_decision.m` (`:39-40, 56, 59, 64`); `+segmentation/` has none at all, so a NaN in one patch pair propagates into `phiall`, then through `segmentation.mutual_similarity` into a whole row and column of `rho`.

Blueprint:

1. In `+segmentation/content_dv_pair.m`, after `rc = dv_c([rp, rh, re]');` (`:24`): `if isnan(rc), rc = 0; end` — with a comment citing Bill's `mk_phi.m` guard and noting that this is the single choke point through which both `content_similarity_matrix` and `neighbor_similarity_matrix` compute content similarity, so guarding here covers both.
2. Do **not** add a guard inside `segmentation.mutual_similarity` — that is exactly the placement Bill moved away from. If you want a safety net, add an assertion/warning there instead of silently zeroing.
3. Update `content_dv_pair`'s docstring output line to say a non-finite content DV is returned as 0.

This needs no retraining — it only affects stages 6 and 7 at run time.

#### Not porting

- `pertex_resize.m` — already covered by `cfg.textures.pertex.resize = true` (`config.m:58`), applied during texture ingestion.
- `plotbnds_all.m`, `self_sup_figs.m`, `sep_joined_plots.m`, `proximity_proxy_figs.m` — manuscript figures built from hand-entered numbers. `demo/` covers the equivalent plots from live data.
- `ave_LL_nat.m` — a diagnostic, and it does not actually branch on its `dim` argument (it always computes gradient magnitudes), so porting it as-is would carry that defect over.
- `mk_masks` `ntrl` → `nmaps` rename — the refactored `gtr.grow_region_masks` already uses a clear parameter name.
- `mk_phi`'s `ne`/`nh` parameterization — already the case here: `content_similarity_matrix.m:29` and `neighbor_similarity_matrix.m:25-26` read the dims from `cfg` and pass them to `content_dv_pair` explicitly. (Its NaN guard is a separate pending item — see item 13.)

#### Conventions to follow

Taken from the existing code, so new files look native:

- Filename == function name, `lower_snake_case`. Pipeline stages are `sN_...`; shared sub-algorithms go in `+gtr/` or `+segmentation/`; genuinely shared low-level maths goes in `vislab-common/+vislab/`.
- Docstring: `% FUNCTION_NAME  One-line summary.`, then the usage line, then prose (citing the original file as "(Was `<old_name>.m`.)" and the paper symbol where there is one), then `% Inputs` / `% Outputs` itemized. See `pipeline/s5_train_decision_vars.m:1-38`.
- `cfg` is the first argument everywhere; no globals. Stage-specific overrides mutate a local copy of `cfg` (`s6_selfsup_discrimination.m:35`).
- Positional arguments, not option structs. Optional trailing args use `if nargin < k || isempty(x), x = default; end`. String enums use `mustBeMember` plus a `struct(...).(name)` dispatch.
- Filenames for artifacts are built in exactly one place (`prior_filename.m`, `decision_bounds_filename.m`).
- Expensive per-patch work is done once and cached (`prep_grid`, `content_features`); pairwise functions only combine cached results. `prep_border_grid` in item 4 follows this deliberately.
- Response-matrix columns are addressed through the `col` struct from `pair_responses`, never by hardcoded index.
- Inline comments flag provenance and open questions: `(Geisler-confirmed ...)`, `(was <old>.m)`, `flagged for Geisler`. Use the same idiom for anything ported here, and cite the revised file and line.

---

### Section 3 — The sibling `texture-segmentation` repo

**None of Bill's six changes land there.** That repo holds the Hierarchical Bayesian Observer model plus the Psychtoolbox psychophysics, not the proximity self-supervised learner.

Evidence from a full survey of `../texture-segmentation`:

- **The flags do not exist.** `borderflg`, `contentflg`, `mutsimflg`, `centerflg`, `ptch12`, `pszh`, `wmopt`, `phiall`, `dbnd` — zero matches, repo-wide.
- **There is no border/content decision-variable split.** No `Rb`-equivalent, no `dvb`/`dvc`/`rbc`, no mutual similarity of any kind.
- **There is no self-supervised learning.** `+general/simulate_discrimination.m` fits ideal-observer bounds with `classify_normals` in one shot, and `texture_grouping.m` (repo root) hardcodes a single fixed quadratic (`q2`,`q1`,`q0`, `texture_grouping.m:78-81`). No training loop, no learned weights. Its README states the learned-model work lives in this repo instead.
- **The legacy grouping routines are absent.** `mk_groups.m`, `merge_groups.m`, `reg_count.m`, `mk_phi.m`, `find_bnd.m`, `plotbnds.m` — none present. `texture_grouping.m` is a much simpler stand-in: pairwise power + histogram responses, one threshold, one same-link-ratio pass. No mutual similarity, no transitive/confidence/region stages.
- **The same-named files are unrelated.** `+grouping/mk_masks.m` and `+grouping/mk_texs.m` generate *trial stimuli*, not segmentation masks. `+grouping/mk_dist.m`, `mk_decc.m`, `mk_mecc.m` build purely geometric all-pairs matrices (distance, eccentricity), not content similarity.

**The one genuine cross-repo point is `vislab-common`, not `texture-segmentation`.** Both repos load the shared `+vislab` package (`texture-segmentation/setup.m:35-38`, `texture-learning/setup.m` "shared lab library" block), and the border decision variable lives there (`vislab-common/+vislab/+nat_stat_bayes/dv_border.m`). So **item 4a — the new `dv_border_center.m` — is a `vislab-common` change**, and it becomes visible to `texture-segmentation` automatically even though nothing there calls it today.

Two adjacent things the survey turned up that are *not* Bill's changes but are worth knowing, since they touch the same shared code:

- `texture-segmentation` still carries its own copies of decision variables that `vislab` now owns: `+lib/power_dv.m` and root `Rp_win.m` (both power), `+lib/hist_dv.m` (spot histogram), root `Re.m` (edge). Consolidating these into `vislab` would be the natural companion to the work above, but it is a separate task.
- `texture_grouping.m:73` calls a bare, unqualified `Rh(...)` that does not resolve in scope — a pre-existing dangling reference its own README already flags. Not ours to fix here, but do not be confused by it when comparing the two repos.
