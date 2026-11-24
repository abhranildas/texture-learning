# Repo-wide cleanup plan: texture-learning

- ✅ done
- ☑️ provisionally done (every 🔴 item done)
- 🚧 in progress
- ⬜ not started

---

<details open>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">0. Status</h2></summary>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">✅ 0.1 · Stage 1 · Style</h3></summary>

<div style="margin-left:1.5em">

**Description.** Comments, header docs, whitespace, reflow, blank-line grouping, file-local renames, and function/file renames. Checked by `isequal` on a canonical AST fingerprint — no execution needed.

**To-do.**

- [x] **0.1.0.** Tooling: `canon`/`check_stage1`/`assert_rename_bijection`, golden-output harness.
- [x] **0.1.1.** `+segmentation/` + `+gtr/`
- [x] **0.1.2.** `pipeline/`
- [x] **0.1.3.** `demo/`
- [x] **0.1.4.** `twin-net/`
- [x] **0.1.5.** Root: `config.m`, `setup.m`, `run_demo.m`
- [x] **0.1.6.** `experiments/adaptive_hist_exp.m`
- [x] **0.1.7.** **Function and file renames, repo-wide** — the six renamed camelCase filenames in `twin-net/` (`load_nat_A_pool.m`, the seventh camelCase-ish name, is a deliberate keep), their `function` lines, and every call site. Map and method in section 3.1.1b. Runs as one tranche over the whole repo, verified file by file with `check_stage1` against `git show HEAD:<file>`. Out of order relative to the skill (which puts this *before* the other tranches, so headers never name a file that later moves) — here it lands after, so its own sweep must also fix the `See also` lines and `Contents.m` entries Stage 1 already wrote.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">✅ 0.2 · Stage 2 · Hygiene</h3></summary>

<div style="margin-left:1.5em">

**Description.** Semicolon insertion, preallocation, `find`→logical indexing, deleting a provably unused assignment. Checked by a whitelisted-pattern diff **plus** a runtime golden-output match. A closed list of four: anything bigger is a Speed item (0.5), not a widening of this stage.

**To-do.**

- [x] **0.2.0.** Extend the golden harness. `tools/golden_harness.m` now covers all tranches except one script. Entry points added this round: `+gtr/` (`grow_region_masks`, `sample_texture_ids`), `demo/` (`sample_texture_pairs`, `apply_dv`; `compute_demo_responses` already covered via `pair_responses`), `twin-net/` (`forward_twin`, `predict_twin`, `pool_stats` — named `forwardTwin`/`predictTwin`/`poolStats` at the time, renamed by tranche 0.1.7 — on a tiny synthetic `dlnetwork`). Captured and replay-verified.
- [x] **0.2.1.** `+segmentation/` + `+gtr/` — no Stage 2 opportunities found (see section 3.2).
- [x] **0.2.2.** `pipeline/` — one fix, `list_natural_images.m` (see section 3.2).
- [x] **0.2.3.** `demo/` — no Stage 2 opportunities found (see section 3.2).
- [x] **0.2.4.** `twin-net/` — one fix, `texture_same_diff_patches_net.m`; one deliberate non-suppressed line left alone and commented (see section 3.2).
- [x] **0.2.5.** Root: `config.m`, `setup.m`, `run_demo.m` — one trivial Stage-1-level cleanup in `setup.m` found along the way (see section 3.2); no genuine Stage 2 target in any of the three.
- [x] **0.2.6.** `experiments/adaptive_hist_exp.m` — no Stage 2 opportunities found (pattern-check only; see section 3.2).

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">☑️ 0.3 · Stage 3 · Organize</h3></summary>

<div style="margin-left:1.5em">

**Description.** Signature changes, `arguments` blocks, merging duplicate functions, reordering statements, float/RNG-order changes, commented-out-code triage — not behaviour-preserving, done after Stage 1/2, and not Bugs (0.4) or Speed (0.5) even if a fix here happens to speed something up. **Rating:** 🔴 clear win, low risk · 🟠 real cost (design decision or wide call-site surface) · 🟡 marginal, defer — a joint call, not a formula. Ids stay `0.3.<n>` (already cited in commits and the section 3.3 work log), not the skill's `O<tier>.<n>`.

**To-do.**

- [x] 🔴 **0.3.1.** Collapse the two copies of `local_show_pair`: extracted to `demo/local_show_pair.m`, both call sites (`demo/plot_stage3.m`, `demo/plot_stage6_pairs.m`) updated. *Obvious duplicate, two call sites, zero risk — the textbook 🔴.*
- [ ] 🟠 **0.3.2.** Collapse `experiments/adaptive_hist_exp.m`'s `collect_natural`/`collect_brodatz`. *Real de-duplication value, but contained to one large exploratory file with no callers (section 3.1.2) — moderate benefit, not urgent.*
- [x] 🟠 **0.3.3.** Convert `pair_responses`' 10 positional arguments (or similar) into an `arguments` block — done: all ten validated by class/attribute, no defaults (MATLAB forbids an optional argument before a required one, and `cfg` is last and required), no reordering, no call-site change at any of the 6 invocations. Details in section 3.3. *High-value shared function, but several genuine design decisions (validation scope, `cfg` as a whole struct, the `lo`/`hi` scope call) and a 6-call-site surface — the design-decision cost is what keeps this 🟠 rather than 🔴, even though it landed with zero risk.*
- [ ] 🟠 **0.3.4.** Turn the three scripts (incl. `experiments/adaptive_hist_exp.m`) into functions. *Closes a real Stage 2 coverage gap (pattern-check-only tranches), but script-to-function conversion is a bigger, riskier surface than a plain rename — moderate benefit, moderate risk.*
- [x] 🔴 **0.3.5.** Triage the commented-out code — done, one verdict per block, recorded in section 3.3, nothing deleted. Only **one** real block survives in the 66 in-scope files (`demo/plot_stage2.m:46`); the survey's "113 lines" was a loose heuristic dominated by header-doc usage examples, which do not count. Keeping is the default; the single conversion it licenses becomes item 0.3.10 below. *Pure reading, zero risk, and it closed a real uncertainty (the 113-line estimate) that the whole plan had been carrying — modest effort, clear benefit.*
- [ ] 🟡 **0.3.6.** Reorder statements, even when it looks purely cosmetic. *No concrete instance identified yet — a category placeholder, not a finding. Stays 🟡 until a real target turns up; reordering also carries real correctness risk by the skill's own rationale (the check can't tell a safe reorder from an unsafe one).*
- [ ] 🟠 **0.3.7.** Rename any zone-2 `cfg.*` cross-file field (listed in section 3.1.1) — deferred to its own pass. Candidates already spotted, not touched: `cfg.gtr.szp`, `cfg.gtr.dcrit`, `cfg.gtr.n_regions` (comment still calls it `ntexr`), `cfg.natural.max_val`. *Real consistency benefit, but touches `config.m` plus every reader — the call-site surface is the cost.*
- [ ] 🟡 **0.3.8.** Rename any zone-3 frozen `save`/`load` name (listed in section 3.1.1). *The benefit is cosmetic naming consistency; the risk is breaking a shipped `.mat` artifact's contract. High risk for low benefit — candidate to drop rather than do.*
- [ ] 🟠 **0.3.9.** `+segmentation/group_patches.m:112` discards `assign_isolated_patches`'s third output (`ngrps`) and recomputes group growth separately in the caller — two code paths compute the same count for the same event. De-duplicate, or confirm they can't diverge and say why. Not a bug as it stands; a divergence hazard. *Real correctness-adjacent benefit (closes a divergence hazard), contained to `+segmentation/`, but touches core segmentation logic and needs a golden-harness check — moderate cost.*
- [x] 🔴 **0.3.10.** Act on the 0.3.5 triage — one item, since the table has one row. Convert `demo/plot_stage2.m:46` (verdict row `stage2-pdf-ylim`, *alternative*) from commented-out code into plain prose in the same spot, keeping the reason and dropping the fake `ylim` call. Nothing to delete: no block was judged *superseded* or *scaffolding*. *One line, in one file, verdict already licenses it — no design decision left, no risk. The other remaining 🔴.*
- [ ] 🟡 **0.3.11.** `setup.m`'s `ensure_addon_on_path` guards an optional 5th argument that both call sites always pass — dead defensiveness, not a bug. Remove the guard or keep it deliberately. *Trivial effort and near-zero risk, but the benefit is genuinely marginal — a guard nobody exercises isn't causing harm either way.*
- [x] 🟠 **0.3.12.** Readable names for the terse cross-file vocabulary, including saved (`.mat`) names: the similarity/grouping names (`phiall`, `rho`, `phi`, `mu`, `gcopt`, `wmopt`, …), the trained-bound struct `dbnd`, its fields and the `dv.*` handles built from it, names copied from Bill's code (`pcmx`, `pcnf`, `nrg`, `emap`, `ngrps`, `rcn`…`rmf`, `qbs`/`qbd`, `dst`, …), `btype`/`itype`/`eccb`/`cstat`, the gradient-PCA variable `pcg` and the priors-file variables `N*`/`e*`. Each new name has a defining comment where it is introduced; `tools/migrate_saved_names.m` renamed the names inside `data/models/*.mat`; the README glossary shrank to the paper-symbol map; `docs/segmentation-parity.md` §4 maps our names to Bill's. Map and verification in section 3.3. Partly does 0.3.8 (frozen save names) for `data/models`. *Real readability benefit across ~50 files, but a wide call-site surface, many naming decisions, and a one-off rewrite of shipped artifacts — that cost keeps it 🟠.*

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">⬜ 0.4 · Stage 4 · Bugs</h3></summary>

<div style="margin-left:1.5em">

**Description.** Bugs found anywhere during Stage 1/2/3, fixed here after Organize so a later organizational change can't clobber or duplicate a fix. Also logged in `docs/bill-2026-revisions.md`. **Rating:** 🔴 B1, silently wrong on a run path · 🟠 B2, reachable but not silent · 🟡 B3, latent. Id `B<severity>.<n>`, sorted by severity then discovery order.

**Status.** B2.2 currently blocks Stage 2's golden-output guarantee.

**To-do.**

- [ ] 🔴 **B1.1.** `+segmentation/assign_isolated_patches.m:10-15` documents its own deliberate behaviour change from the original `iso_patch.m` (`i~=j` → `other_idx~=patch_idx`), already flagged in-file as changing the reproduced paper numbers — resurfaced here so it isn't missed in a skim. 🔴 because it moves numbers on a path that is actually run; the open question is whether the change is the fix or the regression, which is the user's call.
- [ ] 🔴 **B1.2.** `pipeline/s4_optimize_bins.m` (`eval_r`, ~line 245) rejects outliers with `rv < -25` only — no upper-bound check — while `pair_responses.m`'s outlier rejection for the same kind of LLR quantity is two-sided. Comment marks it "as in the original," so likely long-standing, but the asymmetry is worth confirming with Geisler. 🔴 *if* the asymmetry is unintended: it would silently shift trained bin boundaries. Unconfirmed.
- [ ] 🟠 **B2.1.** `run_demo.m`'s "missing artifacts" error text tells the user to set a `run_training_stages` variable that doesn't exist anywhere in the repo — the actual switch is `demo_type = 'full'`. Reachable and user-facing, but it only misdirects a message; no numbers change.
- [ ] 🟠 **B2.2.** `golden_harness('replay', 'tools/golden_ref.mat')` **no longer matches**, and has not for some time. Run headlessly during tranche 0.1.7 (R2024b), four of the fifteen fields differ from the committed reference: `prep_grid_checksum`, `pair_responses_checksum`, `content_similarity_checksum`, `sample_texture_pairs_checksum`. The other eleven match, including all three `twin-net/` fields. **Not caused by tranche 0.1.7**: that tranche modified only `twin-net/*` and `tools/golden_harness.m`, while all four failing entry points live in `+segmentation/`, `pipeline/pair_responses.m`, and `demo/sample_texture_pairs.m`, every one of which is clean at HEAD and was not opened. Filed 🟠 because the symptom is loud — replay throws — rather than silent. **But the cause is unknown and could be worse than the symptom:** if one of those three files' outputs genuinely changed (via the uncommitted colour-extension work-in-progress, or commit `f085bb5` "fixes"), that is a silent numeric change and this should be re-filed as a B1. Either the reference is stale and needs a deliberate re-capture, or an output moved and needs explaining; nothing can distinguish those two without the user's input, and a re-capture must not be taken until it is known which. Until this is settled, **Stage 2's "golden output matched" guarantee is not currently reproducible.**
- [x] 🟠 **B2.3.** `pipeline/s6_selfsup_discrimination.m`'s closing `fprintf` labels its number "mean near-far PC max", but the value is `max(out.accuracy)` — the trial-averaged **same/different** accuracy (`pc` in `nearfar_score_grid`), not the near/far one (`accuracy_nearfar`, was `pcnf`). Display only; no stored number changes. Found while renaming `pcav` in item 0.3.12.
- [ ] 🟡 **B3.1.** `+segmentation/neighbor_similarity_matrix.m` header asserts `cfg.gtr.power_suppress` and `cfg.dv.power_suppress` are "both 16 since Geisler unified b0" — nothing in code enforces this; editing one without the other would silently desync the border/content combination from `content_similarity_matrix.m`. Same coupling recurs in `config.m`. Latent: correct today, a trap for the next edit. An assert in `config.m` would close it.
- [ ] 🟡 **B3.2.** `+segmentation/merge_similar_regions.m` merges exactly one region pair per call by design; `group_patches.m` calls it once per pass, so there is no iterative multi-merge unless a caller loops it. Confirm this is the intended algorithm rather than a truncated loop.
- [ ] 🟡 **B3.3.** `pipeline/self_sup_decision.m`'s `'bc_noshift'` method branch is unreachable: neither `s6_selfsup_discrimination.m` nor `s7_segment_gtr.m` ever passes it. Dead code unless called directly from outside the pipeline.
- [ ] 🟡 **B3.4.** `plot_stage7.m`'s header documents `method` as `'nc'` or `'bc'`, but the code (`plot_stage7.m` and identically `plot_stage8_natural.m`) does `struct('nc', 'c_shft', 'ncb', 'bc').(method)`, which only has fields `nc` and `ncb` — passing the documented `'bc'` value would error. Currently unreachable, but the header disagrees with the code it describes.
- [ ] 🟡 **B3.5.** `run_demo.m`'s `try/catch err/rethrow(err)` around the `s7_segment_gtr` call is a no-op. No behavioural effect; remove it or give it a real handler.
- [ ] 🟡 **B3.6.** Three bugs already flagged in-file by a previous author (not new, resurfaced for visibility): `neighbor_far_responses.m`'s header documents a fixed stateful-renormalization bug in the original code; `s7_segment_gtr.m`'s header documents an ecc-dependent neighbour-distance fix; `s6_selfsup_discrimination.m`'s header documents a `pd`/`eccb` inconsistency. All three are already fixed in this code — the item is to confirm that and keep the headers accurate, not to re-fix anything.
- [ ] 🟡 **B3.7.** Two dangling pointers to a deleted document. `twin-net/texture_same_diff_patches_net.m:23` cites "`docs/readability-pass.md` section 5.3" for the zone-3 frozen-save-name list, and `tools/golden_harness.m:11` cites "`docs/readability-pass.md` sections 1.1 and 10" for the per-tranche entry points — but that file was deleted (it is the `D docs/readability-pass.md` in `git status`) and its content now lives in `docs/repo-cleanup.md`, the frozen-name list in section 3.1.1. Found while sweeping non-`.m` references in tranche 0.1.7; not fixed there, since rewriting a doc pointer is outside that tranche's narrow permitted edit. Latent: it misleads a future reader into thinking the frozen-name list is simply gone, which is exactly the reader who is about to rename a frozen name.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">⬜ 0.5 · Stage 5 · Speed</h3></summary>

<div style="margin-left:1.5em">

**Description.** Optimizations found anywhere, never made at the time — done last, once the code is structurally settled and correct, so a bug fix can't dissolve the optimization out from under it. Every item needs a before/after timing plus golden-output equality; no measurement, no item; if the speedup isn't worth the diff, revert and record the null result — that's completed, not failed. **Rating:** 🔴 big win, low risk · 🟠 real cost (moderate gain, or perturbs float/RNG/`parfor` order) · 🟡 small, speculative, or unverified. Id `S<tier>.<n>`. Separate axis, **verification status** — Proven / Perturbing / Unprofiled; Unprofiled doesn't cap the tier, it just means unmeasured.

**Status.** The scan itself (S3.1) hasn't run — it didn't exist when this repo was surveyed; the two items below surfaced from earlier passes via `checkcode`, not a survey.

**To-do.**

- [ ] 🟡 **S3.1.** Run the optimization scan over all 66 in-scope files and fill in section 2's performance-shape bullet. Seven patterns to look for: loop-invariant work recomputed in a loop; file I/O (`load`/`imread`/`save`/`dir`/`exist`) inside a loop; `inv`/`pinv`/`det` where a solve would do; array growth beyond what Stage 2 covered; whole-array recomputation where an incremental update exists; plainly-elementwise loops and serial `parfor` candidates; `parfor` loops writing to a reduction variable. Every hit becomes a new item here. Pure reading, no execution, no edits. **Verification status: n/a** — this item is the scan itself, not a code change.
- [ ] 🟡 **S3.2.** `+segmentation/content_features.m:47` and `+segmentation/content_similarity_matrix.m:52` each carry a `checkcode` `parfor`-broadcast note — a variable copied to every worker rather than sliced. Recorded twice in section 3.2 as a "Stage 3 performance note." **Verification status: Unprofiled.** Both loops are the O(n²) all-pairs combine, so the potential payoff is plausibly large — but nothing has been measured, and an unmeasured "plausibly large" is exactly the case the skill says stays 🟡 regardless of how big it looks on paper, rather than jumping to 🔴 on the strength of a guess.

Timing runs execute the real pipeline, so each one is asked for first.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">⬜ 0.6 · Stage 6 · Closing</h3></summary>

<div style="margin-left:1.5em">

**Description.** A single fixed gate, run once 0.1 and 0.2 are done and every 🔴 item in 0.3 through 0.5 is done — not a findings list, so no rating legend and no items beyond the four below. Confirms the whole repo agrees with the plan's record, rather than trusting the sum of the per-item checks. Never auto-dispatched, for the same reason as Stages 4 and 5 but a different cause: there's nothing to hand to a subagent, so the orchestrator runs all four itself.

**Status.** Not yet reached: 0.3, 0.4, and 0.5 are still open.

**To-do.**

- [ ] **0.6.1.** `check_stage1` re-run across every in-scope file against current HEAD.
- [ ] **0.6.2.** `golden_harness('replay', ...)` clean, end to end — blocked today by B2.2.
- [ ] **0.6.3.** Every 🔴 item in 0.3, 0.4, and 0.5 ticked, or explicitly closed with a reason.
- [ ] **0.6.4.** Section 2 re-checked against the repo as it now stands.

</div>

</details>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">1. How an agent should execute this cleanup plan</h2></summary>

<div style="margin-left:1.5em">

`mtree` parses a `.m` file into MATLAB's own syntax tree, and `tree2str` prints it back in canonical form: comments stripped, whitespace/bracket spacing normalised, missing `end` supplied.

```matlab
canon = @(f) tree2str(mtree(f,'-file'));
```

This gives a fingerprint blind to exactly what Stage 1 is allowed to change, sensitive to everything else. Verified: succeeds on all 66 in-scope files.

Reverse-rename check: clean a file (renames, header, reflow), then undo the rename map on the canonical form of the new file and assert it's identical to the canonical form of the old one:

```matlab
c_new = canon(new_file);
for k = 1:size(renames,1)   % renames = {new_name, old_name}
    c_new = regexprep(c_new, ['(?<![A-Za-z0-9_.])' renames{k,1} '(?![A-Za-z0-9_])'], renames{k,2});
end
isequal(canon(old_file), c_new)   % must be true
```

The lookahead `(?![A-Za-z0-9_])` matters: without it a short name (`patch`) can wrongly match inside a longer one (`patch_size`). The rename map itself must be a bijection with disjoint domain/range — assert this before using it:

```matlab
dom = renames(:,1); ran = renames(:,2);
assert(numel(unique(dom)) == numel(dom));
assert(numel(unique(ran)) == numel(ran));
assert(isempty(intersect(dom, ran)));
```

Caveat: `mtree`/`tree2str` are undocumented MATLAB APIs — pin the MATLAB version in commit messages (this pass used R2024b throughout).

**Stage 2's extra requirement: runtime golden output.** Unlike the sibling `camouflage_detection` repo (~40% of files don't execute), this repo runs, so Stage 2 changes can be checked against real outputs, not just pattern-matching. `tools/golden_harness.m` captures/replays deterministic outputs (`rng(cfg.seed)`, never through `run_demo`, which uses `rng('shuffle')` on some paths) for entry points across every tranche except `experiments/adaptive_hist_exp.m` (a script — see section 3.2). All nine `parfor` loops in the repo write into a sliced output rather than a reduction variable, so worker order can't change a float sum — safe to leave alone; if a future edit turns one into a reduction, that edit is Stage 3.

Speed is its own stage rather than a corner of Organize because the verification differs: an Organize item is reviewed and reasoned about, a Speed item is not done until a stopwatch says it worked. Being last also makes it the one stage droppable without touching anything else.

Semicolon insertion is stage 2, not stage 1: `tree2str` preserves display-vs-suppress, so the canonical diff is exactly `X` → `X;` — trivially whitelisted, but not invisible.

Stage 3 matters most. The tempting changes in this repo are all Stage 3 (see section 0.3's list). Every one of them changes output, call sites, or validation behaviour, so none of them belong in the behaviour-preserving pass — keeping them out is what makes that pass's diff skimmable instead of line-by-line. They are the next step of the same overall cleanup, not abandoned.

**All three of Organize, Bugs, and Speed rate their items on the same three-colour scale** — 🔴 highest, 🟠 middle, 🟡 lowest — though what the tier means differs by list: how bad a bug is if left unfixed, versus overall cost/benefit for an organizational item, versus overall risk/benefit for an optimization. See sections 0.3, 0.4, and 0.5.

When the pass uncovers an *organizational opportunity* — and it will — **record it in 0.3 with its tier emoji and do not make the change**, the same discipline as a bug or an optimization.

When the pass uncovers an *optimization* — and it will — **record it in 0.5 with its tier emoji and do not make it**, however small it looks. The "easy" one spotted mid-tranche is the likeliest way this rule gets broken.

When the pass uncovers a *bug* — and it will — **record it in the findings list first, marked with its severity emoji**, so the recording survives even before the fix happens; the fix itself comes later, as a Stage 4 item, kept separate from Stage 3 so the bug list never gets buried inside the organizational-cleanup list. Even a 🔴 waits: the severity sets the fix order within Stage 4, it does not pull a fix forward or interrupt the tranche that found it.

**Before working section 0.3 further, check whether section 2 is still current.** If meaningful time has passed since it was measured (2026-09-15), or the file set has changed, re-measure it — Organize's tiers and Stage 5's S3.1 scan both lean on those numbers being live, not on what was true when the plan was written.

**Golden-reference maintenance, Stage 3 and Stage 4.** Run `golden_harness('replay', ...)` after every Stage 3 or Stage 4 item, not only after Stage 1/2 tranches. If the item was meant to be output-preserving and replay still passes, nothing to do — that's what happened for 0.3.3 and 0.3.10, both already verified this way. If replay fails, decide which happened before touching the reference: the item was *expected* to change output — recapture deliberately and log what changed and by how much — or it was supposed to be output-preserving and something moved that shouldn't have, which is a new bug for section 0.4, not a reason to recapture. **B2.2 is exactly this undecided case, from before this rule existed**: replay fails, cause unknown, and it must be resolved (bug, or deliberate recapture) before it can close.

**Stage 6 (Closing), once Stages 1 and 2 are done and every 🔴 item of Stages 3 through 5 is done:** re-run the full check suite end to end (section 0.6's checklist) rather than trusting the sum of the per-item checks. Not reached yet — 0.3, 0.4, and 0.5 are still open.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">2. Scope and measurements</h2></summary>

<div style="margin-left:1.5em">

Every number in this document was measured on the repo as it stands (MATLAB R2024b), not estimated, surveyed 2026-09-15. Re-measure before trusting any of them after substantial changes, or once real time has passed since that date (see section 1).

**Scope, precisely.** `Bill's old code/` and `Bill's old code - revised/` are excluded entirely — 93 `.m` files of ancestral code, gitignored, kept for reference only. That leaves **66 files, 5744 lines** in scope: `+segmentation/` (10 files, 622 lines), `+gtr/` (2, 122), `pipeline/` (21, 1449), `demo/` (18, 1352), `twin-net/` (11, 847), the three root files `run_demo.m`/`setup.m`/`config.m` (547), and `experiments/adaptive_hist_exp.m` (805).

**What is actually wrong with the files**, measured, not assumed:

- **Lint is a non-issue.** `checkcode` reports 11 messages across all 66 files, confined to six files. 62 of 66 are lint-clean.
- **Formatting is nearly clean.** Zero tab-indented files, every file has a header comment. The one real defect: **37 files carry at least one line over 100 characters**, worst `demo/plot_stage1b_gradients.m:128` (159 chars). Two files hold a third of the total: `experiments/adaptive_hist_exp.m` (62 long lines) and `twin-net/train_net.m` (31).
- **Header docs are half-finished.** All 66 open with a comment, but only 34 carry an `Inputs`/`Output` block. Zero have a `See also` line. No `Contents.m` anywhere. This was the single largest, cheapest readability gap.
- **Names are the real problem.** Heavy abbreviation, consistent but never defined: `psz` 321 occurrences, `ecc` 173, `dv` 112, `col` 94, `pimg` 65, `ngrps` 50, `itype` 44, `nsmp` 33, `b0` 24, plus bare loop counters `i`/`j`.
- **Names diverge across call boundaries** — e.g. `prep_grid` returns `[P, G, Gn]` but `content_features` receives the same three renamed `(P, G, E, …)`.
- **Two naming conventions coexist**: the repo is snake_case except `twin-net/`, which is camelCase in both file and identifier names. The *identifiers* were converted in Stage 1 tranche 4; the **seven camelCase filenames remain** — `forwardTwin.m`, `getTwinBatchPairs.m`, `getTwinBatch_nat_live.m`, `load_nat_A_pool.m`, `modelLoss.m`, `poolStats.m`, `predictTwin.m`. Measured 2026-09-15 with `git ls-files '*.m' | grep '[A-Z]'`; the only other capitalized matches are the two `Contents.m` files, which are MATLAB's own required spelling and stay. Target is snake_case throughout — item 0.1.7, **now done**: six of the seven were renamed, and `load_nat_A_pool.m` stays as it is (the deliberate `A` exception, section 3.1.1b). Re-measured after the rename, `git ls-files '*.m' | grep '[A-Z]'` returns only `load_nat_A_pool.m` and the two `Contents.m` files.
- **Performance shape: not measured.** The optimization scan did not exist when this survey was written, so there is no inventory here. Filling it in is item S3.1 in section 0.5. Known so far, both from `checkcode` rather than from looking: two `parfor`-broadcast notes (item S3.2).
- **Timing data: almost none.** Exactly one timer in the in-scope code — `twin-net/train_net.m:269` (`start = tic;`), for per-iteration training progress, not for comparing stages. No logged runtimes, no note anywhere on which stage dominates wall-clock. Nobody knows where the time goes; it is unmeasured, not inferred from loop nesting. This is why every 0.5 item starts life Unprofiled.
- **Three builtin shadows**: `image` used as a parameter name in three `+segmentation/` files.
- **Commented-out code is present but small**: 113 of 5744 lines look like commented-out code. Nothing judged or removed here — that's the Stage 3 triage, item 0.3.5, whose per-block verdicts live in section 3.3.
- **No `arguments` blocks, no `inputParser` anywhere.** Adding them is Stage 3.

**The style target already exists** — do not invent a new one. `vislab-common/+vislab/+lib/watson_otf.m` is the exemplar (summary line, fully-qualified signature, `Inputs`/`Output` with units, `See also`). Within this repo, `+segmentation/prep_grid.m` and `pipeline/pair_responses.m` are the closest existing approximations. Verified: no in-scope file shares a name with anything in `vislab-common` or `Bill's old code*/`, so there is no already-superseded-elsewhere trap here.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">3. Stage-by-stage details and work log</h2></summary>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">3.1 · Stage 1 · Style</h3></summary>

<div style="margin-left:1.5em">

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">3.1.1 Renaming: three zones</h4></summary>

<div style="margin-left:1.5em">

The rename map is the pass's most valuable artifact and its main divergence risk — build it first, once, repo-wide, per tranche.

**Casing: snake_case for everything this repo owns** — variables, arguments, functions, scripts, filenames. It is a casing rule only: a one-word name stays one word, and nothing is padded or qualified just to fit the convention. Not ours to rename: MATLAB/toolbox builtins and name-value strings, fields of structs returned by external code, the zone-3 frozen names below, and `Contents.m` (MATLAB's own required spelling).

1. **File-local variables — free.** `psz`→`patch_size`, `pimg`→`region_image`, `nsmp`→`n_samples`, `ngrps`→`n_groups`, `ptch`→`patches`, `c0`/`m0`→`target_contrast`/`target_mean`, `i`/`j`→`row`/`col` or a domain name, and the three `image` shadows. Because these are file-local, `canon` makes them completely safe.
2. **Cross-file vocabulary — repo-wide, or not at all.** Two sub-vocabularies:
   - The `cfg` struct: 54 distinct `cfg.*` field paths defined in `config.m` and read everywhere. Renaming any of them touches `config.m` plus every reader. **Its own tranche, deferred.**
   - Function arguments named consistently across the repo (`ecc`, `itype`, `psz`, `dv`, `col`). High value because they're everywhere — but a half-done rename is worse than none.
3. **Serialised variable names — forbidden.** Names inside `.mat` files: `coeff`, `cdf_*`/`edges_*` (priors; were `N*`/`e*`, e.g. `Na`, `ea`, until item 0.3.12), `ptchn`, `ptchf`, `pcnt`, `color`, `bin_bounds`, `n_bins`, `eccs`, `bound_type` (was `btype`), `decision_bounds` (was `dbnd`), `gradient_pca` (was `pcg`), `near`, `far`, `same`, `diff`, `same_brod`, `diff_brod`, `net`, `fcParams`, `lms`. Five shipped artifacts in `data/models/` depend on them. A local variable that *holds* one of these can be renamed; the string in the `save`/`load` call cannot. Note `diff` is also a builtin-shadow candidate in `twin-net/texture_same_diff_patches_net.m:68` — there it's a frozen save name; elsewhere it's free. Check which you're looking at.

**Units are the other half of naming** — state them in every header: `cfg.optics.ppd = 60` pixels/deg for all images, `cfg.patch.size`/`cfg.patch.image_size` in pixels, `ecc` an integer divisor (not degrees), `cfg.optics.pupil_diameter` in mm, `cfg.optics.wavelength` in nm, `cfg.dv.edge_thresh` in image units.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">3.1.1b Function and file rename map (item 0.1.7)</h4></summary>

<div style="margin-left:1.5em">

A file rename *is* the function rename — MATLAB dispatches on the filename — so the `function` line is fixed to agree in the same edit. Renames use `git mv` so history follows. This is Stage 1 because a function name is a bare identifier that `check_stage1`'s reverse-rename regex covers at every call site, unlike a dot-qualified `cfg` field.

**Family rule:** `lower_snake_case`, converting casing only. No word is added, dropped, or reordered in this tranche. Two questions about whether a word was the *right* word (not just correctly cased) were raised and settled by the user before this tranche runs — both **no**, i.e. keep the word, convert case only.

| old file | new file | note |
|---|---|---|
| `twin-net/forwardTwin.m` | `forward_twin.m` | casing only |
| `twin-net/predictTwin.m` | `predict_twin.m` | casing only |
| `twin-net/modelLoss.m` | `model_loss.m` | casing only |
| `twin-net/poolStats.m` | `pool_stats.m` | casing only |
| `twin-net/getTwinBatchPairs.m` | `get_twin_batch_pairs.m` | casing only — `get*` prefix kept (user decision) |
| `twin-net/getTwinBatch_nat_live.m` | `get_twin_batch_nat_live.m` | casing only — `get*` prefix kept (user decision) |
| `twin-net/load_nat_A_pool.m` | `load_nat_A_pool.m` | **no rename** — `A` kept capitalized as a domain symbol (user decision); one deliberate exception to the casing rule, noted here so a later pass doesn't "fix" it |

**Two questions resolved before this tranche runs, both "no, keep as is":**

1. **The `get*` prefix** on the two files above — kept, not dropped, even though nothing else in the repo carries it. Both are data-loading callbacks, which is the justification for the exception.
2. **`A` for the achromatic channel** in `load_nat_A_pool.m` — kept capitalized, matching the ecosystem-wide `RGB->LMS->A` notation, rather than lowercased to `a` (unreadable) or respelled `achrom`. This file's name does not change at all in this tranche.

**Four sweeps `check_stage1` cannot do** — all four answered in section 3.1.3, step 7, now that the tranche has run:

- **Package-qualified call sites.** None of the seven are in a package (`twin-net/` is a plain directory, not `+twinnet/`), so the dot-qualified blind spot does not apply here. Confirm at run time rather than assuming.
- **References outside `.m` files.** At minimum `twin-net/net_plan.md` and this plan document both name these functions in prose. Grep every old name repo-wide, including non-`.m` files.
- **Dynamic references.** Grep each old name as a quoted string as well as a bare identifier (`feval`, `str2func`, `exist`, `which`).
- **Already-written cross-references.** Stage 1 added `See also` lines to all 66 files and `Contents.m` to two packages. Because this tranche runs *last* instead of first, those lines already name the old filenames and must be swept too.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">3.1.2 Tranches, sequencing, and model assignment</h4></summary>

<div style="margin-left:1.5em">

The work is concentrated very differently from what file count suggests: 18 files are under 30 lines, while the five files ≥200 lines hold 34% of all code. Batch the small ones; budget real time for the large ones.

The **Agent** column is what the orchestrator dispatches to — see the skill's "Dispatching tranches" section. Tranches ran in order, one at a time.

| # | Tranche | Files / lines | Agent | Why |
|---|---|---|---|---|
| 0 | Rename map + `canon`/checker + golden harness | — | `matlab-cleanup-lead` | Every other step trusts this being right |
| 1 | `+segmentation/` + `+gtr/` | 12 / 744 | `matlab-cleanup-lead` | Sets naming conventions for everything downstream |
| 2 | `pipeline/` | 21 / 1449 | `matlab-cleanup-mechanical` | Mechanical once the map exists; clean helpers before callers |
| 3 | `demo/` | 18 / 1352 | `matlab-cleanup-mechanical` | Independent files, except duplicated `local_show_pair` — clean both copies identically |
| 4 | `twin-net/` | 11 / 847 | `matlab-cleanup-mechanical` | camelCase→snake_case as one decision applied 11 times |
| 5 | Root: `config.m`, `setup.m`, `run_demo.m` | 3 / 547 | `matlab-cleanup-lead` | `config.m` is the zone-2 vocabulary source; `run_demo.m` is user-facing |
| 6 | `experiments/adaptive_hist_exp.m` | 1 / 805 | `matlab-cleanup-mechanical` | Large, exploratory, no callers |
| 7 | **Function and file renames** (section 3.1.1b) | all 66 | `matlab-cleanup-lead` | **Done** (see section 3.1.3, step 7). Repo-wide, never parallel with anything. The skill runs this *first*; here it ran last, so it also swept the `See also` lines tranches 1–6 had already written (neither `Contents.m` named any renamed file) |

**Escalation rule, any tranche:** if `check_stage1` fails and the cause isn't obvious from the diff — stop, don't retry with a bigger prompt, hand that one file to `matlab-cleanup-escalation`. Don't loosen the check instead.

**"Done" checklist for a Stage 1 tranche** (all seven tranches have now run):

- [x] `isequal(canon(old), canon_with_renames_reversed(new))` true for every file.
- [x] Every file has a header matching the `watson_otf.m` shape: summary, signature, `Inputs`/`Output` with units, `See also`.
- [x] No line exceeds 100 characters except the documented string-literal exceptions (listed per tranche in section 3.1.3) — each would require turning a string literal into a `horzcat` expression, a real AST change forbidden by Stage 1.
- [x] No zone-3 frozen identifier renamed, no `save`/`load` string literal changed.
- [x] Each package touched has a `Contents.m` (`+segmentation/`, `+gtr/`).
- [x] Bugs found are written down with a severity tag and not fixed (section 0.4, and section 3.1.3 per-tranche).
- [x] Every identifier the repo owns is snake_case, including filenames — closed by tranche 7. The one standing exception is `load_nat_A_pool.m`, kept by explicit user decision (section 3.1.1b).
- [x] Each file's `function` line agrees with its filename — confirmed by tranche 7 across all of `twin-net/`.
- [ ] Optimizations spotted are written down with a tier tag and not made (section 0.5) — **open**: the scan was never run, item S3.1.

One commit per tranche, each stating the checker result.

**Housekeeping done first:** `demo/plot_stage8_natural-LA-CPSA96551WN.m` (a OneDrive filename-conflict copy) and `demo/pair_responses.m` → `pipeline/` were resolved in the tools commit, before any tranche started.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">3.1.3 Findings log</h4></summary>

<div style="margin-left:1.5em">

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 0 — tooling</h5></summary>

<div style="margin-left:1.5em">

`canon`/`check_stage1`/`assert_rename_bijection` built in `tools/`, verified against the worked `prep_grid.m` example — round-trips clean, MATLAB R2024b. `tools/golden_harness.m` originally captured/replayed five entry points under `rng(cfg.seed)`: `segmentation.prep_grid` (checksum `2.5339e+07` for a 256×256×3 synthetic image), `sample_demo_pairs` (size `[64 128 3 7820]`), `pair_responses` (checksum `2.2431e+05`, 7819/7820 pairs kept), `load_dv_handles` (five handles), `content_similarity_matrix` (checksum `1.4421e+03`). One subtlety found: `sum()` over a cell array from `cellfun` only collapses one dimension, so a naive checksum on a 2-D grid can silently return a row vector instead of a scalar — fixed with an explicit `'all'` reduction.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 1 — `+segmentation/` + `+gtr/`</h5></summary>

<div style="margin-left:1.5em">

All 12 files passed `check_stage1` with file-local rename maps; both `Contents.m` files added. Naming decision (binding for later tranches): `content_features.m`'s third parameter is named `edge_channel`, not `achrom_norm`, since the caller may pass either the raw or contrast-normalized achromatic channel — forcing `achrom_norm` would assert something not always true. `cfg.dv.sd1/nsd1/sd2/nsd2` local aliases were left as-is (they mirror `cfg.dv.*` field names 1:1; renaming only the local copy would introduce a mismatch — defer to the zone-2 `cfg` tranche).

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 2 — `pipeline/` (21 files)</h5></summary>

<div style="margin-left:1.5em">

All 21 passed `check_stage1`; the golden harness was re-run in replay mode afterward and matched bit-for-bit. `psz`→`patch_size` applied throughout. `pair_responses.m`'s parameters renamed `nh`→`spot_llr_dims`, `ne`→`edge_llr_dims`, `b0`→`power_suppress`, `thresh`→`edge_thresh` — now the settled vocabulary for that concept repo-wide. Two lines (`s4_optimize_bins.m:49`, `s5_train_decision_vars.m:70`) stay over 100 chars: an identical 97-character error string whose splitting would be a real AST change — documented exception.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 3 — `demo/` (18 files)</h5></summary>

<div style="margin-left:1.5em">

**Process note for any future tranche:** this repo's working tree already carried a large, legitimate, *uncommitted* "color extension" work-in-progress mixed into `demo/` (and some already-"finished" `pipeline/` files) before this tranche started — confirmed with the user as pre-existing feature work, not to be touched or reverted. Consequence: `git diff HEAD` / `check_stage1` against the last commit is **not a valid baseline** for such a file — it would produce large false "diffs" that are pre-existing content, not this tranche's edits. Verification instead used a pre-edit backup copy of the file's current on-disk content, diffed against the post-edit file. Use this method for any file with uncommitted pre-existing changes.

All 18 files verified. `local_show_pair` (`plot_stage3.m`/`plot_stage6_pairs.m`) confirmed byte-identical between both copies. One documented line-length exception: `plot_stage6_pairs.m:87` (123 chars, unbreakable string literal).

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 4 — `twin-net/` (11 files)</h5></summary>

<div style="margin-left:1.5em">

CamelCase→snake_case identifier unification applied as one consistent decision across all 11 files, verified against `git show HEAD:<file>` (no pre-existing WIP contamination here, unlike `demo/`). Representative renames: `miniBatchSize`→`mini_batch_size`, `pairLabels`→`pair_labels`, `learningRate`→`learning_rate`, `numIterations`→`n_iterations`. File names and top-level function names untouched (Stage 3) since they must match the filename. `fcParams` deliberately left untouched everywhere (zone-3 frozen, saved into `data/models/net_on_nat.mat`), including its own `FcWeights`/`FcBias` struct fields. Zero lines over 100 characters after reflow.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 5 — Root: `config.m`, `setup.m`, `run_demo.m`</h5></summary>

<div style="margin-left:1.5em">

Same backup-vs-HEAD split as Step 3: `config.m`/`run_demo.m` carry pre-existing color-extension WIP, verified against a pre-edit backup; `setup.m` had no dirty diff, verified against HEAD directly. Additionally ran `config(true)`/`config(false)` on backup vs. edited copy and confirmed `isequal` structs. **No `cfg.*` field was renamed, added, or removed** by this tranche. Added the unit annotations called for in section 3.1.1. `run_demo.m`'s `rng('shuffle')` byte-for-byte unchanged. 5 documented line-length exceptions in `setup.m`, 1 in `run_demo.m`.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 6 — `experiments/adaptive_hist_exp.m` (805 lines, untracked)</h5></summary>

<div style="margin-left:1.5em">

User confirmed this file is being kept. No HEAD baseline exists (whole file untracked); verified against a pre-edit backup copy. Rename map applied (all file-local): `patch_size`←`psz`, `n_bins`←`nbin`, `patches`←`ptch`, and others. One rename could not extend to a struct field: `hist_gap_collect` saves its patch-size field as `D.psz`/`S.psz` into `hist_gap_data.mat` — `check_stage1`'s regex excludes dot-qualified names, so this stays `psz` while the local variable is `patch_size`, noted in-file. The two near-identical local functions `collect_natural`/`collect_brodatz` were cleaned independently, **not merged** (Stage 3). All three `rng('shuffle')` calls left byte-for-byte unchanged. 5 documented line-length exceptions, all unbreakable string literals.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 7 — function and file renames, repo-wide (item 0.1.7)</h5></summary>

<div style="margin-left:1.5em">

Six files renamed per the map in section 3.1.1b, all with `git mv` so history follows; `load_nat_A_pool.m` untouched as decided. Twelve `.m` files were edited in total — the six renamed files plus six callers — and two non-`.m` files. Baseline for every one of the twelve was `git show HEAD:<old_path>`, valid because `twin-net/` and `tools/` were both clean at HEAD (`git status` before starting listed only pre-existing `demo/` work-in-progress and the untracked plan and checker).

**Verbatim `check_stage1` output** (MATLAB R2024b, rename map = the six `{new, old}` bare-identifier pairs):

```
twin-net/forward_twin.m                       1
twin-net/predict_twin.m                       1
twin-net/model_loss.m                         1
twin-net/pool_stats.m                         1
twin-net/get_twin_batch_pairs.m               1
twin-net/get_twin_batch_nat_live.m            1
twin-net/find_nat_patch.m                     1
twin-net/load_nat_A_pool.m                    1
twin-net/nat_near_far_patches_net.m           1
twin-net/texture_same_diff_patches_net.m      1
twin-net/train_net.m                          1
tools/golden_harness.m                        1
ALL PASS: 1
```

**Collision check**, `which('<new_name>', '-all')` under R2024b, run *before* the renames with `twin-net/` not yet on the path — all six empty, so no builtin, toolbox function, or sibling-repo function is shadowed:

```
=== forward_twin ===            (empty)
=== predict_twin ===            (empty)
=== model_loss ===              (empty)
=== pool_stats ===              (empty)
=== get_twin_batch_pairs ===    (empty)
=== get_twin_batch_nat_live === (empty)
```

**The seven required sweeps, and what each found.**

1. **The rename itself.** Six `git mv`s; each file's `function` line edited to match its new filename. Also re-checked repo-wide that every `function` line agrees with its filename: the only two apparent mismatches are `experiments/adaptive_hist_exp.m` and `twin-net/texture_same_diff_patches_net.m`, and both are *scripts* whose first `function` keyword introduces a local function — not real mismatches.
2. **Call-site sweep** (each old name as a bare identifier). Found in five callers: `twin-net/train_net.m` (the bulk — 12 call sites, plus `dlfeval(@modelLoss, …)` → `@model_loss`), `twin-net/model_loss.m` (calls `forward_twin`), `twin-net/forward_twin.m` and `twin-net/predict_twin.m` (both call `pool_stats`), and `tools/golden_harness.m` (three calls). All updated.
3. **Non-`.m` references.** `twin-net/net_plan.md` had four (one `getTwinBatch_nat_live`, three `poolStats`) — all updated. `docs/repo-cleanup.md` had three kinds of mention: the rename map in 3.1.1b (the old names *are* the map, left as they are), the section-2 casing census (updated with a fresh measurement), and the Stage 2 log entry naming the harness entry points (updated to the new names, with a parenthetical saying they were renamed here). No other non-`.m` file in the repo mentions any of the six.
4. **Dynamic references.** None exist. Grepped each old name as a quoted string (single and double), and separately grepped the whole repo for `feval`, `str2func`, `which(`, `exist(`, and `help <name>`: every `exist`/`which` hit is about a file path, a config field, or the `dlnetwork` toolbox probe, and no old name appears inside a string literal anywhere. The only indirection is `dlfeval(@model_loss, …)`, which is a bare-identifier function handle and therefore *is* covered by `check_stage1`'s regex.
5. **Already-written cross-references.** This was the real cost of running the tranche late instead of first, and it found more than the call-site sweep did. Stage 1 tranche 4 had written `See also` lines naming the old files in **eight** places across seven files, three of which contain no call at all (`find_nat_patch.m`, `load_nat_A_pool.m`, `nat_near_far_patches_net.m`) and so would have been missed by a call-site-only sweep. All updated. Prose mentions inside header docs were updated too (`load_nat_A_pool.m:17`, `nat_near_far_patches_net.m:8`, `texture_same_diff_patches_net.m:12`, `get_twin_batch_nat_live.m:11`, and the "use X during training, Y for inference" cross-links in `forward_twin.m`/`predict_twin.m`). **Neither `Contents.m` needed a change:** they exist only for `+segmentation/` and `+gtr/`, and neither names a `twin-net/` file — `twin-net/` is a plain directory with no `Contents.m` of its own.
6. **Package-qualified check — confirmed explicitly, not assumed.** `git ls-files | grep -o '^+[^/]*'` returns exactly `+gtr` and `+segmentation`, so `twin-net/` is a plain directory and none of the six functions is packaged. Independently, `git grep -nE "\.(forwardTwin|predictTwin|modelLoss|poolStats|getTwinBatch)"` returns nothing — not one call site anywhere had a `.` immediately before a renamed name. So the dot-qualified blind spot at `check_stage1.m:30` never came into play, every one of the twelve files was verified mechanically, and none needed diff-reading as a fallback.
7. **Collision check.** Above; all six clear.

**Binding decision for any later pass: the `See also` casing rule.** The repo spells `See also` entries in ALL CAPS (MATLAB's own convention, which is what makes them hyperlink in the editor). Converting `forwardTwin` → `forward_twin` therefore makes the entry `FORWARD_TWIN`, **not** `FORWARDTWIN`. The rule is: *a `See also` entry is the new filename uppercased verbatim, underscores kept.* That matches the entries the repo already had for its snake_case files (`TRAIN_NET`, `FIND_NAT_PATCH`, `LOAD_NAT_A_POOL`), so after this tranche every `See also` entry in `twin-net/` follows one rule instead of two. One line needed rewrapping as a side effect: `train_net.m:10-11` grew past 100 characters once three names gained underscores, so the break between its two comment lines moved (`MODEL_LOSS` shifted to the second line). That is a comment reflow, invisible to `canon`.

**Line lengths.** No file this tranche touched has a line over 100 characters as a result of it. `tools/golden_harness.m:67` is 115 characters, but that is the pre-existing `pair_responses` call line, untouched here, and `tools/` is not among the 66 in-scope style files.

**Commented-out code.** None in any of the twelve files — documented negative. The repo-wide triage (item 0.3.5, verdict table in section 3.3) had already swept all 66 files and found exactly one real block, in `demo/plot_stage2.m`, which this tranche did not open.

**Bugs found and not fixed:** two, both recorded in section 0.4 — 🟠 **B2.2** (the golden harness no longer replays; four fields differ, none of them `twin-net/`, and the cause predates this tranche) and 🟡 **B3.7** (two in-code pointers to the deleted `docs/readability-pass.md`).

**Optimizations found:** none. The permitted edit here was `git mv`, `function` lines, call sites, and doc references, so no loop body or numeric path was read closely enough to judge one, and nothing jumped out in what was read. Section 0.5 is unchanged by this tranche, and S3.1 (run the actual scan) stays open.

**Left ambiguous — one thing, and it matters more than this tranche does.** B2.2 is not diagnosable from inside a rename tranche. `tools/golden_ref.mat` and the current repo disagree on four of fifteen fields, and the honest position is that this tranche can prove only the narrow claim: *it* did not cause the disagreement, because all four failing entry points live in files it never opened and which are clean at HEAD. Whether the reference is merely stale or an output genuinely moved is the user's call, and **`golden_harness('capture', …)` was deliberately not run** — re-capturing now would bless whatever the current state happens to be, which is exactly why the standing authorization excludes capture. The field-by-field comparison that produced the diagnosis used a read-only copy of the harness in the scratchpad with its `save` branch removed, so nothing in `tools/` was written.

</div>

</details>

</div>

</details>

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">3.2 · Stage 2 · Hygiene</h3></summary>

<div style="margin-left:1.5em">

**Coverage gaps found while extending the golden harness, and their resolutions:**

- **`experiments/adaptive_hist_exp.m` is a script, not a function** — its local functions (`hist_gap_collect` etc.) have no callable entry point from outside the script, and restructuring it into functions would itself be Stage 3. **Decision: verify this file's Stage 2 edits with the structural pattern check only, no runtime golden check.**
- **`twin-net/` needed the Deep Learning Toolbox** to execute at all — resolved, toolbox is now installed and golden entry points are captured.

**Per-tranche work log:**

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 1 — `+segmentation/` + `+gtr/`</h4></summary>

<div style="margin-left:1.5em">

No Stage 2 edits made — none of the candidate patterns exist in this tranche. Checked all 12 files for: missing suppressing semicolons (none — every apparent hit was a trailing `%` comment after an already-present `;`), `find(...)` calls (zero in the tranche), unpreallocated array growth (`(end+1)` or growing-in-loop patterns — none; every accumulator is preallocated with `zeros`/`cell` sized up front), and unused-assignment lint warnings (`checkcode` reports only the two pre-existing `parfor`-broadcast notes in `content_features.m`/`content_similarity_matrix.m`, already logged as Stage 3 performance notes, not Stage 2 targets). This tranche was already this clean coming out of Stage 1. No golden-harness re-run needed since nothing changed.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 2 — `pipeline/` (21 files)</h4></summary>

<div style="margin-left:1.5em">

One real Stage 2 fix: `list_natural_images.m` grew a cell array one element at a time inside a nested loop (`files{end+1} = ...`, flagged `%#ok<AGROW>` by the author, i.e. already known and suppressed rather than fixed). Rewrote to size `files` once from a precomputed total count and fill it by index — same file order, same output. Verified by capturing `list_natural_images(cfg)`'s real output before the edit and asserting `isequal` against a fresh call after (391 files, exact match); also re-ran `golden_harness('replay', ...)` afterward and it still matches bit-for-bit. One line needed a reflow to stay under 100 characters after the rename (`listing`→`listings{set_idx}` pushed it over).

The rest of `pipeline/` has no Stage 2 opportunities: `checkcode` reports zero warnings repo-wide now (the one AGROW warning above was the only one); no other `find(...)` calls exist except `s4_optimize_bins.m:59` (`find(eccs == ecc, 1)`) paired with `eccs(end+1) = ecc` at `:61` — not a real target, since that list grows by exactly one element *once per function call* (not inside a loop; `eccs` holds at most the handful of eccentricities ever trained, e.g. `[1 2 4 8]`), so there's no repeated-growth pattern to preallocate against and no mask to index with instead of a scalar `find`. No missing suppressing semicolons found anywhere in the tranche.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 3 — `demo/` (18 files)</h4></summary>

<div style="margin-left:1.5em">

No Stage 2 edits made. `find(...)` appears in `plot_stage1b_gradients.m:202` (`h_pcs = find(pc_isH); v_pcs = find(~pc_isH)`), `plot_stage2.m:25,33-34`, and `plot_stage8_natural.m:44` — all genuinely need the numeric indices themselves (used to index into a second array, print a `PC%d` label, or as a scalar `xlim` bound), so none reduce to a "find→logical indexing" simplification. No unpreallocated growth, no missing semicolons.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 4 — `twin-net/` (11 files)</h4></summary>

<div style="margin-left:1.5em">

One real fix: `texture_same_diff_patches_net.m` grew `all_tex`/`brod_tex` one cell at a time inside a nested loop (`all_tex{end+1} = A`, `brod_tex{end+1} = A`, both flagged `%#ok<SAGROW>` by the author). Rewrote with a sizing pre-pass (`dir`/`min`/`numel` only, no RNG draws) that computes each database's `n_use` up front, then preallocates both cells and fills them by an incrementing index in the original loop -- same iteration order, so `randperm`'s draws happen in exactly the same sequence as before. Verified two ways: `checkcode` no longer flags either line, and an isolated synthetic replica of the loop structure (same per-database counts and RNG calls, stand-in "textures") gives `isequal` on both output cells between the old (growing) and new (preallocated) logic. Did not run the real script end-to-end for this check -- it performs slow, real disk I/O and overwrites `data/stimuli/textures/patch_pairs.mat`, so a full run wasn't done without asking first.

One line deliberately **not** touched: `train_net.m:405`, `average_accuracy = mean(accuracy)*100`, MATLAB's only other lint hit in this tranche ("add a semicolon to hide the output"). The variable is never read again, so the missing `;` is the script's only way to show that number when run interactively -- the user confirmed this is deliberate and asked that it be left alone, with a comment added (`% no ";" deliberately -- prints to the console`) so a future pass doesn't "fix" it. Same convention to be applied to any other deliberate unsuppressed-output line found later.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 5 — Root: `config.m`, `setup.m`, `run_demo.m`</h4></summary>

<div style="margin-left:1.5em">

No genuine Stage 2 target in any of the three (no `find`, no unpreallocated growth, no missing semicolons). One trivial cleanup found and made in `setup.m`: `try, web(url,'-browser'); catch, end` had an unnecessary comma (`checkcode` NOCOMMA). Reflowed to a normal multi-line `try`/`catch` -- turned out to be pure whitespace/separator normalization, not even a real Stage 2 change: `canon` on the new file is byte-identical to `canon` of the HEAD version (no rename map needed), so this was actually still Stage 1, just missed in that pass.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">Step 6 — `experiments/adaptive_hist_exp.m`</h4></summary>

<div style="margin-left:1.5em">

No Stage 2 edits (pattern-check-only tranche, per the gap noted above). The two `find(...)` calls (`:209`, `:378`) both pull a single bin-bounds index and can't be simplified to logical indexing. No unpreallocated growth, no missing semicolons. The only `checkcode` hits are the two pre-existing `parfor`-broadcast notes, already logged as Stage 3.

</div>

</details>

**Stage 2 is complete: two real fixes** (`pipeline/list_natural_images.m`, `twin-net/texture_same_diff_patches_net.m`), **one deliberate non-fix documented** (`twin-net/train_net.m:405`), **one stray Stage 1 cleanup caught along the way** (`setup.m`), and **no opportunities found** in `+segmentation/`, `+gtr/`, `demo/`, or `experiments/adaptive_hist_exp.m`. No new bugs surfaced during this tier.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">3.3 · Stage 3 · Organize</h3></summary>

<div style="margin-left:1.5em">

Fills in as each Stage 3 item (section 0.3) is actually done.

**Commented-out code — triage verdicts (item 0.3.5).** One row per block, filled in by reading the surrounding code, not the git history. Verdicts: *superseded* (the live code beside it does the same job better — name it) → delete; *scaffolding* (a stray debug print, plot, or timer) → delete or promote to a real debug flag; *alternative* (a method or parameter set the author could switch back to) → keep, but convert it into a documented option or a note in the header docs; *unfinished* (a sketch never completed) → keep, rewritten as a prose TODO; *unknown* (purpose not recoverable) → leave exactly as is. **Unknown is the default whenever the evidence runs out** — an honest unknown costs a few commented lines, while a wrong *superseded* can destroy the only copy of code that was never live and so is nowhere in the history.

**Result: one block, in one file.** The 66 in-scope files were swept for comment lines that look like MATLAB statements rather than prose — assignments, `for`/`if`/`end`, function-call statements, anything ending in `;` — then every hit was read in context. That produced 363 candidate non-header comment lines plus 101 statement-shaped header lines, and on inspection all but one are prose annotations, `Inputs`/`Output` blocks, `%%` section headers, or header-doc usage examples (which do not count as commented-out code). The detector is not blind: run unchanged over the excluded `Bill's old code/` it flags 389 lines across 19 files, which is what genuinely commented-out ancestral code looks like. **Verdict split: 0 superseded, 0 scaffolding, 1 alternative, 0 unfinished, 0 unknown.** Nothing was edited; the single conversion is item 0.3.10's job.

Notable, and worth the user's attention: section 2 measured **113 of 5744 lines** as commented-out code, and only one is real. Two things explain the gap. First, that 113 was an unvetted "looks like code" line count — re-running a comparably loose heuristic on the repo today gives ~155 hits, essentially all of them header-doc usage-example lines (`%   phi = segmentation.content_similarity_matrix(...)`), which Stage 1 *added* to every file, so the number went up while the real content went to zero. Second, `canon` strips comments, so `check_stage1` cannot see a commented-out line being deleted — a Stage 1 tranche could have removed such lines and still passed. Which of the two accounts for how much is not recoverable from the code, and per this item's method note the git history was deliberately not consulted. No bug was found; nothing added to section 0.4.

| block | file:lines | what the surrounding code says it was for | verdict | action taken |
|---|---|---|---|---|
| `stage2-pdf-ylim` | `demo/plot_stage2.m:46` — `% ylim([0 1]); % Removed ylim because PDF can exceed 1 or have a different scale` | Sits inside the local function `plot_feature`, between `set(gca, 'YTick', [])` (line 45) and `trunc_xlim(e, N)` (line 47). The live code fixes the *x* range (`trunc_xlim`, the 1%–99% span of the CDF `N`) and hides the y ticks entirely, but never constrains the y range — so `ylim` is not reimplemented anywhere else in the file, it was simply dropped. `pdf = diff([0, N])` on line 43 is a per-bin probability mass whose peak depends on the feature and the bin widths, which is exactly the reason the author wrote down. Every identifier it references (`ylim`) is still valid, and switching it back on would be a one-character edit. | **alternative** — a display parameter the author tried, switched away from, and recorded the reason for inline. Not *superseded*: no live code replaced it. Not *scaffolding*: it is a presentation setting, not a debug print. | recommend: convert, do not delete. Replace the two-part line with plain prose in the same spot, e.g. `% No y-limit: the per-bin PDF can exceed 1, and its scale differs per feature.` That keeps the one thing of value (why there is no `ylim` here, so a later reader does not "fix" its absence) and stops it masquerading as code. Low risk, cosmetic only. |

---

**Item 0.3.10 — convert the `stage2-pdf-ylim` block in `demo/plot_stage2.m`.** Done 2026-09-15. Re-located by name, not by line number: the block was still exactly where the 0.3.5 triage found it, at `demo/plot_stage2.m:46`, inside the local function `plot_feature`, between `set(gca, 'YTick', [])` (line 45) and `trunc_xlim(e, N)` (line 47).

The surrounding code said this block was a display parameter the author tried and switched away from: the live code fixes the x-range and hides the y-ticks but never constrains the y-range, and the comment recorded why (`pdf = diff([0, N])` is a per-bin probability mass whose peak varies by feature and bin width, so a fixed `ylim([0 1])` doesn't hold in general).

Verdict from 0.3.5: *alternative*. Action per that verdict: keep the reason, convert to prose, drop the fake `ylim` call — not a delete, since no block here was judged *superseded* or *scaffolding*.

Changed:
```matlab
% before
        % ylim([0 1]); % Removed ylim because PDF can exceed 1 or have a different scale
% after
        % No y-limit: the per-bin PDF can exceed 1, and its scale differs per feature.
```

Verified by diff review only (the plan's own note: this is a comment-only edit, no executable code touched, so `check_stage1`/AST checks don't apply and aren't meaningful here). Confirmed the diff touches exactly this one line in this one file, nothing else.

---

**Item 0.3.3 — `arguments` block for `pipeline/pair_responses.m`.** Done 2026-09-15, MATLAB R2024b. The item was re-located by name, not by line number, and is still accurate: the function still had the same ten positional arguments and no validation of any kind.

The block, placed after the header comment and before the first statement:

```matlab
    arguments
        patches              {mustBeNumeric, mustBeReal}
        bin_bounds     (:,:) {mustBeNumeric, mustBeReal}
        n_bins               {mustBeInteger, mustBeNonnegative}
        feature_list         {mustBeMember(feature_list, [0, 1])}
        spot_llr_dims        {mustBeInteger, mustBePositive}
        edge_llr_dims        {mustBeInteger, mustBePositive}
        power_suppress (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        edge_thresh    (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        patch_size     (1,1) {mustBeInteger, mustBePositive}
        cfg            (1,1) struct
    end
```

**Validation policy: attributes always, size only where the size is load-bearing.** The hard constraint on this item is that validation may reject what was never valid but must not narrow what is currently accepted, and a size specification is the easiest way to break that. So a size appears in only three places, each one load-bearing: `(1,1)` on the three scalars, which the body uses as scalars (`1:patch_size`, and both constants passed straight into `vislab.nat_stat_bayes.dv_power` / `dv_edge_hist`), so a non-scalar was never valid; `(:,:)` on `bin_bounds`, which its sole producer `vislab.nat_stat_bayes.load_bin_bounds` returns as an `n_features x max_bins` matrix and its consumers index as `(f, 1:n_bins(f))`, so a 3-D-or-higher array was never valid; and `(1,1) struct` on `cfg`.

Three deliberate omissions, each one a case where the obvious-looking validation *would* have narrowed:

- **No size on the four vectors** (`n_bins`, `feature_list`, `spot_llr_dims`, `edge_llr_dims`). All four are documented as row vectors and every producer in the repo yields a row, so `(1,:)` was tempting — but no orientation here is load-bearing. `vislab.nat_stat_bayes.dv_spot_hist` and `dv_edge_hist` both return `1 x numel(feature_list)` *rows* (their own headers, line 30 and line 31 respectively), and for a vector `v` the expression `v(idx)` takes `v`'s orientation regardless of `idx`'s, so `rh`/`re` stay rows and the `[rh, re, rp]` concatenation is safe even if a caller passed a column of dims. Specifying `(1,:)` would therefore have rejected input that works today, for no gain. The attribute validators still catch the realistic error this item exists to catch — a mis-ordered positional call.
- **No `(:,:,:,:)` on `patches`**, even though the header documents a 4-D tensor. Whether a 4-dimension size specification rejects a 3-D array depends on MATLAB's trailing-singleton rules in `arguments` blocks, which I did not verify (verifying it would have needed a headless run outside the standing authorization). A 3-D single-pair array does work today — `size(patches, 4)` is 1 and the `patches(..., :, i)` indexing is valid — so an unverified 4-D specification risked narrowing. Class and realness only; the shape stays documentation.
- **No `mustBeNonempty` on `patches`.** A zero-pair tensor such as `zeros(64, 128, 1, 0)` is currently valid and useful: `size(patches, 4)` is 0, the loop never runs, and the function returns an empty `R`, an empty `keep`, and a fully-populated `col`. `mustBeNonempty` would have rejected it. Confirmed by the call-site probe below, which relies on exactly that path.

**`cfg` is validated as a whole struct, not field by field.** Three reasons, in order of weight. (1) Its fields are zone-2 config-struct vocabulary whose renaming is item 0.3.7's job; spelling `cfg.norm.target_contrast` and the four `cfg.dv.sd*` names into a validator here would create a second place 0.3.7 has to edit, for no new guarantee. (2) MATLAB's `arguments` block has no facility for nested field paths, so enforcing them means a custom local validation function — a new function added to the file, duplicating knowledge the header already carries. (3) A missing field already fails immediately and legibly: `cfg.norm.target_contrast` is read on the very first statement of the body, before any computation, so a validator would move the error a few lines earlier and nothing more.

**No argument was given a default, and the reason is structural rather than a judgement call.** MATLAB requires optional positional arguments to be *trailing* — a required argument may not follow one with a default. `cfg` is the tenth argument, is required, and has no sensible default, so no argument before it can be made optional without reordering, which is out of scope (see below). This settles the question independently of the call-site evidence, but the call sites agree anyway: reading all six invocations, the only argument every caller passes identically is `power_suppress`, and even there three of the five files pass the variable `cfg.dv.power_suppress` rather than a literal, with only `tools/golden_harness.m:67` passing a bare `16`. `config.m:97` is the single source of truth for that value and should stay so; a default of 16 baked into the signature would become a second one.

**Argument order unchanged.** No correctness reason to change it, and reordering would touch all six invocations at both name and position — a separate and riskier class of Stage 3 change.

**`lo`/`hi` (the `-25`/`+25` outlier window) deliberately left hardcoded in the body — out of scope for this item.** Two reasons. First, nothing wants to vary them: no caller parameterizes the window, and there is no configuration path to it. Second, and decisively, `docs/to-do.md` item 11 ("Outlier rejection: magnitude window → finiteness test") plans to *delete* both variables outright, replacing `all(check > lo) && all(check < hi)` with `all(isfinite(check))` after Bill's revised `nat_near_far_dv_2.m:131`. Promoting them to arguments-with-defaults now would add plumbing at every level that a planned revision then has to unpick, and would freeze an arbitrary cutoff into the public signature just as the intent is to remove it. They are already named local constants on one line, which is as much clarity as they need while they live.

**Header doc corrected while documenting the validated arguments.** The `cfg` line listed only `cfg.norm.target_contrast` and `cfg.dv.sd1/nsd1/sd2/nsd2`, but the body also reads `cfg.features.spot_achr_dims` (to size `col.spot_achr`). Added. This is a documentation inaccuracy, not a bug — no behaviour is wrong — so nothing was filed in section 0.4.

**Call sites: six invocations in five files, none changed.** A positional call stays positional under an `arguments` block, and every invocation already passes exactly ten arguments, so no call syntax needed to change. Exhaustiveness: `grep -rn "pair_responses" .` over the *whole* repo including the two gitignored ancestral-code directories returns hits in eleven files, of which the six below are invocations and the rest are prose mentions in header docs (`demo/patch_to_rgb_display.m`, `demo/plot_stage5.m`, `demo/plot_stage5_intermediate.m`, `demo/sample_texture_pairs.m`, `pipeline/s4_optimize_bins.m`, `run_demo.m`) or in `docs/`. **Neither `Bill's old code/` nor `Bill's old code - revised/` contains any reference**, so no live ancestral caller exists. A separate grep for `['"]pair_responses` found no quoted-string or dynamic (`feval`/`str2func`/`exist`/`which`) reference anywhere outside `.git/`.

| # | invocation | changed? |
|---|---|---|
| 1 | `demo/compute_demo_responses.m:41` | no |
| 2 | `demo/compute_demo_responses.m:43` | no |
| 3 | `demo/plot_stage6_pairs.m:58` | no |
| 4 | `pipeline/s5_train_decision_vars.m:75` | no |
| 5 | `pipeline/s5_train_decision_vars.m:77` | no |
| 6 | `tools/golden_harness.m:67` | no |

**Call-site type-check, all six, by execution.** `tools/golden_harness.m:67` is checked for real by the harness run below — it executed through the new block and produced the same checksum as before. For the other five, a scratchpad probe rebuilt each call site's actual argument expressions from `config(true)` and `vislab.nat_stat_bayes.load_bin_bounds`, then passed them to `pair_responses` with a zero-pair `patches` tensor, so the validators ran in full while the loop body never executed. Verbatim:

```
compute_demo_responses / plot_stage6_pairs VALIDATION OK   size(R)=[0 11]  numel(keep)=0  col fields: spot, spot_achr, spot_chrom, edge, power, border
s5_train_decision_vars (x2)                VALIDATION OK   size(R)=[0 11]  numel(keep)=0  col fields: spot, spot_achr, spot_chrom, edge, power, border
golden_harness                             VALIDATION OK   size(R)=[0 11]  numel(keep)=0  col fields: spot, spot_achr, spot_chrom, edge, power, border
```

`demo/plot_stage6_pairs.m` was also traced by hand, as the item asked: `patch_size = cfg.patch.size / ecc` = 64/1 = 64 (integer, positive — `config.m:77` and `run_demo.m:112` give 64 and `ecc = 1`; `ecc` is documented repo-wide as an integer divisor from {1,2,4,8}, all of which divide 64, so `mustBeInteger` cannot fire on any current path); `spot_llr_dims = cfg.features.spot_dims` and `edge_llr_dims = cfg.features.edge_dv_dims` are positive integer row vectors from `config.m:140-147`; `power_suppress = 16` and `edge_thresh = 50` are nonnegative real scalars from `config.m:97-98`; `feature_list = zeros(1, 20)` with `cfg.features.dv_dims` set to 1, so it holds only 0s and 1s and satisfies `mustBeMember`; `bin_bounds`/`n_bins` come straight from `load_bin_bounds`. Every one type-checks.

**Golden harness, before and after — no field changed its verdict.** Verbatim `golden_harness('replay', 'tools/golden_ref.mat')` first, which gives only the aggregate assert:

```
{Error using assert
golden output changed -- this edit is not behaviour-preserving

Error in golden_harness (line 127)
    assert(isequal(ref.golden, golden), 'golden_harness:mismatch', ...
```

That is B2.2 and it names no field, so the per-field reading needed the computed struct, which replay mode discards when it throws. A scratchpad helper called `golden_harness('capture', <scratchpad>/pre.mat')` and compared the returned struct against the committed reference field by field. **`tools/golden_ref.mat` was not written, not re-captured, and is unchanged** — the capture went only to a session scratchpad path, so nothing was blessed. Before the edit:

```
--- per-field comparison vs tools/golden_ref.mat ---
prep_grid_checksum               FAIL  numeric mismatch  ref=25338656.607611127  new=25338098.821923982  absdiff=557.78568714484572
dv_fields                        PASS
demo_pairs_size                  PASS
pair_responses_checksum          FAIL  numeric mismatch  ref=224307.79032615953  new=232569.37061908742  absdiff=8261.5802929278871
pair_responses_keep_n            PASS
content_similarity_checksum      FAIL  numeric mismatch  ref=1442.0785314816135  new=1051.740400388818  absdiff=390.33813109279549
grow_region_masks_checksum       PASS
grow_region_masks_size           PASS
sample_texture_ids_checksum      PASS
sample_texture_pairs_checksum    FAIL  numeric mismatch  ref=13586114.960232332  new=13582226.131522207  absdiff=3888.8287101257592
sample_texture_pairs_same_gt     PASS
apply_dv_checksum                PASS
forward_twin_checksum            PASS
predict_twin_checksum            PASS
pool_stats_checksum              PASS
```

After the edit, byte-for-byte the same output — same eleven PASS, same four FAIL, and identically the same `new=` values to all 17 digits:

```
--- per-field comparison vs tools/golden_ref.mat ---
prep_grid_checksum               FAIL  numeric mismatch  ref=25338656.607611127  new=25338098.821923982  absdiff=557.78568714484572
dv_fields                        PASS
demo_pairs_size                  PASS
pair_responses_checksum          FAIL  numeric mismatch  ref=224307.79032615953  new=232569.37061908742  absdiff=8261.5802929278871
pair_responses_keep_n            PASS
content_similarity_checksum      FAIL  numeric mismatch  ref=1442.0785314816135  new=1051.740400388818  absdiff=390.33813109279549
grow_region_masks_checksum       PASS
grow_region_masks_size           PASS
sample_texture_ids_checksum      PASS
sample_texture_pairs_checksum    FAIL  numeric mismatch  ref=13586114.960232332  new=13582226.131522207  absdiff=3888.8287101257592
sample_texture_pairs_same_gt     PASS
apply_dv_checksum                PASS
forward_twin_checksum            PASS
predict_twin_checksum            PASS
pool_stats_checksum              PASS
```

Three things this pins down, all relevant to B2.2. The four failing fields are exactly the four B2.2 names, so this edit neither added nor removed a failure. `pair_responses_checksum` fails the *same way* before and after — a numeric mismatch with an identical fresh value, not a dimension or validation error — so the new block rejects nothing the harness passes. And `pair_responses_keep_n` **passes** in both runs, meaning the same set of pairs survives outlier rejection and only the summed response value differs; B2.2 remains open and untouched, with that as a new datum for whoever settles it.

**`checkcode('pipeline/pair_responses.m')` is clean** (empty output) with the block in place.

**No bug and no optimization found while doing this item** — a documented negative. Nothing was added to section 0.4 or 0.5. The `mustBeInteger` pass over `n_bins` is the only new per-call work and it is a scan of a 20-element vector, immaterial next to the per-pair histogram loop.

---

**Item 0.3.12 — readable names for the cross-file and saved vocabulary.** Done 2026-11-24, MATLAB R2024b. Left uncommitted: the user's standing rule is that they review and commit.

**Goal (the user's words):** comments that explain the non-obvious variables, and more obvious names where possible; then remove as much of the README glossary as possible. Binding decisions from the user: paper-symbol names become words; names copied from Bill's code are renamed too, with an our-name ↔ Bill's-name table; names stored in saved files are renamed too, via a one-off migration script.

**Naming rule used (binding for later work).** The shortest snake_case word(s) that are unambiguous where the name lives, reusing words the repo already had: `est_map` and `n_correct` (already in `count_correct_regions`, `adjusted_rand_index`, `s7`), `content_sim` (already the argument name in `mutual_similarity` and `group_patches`), and the `col.spot`/`col.edge`/`col.border` column names, so a trained handle reads `apply_dv(dv.spot, R(:, col.spot))`. A struct field and the local that fills it get the same name, and a saved bound and the handle built from it share a name (`decision_bounds.spot` → `dv.spot`). Bill's names stay wherever the text is *about* Bill's code: the strings that patch his code in `tools/compare_otf_*.m`, all of `tools/capture_bill_segmentation.m` (untouched), the golden file `tools/golden_bill_segm.mat`, and prose such as "Bill's rho".

**Rename map** (bare identifiers unless a field is named; every renamed field keeps its position, so struct field order is unchanged):

| old | new | where |
|---|---|---|
| `phiall` | `content_sim` | var + `S` field (`learn_image_similarity`, s6); `phi` output of `content_similarity_matrix` too |
| `rho` | `mutual_sim` | var + `S` field |
| `phi` | `neighbor_sim` | var + `S` field (neighbour border+content similarity) |
| `mu` | `combined_sim` | var + `S` field |
| `dst` | `patch_dist` | var + `S` field |
| `gc`, `wm` | `group_crit`, `mutual_weight` | args/vars; s6 `out` fields |
| `gc_vec`, `wm_vec`, `gc_idx`, `wm_idx`, `ngc`, `nms` | `group_crit_vec`, `mutual_weight_vec`, `crit_idx`, `weight_idx`, `n_crit`, `n_weight` | vars |
| `gcopt`, `wmopt` | `group_crit_best`, `mutual_weight_best` | var + `S` field |
| `pc`, `pcs`, `pcd`, `pcnf` | `accuracy`, `accuracy_same`, `accuracy_diff`, `accuracy_nearfar` | vars + `S` fields |
| `pcav`, `pcsav`, `pcdav`, `pcnfav` | `accuracy`, `accuracy_same`, `accuracy_diff`, `accuracy_nearfar` | s6 `out` fields |
| `pcmx` | `accuracy_best` | `S`/`seg` field |
| `rcn rbn rmn` / `rcf rbf rmf` | `content_near border_near mutual_near` / `content_far border_far mutual_far` | vars + `R`/`S` fields |
| `ncnt`, `scnt`, `dcnt` | `n_pairs`, `n_near`, `n_far` | `R` field / vars |
| `npx`, `npy` (neighbor_far_responses) | `n_rows`, `n_cols` | vars |
| `rc`, `rb` (DVs of one pair) | `content_dv`, `border_dv` | vars |
| `qbs`, `qbd` | `bc_near`, `bc_far` | vars |
| `copt`, `rbcn`, `rbcf`, `dvbc` | `shift`, `unshifted_near`, `unshifted_far`, `bc_dv` | vars (self_sup_decision) |
| `ncs ncd sc dc ncn ncf` | `same_ok diff_ok n_same n_diff near_ok far_ok` | vars (nearfar_score_grid) |
| `emap`, `ngrps`, `nrg` | `est_map`, `n_groups`, `n_correct` | vars + `seg` fields |
| `dv.h`, `.e`, `.c`, `.b`, `.bc` | `dv.spot`, `.edge`, `.content`, `.border`, `.border_content` | handle-struct fields |
| `dbnd` | `decision_bounds` | **saved** variable |
| `dbnd.h ha hb pg ms_n e c b bc spot_achr_n` | `.spot spot_achr spot_chrom ms_grad n_ms_grad edge content border border_content n_spot_achr` | **saved** fields |
| `dvh dve dvc dvb dvha dvhb dvh2`/`dvh_2d` `dvpg dve_last` | `spot_dv edge_dv content_dv border_dv spot_achr_dv spot_chrom_dv spot_combine_dv ms_grad_dv final_dv` | vars |
| `btype`, `cstat`, `eccb` | `bound_type`, `feature_bound_type`, `bin_ecc` | vars; `bound_type` also **saved** (bins files) |
| `itype`, `itypes` | `texture_set`, `texture_sets` | args/vars; s6/s7/compare_otf `out`/`result` fields |
| `pcg` | `gradient_pca` | var + **saved** variable |
| priors `N<tag>`, `e<tag>` | `cdf_<feature>`, `edges_<feature>` | **saved** variables; features `a_pixel b_pixel r_pixel edge_mag edge_ori edge_mag_ori bar_mag bar_ori bar_mag_ori cs_ratio_small cs_linear_small cs_linear_large pc1 pc2 pc3` |
| `img_feats`/`s` fields `g1m g1o g1mo g2m g2o g2mo cs1 cs2 cs4` | the same feature names | fields (sample_prior_features → finalize_priors) |
| s6 `mp` and its fields `pd itype dgc gcmx dms msmx`; `ntrl`, `trl`, `px`, `py` | `method_params` with `pupil_diameter texture_set group_crit_step group_crit_max mutual_weight_step mutual_weight_max`; `n_trials`, `trial`, `patch_x`, `patch_y` | vars/fields |
| `ntexr` (s7), `emaps` (compare_otf_models), `stage_order` (check_bill_segmentation) | `n_regions`, `est_maps`, `stage_names` | vars |

No `cfg` field was renamed (config() returns identical structs, below); item 0.3.7 still owns that.

**Deliberately left alone.** `ecc`, `lms`, `ppd`: standard names; `config.m` now defines `ecc`'s rough degrees, LMS/ABR and `coeff`, and already had `ppd` in pixels/deg. The patch-pair file's `ptchn`/`ptchf`/`pcnt` (data/stimuli, ~1 GB, and `rename_check` reads `pp.ptchn`): documented in `load_patch_pairs`'s header instead. `twin-net/` saved names (`same_brod`, `fcParams`, …): out of scope. External names: `vislab` function names and its `load_bin_bounds` file contract (`bin_bounds`, `n_bins`, `eccs` stay; vislab's own doc still says `btype` for the type field), and `classify_normals`/`pca` output fields (`samp_opt_bd`, `coeff`, `mu`, `explained`). The `self_sup_decision` method strings (`'bc'`, `'c_shft'`, …) and `cfg.segment.method` values (saved in `segmentation_params*.mat`): values, not names. File-local terse names outside this vocabulary (the `g1m` locals in sample_prior_features, `ea`/`Na` locals in the experiment script): commented where they meet a renamed field. `tools/golden_ref.mat` and `tools/golden_bill_segm.mat` were not regenerated. `golden_harness` runs with the new names, but its reference field `dv_fields` holds the old `dv` field names, so a replay will now report that field as well as B2.2's four.

**README.** The Glossary now holds only the paper-symbol ↔ code map: the decision-variable table (adding the trained-handle names, `cfg.features.edge_dv_dims` and PC features 15–17) and a similarity/grouping table (φ, μ/u, w_m, s, γ_l, γ_c, γ_r, β). Everything else moved into code comments or into `docs/segmentation-parity.md` §4. The code comments are in `config.m` (LMS/ABR/`coeff`, ecc ↔ degrees, normalization targets; the feature-dimension list was already next to `cfg.features`). The parity doc takes Bill's names, the `NO`/`BF` file tags and the N/NC/NCB… labels. `p_s`, `p_d` were dropped because no code uses them. Paper symbols were checked against the text of `docs/paper.pdf`: $u_{ij}$ (Eq. 1) and $s_{ij}$ (Eq. 2, the combined similarity) are verified. The weight's and φ's glyphs did not survive text extraction, so `w_m` and φ are carried over from the old README, not re-verified. A stale fact fixed while there: the s6/s7 signatures in the pipeline table.

**Other docs.** `docs/segmentation-parity.md` gains §4 (our name ↔ Bill's name; every Bill name was grep-checked in `Bill's code/`). `docs/to-do.md` and `docs/color-extension-plan.md` got a note that their code snippets quote pre-rename names; rewriting pending-task snippets by hand risked changing what they mean. The two prose references in to-do.md were updated, as were `docs/top-level-scripts-plan.md` and `twin-net/net_plan.md`. Historical work-log text in this file is unchanged.

**Baselines.** `git show HEAD:<file>` for every clean file. For the dirty or untracked files (`demo/plot_dv_hist.m`, `demo/plot_range.m`, `demo/plot_stage5.m`, `demo/plot_stage5_intermediate.m`, `tools/make_readme_figure.m`, `data/models/segmentation_params_pcagrad.mat`), the on-disk content before this item. All were copied to the session scratchpad first, and `data/models` was backed up in full before migrating.

**Verification, verbatim.**

1. Behaviour: `rename_check('replay', ref.mat)` segments 2 GTR images in default and PCA mode, evaluates the DV handles and computes 300 Stage-5 pair responses. It compares values in field order and ignores names. After the code edits, before migrating any file:
```
Starting parallel pool (parpool) using the 'Processes' profile ...
Connected to parallel pool with 8 workers.
RENAME_CHECK PASS (8 items identical)
Parallel pool using the 'Processes' profile is shutting down.
```
After `migrate_saved_names` and the loader/saver updates:
```
Starting parallel pool (parpool) using the 'Processes' profile ...
Connected to parallel pool with 8 workers.
RENAME_CHECK PASS (8 items identical)
Parallel pool using the 'Processes' profile is shutting down.
```

2. Migration, run twice (idempotent):
```
--- run 1
  migrated:         decision_bounds_ecc_1.mat
  migrated:         decision_bounds_ecc_1_color_otf_bill.mat
  migrated:         decision_bounds_ecc_1_otf.mat
  migrated:         decision_bounds_ecc_1_otf_bill.mat
  migrated:         decision_bounds_ecc_1_pcagrad.mat
  migrated:         AHEO_bins.mat
  migrated:         AHEO_bins_bill.mat
  migrated:         AHE_bins.mat
  migrated:         AHE_bins_pcagrad.mat
  migrated:         gradient_pca.mat
  migrated:         priors_abr_mo13_mo23_cs33_ecc_1.mat
  migrated:         priors_abr_mo13_mo23_cs33_otf_ecc_1.mat
  migrated:         priors_abr_mo13_mo23_cs33_pcagrad_ecc_1.mat
--- run 2
  already migrated: decision_bounds_ecc_1.mat
  already migrated: decision_bounds_ecc_1_color_otf_bill.mat
  already migrated: decision_bounds_ecc_1_otf.mat
  already migrated: decision_bounds_ecc_1_otf_bill.mat
  already migrated: decision_bounds_ecc_1_pcagrad.mat
  already migrated: AHEO_bins.mat
  already migrated: AHEO_bins_bill.mat
  already migrated: AHE_bins.mat
  already migrated: AHE_bins_pcagrad.mat
  already migrated: gradient_pca.mat
  already migrated: priors_abr_mo13_mo23_cs33_ecc_1.mat
  already migrated: priors_abr_mo13_mo23_cs33_otf_ecc_1.mat
  already migrated: priors_abr_mo13_mo23_cs33_pcagrad_ecc_1.mat
```
Values check of each migrated file against the backup, name for name (and `decision_bounds` field order = `dbnd`'s): `MIGRATION VALUES: 13 of 13 files equal to backup`.

3. AST checks over every edited `.m` file: 53 files, including the two untracked demo helpers, which this item left unchanged. `strict` is `check_stage1` with the file's bare-identifier map, after `assert_rename_bijection`. It cannot see field or string renames, so it fails, as expected, on every file that renames a struct field or a field-name string. `extended` reverses every recorded rename (identifier, `base.field`, quoted string) in reverse order of application and compares the canons; entries that matched nothing in the old file are skipped. The two `extended=0` files were checked by reading the diff. In `config.m` the only code change is the load name `'pcg'` → `'gradient_pca'`; the reversal also hits the unrelated filename string `'gradient_pca'`. In `tools/check_bill_segmentation.m` the change is real and intended: the stage list became a two-column our-name/Bill-name map, and `first_difference` looks up Bill's name in the golden file. That tool is a legacy fixture and was not run.
```
+segmentation/adjusted_rand_index.m           strict=1 extended=1
+segmentation/assign_isolated_patches.m       strict=1 extended=1
+segmentation/content_features.m              strict=1 extended=1
+segmentation/content_similarity_matrix.m     strict=1 extended=1
+segmentation/group_patches.m                 strict=1 extended=1
+segmentation/learn_image_similarity.m        strict=0 extended=1
+segmentation/merge_similar_regions.m         strict=1 extended=1
+segmentation/mutual_similarity.m             strict=1 extended=1
+segmentation/neighbor_similarity_matrix.m    strict=0 extended=1
+segmentation/segment_lms.m                   strict=0 extended=1
config.m                                      strict=0 extended=0
demo/compute_demo_responses.m                 strict=1 extended=1
demo/pc_filter_images.m                       strict=1 extended=1
demo/plot_dv_hist.m                           strict=1 extended=1
demo/plot_model_diagram.m                     strict=1 extended=1
demo/plot_range.m                             strict=1 extended=1
demo/plot_stage1b_gradients.m                 strict=1 extended=1
demo/plot_stage2.m                            strict=0 extended=1
demo/plot_stage5.m                            strict=0 extended=1
demo/plot_stage5_intermediate.m               strict=0 extended=1
demo/plot_stage6.m                            strict=0 extended=1
demo/plot_stage6_pairs.m                      strict=0 extended=1
demo/plot_stage7.m                            strict=0 extended=1
demo/plot_stage7_pair_accuracy.m              strict=0 extended=1
demo/plot_stage8_natural.m                    strict=0 extended=1
demo/sample_texture_pairs.m                   strict=1 extended=1
experiments/adaptive_hist_exp.m               strict=0 extended=1
pipeline/decision_bounds_filename.m           strict=1 extended=1
pipeline/edge_dv_handle.m                     strict=0 extended=1
pipeline/finalize_priors.m                    strict=0 extended=1
pipeline/load_dv_handles.m                    strict=0 extended=1
pipeline/load_patch_pairs.m                   strict=1 extended=1
pipeline/load_texture_images.m                strict=1 extended=1
pipeline/make_gtr_image.m                     strict=1 extended=1
pipeline/nearfar_score_grid.m                 strict=0 extended=1
pipeline/neighbor_far_responses.m             strict=0 extended=1
pipeline/s1b_learn_gradient_pca.m             strict=1 extended=1
pipeline/s23_learn_priors_and_pairs.m         strict=1 extended=1
pipeline/s4_optimize_bins.m                   strict=0 extended=1
pipeline/s5_train_decision_vars.m             strict=0 extended=1
pipeline/s6_selfsup_discrimination.m          strict=0 extended=1
pipeline/s7_segment_gtr.m                     strict=0 extended=1
pipeline/sample_prior_features.m              strict=0 extended=1
pipeline/segment_image.m                      strict=0 extended=1
pipeline/self_sup_decision.m                  strict=0 extended=1
run_demo.m                                    strict=0 extended=1
tools/check_bill_segmentation.m               strict=0 extended=0
tools/compare_otf_bill.m                      strict=0 extended=1
tools/compare_otf_models.m                    strict=0 extended=1
tools/golden_harness.m                        strict=0 extended=1
tools/import_bill_model.m                     strict=0 extended=1
tools/make_readme_figure.m                    strict=0 extended=1
tools/segment_bill_image.m                    strict=1 extended=1
check_stage1 (bare-identifier map): 21 of 53 files true
extended check (all recorded renames reversed): 51 of 53 files true
```

4. `checkcode` on every changed tracked `.m` file plus the new `tools/migrate_saved_names.m`, against each baseline (message texts, line numbers ignored): `CHECKCODE: 52 files, 0 new message texts`.

5. `config()` for 13 argument combinations, old code + backed-up data vs new code + migrated data, paths normalized. The structs are identical because no `cfg` field was renamed.
```
config(): equal = 1
config(false): equal = 1
config(true): equal = 1
config(false, false): equal = 1
config(true, false): equal = 1
config(false, true): equal = 1
config(true, true): equal = 1
config(false, true, false): equal = 1
config(true, false, true): equal = 1
config(false, false, [], true): equal = 1
config(false, true, [], true): equal = 1
config(true, true, [], true): equal = 1
config(true, false, [], true): equal = 1
CONFIG COMBOS: 13 of 13 equal
```

**Found, not fixed.** B2.3 (an s6 display label). No optimization spotted. One line-length exception added: `run_demo.m`'s Stage 8 `fprintf` string (117 characters; splitting a literal is an AST change).


</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">3.4 · Stage 4 · Bugs</h3></summary>

<div style="margin-left:1.5em">

Bugs discovered while doing stage 1/2/3 are recorded in section 0.4 as they're found, each with its `B<severity>.<n>` id and emoji; their fixes, done last and in that order, get logged here — what was wrong, the fix, and how it was verified (call-site search, not a mechanical check). If the severity turned out to be wrong once the bug was looked at properly, say so here, and re-file it in 0.4 under the correct severity's next `n` — a new id, not a relabel of the old one.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">3.5 · Stage 5 · Speed</h3></summary>

<div style="margin-left:1.5em">

One entry per section 0.5 item, filled in as it's measured. Each entry carries all of: the re-triage verdict (does the item still exist after stages 3 and 4, or did an organizational change or bug fix already dissolve it), the **before** timing with input size and repeat count, the golden-output result (bit-identical for a Proven item, inside the agreed tolerance for a Perturbing item, tolerance quoted), and the **after** timing on the same input and repeats.

**A measured null result is a completed item.** If the speedup didn't justify the diff, the change was reverted — log the numbers that said so. For an item still marked Unprofiled, the profile *is* the item: log where the time actually went, then update its status to Proven or Perturbing with a number attached (re-tiering if the measurement changes the priority call), or close it here.

Timing and profiling runs execute the real pipeline, so they fall outside the standing headless-MATLAB authorization — each one is asked for first, with its wall-clock cost stated.

| item | re-triage | before | after | output check | kept? |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">3.6 · Stage 6 · Closing</h3></summary>

<div style="margin-left:1.5em">

One entry, filled in once, when 0.6 is actually run — not per sub-item, since it's one gate, not a findings list. States the result of each of the four checks (0.6.1–0.6.4), verbatim checker output for the two mechanical ones, and any discrepancy found and how it was resolved before the plan was called complete.

</div>

</details>

</details>
