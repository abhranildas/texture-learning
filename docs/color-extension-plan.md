# Colour extension: blueprint

How to extend this repo's texture-learning model from achromatic to colour, matching the
change Bill made in `Bill's old code - revised/`.

This document is written to be executed by someone (or something) that has not seen the
comparison. Every claim about Bill's code is cited by `file:line`. Follow the steps in
order; each one names the exact file and edit.

---

## Part 0 — Verification of Bill's change

**Bill's verbal description is accurate.** Verified against the two code folders.

The original model built one "spot" decision variable from three features — A (achromatic)
pixel, centre-surround small, centre-surround large:

- `Bill's old code/nat_near_far_dv_2.m:55` — `nh = [1,13,14]`
- `Bill's old code/nat_near_far_dv_2.m:190-210` — one 3-D bound `dbndh`, saved as `dbndhNO<lev>.mat`

The revised model splits this into three bounds:

| stage | features | bound variable | file written | citation |
|---|---|---|---|---|
| achromatic spot | `[1 13 14]` = A pixel, CS-small, CS-large | `dbndha` | `dbndahNO<lev>.mat` | `nat_near_far_dv_2.m:185-203` |
| chromatic ("colour") spot | `[2 3]` = B pixel, R pixel | `dbndhb` | `dbndbhNO<lev>.mat` | `nat_near_far_dv_2.m:206-224` |
| full spot | the two DVs above, 2-D | `dbndh` | `dbndchNO<lev>.mat` | `nat_near_far_dv_2.m:227-246` |

The feature list is literally the old list with the two colour channels appended
(`nat_near_far_dv_2.m:53-60`):

```matlab
if colorflg == 1
  nh = [1,13,14,2,3];   % spot features to use
elseif colorflg == 0
  nh = [1,13,14];
end
```

Downstream is **structurally unchanged**: the full spot DV feeds the content DV
(power, spot, edge) exactly where the old spot DV did — `nat_near_far_dv_2.m:296-303`. The
downstream bounds are all *retrained* and written under `c`-prefixed names
(`dbndceNO`, `dbndccNO`, `dbndcbNO`, `dbndcbcNO`, lines 278-365), but the maths of the
downstream stages is identical.

Run-time application of the trained bounds, in `Bill's old code - revised/mk_phi_c.m:60-62`:

```matlab
rha = dvhafun([log(Rhout(nh(1:3)))]');   % achromatic spot DV
rhb = dvhbfun([log(Rhout(nh(4:5)))]');   % chromatic spot DV
rh  = dvhfun([rha,rhb]');                % full spot DV -> feeds content DV as before
```

### Supporting changes that the colour change genuinely requires

1. **Bin bounds and feature flags turned on for dims 2 and 3.**
   `nat_near_far_dv_2.m:50-52` — `cstat` and `flist` change from `[b,0,0,0,...]` /
   `[1,0,0,0,...]` to `[b,b,b,0,...]` / `[1,1,1,0,...]`.
2. **New adaptive-histogram bin files for dims 2 and 3.** `mk_bb.m` loads
   `AHEO<btype><dim><lev>.mat` per feature. The revised folder adds `AHEO52{1,2,4,8}.mat`
   and `AHEO53{1,2,4,8}.mat` (dims 2 and 3), which the old folder does not have. They come
   from `opt_bins_nat.m` run with `dim = 2` and `dim = 3`.
3. **`mk_phi` was parameterised.** `mk_phi.m` now takes `ne, nh` as arguments instead of
   hardcoding them (`mk_phi.m:1-2, 28-31`), and `mk_phi_c.m` is the colour twin.

### Changes in the revised folder that are NOT the colour change — do not port here

These are mixed into the same folder. Keep them out of this task.

- Edge feature set changed: `ne = [5,7,9,10]` → `[5,9,10,11]` (`nat_near_far_dv_2.m:53`).
- Power suppression `b0` now comes from `load_b0_nat` (value `5e-5`) instead of the
  hardcoded `16` (`nat_near_far_dv_2.m:45-46`). This repo currently uses 16
  (`config.m:59`, `s5_train_decision_vars.m:38`).
- Outlier rejection changed from a `|value| < 25` window to an `isinf` test
  (`nat_near_far_dv_2.m:132`).
- A new second border stage (`borderflg = 2`): border bound retrained on near pairs split
  by the sign of the content DV (`nat_near_far_dv_2.m:367-426`).
- Bug fixes: `Rb.m:49-50` (`/` → `./`), `Re.m:156` (`gmb` → `gm2b`),
  `nat_near_far_patches.m:260-262` (`pcnt12` miscount), `aply_otf.m:26` (mean added twice),
  `cdfs_of_features.m:468` (`csl2` → `csl4`), `iso_patch.m:47-48` (`i~=j` → `i1~=i0`).
- The discrimination/segmentation rewrite (`self_sup_tex_discrim.m`,
  `self_sup_tex_segment.m`, `find_border.m`, `opt_b0_nat.m`, figure scripts).

---

## Part 1 — What this repo already has

Good news: most of the plumbing is colour-ready.

- **The shared `vislab` layer already computes B and R.**
  `vislab.nat_stat_bayes.spot_features` extracts pixel channels 1-3 from an ABR patch and
  handles 1-channel input gracefully; `dv_spot_hist` histograms whichever dims
  `feature_list` requests. No change needed in `vislab-common` for the features themselves.
- **The natural priors already include B and R CDFs.**
  `pipeline/finalize_priors.m:11-12` writes `P.Nb/P.eb` and `P.Nr/P.er`.
- **Stage 4 already knows how to bin dims 2 and 3.**
  `pipeline/s4_optimize_bins.m:148-149` maps dim 2 → `priors.eb/Nb`, dim 3 → `priors.er/Nr`.
- **The segmentation path already carries full colour patches.**
  `+segmentation/prep_grid.m` returns the 3-channel ABR patch `P`, and
  `+segmentation/content_features.m` histograms whatever `spot_dims` it is given.

### The one real blocker

**Stage 3 throws the colour away when it stores patch pairs.**
`pipeline/sample_nearfar_pairs.m:25-49` calls `vislab.nat_stat_bayes.patch_to_a` on every
patch and stores a `[psz x 2*psz x 1 x n]` tensor — achromatic only. `patch_to_a` normalises
the 3-channel LMS patch, rotates LMS→ABR, and returns channel 1 only.

So `data/stimuli/patch_pairs_ecc1.mat` contains no colour, and stages 4 and 5 cannot see B
or R no matter what feature list they ask for. **This must be fixed first, and the patch
pairs must be regenerated.**

### Other things that are currently achromatic-only

- `data/models/AHEO_bins.mat` has no entries for dims 2 and 3 — `run_demo.m:87` only ever
  trains dims `[1 5 9 10 13 14]`.
- The literal `[1 5 9 10 13 14]` is hardcoded in **seven** places:
  `run_demo.m:87`, `pipeline/s5_train_decision_vars.m:43-44`,
  `pipeline/s6_selfsup_discrimination.m:37`, `pipeline/s7_segment_gtr.m:43`,
  `demo/compute_demo_responses.m:15-16`, `demo/plot_stage6_pairs.m:16-17`,
  `demo/plot_stage7.m:15`, `demo/plot_stage8_natural.m:74`. All of them become wrong the
  moment dims 2 and 3 join the spot set, so consolidating them is part of this change, not
  optional tidying.
- The per-pair response matrix has a fixed 9-column layout `[rh1 rh2 rh3 re1 re3 re4 rp rb1
  rb2]`, sliced by hardcoded index in five places (see Step 4).
- `demo/pair_responses.m` and the local `pair_responses` subfunction in
  `pipeline/s5_train_decision_vars.m:101-134` are near-identical duplicates of the same
  routine. Fold them into one.

---

## Part 2 — Design decisions

### D1. One boolean in `config.m`; everything else derived from it.

Bill's code branches on `colorflg` in roughly ten places. Do not copy that. There is exactly
one switch, in `config.m`, and every other part of the model reads the derived dimension
lists rather than the boolean:

```matlab
cfg.features.color          = true;        % false = the published achromatic model
cfg.features.spot_achr_dims = [1 13 14];   % achromatic spot: A pixel, CS small, CS large
if cfg.features.color
    cfg.features.spot_chrom_dims = [2 3];  % chromatic spot: B and R pixels
else
    cfg.features.spot_chrom_dims = [];
end
cfg.features.spot_dims = [cfg.features.spot_achr_dims, cfg.features.spot_chrom_dims];
```

So `isempty(cfg.features.spot_chrom_dims)` is the derived test the rest of the code uses;
the boolean itself is read in only two places (below).

`cfg.features.color = false` reproduces the published achromatic model exactly, *and* keeps
it cheap: stage 3 then stores single-channel pairs as it does today (Step 1b), so the pairs
file stays ~1 GB and nothing downstream does extra work.

Only two places may read `cfg.features.color` directly: `config.m` itself, and
`sample_nearfar_pairs` (which must know how many channels to store). Everywhere else reads
`cfg.features.spot_dims` / `spot_achr_dims` / `spot_chrom_dims`.

### D1b. The pairs file records which mode wrote it.

Because the achromatic and colour runs write pairs of different shape to the *same* path,
flipping the switch without regenerating would silently feed the wrong data to stages 4 and
5. Prevent it: `s23_learn_priors_and_pairs` saves `color` alongside `ptchn`/`ptchf`/`pcnt`,
and `s4_optimize_bins` / `s5_train_decision_vars` error out on mismatch:

```matlab
if pp.color ~= cfg.features.color
    error('...:pairsModeMismatch', ...
        'patch_pairs_ecc%d.mat was written with color=%d but config asks for color=%d — rerun stage 3.', ...
        ecc, pp.color, cfg.features.color);
end
```

### D2. The spot DV stays a single function handle.

`pipeline/load_dv_handles.m` composes the two-stage spot DV into one handle `dv.h` that
takes the full spot LLR vector (in `spot_dims` order) and returns a scalar. Every downstream
caller — `+segmentation/content_dv_pair.m`, `pipeline/neighbor_far_responses.m`,
`+segmentation/content_similarity_matrix.m`, `+segmentation/neighbor_similarity_matrix.m`,
`s6`, `s7`, the stage 7/8 demo plots — then needs **no change at all**. This is the main
reason to prefer this design over Bill's.

### D3. Bound-file layout stays backward compatible.

In `decision_bounds_ecc_<ecc>.mat`:

- **Achromatic-only run** (`spot_chrom_dims = []`): `dbnd.h` is the 3-D bound over
  `[1 13 14]` — exactly what the shipped file already contains. Nothing breaks.
- **Colour run**: `dbnd.ha` (3-D achromatic), `dbnd.hb` (2-D chromatic), and `dbnd.h`
  becomes the 2-D combiner over `[ha_DV, hb_DV]`.

`load_dv_handles` decides which to build by testing `isfield(dbnd, 'ha')`. That is the only
branch in the whole codebase.

Also store the layout in the artifact so a mismatch is caught loudly:
`dbnd.spot_dims`, `dbnd.spot_achr_n = numel(cfg.features.spot_achr_dims)`.

---

## Part 3 — Implementation steps

Do these in order. Steps 1-3 must be complete before anything can be retrained.

### Step 1 — Keep all three channels through the patch pipeline

**1a.** In `vislab-common`, add `+vislab/+nat_stat_bayes/patch_to_abr.m`: same body as the
existing `patch_to_a.m` but returning all three ABR channels. Then rewrite `patch_to_a.m` as
a one-line wrapper (`a = patch_to_abr(...); a = a(:,:,1);`) so the normalise-then-rotate
order stays defined in exactly one place. `patch_to_a` must keep its current pass-through
behaviour for 1-channel input, because the twin network in `twin-net/` also calls it.

**1b.** In `pipeline/sample_nearfar_pairs.m`, keep all three channels when
`cfg.features.color` is true and the single achromatic channel when it is false — this is
the one place that reads the boolean directly, and it is what makes the achromatic mode stay
cheap. Concretely: pick the preparation function and channel count once at the top,

```matlab
if cfg.features.color
    nch = 3;  prep = @(p) vislab.nat_stat_bayes.patch_to_abr(p, m0, c0);
else
    nch = 1;  prep = @(p) vislab.nat_stat_bayes.patch_to_a(p, m0, c0);
end
```

then preallocate `zeros(psz, psz2, nch, 2*nsmp)` (lines 25-26) and write
`ptchn(:, :, :, pcnt) = ...` (which is correct for both `nch = 1` and `nch = 3`).

Careful with the "down" pairs at lines 43-48: they transpose the patch, and a 3-D array
cannot use `.'` — use `permute(p, [2 1 3])`, which is also correct for a 1-channel array.
Update the doc comment at lines 15-18.

**1c. Stop re-preparing the stored pairs downstream — this is a correctness fix, not tidying.**

`patch_to_a`'s contract is: *3-channel input means raw LMS* (normalise, rotate, return A);
*1-channel input means already-prepared A* (pass through). The stored pairs are already
normalised and ABR-rotated, so today's 1-channel file hits the pass-through branch and all
is well. The moment stage 3 stores 3-channel **ABR**, that same call would treat it as LMS
and normalise + rotate it a second time, silently corrupting every response. Nothing in the
array's shape distinguishes stored-ABR from raw-LMS, so no version of `patch_to_a` /
`patch_to_abr` can tell them apart.

The fix: the two consumers of the pairs file must read it **as-is**, with no `patch_to_*`
call at all. In `pair_responses.m:16-17` and `s4_optimize_bins.m:182-183`, replace

```matlab
p1 = vislab.nat_stat_bayes.patch_to_a(patches(1:psz, 1:psz, :, i), m0, c0);
```

with a plain slice `p1 = patches(1:psz, 1:psz, :, i);`, and take `p1(:,:,1)` where the
achromatic channel is needed. This also removes the "older 3-channel LMS files" legacy
accommodation those comments describe, which is exactly the kind of shim that caused the
ambiguity.

> **Cost of colour mode — state it, do not try to optimise it away.** Both
> `s4_optimize_bins.m:37` and `s5_train_decision_vars.m:49` load the whole pairs file into
> RAM at once. Today: 7820 near + 7820 far pairs (`config.m:34`, 3910 references x 2), each
> `64 x 128` doubles = 64 KB, so **~1.0 GB resident** and 955 MB on disk. Colour makes that
> **~3.1 GB resident / ~2.9 GB on disk**, and stage 3's `parfor` + `cat(4, ...)`
> (`s23_learn_priors_and_pairs.m:40-49`) transiently holds about two copies, so budget ~6 GB
> peak there.
>
> Do **not** store the pairs as `single` to shrink this. Casting back to `double` on load
> saves disk but no memory; not casting silently runs the entire feature computation —
> histograms, convolutions, FFTs — in single precision, which is an uncontrolled change to
> the model's arithmetic and breaks bit-identical reproduction of the published achromatic
> results. If memory ever becomes the binding constraint, the correct fix is to process the
> pairs in chunks in `s4`/`s5` (the per-pair loops are already independent) rather than to
> lower precision.

### Step 2 — Config

Edit `config.m:91-93` to the switch and derived lists in D1, and add one more derived field
to kill the seven hardcoded literals:

```matlab
cfg.features.dv_dims = sort([cfg.features.spot_dims, cfg.features.edge_dv_dims]);
```

Then replace every occurrence of the literal `[1 5 9 10 13 14]` (list in Part 1) with
`cfg.features.dv_dims`. Each site uses it the same two ways:

```matlab
feature_list = zeros(1, 20);  feature_list(cfg.features.dv_dims) = 1;
cstat        = zeros(1, 20);  cstat(cfg.features.dv_dims) = btype;
```

### Step 3 — Stage 4: bins for dims 2 and 3

No code change needed in `s4_optimize_bins.m` — it already handles dims 2 and 3. Only the
call sites pass the new dim list (Step 2 covers `run_demo.m:87`).

### Step 4 — Stage 5: train the two-level spot DV

**4a. Consolidate `pair_responses`.** Delete the local subfunction at
`pipeline/s5_train_decision_vars.m:101-134` and move `demo/pair_responses.m` to
`pipeline/pair_responses.m` (both directories are on the path via `setup.m:24-25`; move it
to `pipeline/` because it is now a pipeline function, not a demo helper). `s5` then calls
the shared one.

**4b. Make the response matrix layout dynamic.** In `pair_responses.m`:

- replace the fixed `rh = log([spot(nh(1)), spot(nh(2)), spot(nh(3))])` (line 23) with
  `rh = log(spot(nh))` — `nh` is now 3 or 5 elements;
- likewise `re = log(edge(ne))` (line 29);
- widen `R = zeros(n_pairs, 9)` to `numel(nh) + numel(ne) + 3`;
- return a third output `col`, a struct of column indices, so no caller ever hardcodes them
  again:

```matlab
n_h = numel(nh);  n_e = numel(ne);
col = struct('spot',   1:n_h, ...
             'edge',   n_h + (1:n_e), ...
             'power',  n_h + n_e + 1, ...
             'border', n_h + n_e + (2:3));
```

Also add `col.spot_achr` and `col.spot_chrom` (the first `numel(spot_achr_dims)` spot
columns and the rest) since Step 4c and the plots need them.

**4c. Train three spot bounds instead of one.** In `s5_train_decision_vars.m`, replace
line 56 with:

```matlab
if isempty(cfg.features.spot_chrom_dims)
    dbnd.h = train_bound(near(:, col.spot), far(:, col.spot));
    dvh = quad2fun(dbnd.h, 0);
else
    dbnd.ha = train_bound(near(:, col.spot_achr),  far(:, col.spot_achr));
    dbnd.hb = train_bound(near(:, col.spot_chrom), far(:, col.spot_chrom));
    dvha = quad2fun(dbnd.ha, 0);
    dvhb = quad2fun(dbnd.hb, 0);
    % full spot bound over the two intermediate DVs
    spot_near = [apply_dv(dvha, near(:, col.spot_achr)), apply_dv(dvhb, near(:, col.spot_chrom))];
    spot_far  = [apply_dv(dvha, far(:,  col.spot_achr)), apply_dv(dvhb, far(:,  col.spot_chrom))];
    dbnd.h = train_bound(spot_near, spot_far);
    dvh_2d = quad2fun(dbnd.h, 0);
    dvh = @(x) dvh_2d([dvha(x(col.spot_achr)); dvhb(x(col.spot_chrom - numel(col.spot_achr)))]);
end
```

Then the existing content/border/bc training at lines 60-77 is unchanged **except** that
every hardcoded column range becomes the matching `col.*` field, and `apply_dv(dvh, ...)` is
now fed `near(:, col.spot)` (all spot columns) rather than `near(:, 1:3)`.

Finally record the layout alongside the bounds before saving (line 79-83 area):

```matlab
dbnd.spot_dims   = cfg.features.spot_dims;
dbnd.spot_achr_n = numel(cfg.features.spot_achr_dims);
```

### Step 5 — `load_dv_handles`: compose the spot DV

In `pipeline/load_dv_handles.m`, replace line 18 with:

```matlab
if isfield(dbnd, 'ha')
    dvha = quad2fun(dbnd.ha, 0);
    dvhb = quad2fun(dbnd.hb, 0);
    dvh2 = quad2fun(dbnd.h,  0);
    na = dbnd.spot_achr_n;
    dv.h = @(x) dvh2([dvha(x(1:na)); dvhb(x(na+1:end))]);   % x = column of spot LLRs, spot_dims order
else
    dv.h = quad2fun(dbnd.h, 0);
end
```

Add a consistency check right after loading, because the most likely runtime failure is
"config says colour, shipped bounds are achromatic":

```matlab
if isfield(dbnd, 'spot_dims') && ~isequal(dbnd.spot_dims, cfg.features.spot_dims)
    error('load_dv_handles:spotDimMismatch', ...
        'Trained bounds use spot dims %s but config asks for %s — retrain stage 5.', ...
        mat2str(dbnd.spot_dims), mat2str(cfg.features.spot_dims));
end
```

**After this step, stages 6, 7 and 8 need no changes.** `dv.h` has the same signature as
before; `content_features`/`content_dv_pair` already build the spot LLR vector in
`spot_dims` order.

### Step 6 — Demo plots

Five files slice the response matrix by hardcoded column and must use `col` instead:
`demo/plot_stage5.m:32-38`, `demo/plot_stage5_intermediate.m:30,45,59`,
`demo/plot_stage6_pairs.m:43-45`. Thread `col` through from wherever the responses were
produced (`compute_demo_responses` and `s5_train_decision_vars` both already return them).

`plot_stage5_intermediate.m` is the figure that actually shows the new structure. Currently
three rows (spot / edge / border). In colour mode it should become four:

| row | cloud | contribution bar | DV histogram |
|---|---|---|---|
| 1 | achromatic spot, 3-D, labels `A / CS-small / CS-large` | as now | achromatic spot DV |
| 2 | **chromatic spot, 2-D**, labels `B (blue-yellow) / R (red-green)` | 2 bars | chromatic spot DV |
| 3 | **full spot, 2-D**, labels `Achromatic spot DV / Chromatic spot DV` | 2 bars | full spot DV |
| 4 | edge, then border as before | | |

The existing `local_scatter2_bd` helper (line 99) already draws a 2-D cloud with its bound,
so rows 2 and 3 reuse it. Keep the achromatic-only layout (3 rows) when
`spot_chrom_dims` is empty — branch on `isfield(S.dbnd,'ha')`, not on a config flag, so the
figure always matches the artifact it is plotting.

---

## Part 4 — Updating `run_demo.m`

**Quick mode is always achromatic. Colour is offered only in full mode.** Quick mode
(`run_demo.m:99-103`) uses the shipped `decision_bounds_ecc_1.mat` and the shipped bins,
both of which are achromatic; retraining is exactly what quick mode exists to skip. So it
does not get a colour option — it just says so.

**1. Mode prompt.** Leave the existing quick/full prompt (lines 45-49) as is. In the quick
branch, force achromatic and state it plainly, e.g.

```matlab
cfg.features.color = false;   % quick mode uses the shipped achromatic artifacts
...
fprintf(['\nSkipping Stages 1-5 (Training). Using the pre-built shipped models.\n' ...
         'Quick mode runs the ACHROMATIC model: the shipped decision bounds and bin\n' ...
         'bounds were trained without the chromatic (B, R) features. Choose ''full'' mode\n' ...
         'to train and run the colour model.\n']);
```

Setting `cfg.features.color` after `cfg = config()` (line 34) means `config.m` must expose
the derived lists as a small local helper, or `run_demo` must recompute
`spot_chrom_dims` / `spot_dims` / `dv_dims` after flipping the flag. Prefer the former:
factor the four lines of D1 into a nested function in `config.m` and call it from both
places, so the derivation lives in one spot.

**2. Colour prompt in full mode.** Immediately after the user confirms full mode (line 57
area), ask, in the same style as the existing prompt:

```matlab
color_reply = '';
while ~ismember(color_reply, {'y', 'n'})
    color_reply = lower(strtrim(input('Train the COLOUR model (chromatic B/R spot features)? [y/n, default y]: ', 's')));
    if isempty(color_reply), color_reply = 'y'; end
end
cfg.features.color = strcmp(color_reply, 'y');
```

Everything downstream — stage 3's channel count, stage 4's dim list, stage 5's bound
structure — follows from that one assignment.

**3. Stage 4 dim list** (`run_demo.m:87`). Replace the literal with the config-derived list,
so dims 2 and 3 get bins when and only when colour is on:

```matlab
s4_optimize_bins(cfg, cfg.features.dv_dims, ecc, true);   % spot (achromatic + chromatic) + edge DV dims
```

**4. Stages 6-7 need a colour texture database when colour is on.** Stages 6 and 7 currently
run on Brodatz (`run_demo.m:159`, `itype = 3`), which is **grayscale**:
`cfg.textures.brodatz.gray = true` (`config.m:48`) replicates the one channel to R=G=B. For
such an input, LMS and then ABR are all fixed scalar multiples of the same gray image, so B
and R carry **no information the achromatic channel does not already have** — the chromatic
spot DV can only add noise. Pick the database from the mode:

```matlab
if cfg.features.color
    itype = 2;   % Fabric — colour texture sheets
else
    itype = 3;   % Brodatz — grayscale (the published achromatic demo)
end
```

**Fabric (`itype = 2`) is the chosen colour set.** `load_texture_images`
(`pipeline/load_texture_images.m:28-63`) also supports VisTex (`5`) and McGill (`6`), and all
three are present on disk with 60 sheets each, but do not substitute one for another without
asking. Print which set is in use so the figure is self-explanatory.

**5. Stage 8 needs no change.** It segments a natural image, which is colour regardless of
mode, and its only dependence on stage 7 is the merge parameters `out7.mc` / `out7.dgc`
(`demo/plot_stage8_natural.m:34-37`) — not Brodatz imagery. It picks up the colour model
automatically via Step 5.

**6. Narration.** The header comment (lines 6-28) and the Stage 5 `fprintf` (line 127)
should note that in colour mode the spot DV is built in two steps — achromatic
(A, CS-small, CS-large) and chromatic (B, R) — combined into the full spot DV that feeds the
content DV. Two sentences is enough.

---

## Part 5 — Numerical gotchas

1. **`-Inf` spot LLRs are much more common with B and R.**
   `vislab.nat_stat_bayes.multinomial_llr` clamps its output at 0 (`multinomial_llr.m:19`),
   and `pair_responses` takes `log` of it. Opponent chromatic channels in natural images are
   narrowly distributed, so two patches frequently produce identical histograms → LLR
   clamped to 0 → `log(0) = -Inf`. Bill hit exactly this and changed his outlier rule from a
   `|value| < 25` window to an explicit `isinf` test
   (`Bill's old code - revised/nat_near_far_dv_2.m:132`), and added a runtime fallback to
   the achromatic-only DV when the combined DV comes back `NaN`
   (`self_sup_tex_discrim.m:618-621`).

   This repo still uses the `|value| < 25` window (`pair_responses.m:8,31-32`). That window
   *does* reject `-Inf`, so it is not broken — but it will now reject a larger fraction of
   pairs, and it rejects the whole pair when any one feature is `-Inf`.

   **Decided: keep the `|value| < 25` rule as is.** Do not change it as part of this work.
   Just report the kept-pair count after the first colour training run so the effect is
   visible; if it turns out to be a problem, that is a separate decision. (Switching to
   Bill's `isinf` test would change the achromatic results too, so it is not free.)

2. **Do not port `b0 = 5e-5`.** Bill's revised code changed the power-suppression constant.
   This repo deliberately uses 16 (`config.m:59`, with a note that Geisler unified it in
   2026-07). Leave it alone; it is not part of the colour change.

3. **Bin bounds for dims 2 and 3 do not exist yet** in `data/models/AHEO_bins.mat`. Stage 4
   must run before stage 5, or `load_bin_bounds` will hand back a zero-width bin row and
   `histcounts` will fail or return garbage.

---

## Part 6 — Order of operations for the first colour run

1. Steps 1-3 (code). Set `cfg.features.color = true`, then regenerate the patch pairs:
   `s23_learn_priors_and_pairs(cfg, 1, true)`. **The existing `patch_pairs_ecc1.mat` is
   achromatic and cannot be reused for colour** — rename it aside rather than deleting it,
   since it is the artifact the achromatic mode still runs on and it takes a full pass over
   the natural images to rebuild.
2. `s4_optimize_bins(cfg, cfg.features.dv_dims, 1, true)` — adds dims 2, 3.
3. Steps 4-5 (code), then `s5_train_decision_vars(cfg, 1, 1, true)`.
4. Step 6 (plots) and Part 4 (`run_demo`).
5. **Regression check first:** rerun the whole chain with `cfg.features.color = false` and
   confirm it reproduces the current achromatic results exactly. Under this design it should
   be bit-identical — nothing in the achromatic path changes except where the column indices
   come from. If it is not, stop and find out why before looking at the colour numbers.
6. Then compare: colour vs achromatic near/far separability on natural-image pairs. Colour
   should be at least as good; if it is worse, gotcha 1 is the first suspect.

---

## Part 7 — Decisions

### Still open

1. **Whether to eventually ship colour-trained artifacts** so quick mode could offer colour
   too. Out of scope for this change — quick mode stays achromatic — but worth revisiting
   once the colour model is validated. Two notes for when it comes up:
   - It needs *two* artifacts, not one. As well as a colour `decision_bounds_ecc_1.mat`
     (`dbnd.h` means something different in each mode, so the two variants cannot share a
     filename), quick mode's `compute_demo_responses` needs bin bounds for dims 2 and 3.
     Those, however, can live in the *same* `AHEO_bins.mat`: it is a consolidated
     `[14 x n_ecc]` cell (`s4_optimize_bins.m:102-103`) and dims 2, 3 simply fill two
     currently-empty rows. Both files are tiny (1.9 KB and 677 bytes).
   - Colour quick mode should run at roughly achromatic speed. The extra work is two
     `histcounts` per patch and two small LLRs plus two quadratic evaluations per pair, while
     the dominant costs are unchanged: the per-patch FFT and steerable filtering, and the
     per-pair power DV, which takes logs over the full 4096-element spectrum
     (`power_llr_from_spectra.m:13-17`). Estimated from reading the code, not profiled.

### Resolved (do not reopen)

- **Outlier rule: keep `|value| < 25` unchanged.** Report the kept-pair count; do not tune it.
- **Colour texture database for stages 6-7: Fabric (`itype = 2`).**
- Patch-pair storage: keep `double`, accept ~2.9 GB / ~3.1 GB resident in colour mode. No
  `single`. Chunk the `s4`/`s5` loops if memory ever binds.
- Quick mode: always achromatic, and says so.
- Stage 8: unchanged; it segments a natural image and only inherits `mc`/`dgc` from stage 7.

---

## Part 8 — Execution log (corrections found while implementing)

Implemented per Parts 1-4 with three corrections the design missed:

1. **`config(color)` replaces the "one boolean + nested helper" idea.** Local functions
   after the main one in a `.m` file are private to that file, so `run_demo` could not
   call a `derive_spot_dims` helper. Instead `config` takes an optional `color` argument
   (default true) and derives everything internally; `run_demo` calls `config(false)` for
   quick mode and `config(color_choice)` after the full-mode prompt. One source of truth,
   no cross-file helper needed.
2. **`plot_stage5.m`, `plot_stage5_intermediate.m`, `plot_stage6_pairs.m` must use
   `load_dv_handles`, not `quad2fun(S.dbnd.h, 0)` directly.** These three files loaded
   `dbnd.h` and wrapped it with `quad2fun` themselves. That breaks in colour mode: `dbnd.h`
   is then a 2-D bound over `[achromatic spot DV, chromatic spot DV]`, not a function of the
   raw 3-or-5-element spot LLR vector these files were feeding it. Fixed by having all three
   call `load_dv_handles(cfg, ecc, ...)` and use its already-composed `dv.h` (and `dv.e/c/b/bc`)
   instead of loading+wrapping bounds by hand. `plot_stage5_intermediate` additionally needs
   `dbnd.ha`/`dbnd.hb` directly (to show the two intermediate DVs before combining), so it
   still loads `dbnd` itself but only for that -- edge/border/full-spot go through the composed
   handles like everywhere else.
3. **Stage 6 in `run_demo.m` is not `s6_selfsup_discrimination.m`.** It is
   `plot_stage6_pairs` -> `sample_brodatz_pairs`, a separate qualitative same/different demo
   that hardcoded Brodatz independently of the `itype` variable used by Stage 7. Brodatz is
   grayscale, so in colour mode every chromatic spot feature is a fixed multiple of the
   achromatic one (histograms of near-degenerate values) -- not just uninformative but liable
   to reject most pairs outright via the `|value|<25` outlier window. Fixed by generalizing
   `sample_brodatz_pairs.m` -> `sample_texture_pairs.m` (adds an `itype` argument, colour-aware
   channel count like `sample_nearfar_pairs`) and having `plot_stage6_pairs` pick Fabric/Brodatz
   from `cfg.features.color` itself, the same rule Stage 7 uses.

Also folded in along the way (mechanical, no design change): `demo/pair_responses.m` moved to
`pipeline/pair_responses.m` and made column-count-agnostic (returns a `col` struct); the local
`pair_responses` in `s5_train_decision_vars.m` deleted in favor of the shared one; the two
`patch_to_a` call sites that read *already-prepared* pairs (`pair_responses.m`,
`s4_optimize_bins.m`'s `feature_values`) now read the array as-is instead of calling
`patch_to_a`/`patch_to_abr` (Step 1c); two callers in `experiments/adaptive_hist_exp.m`
(unrelated WIP script, not part of this feature) updated for the `sample_texture_pairs` rename
so that file isn't left broken.

**Not yet run.** `s23_learn_priors_and_pairs` needs to be rerun once (in either colour setting)
before ANY `full`-mode run works, achromatic included -- the existing `patch_pairs_ecc1.mat`
predates the `color` tag entirely, and `s4`/`s5` now refuse to load a pairs file missing that
tag rather than guess. This is expected (Part 6 already called for regenerating it), not a bug.

---

## Part 9 — Follow-up: figures actually showing colour

Part 8's execution ran once (full mode, colour) and surfaced a gap: the pipeline was colour-
correct but every demo figure still displayed grayscale/tinted-overlay regardless of mode.
Fixed, all in `demo/` (visualization only, no numeric-pipeline change):

- **`patch_to_rgb_display.m`** (new) -- single shared inverse-colour helper. `nch=1` -> min-max
  + gamma grayscale (unchanged behaviour). `nch=3` -> inverts the LMS->ABR rotation (`space=
  'abr'`, for stored patch pairs) or skips straight to the RGB->LMS inverse (`space='lms'`, for
  GTR/natural images, which are stored as LMS, never rotated -- see
  `pipeline/neighbor_far_responses.m`'s docstring). Both matrices are loaded from
  `cfg.paths.data_root` the same way `plot_stage1.m`/`rgb2lms.m` already do; this is a display
  approximation (not exact where the forward transform clipped), never used by the model itself.
- **`overlay_region_boundaries.m`** (new) -- `bwboundaries` outlines instead of an
  alpha-tinted `imagesc`, so region structure reads on top of a real colour image, in both
  modes (IPT is already a dependency via `imresize`).
- **`plot_stage2.m`** -- adds B/R pixel prior+bin panels in colour mode (5x2 grid; achromatic
  mode's 4x2 layout is untouched, verified index-for-index against the original).
- **`plot_stage3.m`, `plot_stage6_pairs.m`** -- `local_show_pair` now passes full-channel
  patches through `patch_to_rgb_display(..., 'abr')`. Both halves of a pair are concatenated
  *before* calling it so normalization/gamma is computed jointly -- calling it on each half
  separately would rescale them independently and hide real brightness differences between
  the two patches, silently changing what the figure means.
- **`plot_stage7.m`, `plot_stage8_natural.m`** -- replaced the forced
  `mean(pimg,3)`-grayscale + jet-alpha overlay with `patch_to_rgb_display(cfg, pimg, 'lms')` +
  `overlay_region_boundaries`. No `cfg.features.color` branch needed here: `pimg` is always
  3-channel LMS regardless of the spot-feature colour switch (`load_texture_images` loads all
  three channels unconditionally), so it renders as true grayscale for Brodatz and true colour
  for Fabric/VisTex/McGill on its own -- controlled entirely by which `itype` `run_demo` already
  picks from `cfg.features.color`.

## Part 10 — Follow-up: shipping BOTH colour and achromatic bounds

Quick mode used to hardcode `config(false)` (achromatic). A first fix made it detect colour vs
achromatic from whichever single `decision_bounds_ecc_1.mat` happened to be shipped -- but a
`full` colour run overwrites that one file, permanently destroying the achromatic artifact, so
"say no to colour" had no shipped achromatic bounds left to fall back to. Fixed properly by
shipping **both** modes as separate files, so either can be requested at any time:

- **`pipeline/decision_bounds_filename.m`** (new) -- single source for the filename:
  `decision_bounds_ecc_<ecc>.mat` (achromatic) or `decision_bounds_ecc_<ecc>_color.mat` (colour).
  `dbnd.h` means something different in each mode, so they cannot share a filename (same
  reasoning as `AHEO_bins.mat` vs `AHE_bins.mat` for optics). Used by `s5_train_decision_vars`
  (save), `load_dv_handles` and `demo/plot_stage5_intermediate` (load), and `run_demo` (artifact
  check / quick-mode file pick) -- one function, no filename string duplicated anywhere else.
- **`run_demo.m`** (quick-mode branch) -- asks the same colour y/n question as full mode (no
  detection needed now: the two modes are just two files), builds `cfg` from the answer, then
  checks whether that mode's file is actually shipped; if not, falls back to whichever mode IS
  shipped, with a clear notice, rather than erroring or silently doing the wrong thing.
- **`vislab-common/+vislab/+nat_stat_bayes/load_bin_bounds.m`** -- added a loud error if a
  requested feature has no trained bins at that eccentricity (was: silently `n_bins(f) = 0`),
  since the achromatic and colour models share one bins file (`AHEO_bins.mat`) that must have
  valid entries for whichever dims the requested mode needs.
- Renamed the already-shipped colour-trained artifact from `decision_bounds_ecc_1.mat` to
  `decision_bounds_ecc_1_color.mat` (`git mv`) to match the new scheme. An achromatic-mode
  `decision_bounds_ecc_1.mat` has since been trained and shipped too (confirmed: `dbnd.spot_dims
  = [1 13 14]`, no `ha`/`hb` fields), so both modes are now genuinely available in quick mode.

## Working rules for whoever executes this

- Do **not** run MATLAB headlessly to self-verify. Make the edits and hand back to Abhranil
  to run.
- Do **not** commit unless explicitly asked, and never push.
- Cite `file:line` for any claim about what the code does.
