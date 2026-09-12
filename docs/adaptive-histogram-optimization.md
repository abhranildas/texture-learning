# Adaptive histogram optimization for same/different texture discrimination

*On pipeline Stage 4 ([`s4_optimize_bins.m`](../pipeline/s4_optimize_bins.m)) and the histogram decision
variable it feeds. Companion to the proximity paper (Geisler, bioRxiv 2026).*

## 1. The discrimination decision variable, as a per-bin divergence $D_i$

For one feature, each patch becomes a histogram of counts over fixed bins $i = 1,\dots,B$. Given per-bin
counts $a_i$ (patch A) and $b_i$ (patch B), with $n_a=\sum_i a_i$, $n_b=\sum_i b_i$, $N=n_a+n_b$, the
decision variable (the log-likelihood ratio $L$;
[`multinomial_llr.m`](../../vislab-common/+vislab/+nat_stat_bayes/multinomial_llr.m), paper Eq. 1/A4) is

$$L = \sum_i L_i, \qquad L_i = a_i\ln\frac{a_i}{n_a} + b_i\ln\frac{b_i}{n_b} - (a_i+b_i)\ln\frac{a_i+b_i}{N} \;\ge 0$$

($L_i \ge 0$ by concavity of entropy.) Rewritten, $L$ is **exactly $N \cdot D$**, where
$D = \mathrm{JSD}(a,b)$ is the Jensen–Shannon divergence between the normalized patch histograms. The identity holds **bin by bin**, $L_i = N\,D_i$.

So the DV measures how *divergent* the two patch histograms are, and $\{D_i\}$ is a per-bin **divergence
profile** summing to $D$: near-zero in every bin for near pairs (alike histograms), large in bins where
far pairs diverge. This frames the whole diagnostic — **compare the near-pair and far-pair distributions
of $D_i$, bin by bin:** bins where far pairs' $D_i$ systematically exceeds near pairs' (a large near/far
gap) carry the discriminative signal; bins where near and far look alike carry none (§4 makes this
precise). *(From here on we use the divergence form $D$, $D_i$; recall $L=ND$, $L_i=ND_i$, so nothing
changes if you'd rather track the LLR directly — only the overall scale $N$ differs.)*

## 2. Improvements

The current experiment (`adaptive_hist_exp.m`) shows the JSD-profile-equalized bins roughly tied with
plain uniform bins, both a bit below the model's shipped adaptive bins — for the achromatic (A) feature
only. Open questions and next steps, in rough priority order:

1. **The JSD-density argument is right locally, and worth stating explicitly.** For a small difference
   $\delta(x) = p_A(x) - p_B(x)$ around the pooled density $\bar p(x)$, the JSD density is
   $\approx \tfrac{1}{8}\,\delta(x)^2/\bar p(x)$ — exactly the per-bin $d'^2$ contribution for multinomial
   counts. So JSD density is a legitimate discriminability density; this derivation belongs in §1 as the
   theoretical basis for equalizing it.
2. **But equalizing JSD mass may not be the optimal allocation rule.** A wide bin only costs discriminability
   if the log-likelihood ratio $r(x) = \log\big(p_A(x)/p_B(x)\big)$ varies across it — a flat $r$ costs
   nothing. The optimal (Lloyd–Max / Panter–Dite style) quantizer allocates bin density
   $\propto \big(p(x)\,|r'(x)|^2\big)^{1/3}$, not $\propto$ signal mass. Equalizing mass likely
   over-allocates bins to the peak of the JSD profile where $r$ is already smooth, at the expense of
   places where $r$ is changing fast. Worth testing directly against the current mass-equalized scheme.
3. **Per-bin $D_i$ are correlated, and the total signal is not their sum.** Total discriminability is
   $\Delta\mu^\top \Sigma^{-1} \Delta\mu$ over the joint distribution of $\{D_i\}$, not
   $\sum_i D_i$ treated independently — panel i's bin-bin correlation matrix already shows this
   structure. Equalizing marginal signal is only optimal if $\Sigma$ is diagonal; quantifying how far off
   diagonal it is would show how much headroom any bin-placement rule actually has, and may explain why all
   schemes saturate near the same accuracy.
4. **Test on features beyond A.** A is smooth, unimodal, and signal-rich almost everywhere — close to the
   worst case for showing that bin placement matters. The heavy-tailed edge / center-surround features
   (dims 5, 9, 10, 13, 14) and smaller patches at higher eccentricities (sparser per-bin counts) are where a
   principled placement rule should separate from uniform binning most clearly. Running the same comparison
   across features and eccentricities also turns one noisy curve into a paired, reportable result.