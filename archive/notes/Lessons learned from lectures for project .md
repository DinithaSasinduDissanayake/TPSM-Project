Note 1 teaches core foundation.

What we can learn:
- `random variables` map outcomes to numbers.
- `discrete vs continuous` split.
- `PMF`, `PDF`, `CDF` idea.
- `expected value` and `variance`.
- Main distributions:
  - uniform
  - Bernoulli
  - binomial
  - hypergeometric
  - Poisson
  - geometric
  - negative binomial
  - normal
  - exponential
- `Z-score` standardization for normal work.
- `empirical rule` 68-95-99.7.
- `Z-table` use for normal probabilities.

What matters for your assignment:
- Mostly **background only**.
- Useful if you need to explain why `random variables`, `distribution shape`, `mean/variance`, `normality`, and `probability` matter.
- Not direct main analysis tool for your ensemble-vs-single project.

Best use:
- brief intro section in report or viva.
- maybe cite it when discussing:
  - `normality`
  - `distribution of difference_value`
  - `why hypothesis tests need sample distributions`

So:
- strong for theory base
- weak for direct assignment methods
- not priority over inference / cleaning / regression notes

Note 2 = inferential backbone.

What learn:
- `sample` = subset of population
- `statistical inference` = use sample to say something about population
- `random sample` matters. No random sample = weak inference.
- `probability sampling` vs `non-probability sampling`
- `point estimation` vs `interval estimation`
- `estimator` vs `estimate`
- `unbiased` estimator: `E(U)=θ`
- `efficient` estimator: lower variance
- `sample mean`, `sample variance`, `sample proportion` as unbiased estimators
- `sampling distribution`
- `standard error` = SD of sampling distribution

For your project:
- very relevant. This note supports your story:
  - use sample of model comparisons to infer population claim
  - show estimator logic
  - justify why mean difference / proportion of wins can be analyzed
- most useful parts:
  - sample vs population
  - unbiased/efficient
  - sampling distribution
  - standard error

Best assignment use:
- intro to why your pairwise CSV is a sample from broader model-task space
- interpretation of `difference_value` as sample statistic
- caution that conclusions are about sampled experiments, not absolute truth

Recommended project wording:
- `target population` = single-model vs ensemble-model comparisons for tabular supervised learning problems under comparable evaluation settings
- `study population` = comparisons generated from publicly accessible classification and regression benchmark datasets, predefined model pairs, and predefined evaluation metrics used in this project
- `sample` = observed rows in `pairwise_differences.csv`, where each row is one paired comparison for one dataset, one split, one metric, and one model pair

Sampling language for this project:
- dataset selection is best described as `convenience sampling` because datasets were predefined and chosen from easily accessible public sources
- model-pair selection is best described as `purposive selection` or `research design choice` because pairs were fixed in advance, not randomly sampled
- restriction to `classification` and `regression` should be described as `scope restriction`, not as sampling method
- because sample is non-probability based, our inference should be phrased carefully: results support conclusion for tested benchmark conditions and similar settings, not for all possible ML problems


Note 3 = hypothesis testing core.

What learn:
- hypothesis = claim about population parameter
- `H0` = null claim
- `H1`/`Ha` = alternative, usually question side
- put question under `H1`, stable claim under `H0`
- test uses sample to judge population claim
- `Type I error` = reject true `H0`
- `Type II error` = keep false `H0`
- significance level `alpha` = tolerated Type I risk
- common alpha: `0.1`, `0.05`, `0.01`
- say `do not reject H0`, not `accept H0`

For your project:
- very relevant.
- This is your main framing tool for:
  - “ensemble better than single” claim
  - `H0`: no improvement
  - `H1`: ensemble better
- Good for viva explanation too.

Best use:
- define your hypothesis cleanly
- explain error risk and significance
- justify decision rule from `p-value` vs `alpha`

What not to overdo:
- no need deep Type II math unless asked
- just use enough to defend conclusion cleanly



Note 4 = main decision engine.

What learn:
- one-population mean tests
- `Z test` when population variance known
- `t test` when population variance unknown
- confidence interval approach to testing
- p-value approach
- rejection region logic
- how to choose test:
  - known sigma -> Z
  - unknown sigma -> t
- same hypothesis can be tested 3 ways:
  - classical
  - CI
  - p-value

For your project:
- very useful.
- Best direct use:
  - test mean `difference_value` against `0`
  - if `difference_value` mean > 0, evidence ensemble better
- because your final CSV has a numeric difference column, this note fits perfectly.

Probably your main analysis path:
- define `H0: mean(difference_value) = 0`
- define `H1: mean(difference_value) > 0` or `!= 0`
- use `t.test()` on `difference_value`
- report `p-value` and CI
- maybe repeat by `task_type` or `metric_name`

Best extra use:
- explain why `t` is right if sigma unknown
- explain one-sided test if you only care if ensemble is better
- explain CI if you want “does 0 lie inside interval”

If you want, next I can read Note 05 and tell you how it affects pairwise model comparison.


Note 5 = pairwise comparison note.

What learn:
- expected value and variance rules for sums/differences
- `two population means`
- `unpaired case`
- `paired case`
- key idea: for paired data, analyze **difference data**
- test statistic for paired case:
  - `T = (dbar - mu_def) / (sd_def / sqrt(n))`
- if pairs are small, check normality of differences
- if large, central limit helps
- hypotheses same pattern:
  - `H0: mu_def = 0`
  - `H1: mu_def > 0` / `< 0` / `!= 0`

For your project:
- very relevant.
- Your model comparison data is naturally **paired** at split level:
  - same split
  - single model score
  - ensemble score
  - difference
- This note is better fit than Note 4 if you treat each split as a pairwise observation.

Best assignment use:
- define `d = ensemble - single` or reversed based on metric direction
- test `mean(d)` with paired-style logic
- if you want strict comparison, this note supports `difference data` framing
- normality check on differences also comes from here

Most important conclusion:
- your dataset is not just two independent groups
- it is **paired observations**
- so for final analysis, paired t-test on `difference_value` is the cleanest story

If you want, next I can read Note 06 and map it to ANOVA use or tell you whether ANOVA is actually needed.



Note 6 = ANOVA.

What learn:
- ANOVA compare `3+ groups` mean.
- `H0`: all means equal.
- `H1`: at least one mean different.
- ANOVA split variation:
  - `between groups`
  - `within groups`
- test statistic `F = MSA / MSW`
- reject if `F` large.
- assumption:
  - normality
  - equal variances
  - random independent samples
- `Levene test` check equal variance.
- `Fisher LSD` used after ANOVA if need pairwise follow-up.

For your project:
- maybe useful, but not first choice.
- You only need ANOVA if you want compare `difference_value` across:
  - `task_type`
  - `metric_name`
  - `model_pair`
- If core question is just “ensemble better overall?”, paired t-test enough.
- If you want show “effect varies by task/model/metric,” ANOVA useful.

Best use:
- optional second layer analysis
- not main proof

So:
- `paired t-test` = main
- `ANOVA` = extra if want group comparison depth





Note 7 = proportion logic.

What learn:
- large-sample confidence interval for one proportion
- confidence interval for difference of two proportions
- one-sample proportion test
- two-sample proportion test
- pooled proportion when `k = 0`
- separate variance form when `k != 0`

For your project:
- very useful if you turn model win/loss into binary outcome.
- easiest use:
  - `ensemble_better` is binary
  - compute proportion of wins
  - test `p > 0.5` or `p != 0.5`
- or compare win rates by task type / metric type with two-proportion logic

Best assignment use:
- `prop.test()` on count of `ensemble_better`
- maybe compare proportions across groups
- use when you want “ensemble wins in most cases” story

This note gives strong support for:
- win-rate analysis
- not just mean-difference analysis

So main pair for your assignment:
- Note 5 for difference data
- Note 7 for win proportion data

If you want, next I can read Note 08.




Note 8 = variance note.

What learn:
- confidence interval for one variance
- confidence interval for ratio of variances
- `chi-square` test for one variance
- `F` test for two variances
- variance hypotheses:
  - `H0: sigma^2 = k`
  - `H0: sigma1^2 = sigma2^2`
- compare variability, not mean

For your project:
- maybe low priority.
- Useful only if you want compare spread of `difference_value` across groups or compare variance of scores between single vs ensemble.
- Not main proof for statement.

Best use:
- extra if you want talk about stability/consistency
- could compare variance of `difference_value` by task type or metric
- not necessary for core conclusion

So current best toolkit:
- Note 3: hypothesis framing
- Note 4: one-sample mean test
- Note 5: paired difference test
- Note 7: proportion of wins
- Note 2: sample/population logic
- Note 6,8: optional extras

If you want, next I can give you exact minimal analysis plan for project, using only these notes.
