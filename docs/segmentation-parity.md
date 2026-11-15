# GTR segmentation: why it differs from Bill's code, and how to fix it

**Reference used throughout:** Bill's newest code, `Bill's code/texture-learning-newer/GTRdiscsegm/`
(`GTR_segment.m`, `self_sup_tex_segm.m`, `ss_segm.m`, `test_ss_segm.m`). Below, "Bill" means that folder.

## 1. Diagnosis

### 1.1 Main cause: the demo never uses fixed grouping parameters

Bill's workflow has two separate steps:

1. **Choose parameters once.** `GTR_segment.m` runs `self_sup_tex_segm` on all 6 texture sets, 120 images each
   (10 seeds × 12 images, `rng(seed-1)`). It sweeps the grouping offset $g_l$ and the region-merge criterion
   $g_r$. It averages the **mean number of correctly segmented regions** over the 6 sets and takes the best cell
   (`GTR_segment.m:52-56`). The result is saved as `gl, gr, gcc`.
2. **Segment with those fixed values.** `test_ss_segm.m:28` loads them, and `ss_segm.m:710` groups each image
   at `gcopt + gl`, with confidence criterion `gcc` and merge criterion `gr`.

The paper says the same thing (paper §"three parameters … learned by maximizing average segmentation
accuracy over all six kinds of GTR image").

Bill's saved choices (read from his `.mat` files):

| File | flags `[lev content mutsim border center color otf]` | $g_l$ | $g_c$ | $g_r$ | mean regions correct |
|---|---|---|---|---|---|
| `seg_11_8_26_1_1` (loaded by `test_ss_segm`) | `[1 0 1 1 1 0 1]` | **−0.25** | **1.2** | **0.8** | 72.3% |
| `seg_11_8_26_1_3` | same | 0 | 1.0 | 0.8 | 72.2% |
| `seg_10_31_26_1_1` (before the `[rc,rb]` order fix) | same | 0.5 | 1.2 | 0.8 | 71.9% |
| Published PDF, Fig. 6 caption | — | 2.4 (absolute) | 0.6 | 0.8 | — |

This repo does neither step:

- `s7_segment_gtr` sweeps merge × offset on the **same images** it scores, and reports the peak
  (`s7_segment_gtr.m:107-119, 133`).
- The demo runs that sweep on **2 images** (`run_demo.m:235`). With 2 images every cell scores 0, 0.5 or 1,
  so the argmax is mostly a tie. MATLAB then returns the first tied cell: the lowest merge, then the lowest offset.
  If both images fail everywhere, that is merge = 0, offset = 0.
- `plot_stage7.m:19-22` and `plot_stage8_natural.m:36-39` reuse that noisy argmax on **new** images.
- The objective is different too: the repo maximizes the fraction of fully correct images (`nregs5_ave`);
  Bill maximizes the mean number of correct regions (`mnregs`).
- The swept ranges cannot even reach Bill's values: offset is `0:0.25:2` (`s7_segment_gtr.m:75`), so
  −0.25 is excluded; confidence is fixed at 1.1 (`:74`), not 1.2.

### 1.2 Per-image learning step differs

| | Bill (`ss_segm.m`) | This repo (`s7`, method `'ncb'`) |
|---|---|---|
| Per-image DV | pre-trained border+content DV, NaN → 0 (`contentflg=0, borderflg=1`, `:543-552`) | **refits** the border+content bound on each image with `classify_normals` (`self_sup_decision.m:35-42`) |
| $g$ grid | `0:0.8:16` (`:231`) | `0:0.8:8` (`s7:71`) |
| $w_m$ grid | `0:0.8:16` (`:234`) | `0:0.8:9.6` (`s7:72`) |
| Argmax tie-break | first in column order: smallest $w_m$, then smallest $g$ (`:594`) | smallest $g$, then smallest $w_m$ (`s7:97-100`) |

Bill's per-image rule already exists here as `self_sup_decision`'s `'bc_noshift'` branch, but `s7` never calls it.
Ties are common, because accuracy is a count over 324 pairs on a 21 × 21 grid. So the tie-break changes
`gcopt`, and that moves the grouping threshold.

### 1.3 The model itself differs (affects every DV value)

| | Bill | This repo |
|---|---|---|
| Power suppression $b_0$ | 5e-5 (`load_b0_nat`) | 16 (`config.m:66, 79`) |
| Edge DV dims | `[5 9 10 11]` (`ss_segm.m:82`) | `[5 9 10]` (`config.m:103`) |
| Border cue | patch centred on the border, `Rb12` (`centerflg=1`) | two-patch `dv_border` |
| Shipped bounds | `dbnd*NO1.mat` | `data/models/decision_bounds_ecc_1_otf.mat` |

The shipped bounds really do differ. The content bound offset is −4.23 here and −0.17 in Bill's `dbndcNO1`.
The border and border+content bounds are close. So the DV scale is different, and a criterion offset tuned
on one model does not carry over to the other. These are pending items 4, 9 and 10 in `docs/to-do.md`.

### 1.4 Assumptions the golden capture tests

- Bill's current runs load the `dbnd*NO1.mat` files in `texture-learning-new/`. The newer folder ships no bounds.
- `ss_segm_11_8_26_22.mat` is `test_ss_segm` run on `GTR22.mat` with the `seg_11_8_26_1_1` parameters.

Both are now confirmed: `capture_bill_segmentation` reproduced Bill's saved file exactly on all 20 images.

Not tested by anything yet:
- I did not line-compare `+segmentation/group_patches.m` with Bill's `mk_groups.m`. On reading, it looks like a faithful port. The golden test will catch any difference.
- The demo defaults to colour + Fabric (`run_demo.m:231`). All of Bill's saved runs are achromatic (`colorflg = 0`).

## 2. Plan

**Steps 1–4 are done: exact parity, and the demo now segments the way Bill's code does.**

- [x] **1. Capture the golden reference from Bill's code.** Done on 2026-11-14 and took 14 min. All 20 images match Bill's saved run exactly, so both assumptions in §1.4 hold.
  - `tools/capture_bill_segmentation.m` calls Bill's own `ss_segm.m` on the 20 images in `GTR22.mat`, the same way `test_ss_segm.m` does. Bill's files are only read.
  - It saves `tools/golden_bill_segm.mat`: each image's segmentation, its RNG state, and Bill's intermediate values.
- [x] **2. Per-image entry point and baseline.**
  - [x] `segmentation.learn_image_similarity` holds the per-image similarities and the learned criterion and weight. `s7` now calls it instead of keeping its own copy.
  - [x] `segmentation.segment_image` calls `learn_image_similarity`, then groups the patches at fixed parameters. It is this repo's counterpart of `ss_segm`.
  - [x] Baseline: run `check_bill_segmentation()` with no arguments. It runs *this repo's* `segment_image` on the same 20 images and compares the result with the golden file. Result (2026-11-14, 2 min): **0 of 20 match**. All 20 first differ at `phiall`, the all-pairs content similarity, with a max difference of 1.5–3.5 per image.
- [x] **3. Make the repo match, one stage at a time.** Done 2026-11-14: **20 of 20 images match**, and every intermediate stage agrees with Bill's to round-off. Each row is one sub-step and the check result after it.
  - [x] **a. Bounds and bins.** `tools/import_bill_model.m` writes Bill's `dbnd*NO1` bounds (achromatic and colour), his `AHEO` adaptive bins (they differed for every feature) and his LMS→ABR rotation into `data/models/`. → 0/20, first difference `phiall`.
  - [x] **b. Model settings** in `config.m`: $b_0 = 5\text{e-}5$, edge DV features `[5 9 10 11]`. → still 0/20 at `phiall`.
  - [x] **c. Image front end, behind a temporary `cfg.bill_compat` switch** (on by default). → 9/20, first difference `rho`; `phiall` matches.
    - Eye optics. Bill's `aply_otf` converts frequency as $u = k/\text{ppd}$; `vislab.lib.otf_filter` uses $u = k\cdot\text{ppd}/N$ ($k$ cycles per image, $N$ pixels). Bill's blur is therefore much weaker, about $10\times$ less signal removed on image 1. Reported to Bill as a likely bug. `pipeline/otf_ppd.m` passes the effective ppd $N/\text{ppd}$, which makes the shared filter compute Bill's formula exactly; `load_texture_images` and the checker use it.
    - Colour rotation. Bill's `coeff` differs from the shared `vislab-common` one by up to 0.0033. `prep_grid` now rotates with `cfg.color_rotation`.
  - [x] **d. Per-image rule.** `learn_image_similarity` gained method `'bc'` (pre-trained border+content DV, only $g$ and $w_m$ learned), now the default in `s7`. Grids `0:0.8:16` for all methods, and Bill's tie-break (first maximum in column order). Bill's learned values reach $g = 10.4$, $w_m = 15.2$, outside the old grids.
  - [x] **e. Mutual similarity, also behind `cfg.bill_compat`.** → 9/20, first difference `rbn`; `rho` matches. Bill's `ss_segm.m:208-228` allocates `vi`/`vj` with $N-2$ entries; they grow to $N-1$ on the first $i=j$ pass and never shrink. So every later pair also sums one stale term left by the last $i=j$ pass. Verified: with that term the repo reproduces Bill's `rho` to $10^{-15}$; without it the difference is up to 0.107. Likely another bug worth telling Bill about. `mutual_similarity(phiall, cfg.bill_compat)` reproduces it.
  - [x] **f. Border-centred border cue** (`cfg.dv.border_center = true`, Bill's `centerflg = 1`). → **20/20.** `+segmentation/border_windows.m` gets the windows as the patch grid shifted by half a patch (via `prep_grid`). `+segmentation/border_cue.m` splits each window into halves for the existing `dv_border`, which then equals `Rb12`. Near pairs use it; far pairs keep the two-patch cue, as in Bill's code. No new `vislab-common` code was needed.
  - [x] **g. Grouping.** `segment_image` groups at `gcopt + gl`, with `gcc` and `gr`.
- [x] **4. Restructure stage 7 to mirror Bill's two steps.** Done 2026-11-14. The golden check still passes 20/20.
  - [x] **Fixed parameters in one place.** `tools/import_bill_model.m` writes Bill's chosen values (from `seg_11_8_26_1_1.mat`) to `data/models/segmentation_params_otf.mat`: method `'bc'`, offset $-0.25$, confidence $1.2$, merge $0.8$. `config.m` loads them as `cfg.segment`, and `segment_image` uses them by default.
  - [x] **`s7_segment_gtr(cfg, itypes, ecc, n_images, save_params)` chooses those parameters**, as Bill's `GTR_segment.m` does. It sweeps the offset (`-1.25:0.25:1.25`) and the merge criterion (`0:0.2:1.4`) over his six texture sets, and maximizes the mean number of regions exactly right. Ties go to the first cell in column order. Images are drawn under `rng(cfg.seed)`. It reuses each image's similarities across the grid through `segment_image`'s optional fifth argument, so there is no second copy of the grouping code. Smoke test: about 4 s per image, so roughly 50 min for the full 6 × 120 sweep (an estimate). The full sweep has not been run, and its result would not equal Bill's exactly, because the GTR images come from the repo's generator, not his.
  - [x] **Demo.** `run_demo` no longer sweeps. Stage 7 calls `plot_stage7(cfg, itype, ecc, n_images)`, which segments 3 new GTR images at `cfg.segment` and reports the share of regions exactly right. Stage 8 (`plot_stage8_natural(cfg, ecc)`) uses the same parameters.
  - [x] **One per-image code path.** `plot_stage7` and `plot_stage8_natural` call `segment_image`; their own copies are gone.
  - Still to note: stage 8's natural image gets the shared (corrected) optics even under `cfg.bill_compat`, because Bill's formula is defined only for square images.
- [ ] **5. After parity:** retrain s4/s5 with the new $b_0$ and edge dims, then re-sweep the parameters for the repo's own bounds. This replaces the shipped artifacts in `data/models/`.

## 3. Issues in Bill's code to report

Found while matching his code. "Verified" means checked by running it or by the golden test; otherwise it is from reading the code.

| # | Issue | Where | Effect | Status |
|---|---|---|---|---|
| 1 | **Optics frequency units.** $u = k/\text{ppd}$ instead of $k\cdot\text{ppd}/N$. Every frequency is too low by $N/\text{ppd}^2$ ($\approx 5.6\times$ at 640 px, 60 ppd), so the eye-optics blur is far too weak. | `aply_otf.m:21`, in all of his folders, including texture-segmentation | Removes about $10\times$ less signal from image 1 than the corrected filter. Affects all training and GTR images in both projects. | Verified. **Already emailed.** |
| 2 | **Stale term in mutual similarity.** `vi`/`vj` are allocated once with $N-2$ entries. They grow to $N-1$ on the first $i=j$ pass and never shrink, so every later pair also sums one leftover term from the last $i=j$ pass. | `ss_segm.m:208-228`. The same allocation pattern is in 13 other files, including `self_sup_tex_segm.m`, `ss_disc.m`, `self_sup_tex_disc.m` and texture-segmentation's `tex_grp_s_p_ms_BF.m`. | `rho` differs from the paper's definition by up to 0.107 on these images. | Verified for `ss_segm.m` only, to $10^{-15}$. |
| 3 | **ppd = 64 in three training scripts, 60 elsewhere.** | `mk_rot_mtrx.m:20`, `cdfs_of_features.m:33`, `nat_near_far_patches.m:31`; `nat_near_far_dv_2.m:25` and the segmentation code use 60. | The colour rotation, feature CDFs and near/far training patches are filtered at a different scale from everything else. | From the code. |
| 4 | **Colour rotation is not reproducible.** `mk_rot_mtrx.m` samples pixels at random with no `rng` seed (the other training scripts call `rng(0)`). | `mk_rot_mtrx.m` | Re-running it gives a slightly different matrix. | From the code. |
| 5 | **Flag comments contradict the code.** `ss_segm.m` and `test_ss_segm.m` say flag 2 (`contentflg`) is "not used here", but it selects the per-image rule (`ss_segm.m:543-552`). His saved runs set it to 0, so the criterion and weight are learned from the border+content DV, not the content-only DV. | `ss_segm.m:17, 34`, `test_ss_segm.m:15` | Easy to misread which model produced the results. Worth confirming 0 is what he intends. | From the code. |
| 6 | **Undefined variable on the colour path.** `nanh = nanh + 1` runs whenever the colour spot DV is NaN, but `nanh` is never initialized in `ss_segm.m`. (`self_sup_tex_segm.m:371` does initialize it.) | `ss_segm.m:285, 342, 403, 654` | Would crash a colour run (`colorflg = 1`) the first time a NaN appears. Not hit by his achromatic runs. | From the code. |
| 7 | **Border bound trained on one statistic, applied to another.** With `centerflg = 1`, near pairs use `Rb12` (a single window centred on the border, not contrast-normalized), but `dbndb` is trained on two-patch `Rb` (`nat_near_far_dv_2.m:125, 165`). | `ss_segm.m:299-304` | Possibly intended; worth asking. | From the code; also in `docs/to-do.md` §1.2. |
| 8 | **"Fabric" GTR images are grayscale.** `mk_GTR_images.m` sets `grayflg = 1`, and `GTR22.mat` has R = G = B. | `mk_GTR_images.m` | Colour cues cannot help on these images, so they can't evaluate the colour model. | Verified on `GTR22.mat`. |

**Why the colour rotation differs (not a bug by itself).** Both matrices are PCA axes of LMS pixels sampled from the calibrated natural images. They differ by up to 0.0033 because:
- Bill's used his weak optics filter (#1), at ppd 64 (#3).
- The repo's used the corrected filter at ppd 60.
- Each was fit to a different random pixel sample (#4).

Sampling alone gives differences of this size. The committed and current working copies of `vislab-common/data/cps_lms2abr_otf.mat` differ from each other by up to 0.0028. (That file also has uncommitted changes in `vislab-common`.)
