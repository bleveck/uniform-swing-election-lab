# Normal historical priors for midterm performance

The app now defaults to **House-minus-president** performance and retains **House-to-House** swing as an alternative. They have separately fitted priors and residual scales. The conjugate update and conditional-independence assumption are the same for both.

## Default: House-minus-president

For district \(i\) in midterm \(t\), the quantity is \(100[H^D_{it}-P^D_{i,t-2}]\), using Democratic two-party shares. Reverse its sign under Democratic presidents to orient history toward the out-party. Each midterm contributes its equal-weight mean over eligible districts. `scripts/build_presidential_history.R` writes the election summary, pair audit, and prior summary as `data/historical_president_*.csv`.

The [Jacobson aggregate replication dataset](https://doi.org/10.7910/DVN/29559), version 1.0, supplies `dv` and `dpres` through 2014. Its codebook defines both as major-party shares (in percentage points), with `dpres` lagged two years in midterms. The API-provided tab file contains trailing rows with no year; these are discarded. Districts are decoded using the codebook’s alphabetical state index. Missing or unopposed House shares and `redist == 1` are excluded. No historical GIS reconstruction is required.

For 2018, House shares come from the saved MEDSL current-share audit; **2016 House competition is not required**. Presidential shares come from `cd_info_2018` in [ccesMRPprep](https://www.shirokuriwaki.com/ccesMRPprep/reference/cd_info.html), pinned to commit `e4482502dbebc00ca4060c29c7e532272d4b03c6`. The package credits The Downballot / Daily Kos; its `pct_trump` in that object denotes **2016** two-party vote on **2018** lines. Democratic share is `1 - pct_trump`. Pennsylvania is usable here because the presidential reference is explicitly reaggregated to the midterm map.

The first usable midterm is 1954: the source has no presidential shares for 1946 or 1950. The sample contains **14 midterms through 2018**, retaining the rule excluding whole post-census midterms 1962, 1982, 2002, and 2022. The new prior for 2026 is:

```text
theta ~ Normal(mean = +7.164989 pp, SD = 5.687770 pp)
pooled within-election district residual SD = 10.88906 pp
```

This captures cross-office performance, including historical ticket splitting and candidate differences. It is not a pure midterm penalty or a presidential-to-presidential swing. Earlier Democratic House candidates often outran Democratic presidential candidates; that contributes to this prior’s location and spread. It would be inappropriate to reuse the narrower House-to-House prior for this estimand.

At default replay snapshot 6, the raw mean is +3.102709 pp; the posterior is +4.192269 pp, with SD 2.945660 pp and 26.821% historical weight. Both replay files are generated from the same classroom pattern on their respective reference maps, so selecting a different reference never silently reinterprets a snapshot from the other map.

## House-to-House alternative

The following historical construction and numerical example describe the House-to-House alternative. Its target is the common change in Democratic **two-party House vote share**, in percentage points, between a presidential-year House election and the following midterm. The same update formulas apply to the default with its own fitted parameters above.

## Historical construction

`scripts/build_history.R` produces a fully inspectable sample from saved sources:

- **Wolf / King / CLEA:** [Wolf's OSF data archive](https://doi.org/10.17605/OSF.IO/MJVKB), described in [Wolf (2017), Scientific Data](https://doi.org/10.1038/sdata.2017.108). The compact `extended_6311.csv` supplies historical district two-party shares through 2014. Earlier data come from Gary King; later data from the Constituency-Level Elections Archive. Credit Levi John Wolf, Gary King, and the CLEA team. OSF lists CC BY 4.0. This project filters and transforms those source records.
- **Modern extension:** [MIT Election Data and Science Lab's constituency returns](https://github.com/MEDSL/constituency-returns), revision `fe67c056502fc09ddb1ace2ff8f87c53233a744e`. Both sides of the 2016–2018 pair use this source. Candidate fusion ballot lines are combined with the endorsed major-party candidate. General, non-special, non-runoff totals are selected; the source's missing runoff flag is not interpreted as a positive runoff indicator. The source file is decoded as Latin-1 because some candidate names are not valid UTF-8.
- **Boundary screen:** [Lewis, DeVine, Pitcher, and Martis's boundary archive](https://github.com/JeffreyBLewis/congressional-district-boundaries), revision `3c663a8098b58156601e0893f0e67b502f7f8354`. Its public file inventory encodes state boundary vintages and the Congresses when each applies. We preserve that compact metadata as `data/raw/boundary_vintages.csv`; no large geometry files are needed.

The conventional post-census midterm cycles **1962, 1982, 2002, and 2022** are excluded entirely. In all other midterms, the screen drops every state with a new boundary vintage at the current Congress. States without verified continuity across both Congresses also fail closed. The archive warns that vintages can change after mapping revisions even without legal redistricting, so this conservatively drops some legally unchanged districts. It is a continuity screen, not a claim to identify every legal boundary change perfectly.

Then pair districts by state and district number, retaining only shares strictly between zero and one in both elections. Ambiguous multi-seat at-large IDs are excluded. The source's at-large conventions are normalized for the modern pair. The district audit lists every retained pair and every exclusion reason, including Pennsylvania's 2018 redistricting and the widespread 1966 changes.

For each remaining midterm, take the **unweighted mean district swing**. If the incumbent president's party is Democratic, reverse its sign. Thus a positive historical observation always means swing against the president's party. Negative observations stay in the sample; 1998 is an example. The historical electoral unit is one midterm, not one district and not one ballot.

There are **16 included midterms**: 1946, 1950, 1954, 1958, 1966, 1970, 1974, 1978, 1986, 1990, 1994, 1998, 2006, 2010, 2014, and 2018. Data from 1944 provide only the preceding-election share for 1946. There are no pre-1946 midterm observations in the prior. The omitted 2022 cycle explains why the latest included midterm is 2018.

`data/historical_midterms.csv` reports all 20 midterms and their inclusion decisions. `data/historical_pair_audit.csv` provides pair-level calculations. `data/historical_prior.csv` stores the fitted summary. Source snapshots, codebooks, and hashes are bundled for reproducibility.

## Prior and likelihood

Let \(z_t\) be each historical midterm's mean share swing against the president's party. Fit the simple empirical prior for a **new midterm**:

\[
\mu_0 = \operatorname{mean}(z_t)=4.200877,\qquad
\tau = \operatorname{sd}(z_t)=2.157266.
\]

For a Republican president, \(\theta_D\sim N(\mu_0,\tau^2)\). For a Democratic president, the mean becomes \(-\mu_0\), with the same SD. The SD is the spread of historical outcomes, **not** the standard error of their estimated mean. Using \(\tau/\sqrt{16}\) would wrongly pretend the next midterm is almost known just because the historical average is measured reasonably well.

For the current snapshot, the original app gives the raw equal-weight mean \(\bar y\) across \(n\) eligible districts. Use the working likelihood:

\[
\bar y\mid\theta \sim N(\theta,s^2),\qquad
s^2=\frac{\sigma_d^2}{n}.
\]

The historical within-election residual SD is pooled across the retained district pairs:

\[
\sigma_d=\sqrt{\frac{\sum_t(n_t-1)\,\operatorname{var}(\Delta_{it})}{\sum_t(n_t-1)}}=7.072660\text{ pp}.
\]

This is the simple independent-district Gaussian model: district swings have zero covariance conditional on the common swing \(\theta\), with a common residual variance \(\sigma_d^2\). Consequently, the raw average has standard error \(\sigma_d/\sqrt n\). The model uses no geography or district demographics. The app permits multiplying the prior SD to illustrate weaker or stronger historical information.

The independent observations in this likelihood are districts. With the same included districts and fixed prior settings, more votes may change the raw mean but do not add district observations or change the precision weight. Each snapshot replaces its predecessor. Conditional independence is a teaching assumption, and the historical district residual scale does not establish calibration for this watchlist or measure error in partial returns.

## Analytic update

The product of two Normal kernels is Normal:

\[
v_1=\left(\tau^{-2}+s^{-2}\right)^{-1},\qquad
\mu_1=v_1\left(\frac{\mu_0}{\tau^2}+\frac{\bar y}{s^2}\right).
\]

Writing \(w=\tau^2/(\tau^2+s^2)\) makes the teaching point explicit:

\[
\mu_1=(1-w)\mu_0+w\bar y.
\]

At replay snapshot 6, \(n=10\), \(\bar y=3.102863\), \(s=2.236571\), and \(w=0.481957\). Thus:

```text
posterior mean = 0.518043 × 4.200877 + 0.481957 × 3.102863
               = 3.671682 pp
posterior SD   = 1.552697 pp
95% interval   = [0.628451, 6.714912] pp
```

With no eligible observations, the posterior equals the prior. The seat display then explicitly says **prior only**. More included districts decrease the historical weight, as does increasing the prior SD multiplier. The displayed likelihood curve is normalized for visual comparison with the prior and posterior.

An independent hand example in the tests uses prior \(N(4,2^2)\) and one observation \(-2\) with noise SD 3. Then \(w=4/13\), \(\mu_1=28/13\), and \(v_1=36/13\). The tests also recover these values through numerical integration of prior times likelihood.

## Limits of this option

This is a **plug-in empirical prior**. It treats the fitted historical mean, prior SD, and district residual scale as known. A model integrating their uncertainty could use a Student-t predictive distribution or a hierarchical model; that would complicate this particular analytic example. The Normal prior already allows gains by the president's party and has an elementary conjugate update, so it is the default here.

No historical sample selection makes early reported districts representative, and prior/posterior agreement does not prove the model right. The interval is conditional on this model, not a calibrated forecast interval or probability of winning the House. The seat graphic applies the selected mean shift everywhere; it does not integrate district-specific uncertainty or publish majority probabilities.

Each historical prior applies to its own reference. Both support Bayesian mode; selecting one switches the fitted prior, historical graphics, and replay consistently. The House alternative retains its live changed-map exclusions. The default presidential reference uses presidential results already aggregated to 2026 boundaries.
