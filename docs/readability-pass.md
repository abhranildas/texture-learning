# Blueprint: repo-wide readability pass (behaviour-preserving)

Read every `.m` file in the repo and clean it in place — better names, complete header docs,
consistent conventions, reflowed long lines — under the constraint that **no output changes**.
What makes this worth doing as a distinct pass is that the constraint is **mechanically
checkable**, so the diff does not need to be trusted, only verified. Three tiers of change,
defined fully in section 3: Tier A, Tier B, Tier C — described under their own headings below.

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">0. Status</h2></summary>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">0.1 Tier A — complete</h3></summary>

<div style="margin-left:1.5em">

Comments, header docs, whitespace, reflow, file-local renames. Checked by `isequal` on a
canonical AST fingerprint — no execution needed.

All 66 in-scope files, one commit per tranche on `main`. Nothing left to do.

- [x] **0.1.0.** Tooling: `canon`/`check_tier_a`/`assert_rename_bijection`, golden-output harness.
- [x] **0.1.1.** `+segmentation/` + `+gtr/`
- [x] **0.1.2.** `pipeline/`
- [x] **0.1.3.** `demo/`
- [x] **0.1.4.** `twin-net/`
- [x] **0.1.5.** Root: `config.m`, `setup.m`, `run_demo.m`
- [x] **0.1.6.** `experiments/adaptive_hist_exp.m`

Full detail, tranche sequencing, and per-tranche findings: section 4.1.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">0.2 Tier B — complete</h3></summary>

<div style="margin-left:1.5em">

Semicolon insertion, preallocation, `find`→logical indexing, deleting a provably unused
assignment. Checked by a whitelisted-pattern diff **plus** a runtime golden-output match.

- [x] **0.2.0.** Extend the golden harness. `tools/golden_harness.m` now covers all tranches except
      one script. Entry points added this round: `+gtr/` (`grow_region_masks`,
      `sample_texture_ids`), `demo/` (`sample_texture_pairs`, `apply_dv`; `compute_demo_responses`
      already covered via `pair_responses`), `twin-net/` (`forwardTwin`, `predictTwin`,
      `poolStats`, on a tiny synthetic `dlnetwork`). Captured and replay-verified.
- [x] **0.2.1.** `+segmentation/` + `+gtr/` — no Tier-B opportunities found (see section 4.2).
- [x] **0.2.2.** `pipeline/` — one fix, `list_natural_images.m` (see section 4.2).
- [x] **0.2.3.** `demo/` — no Tier-B opportunities found (see section 4.2).
- [x] **0.2.4.** `twin-net/` — one fix, `texture_same_diff_patches_net.m`; one deliberate
      non-suppressed line left alone and commented (see section 4.2).
- [x] **0.2.5.** Root: `config.m`, `setup.m`, `run_demo.m` — one trivial Tier-A-level cleanup in
      `setup.m` found along the way (see section 4.2); no genuine Tier-B target in any of the three.
- [x] **0.2.6.** `experiments/adaptive_hist_exp.m` — no Tier-B opportunities found (pattern-check
      only; see section 4.2).

Coverage gaps found while extending the harness, and the two Tier-B fixes made, are detailed in
section 4.2.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">0.3 Tier C — never do, in this pass</h3></summary>

<div style="margin-left:1.5em">

Bug fixes, signature changes, merging duplicate functions, reordering statements — forbidden in
this pass, always. Bugs found are recorded, never fixed.

Not a to-do list — a **never-do** list, left unchecked on purpose. These are things this pass
explicitly must not touch, no matter how tempting. Full rationale in section 3.

- [ ] **0.3.1.** Collapse the two copies of `local_show_pair` (`demo/plot_stage3.m`, `demo/plot_stage6_pairs.m`)
- [ ] **0.3.2.** Collapse `experiments/adaptive_hist_exp.m`'s `collect_natural`/`collect_brodatz`
- [ ] **0.3.3.** Convert `pair_responses`' 10 positional arguments (or similar) into an `arguments` block
- [ ] **0.3.4.** Turn the three scripts (incl. `experiments/adaptive_hist_exp.m`) into functions
- [ ] **0.3.5.** Delete commented-out code
- [ ] **0.3.6.** Reorder statements, even when it looks purely cosmetic
- [ ] **0.3.7.** Rename any zone-2 `cfg.*` cross-file field (listed in section 4.1.1) — deferred to
      its own pass
- [ ] **0.3.8.** Rename any zone-3 frozen `save`/`load` name (listed in section 4.1.1)
- [ ] **0.3.9.** Fix any bug found along the way — record it instead (also logged, as a repo-wide
      to-do item, in `docs/bill-2026-revisions.md`):
  - [ ] **0.3.9.1.** `+segmentation/group_patches.m:112` discards `assign_isolated_patches`'s third
        output (`ngrps`) and recomputes group growth separately in the caller — two code paths
        compute the same count for the same event; confirm they can't diverge.
  - [ ] **0.3.9.2.** `+segmentation/neighbor_similarity_matrix.m` header asserts `cfg.gtr.power_suppress`
        and `cfg.dv.power_suppress` are "both 16 since Geisler unified b0" — nothing in code
        enforces this; editing one without the other would silently desync the border/content
        combination from `content_similarity_matrix.m`. Same coupling recurs in `config.m`.
  - [ ] **0.3.9.3.** `+segmentation/assign_isolated_patches.m:10-15` documents its own deliberate
        behaviour change from the original `iso_patch.m` (`i~=j` → `other_idx~=patch_idx`),
        already flagged in-file as changing the reproduced paper numbers — resurfaced here so
        it isn't missed in a skim.
  - [ ] **0.3.9.4.** `+segmentation/merge_similar_regions.m` merges exactly one region pair per call by
        design; `group_patches.m` calls it once per pass, so there is no iterative multi-merge
        unless a caller loops it.
  - [ ] **0.3.9.5.** `pipeline/s4_optimize_bins.m` (`eval_r`, ~line 245) rejects outliers with `rv < -25`
        only — no upper-bound check — while `pair_responses.m`'s outlier rejection for the same
        kind of LLR quantity is two-sided. Comment marks it "as in the original," so likely
        long-standing, but the asymmetry is worth confirming with Geisler.
  - [ ] **0.3.9.6.** `pipeline/self_sup_decision.m`'s `'bc_noshift'` method branch is unreachable: neither
        `s6_selfsup_discrimination.m` nor `s7_segment_gtr.m` ever passes it. Dead code unless
        called directly from outside the pipeline.
  - [ ] **0.3.9.7.** Three bugs already flagged in-file by a previous author (not new, resurfaced for
        visibility): `neighbor_far_responses.m`'s header documents a fixed
        stateful-renormalization bug in the original code; `s7_segment_gtr.m`'s header
        documents an ecc-dependent neighbour-distance fix; `s6_selfsup_discrimination.m`'s
        header documents a `pd`/`eccb` inconsistency.
  - [ ] **0.3.9.8.** `plot_stage7.m`'s header documents `method` as `'nc'` or `'bc'`, but the code
        (`plot_stage7.m` and identically `plot_stage8_natural.m`) does
        `struct('nc', 'c_shft', 'ncb', 'bc').(method)`, which only has fields `nc` and `ncb` —
        passing the documented `'bc'` value would error. Currently unreachable, but the header
        disagrees with the code it describes.
  - [ ] **0.3.9.9.** `run_demo.m`'s "missing artifacts" error text tells the user to set a
        `run_training_stages` variable that doesn't exist anywhere in the repo — the actual
        switch is `demo_type = 'full'`.
  - [ ] **0.3.9.10.** `run_demo.m`'s `try/catch err/rethrow(err)` around the `s7_segment_gtr` call is a
        no-op.
  - [ ] **0.3.9.11.** `setup.m`'s `ensure_addon_on_path` guards an optional 5th argument that both call
        sites always pass — dead defensiveness, not a bug.
  - [ ] **0.3.9.12.** Zone-2 `cfg.*` rename candidates spotted for whenever that tranche happens (not
        touched): `cfg.gtr.szp`, `cfg.gtr.dcrit`, `cfg.gtr.n_regions` (comment still calls it
        `ntexr`), `cfg.natural.max_val`.

Tier C has no work log (section 4.3) beyond this list — nothing in it is ever implemented in
this pass.

</div>

</details>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">1. Scope and measurements</h2></summary>

<div style="margin-left:1.5em">

Every number in this document was measured on the repo as it stands (MATLAB R2024b), not
estimated. Re-measure before trusting any of them after substantial changes.

**Scope, precisely.** `Bill's old code/` and `Bill's old code - revised/` are excluded
entirely — 93 `.m` files of ancestral code, gitignored, kept for reference only. That leaves
**66 files, 5744 lines** in scope: `+segmentation/` (10 files, 622 lines), `+gtr/` (2, 122),
`pipeline/` (21, 1449), `demo/` (18, 1352), `twin-net/` (11, 847), the three root files
`run_demo.m`/`setup.m`/`config.m` (547), and `experiments/adaptive_hist_exp.m` (805).

**What is actually wrong with the files**, measured, not assumed:

- **Lint is a non-issue.** `checkcode` reports 11 messages across all 66 files, confined to six
  files. 62 of 66 are lint-clean.
- **Formatting is nearly clean.** Zero tab-indented files, every file has a header comment. The
  one real defect: **37 files carry at least one line over 100 characters**, worst
  `demo/plot_stage1b_gradients.m:128` (159 chars). Two files hold a third of the total:
  `experiments/adaptive_hist_exp.m` (62 long lines) and `twin-net/train_net.m` (31).
- **Header docs are half-finished.** All 66 open with a comment, but only 34 carry an
  `Inputs`/`Output` block. Zero have a `See also` line. No `Contents.m` anywhere. This was the
  single largest, cheapest readability gap.
- **Names are the real problem.** Heavy abbreviation, consistent but never defined: `psz` 321
  occurrences, `ecc` 173, `dv` 112, `col` 94, `pimg` 65, `ngrps` 50, `itype` 44, `nsmp` 33,
  `b0` 24, plus bare loop counters `i`/`j`.
- **Names diverge across call boundaries** — e.g. `prep_grid` returns `[P, G, Gn]` but
  `content_features` receives the same three renamed `(P, G, E, …)`.
- **Two naming conventions coexist**: the repo is snake_case except `twin-net/`, which is
  camelCase in both file and identifier names.
- **Three builtin shadows**: `image` used as a parameter name in three `+segmentation/` files.
- **Commented-out code is present but small**: 113 of 5744 lines look like commented-out code.
  Not removed (Tier C) — flagged as a diagnostic for a separate pass.
- **No `arguments` blocks, no `inputParser` anywhere.** Adding them is Tier C.

**The style target already exists** — do not invent a new one. `vislab-common/+vislab/+lib/
watson_otf.m` is the exemplar (summary line, fully-qualified signature, `Inputs`/`Output` with
units, `See also`). Within this repo, `+segmentation/prep_grid.m` and `pipeline/pair_responses.m`
are the closest existing approximations. Verified: no in-scope file shares a name with anything in
`vislab-common` or `Bill's old code*/`, so there is no already-superseded-elsewhere trap here.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">2. The check (Tier A) and what the repo affords for Tier B</h2></summary>

<div style="margin-left:1.5em">

`mtree` parses a `.m` file into MATLAB's own syntax tree, and `tree2str` prints it back in
canonical form: comments stripped, whitespace/bracket spacing normalised, missing `end` supplied.

```matlab
canon = @(f) tree2str(mtree(f,'-file'));
```

This gives a fingerprint blind to exactly what Tier A is allowed to change, sensitive to
everything else. Verified: succeeds on all 66 in-scope files.

Reverse-rename check: clean a file (renames, header, reflow), then undo the rename map on the
canonical form of the new file and assert it's identical to the canonical form of the old one:

```matlab
c_new = canon(new_file);
for k = 1:size(renames,1)   % renames = {new_name, old_name}
    c_new = regexprep(c_new, ['(?<![A-Za-z0-9_.])' renames{k,1} '(?![A-Za-z0-9_])'], renames{k,2});
end
isequal(canon(old_file), c_new)   % must be true
```

The lookahead `(?![A-Za-z0-9_])` matters: without it a short name (`patch`) can wrongly match
inside a longer one (`patch_size`). The rename map itself must be a bijection with disjoint
domain/range — assert this before using it:

```matlab
dom = renames(:,1); ran = renames(:,2);
assert(numel(unique(dom)) == numel(dom));
assert(numel(unique(ran)) == numel(ran));
assert(isempty(intersect(dom, ran)));
```

Caveat: `mtree`/`tree2str` are undocumented MATLAB APIs — pin the MATLAB version in commit
messages (this pass used R2024b throughout).

**Tier B's extra requirement: runtime golden output.** Unlike the sibling `camouflage_detection`
repo (~40% of files don't execute), this repo runs, so Tier-B changes can be checked against real
outputs, not just pattern-matching. `tools/golden_harness.m` captures/replays deterministic
outputs (`rng(cfg.seed)`, never through `run_demo`, which uses `rng('shuffle')` on some paths) for
entry points across every tranche except `experiments/adaptive_hist_exp.m` (a script — see
section 4.2). All nine `parfor` loops in the repo write into a sliced output rather than
a reduction variable, so worker order can't change a float sum — safe to leave alone; if a future
edit turns one into a reduction, that edit is Tier C.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">3. Three tiers of change, in full</h2></summary>

<div style="margin-left:1.5em">

| Tier | Change | Canonical diff | Verification |
|---|---|---|---|
| **A** | Comments, header docs, whitespace, reflow, blank-line grouping, file-local renames | empty (after reverse rename) | `isequal` — fully automatic, no execution |
| **B** | Adding a suppressing `;`, preallocation, `find`→logical indexing, deleting a provably unused assignment | non-empty but must match a whitelisted pattern | pattern check **plus** runtime golden output |
| **C** | Bug fixes, signature changes, adding `arguments` blocks, merging duplicate functions, reordering statements, changing accumulation order in a float reduction, anything touching the RNG stream, **deleting commented-out code** | — | **forbidden in this pass** |

Semicolon insertion is Tier B, not A: `tree2str` preserves display-vs-suppress, so the canonical
diff is exactly `X` → `X;` — trivially whitelisted, but not invisible.

Tier C matters most. The tempting changes in this repo are all Tier C (see section 0.3's list).
Every one of them changes output, call sites, or validation behaviour. Keeping them out is
what makes the diff skimmable instead of line-by-line.

When the pass uncovers a *bug* — and it will — **record it in the findings list and leave the
code broken**. That recording is the main scientific payoff; the tidier code is a side effect.

Statement reordering is Tier C even though it looks cosmetic, purely because the check cannot
distinguish a safe reorder from an unsafe one.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">4. Tier-by-tier details and work log</h2></summary>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">4.1 Tier A — renaming zones, tranches, and findings log</h3></summary>

<div style="margin-left:1.5em">

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">4.1.1 Renaming: three zones</h4></summary>

<div style="margin-left:1.5em">

The rename map is the pass's most valuable artifact and its main divergence risk — build it
first, once, repo-wide, per tranche.

1. **File-local variables — free.** `psz`→`patch_size`, `pimg`→`region_image`, `nsmp`→
   `n_samples`, `ngrps`→`n_groups`, `ptch`→`patches`, `c0`/`m0`→`target_contrast`/`target_mean`,
   `i`/`j`→`row`/`col` or a domain name, and the three `image` shadows. Because these are
   file-local, `canon` makes them completely safe.
2. **Cross-file vocabulary — repo-wide, or not at all.** Two sub-vocabularies:
   - The `cfg` struct: 54 distinct `cfg.*` field paths defined in `config.m` and read everywhere.
     Renaming any of them touches `config.m` plus every reader. **Its own tranche, deferred.**
   - Function arguments named consistently across the repo (`ecc`, `itype`, `psz`, `dv`, `col`).
     High value because they're everywhere — but a half-done rename is worse than none.
3. **Serialised variable names — forbidden.** Names inside `.mat` files: `coeff`, `ea`, `Na`,
   `ptchn`, `ptchf`, `pcnt`, `color`, `bin_bounds`, `n_bins`, `eccs`, `dbnd`, `near`, `far`, `same`,
   `diff`, `same_brod`, `diff_brod`, `net`, `fcParams`, `lms`. Five shipped artifacts in
   `data/models/` depend on them. A local variable that *holds* one of these can be renamed; the
   string in the `save`/`load` call cannot. Note `diff` is also a builtin-shadow candidate in
   `twin-net/texture_same_diff_patches_net.m:68` — there it's a frozen save name; elsewhere it's
   free. Check which you're looking at.

**Units are the other half of naming** — state them in every header: `cfg.optics.ppd = 60`
pixels/deg for all images, `cfg.patch.size`/`cfg.patch.image_size` in pixels, `ecc` an integer
divisor (not degrees), `cfg.optics.pupil_diameter` in mm, `cfg.optics.wavelength` in nm,
`cfg.dv.edge_thresh` in image units.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">4.1.2 Tranches, sequencing, and model assignment</h4></summary>

<div style="margin-left:1.5em">

The work is concentrated very differently from what file count suggests: 18 files are under 30
lines, while the five files ≥200 lines hold 34% of all code. Batch the small ones; budget real
time for the large ones.

| # | Tranche | Files / lines | Model / effort | Why |
|---|---|---|---|---|
| 0 | Rename map + `canon`/checker + golden harness | — | Opus, medium | Every other step trusts this being right |
| 1 | `+segmentation/` + `+gtr/` | 12 / 744 | Opus, medium | Sets naming conventions for everything downstream |
| 2 | `pipeline/` | 21 / 1449 | Sonnet, medium | Mechanical once the map exists; clean helpers before callers |
| 3 | `demo/` | 18 / 1352 | Sonnet, medium | Independent files, except duplicated `local_show_pair` — clean both copies identically |
| 4 | `twin-net/` | 11 / 847 | Sonnet, medium | camelCase→snake_case as one decision applied 11 times |
| 5 | Root: `config.m`, `setup.m`, `run_demo.m` | 3 / 547 | Opus, medium | `config.m` is the zone-2 vocabulary source; `run_demo.m` is user-facing |
| 6 | `experiments/adaptive_hist_exp.m` | 1 / 805 | Sonnet, medium | Large, exploratory, no callers |

**Escalation rule, any tranche:** if `isequal(canon(old), canon(new))` fails and the cause isn't
obvious from the diff — stop, don't retry with a bigger prompt, hand that one file to Opus at
medium (high only if that also can't explain it). Don't loosen the check instead.

**"Done" checklist for a Tier-A tranche** (all six tranches satisfy all of these):

- [x] `isequal(canon(old), canon_with_renames_reversed(new))` true for every file.
- [x] Every file has a header matching the `watson_otf.m` shape: summary, signature,
      `Inputs`/`Output` with units, `See also`.
- [x] No line exceeds 100 characters except the documented string-literal exceptions (listed per
      tranche in section 4.1.3) — each would require turning a string literal into a `horzcat`
      expression, a real AST change forbidden by Tier A.
- [x] No zone-3 frozen identifier renamed, no `save`/`load` string literal changed.
- [x] Each package touched has a `Contents.m` (`+segmentation/`, `+gtr/`).
- [x] Bugs found are written down and not fixed (section 0.3, and section 4.1.3 per-tranche).

One commit per tranche, each stating the checker result.

**Housekeeping done first:** `demo/plot_stage8_natural-LA-CPSA96551WN.m` (a OneDrive
filename-conflict copy) and `demo/pair_responses.m` → `pipeline/` were resolved in the tools
commit, before any tranche started.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">4.1.3 Findings log</h4></summary>

<div style="margin-left:1.5em">

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 0 — tooling</h5></summary>

<div style="margin-left:1.5em">

`canon`/`check_tier_a`/`assert_rename_bijection` built in `tools/`, verified against the worked
`prep_grid.m` example — round-trips clean, MATLAB R2024b. `tools/golden_harness.m` originally
captured/replayed five entry points under `rng(cfg.seed)`: `segmentation.prep_grid` (checksum
`2.5339e+07` for a 256×256×3 synthetic image), `sample_demo_pairs` (size `[64 128 3 7820]`),
`pair_responses` (checksum `2.2431e+05`, 7819/7820 pairs kept), `load_dv_handles` (five handles),
`content_similarity_matrix` (checksum `1.4421e+03`). One subtlety found: `sum()` over a cell array
from `cellfun` only collapses one dimension, so a naive checksum on a 2-D grid can silently return
a row vector instead of a scalar — fixed with an explicit `'all'` reduction.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 1 — `+segmentation/` + `+gtr/`</h5></summary>

<div style="margin-left:1.5em">

All 12 files passed `check_tier_a` with file-local rename maps; both `Contents.m` files added.
Naming decision (binding for later tranches): `content_features.m`'s third parameter is named
`edge_channel`, not `achrom_norm`, since the caller may pass either the raw or contrast-normalized
achromatic channel — forcing `achrom_norm` would assert something not always true. `cfg.dv.sd1/
nsd1/sd2/nsd2` local aliases were left as-is (they mirror `cfg.dv.*` field names 1:1; renaming
only the local copy would introduce a mismatch — defer to the zone-2 `cfg` tranche).

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 2 — `pipeline/` (21 files)</h5></summary>

<div style="margin-left:1.5em">

All 21 passed `check_tier_a`; the golden harness was re-run in replay mode afterward and matched
bit-for-bit. `psz`→`patch_size` applied throughout. `pair_responses.m`'s parameters renamed
`nh`→`spot_llr_dims`, `ne`→`edge_llr_dims`, `b0`→`power_suppress`, `thresh`→`edge_thresh` — now
the settled vocabulary for that concept repo-wide. Two lines (`s4_optimize_bins.m:49`,
`s5_train_decision_vars.m:70`) stay over 100 chars: an identical 97-character error string whose
splitting would be a real AST change — documented exception.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 3 — `demo/` (18 files)</h5></summary>

<div style="margin-left:1.5em">

**Process note for any future tranche:** this repo's working tree already carried a large,
legitimate, *uncommitted* "color extension" work-in-progress mixed into `demo/` (and some
already-"finished" `pipeline/` files) before this tranche started — confirmed with the user as
pre-existing feature work, not to be touched or reverted. Consequence: `git diff HEAD` /
`check_tier_a` against the last commit is **not a valid baseline** for such a file — it would
produce large false "diffs" that are pre-existing content, not this tranche's edits. Verification
instead used a pre-edit backup copy of the file's current on-disk content, diffed against the
post-edit file. Use this method for any file with uncommitted pre-existing changes.

All 18 files verified. `local_show_pair` (`plot_stage3.m`/`plot_stage6_pairs.m`) confirmed
byte-identical between both copies. One documented line-length exception:
`plot_stage6_pairs.m:87` (123 chars, unbreakable string literal).

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 4 — `twin-net/` (11 files)</h5></summary>

<div style="margin-left:1.5em">

CamelCase→snake_case identifier unification applied as one consistent decision across all 11
files, verified against `git show HEAD:<file>` (no pre-existing WIP contamination here, unlike
`demo/`). Representative renames: `miniBatchSize`→`mini_batch_size`, `pairLabels`→`pair_labels`,
`learningRate`→`learning_rate`, `numIterations`→`n_iterations`. File names and top-level function
names untouched (Tier C) since they must match the filename. `fcParams` deliberately left
untouched everywhere (zone-3 frozen, saved into `data/models/net_on_nat.mat`), including its own
`FcWeights`/`FcBias` struct fields. Zero lines over 100 characters after reflow.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 5 — Root: `config.m`, `setup.m`, `run_demo.m`</h5></summary>

<div style="margin-left:1.5em">

Same backup-vs-HEAD split as Step 3: `config.m`/`run_demo.m` carry pre-existing color-extension
WIP, verified against a pre-edit backup; `setup.m` had no dirty diff, verified against HEAD
directly. Additionally ran `config(true)`/`config(false)` on backup vs. edited copy and confirmed
`isequal` structs. **No `cfg.*` field was renamed, added, or removed** by this tranche. Added the
unit annotations called for in section 4.1.1. `run_demo.m`'s `rng('shuffle')` byte-for-byte
unchanged. 5 documented line-length exceptions in `setup.m`, 1 in `run_demo.m`.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 6 — `experiments/adaptive_hist_exp.m` (805 lines, untracked)</h5></summary>

<div style="margin-left:1.5em">

User confirmed this file is being kept. No HEAD baseline exists (whole file untracked); verified
against a pre-edit backup copy. Rename map applied (all file-local): `patch_size`←`psz`,
`n_bins`←`nbin`, `patches`←`ptch`, and others. One rename could not extend to a struct field:
`hist_gap_collect` saves its patch-size field as `D.psz`/`S.psz` into `hist_gap_data.mat` —
`check_tier_a`'s regex excludes dot-qualified names, so this stays `psz` while the local variable
is `patch_size`, noted in-file. The two near-identical local functions `collect_natural`/
`collect_brodatz` were cleaned independently, **not merged** (Tier C). All three `rng('shuffle')`
calls left byte-for-byte unchanged. 5 documented line-length exceptions, all unbreakable string
literals.

</div>

</details>

</div>

</details>

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">4.2 Tier B — coverage gaps and work log</h3></summary>

<div style="margin-left:1.5em">

**Coverage gaps found while extending the golden harness, and their resolutions:**

- **`experiments/adaptive_hist_exp.m` is a script, not a function** — its local functions
  (`hist_gap_collect` etc.) have no callable entry point from outside the script, and
  restructuring it into functions would itself be Tier C. **Decision: verify this file's
  Tier-B edits with the structural pattern check only, no runtime golden check.**
- **`twin-net/` needed the Deep Learning Toolbox** to execute at all — resolved, toolbox is now
  installed and golden entry points are captured.

**Per-tranche work log:**

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 1 — `+segmentation/` + `+gtr/`</h4></summary>

<div style="margin-left:1.5em">

No Tier-B edits made — none of the candidate patterns exist in this tranche. Checked all 12
files for: missing suppressing semicolons (none — every apparent hit was a trailing `%` comment
after an already-present `;`), `find(...)` calls (zero in the tranche), unpreallocated array
growth (`(end+1)` or growing-in-loop patterns — none; every accumulator is preallocated with
`zeros`/`cell` sized up front), and unused-assignment lint warnings (`checkcode` reports only the
two pre-existing `parfor`-broadcast notes in `content_features.m`/`content_similarity_matrix.m`,
already logged as Tier C performance notes, not Tier-B targets). This tranche was already this
clean coming out of Tier A. No golden-harness re-run needed since nothing changed.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 2 — `pipeline/` (21 files)</h4></summary>

<div style="margin-left:1.5em">

One real Tier-B fix: `list_natural_images.m` grew a cell array one element at a time inside a
nested loop (`files{end+1} = ...`, flagged `%#ok<AGROW>` by the author, i.e. already known and
suppressed rather than fixed). Rewrote to size `files` once from a precomputed total count and
fill it by index — same file order, same output. Verified by capturing `list_natural_images(cfg)`'s
real output before the edit and asserting `isequal` against a fresh call after (391 files, exact
match); also re-ran `golden_harness('replay', ...)` afterward and it still matches bit-for-bit.
One line needed a reflow to stay under 100 characters after the rename (`listing`→`listings{set_idx}`
pushed it over).

The rest of `pipeline/` has no Tier-B opportunities: `checkcode` reports zero warnings repo-wide
now (the one AGROW warning above was the only one); no other `find(...)` calls exist except
`s4_optimize_bins.m:59` (`find(eccs == ecc, 1)`) paired with `eccs(end+1) = ecc` at `:61` — not a
real target, since that list grows by exactly one element *once per function call* (not inside a
loop; `eccs` holds at most the handful of eccentricities ever trained, e.g. `[1 2 4 8]`), so
there's no repeated-growth pattern to preallocate against and no mask to index with instead of a
scalar `find`. No missing suppressing semicolons found anywhere in the tranche.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 3 — `demo/` (18 files)</h4></summary>

<div style="margin-left:1.5em">

No Tier-B edits made. `find(...)` appears in `plot_stage1b_gradients.m:202`
(`h_pcs = find(pc_isH); v_pcs = find(~pc_isH)`), `plot_stage2.m:25,33-34`, and
`plot_stage8_natural.m:44` — all genuinely need the numeric indices themselves (used to index
into a second array, print a `PC%d` label, or as a scalar `xlim` bound), so none reduce to a
"find→logical indexing" simplification. No unpreallocated growth, no missing semicolons.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 4 — `twin-net/` (11 files)</h4></summary>

<div style="margin-left:1.5em">

One real fix: `texture_same_diff_patches_net.m` grew `all_tex`/`brod_tex` one cell at a time
inside a nested loop (`all_tex{end+1} = A`, `brod_tex{end+1} = A`, both flagged
`%#ok<SAGROW>` by the author). Rewrote with a sizing pre-pass (`dir`/`min`/`numel` only, no RNG
draws) that computes each database's `n_use` up front, then preallocates both cells and fills
them by an incrementing index in the original loop -- same iteration order, so `randperm`'s
draws happen in exactly the same sequence as before. Verified two ways: `checkcode` no longer
flags either line, and an isolated synthetic replica of the loop structure (same per-database
counts and RNG calls, stand-in "textures") gives `isequal` on both output cells between the old
(growing) and new (preallocated) logic. Did not run the real script end-to-end for this check --
it performs slow, real disk I/O and overwrites `data/stimuli/textures/patch_pairs.mat`, so a full
run wasn't done without asking first.

One line deliberately **not** touched: `train_net.m:405`,
`average_accuracy = mean(accuracy)*100`, MATLAB's only other lint hit in this tranche
("add a semicolon to hide the output"). The variable is never read again, so the missing `;` is
the script's only way to show that number when run interactively -- the user confirmed this is
deliberate and asked that it be left alone, with a comment added
(`% no ";" deliberately -- prints to the console`) so a future pass doesn't "fix" it. Same
convention to be applied to any other deliberate unsuppressed-output line found later.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 5 — Root: `config.m`, `setup.m`, `run_demo.m`</h4></summary>

<div style="margin-left:1.5em">

No genuine Tier-B target in any of the three (no `find`, no unpreallocated growth, no missing
semicolons). One trivial cleanup found and made in `setup.m`: `try, web(url,'-browser'); catch, end`
had an unnecessary comma (`checkcode` NOCOMMA). Reflowed to a normal multi-line `try`/`catch` --
turned out to be pure whitespace/separator normalization, not even a real Tier-B change: `canon`
on the new file is byte-identical to `canon` of the HEAD version (no rename map needed), so this
was actually still Tier A, just missed in that pass.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 6 — `experiments/adaptive_hist_exp.m`</h4></summary>

<div style="margin-left:1.5em">

No Tier-B edits (pattern-check-only tranche, per the gap noted above). The two `find(...)` calls
(`:209`, `:378`) both pull a single bin-bounds index and can't be simplified to logical indexing.
No unpreallocated growth, no missing semicolons. The only `checkcode` hits are the two
pre-existing `parfor`-broadcast notes, already logged as Tier C.

</div>

</details>

**Tier B is complete: two real fixes** (`pipeline/list_natural_images.m`,
`twin-net/texture_same_diff_patches_net.m`), **one deliberate non-fix documented**
(`twin-net/train_net.m:405`), **one stray Tier-A cleanup caught along the way** (`setup.m`), and
**no opportunities found** in `+segmentation/`, `+gtr/`, `demo/`, or
`experiments/adaptive_hist_exp.m`. No new bugs surfaced during this tier.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">4.3 Tier C — work log</h3></summary>

<div style="margin-left:1.5em">

Nothing to log — Tier C is a never-do list (section 0.3), not implemented work. Bugs discovered
while doing Tier A/B are recorded in section 0.3's item 0.3.9 sublist, not here.

</div>

</details>

</details>
