# From your working code to the published `texture-learning` repository

Bill — this note walks through how your texture-learning code was packaged into the version now on
GitHub. The starting point was a complete, working codebase that already produced every result in
the paper; the work here was mostly about **preparing it to be shared and run by other people**.

---

## 1. Reorganization and presentation — so a new person can pick it up

### Before
The code grew organically as the research progressed: the working scripts and their output files (`AHEO5101.mat`, `dbndbcNO4.mat`,
`PCA_matrix_3_OTF.mat`, and dozens more) lived together in one folder, alongside the project
PowerPoint. The order the scripts run in — `mk_rot_mtrx` first, then `cdfs_of_features`, then
`nat_near_far_patches`, would not be obvious to a new user. The file names (`Rp`, `Rh`, `Re`, `mk_phi`, `iso_patch`, `dsmp`, `aply_otf`) were compact, but less intelligible to a newcomer.

### After
The same code is now laid out so the order and purpose are visible to someone seeing it for the
first time:

```
texture-learning/
├── README.md            plain-English overview + how to run + a glossary
├── setup.m, config.m    one-time setup, and one place for every setting
├── pipeline/            the model, as numbered stages s1 … s7
├── +segmentation/       the grouping algorithm
├── +gtr/                the grown-texture-region image generator
├── twin-net/            the neural-network comparison model
├── data/models/         the trained parameter files
└── docs/                the papers and technical notes
```

Concretely, this helps a newcomer (or a future collaborator, or you in the future) in a few ways:

- **The pipeline reads as a recipe.** The seven stages are named and numbered in the order they
  run — `s1_learn_color_transform`, `s23_learn_priors_and_pairs`, `s4_optimize_bins`,
  `s5_train_decision_vars`, `s6_selfsup_discrimination`, `s7_segment_gtr` — so the running order
  that used to live in your head is now written into the file names themselves.
- **Every file introduces itself.** Each function starts with a short description of what it takes
  in, what it produces, and which original file it came from (e.g. the top of
  `s1_learn_color_transform.m` notes "*was mk_rot_mtrx.m*"). Your original names are kept as the
  link, so any new file can always be traced back to the one you wrote.
- **A README and a glossary.** The `README.md` explains the idea (proximity as a free
  same/different label), lists the stages in a table, and — importantly — has a **glossary** that
  pairs each compact code name with the paper's symbol and a plain meaning
  (`Rp` ↔ ln L_p ↔ power-spectrum decision variable; `phi` ↔ φ_ij ↔ content similarity;
  `ecc` ↔ eccentricity downsample factor, and so on). Anyone reading the paper can now find the
  matching code, and vice versa.
- **Results sit apart from code.** The many `.mat` files now live in `data/models/` (the trained
  parameters that ship with the repo) and `data/stimuli/` (things the code generates as it runs),
  so the code folder holds code and the data folder holds data.
- **The compact file names come with a key.** Beyond the glossary, the README's "Model Data"
  section decodes the file-name codes — e.g. what the `NO` in `dbndbcNO4.mat` means
  (Natural-image-trained, OTF applied), and what `<ecc>` means in a file name.

The upshot: someone can now open the repo, read the README, run the demo, and follow the stages
without needing you to walk them through the layout first.

---

## 2. Streamlining — unifying each computation into one place

The largest change was gathering pieces of the computation that appeared in more than one spot into
a single copy. This is a normal side-effect of active research: when you're exploring, it's faster
to copy a working script and adjust it than to stop and generalize it. The benefit of consolidating
now, for a codebase that's going to live on and be shared, is that a future change or improvement
only has to be made once — and the copies can't quietly fall out of step with each other over time.

Here are the concrete cases, using your files.

### Closely-related script variants brought together

Your self-supervised-training work lived as three variants of one script:

| Original file | Lines |
|---|---|
| `self_sup_train_bnd_bc.m` | 753 |
| `self_sup_train_bnd_bc_shft.m` | 807 |
| `self_sup_train_bnd_c_shft.m` | 823 |

The first two share all but a couple of hundred lines; the third is again very close. They now live
as **one** stage, `s6_selfsup_discrimination`, where the differences between the variants became a
single `method` option you pass in. The two segmentation scripts were the same story:

| Original file | Lines |
|---|---|
| `tex_grp_s_p_ms_SS_ncm.m` | 924 |
| `tex_grp_s_p_ms_SS_ncbm.m` | 920 |

These differ on only ~35 lines, and are now one stage, `s7_segment_gtr`, again with a `method`
option. The segmentation scripts also shared their first two-thirds with the self-supervised script;
that common part was pulled into small helper files both stages call, so the GTR-image building, the
near/far sampling, and the similarity computation live in one place rather than four.

What this buys you day to day: an improvement to, say, the near/far sampling is now a single edit
that every method picks up automatically, instead of the same edit repeated across five long
scripts with a chance of missing one.

### The per-image-set loop, generalized

`mk_rot_mtrx.m` (stage 1) handles Set 9, then repeats the same loop body for Set 10 and again for
Set 12, with each set's image count (104, 90, 197) and file-name stem written in by hand. In the new
stage 1, the images are simply *found* on disk by one shared helper (`list_natural_images`) and run
through a single loop. Adding images, or a whole new image set, now needs no code change — you just
place the files in the folder.

### The decision variables in one shared home

The decision-variable functions (`Rp`, `Rh`, `Re`, `Rb`, `Rcc`) appeared here and, in similar form,
in the lab's other two projects (segmentation, camouflage). And within `Rh` and `Re`, the core
histogram log-likelihood-ratio step (your paper's Eq. A4) recurred several times. These now come
from **one shared library** (`vislab`, described below): each decision variable exists once, with a
descriptive name alongside your original (`Rp` → `dv_power`, `Rh` → `dv_spot_hist`,
`Re` → `dv_edge_hist`), and the Eq. A4 step is a single helper (`multinomial_llr`) they all call.

### One place for every setting

Each script used to set its own constants at the top — pupil diameter, wavelength,
pixels-per-degree, patch size, target mean and contrast, the RGB→LMS matrix, the feature list, the
image counts. These now live once in **`config.m`**, and every stage reads from there, so a value
changed in one place is seen everywhere and the settings stay consistent across stages. (This is
also what surfaced one of the small discrepancies noted at the end, where the natural images were
handled at 64 pixels/degree in one stage and 60 in another.)

### Paths that no longer point at one machine

Because the scripts were written to run on your computer, most began with lines like:

```matlab
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Brodatz')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Fabric')
...
```

Perfectly natural for day-to-day work, but they tie the code to one machine. The published version
takes all locations from `config.m`, with the one data folder that needs setting clearly marked by a
comment — which is what lets the code run on anyone's computer.

### Exploratory code set aside

Working scripts naturally accumulate earlier experiments kept around "just in case" — e.g. the
disabled "weak-patch relinking" block and an unused `nodes` loop in `mk_groups.m`, some
commented-out rescaling lines in `mk_rot_mtrx.m`, and diagnostic-histogram code sitting alongside the
main computation. For the public version these were set aside so what remains is just the active
path, and the results were checked to be unchanged after each removal. Nothing is lost — the
originals are all still in `Bill's old code/`.

### Shared code in one library, not copied per project

The lab's three projects (this one, texture-segmentation, camouflage) drew on the same low-level
routines — optics, filters, patch normalization, the decision variables — each with its own copy.
These now live in **one shared library, `vislab-common`**, that all three load, so an improvement to
the optics or a decision variable reaches every project at once. This repo fetches that library
automatically the first time you run `setup`, so there's nothing to manage by hand.

---

## 3. Speedups and parallelization

- **Each patch's features are measured only once (the largest speedup, in the segmentation / GTR
  code).** To compare every patch in an image against every other, `mk_phi.m` loops over all patch
  pairs (~5,000 for a 10×10-patch image) and, inside each pair, re-cuts, re-normalizes, and
  re-rotates both patches and recomputes their Fourier power spectra and edge/bar steerable-filter
  histograms — so each of the ~100 patches gets its (expensive) features recomputed ~99 times over.
  The published version separates "measure" from "compare": `content_features` measures each patch's
  features once and stores them, and `content_dv_pair` then just combines two stored measurements. So
  the expensive step runs ~100 times per image instead of ~10,000. This measure-once step is *shared*
  by all three places that need it (all-pairs similarity, neighbor similarity, near/far responses),
  so stages 6 and 7 all benefit without it being written three ways; and both halves run across all
  CPU cores (`parfor`). Separating the work also sidesteps a subtle detail in the original, where the
  reference patch's grayscale was normalized in place and reused for the next pair in a changed state.
- **The image loops run in parallel.** Stage 1 (and the other stages that sweep over all the
  natural images) handle each image independently, so they run on all your CPU cores at once
  (MATLAB's `parfor`). On a multi-core machine this cuts the per-stage wait roughly in proportion to
  the number of cores. If the Parallel Computing Toolbox isn't installed, the exact same code simply
  runs one image at a time — nothing breaks.
- **The innermost pixel copying is vectorized.** `mk_rot_mtrx.m` copied each patch pixel by pixel
  with a double `for i … for j` loop (4,096 steps per patch). MATLAB is much faster doing this as a
  single array operation, so those inner loops became array copies. The same pattern was tidied in
  the GTR mask and region-scoring code.
- **A repeated array re-sizing is avoided.** In `mk_masks.m` the region-mask array grew as it went,
  which makes MATLAB keep copying it; it's now sized once up front — same result, less memory churn.
- **The demo has a "quick" mode.** Re-training from scratch genuinely takes a while (it reads the
  whole ~19 GB natural-image set), so the demo defaults to a quick mode that uses the shipped trained
  parameters and lets a newcomer see the whole thing work in a few minutes. Full re-training is one
  setting away.

---

## 4. Demo, and new features

### A guided, self-explaining demo (`run_demo.m`)
This is new. Running `run_demo` walks through the **entire model lifecycle** end to end and prints
what it's doing at each step. It:

- learns (or, in quick mode, loads) the model,
- **plots each stage** so you can *see* the color transform, the learned feature priors, the
  near/far training pairs, the trained decision boundaries, the discrimination accuracy, and the
  final segmentation,
- runs the self-supervised discrimination and the GTR segmentation on freshly built texture images,
- and finishes by segmenting a **real natural image** with the same model.

All the plotting lives in the `demo/` folder (the `plot_stage1` … `plot_stage8_natural` files). It
turns the project into something a reader can run and watch for themselves — exactly what a reviewer
or a new student needs.

### One-command, self-healing setup (`setup.m`)
Also new. Running `setup` once puts everything on the path and, if a required piece is missing, it
sorts it out for you: it downloads and installs the two MATLAB add-on toolboxes the model needs
(`classify_normals` and `gx2`) straight from their github releases, and it fetches the
shared `vislab-common` library if it isn't already alongside. Getting the code running no longer
depends on the target machine already having everything in the right place.

### A built-in demo dataset with "constant-volume" sampling
The full natural-image set is far too large for GitHub (~19 GB), so a small **12-image demo subset**
is bundled in the repo, and the sampling was made **dataset-size-aware**: it automatically draws more
patches per image when the dataset is small, keeping the total number of training patches fixed
(~7,820) whether you run on 12 images or the full set. The bundled demo therefore trains on the same
amount of data as the full model — it works out of the box, with no large download.

### The twin (Siamese) neural network — a comparison model (`twin-net/`)
This is a learned neural-network model that plays the same game as your Bayesian observer, to see how far a model that *learns*
its features, rather than using the hand-defined ones, can transfer. It shares one image-ingestion
path with the Bayesian pipeline (same optics, same calibration, all from `config.m`), so the two
models can be compared fairly, with no chance they're quietly seeing different inputs.
