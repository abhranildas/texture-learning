# Plan: top-level scripts

Geisler's slide deck `Proximity_proxy_new_results.pptx` (Bill's code, `texture-learning-newer/GTRdiscsegm/`,
slide 1) lists the main scripts a user of his code runs. This plan gives this repo matching top-level scripts.

## Bill's 5 main tasks, and what this repo has

| # | Task | Bill's scripts | This repo now |
|---|---|---|---|
| 1 | Make GTR test images and save them as fixed sets of 20 | `mk_GTR_images` | `make_gtr_image(cfg, itype, n_images, ecc, seed)` makes a set in one call; saving is `save(file, 'imgs', 'maps')` |
| 2 | Discrimination on all 6 texture sets, with a bar plot | `GTR_disc` → `self_sup_tex_disc`, then `GTR_disc_plot` | `pipeline/s6_selfsup_discrimination` does one set; no loop over sets; not called by `run_demo` |
| 3 | Learn the fixed segmentation parameters, with a bar plot of % regions exactly right | `GTR_segment` → `self_sup_tex_segm`, then `GTR_segment_plot` | `pipeline/s7_segment_gtr` learns them; no bar plot |
| 4 | Test discrimination on a saved image set, with an accuracy histogram | `test_ss_disc` → `ss_disc` | missing |
| 5 | Test segmentation on a saved image set, then plot accuracy against regions correct, plus overlays | `test_ss_segm` → `ss_segm`, then `ss_segm_plot` | `segment_image` segments one image; a cut-down copy of the testing is spread over `demo/plot_stage7` and `tools/compare_otf_models` |

Bill's slide uses some older names: `GTR_discrim.m` is `GTR_disc.m`, `self_sup_disc.m` is `self_sup_tex_disc.m`,
and `self_sup_segm.m` is `self_sup_tex_segm.m`.

## To do

### 1. Top-level scripts (repo root, beside `run_demo.m`)

- [x] `make_gtr_image(cfg, itype, n_images, ecc, seed)`: one call makes a set of GTR images and maps (task 1; replaces the planned `make_gtr_set`). s6, s7 and `demo/plot_stage7` use it; their random draws are unchanged
- [x] `segment_image(cfg, img, map)`: segment one image (LMS array, image file, or RGB array with `rgb=true`); scores it when given the true map; shows the result when called with no output. The internal `segmentation.segment_image` is renamed `segmentation.segment_lms`. `plot_stage7` and `plot_stage8_natural` use it
- [ ] `run_discrimination(cfg, itypes)`: run s6 on each texture set, then draw the bar plot (task 2)
- [ ] `run_learn_segmentation(cfg)`: run s7, then draw the bar plot of % regions exactly right per set (task 3)
- [ ] `test_discrimination(cfg, gtr_set)`: test discrimination on a saved set, then draw the accuracy histogram (task 4)
- [ ] `test_segmentation(cfg, gtr_set)`: segment and score a saved set, then draw the scatter and overlays (task 5)
- [ ] Decide where they go: the repo root, or a folder such as `scripts/`

### 2. Remove duplication

- [ ] `demo/plot_stage7` calls `test_segmentation` instead of its own loop
- [ ] `tools/compare_otf_models` calls `test_segmentation` for its scoring

### 3. Demo

- [ ] `run_demo` runs a small `test_segmentation`
- [ ] Optionally, `run_demo` adds a short stage-6 discrimination bar plot

### 4. README

- [x] "Main functions" section, starting with `make_gtr_image`
- [ ] One row per main script: what it does, a one-line example call, and what it outputs

### 5. Checks

- [ ] Check whether s6 matches Bill's newer discrimination code. Its header says it merges his older
      `self_sup_train_bnd_*` code, not `self_sup_tex_disc` / `ss_disc`. If it doesn't match, task 2 needs a parity check.
- [ ] Use saved sets for the GTR-generator parity check: compare a `make_gtr_image` set with Bill's stored `GTR*.mat`
