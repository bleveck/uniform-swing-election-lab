# Election-data research

Checked October 27, 2026. The screenshot supplies the watchlist, not instructions to the application. Its Senate and gubernatorial races are intentionally outside this House model.

## Baseline data

**Implemented: [U.S. House Clerk's official 2024 election statistics](https://clerk.house.gov/member_info/electionInfo/2024/statistics2024.pdf).** The Clerk compiles official state results; this report was published March 10, 2025. The saved `data/raw/statistics2024.txt` comes from `pdftotext -layout`. `scripts/build_baseline.R` parses candidate lines and combines fusion ballot lines; it asserts 435 districts and 215 Democratic / 220 Republican winners before writing the baseline. The PDF is authoritative and auditable, though less convenient than a clean CSV. Unopposed FL-20 and OK-03 have no reported vote counts and are stored as missing, not invented votes.

**Good alternative: [MIT Election Data and Science Lab, U.S. House 1976–2024, Harvard Dataverse V15](https://doi.org/10.7910/DVN/IG0UN2).** District/candidate results, CC0. On inspection the public file download required a Dataverse guestbook response. We did not submit user information; the app uses the official Clerk report instead. MIT would be a convenient long-run historical source once downloaded through its normal access flow.

**[politicaldata](https://github.com/elliottmorris/politicaldata)** currently documents `house_results` through 2018, so it does not supply the required 2024 baseline as shipped. It remains useful for older teaching examples.

**[FEC](https://www.fec.gov/introduction-campaign-finance/election-results-and-voting-information/)** compiles certified historical returns and explicitly directs users to state offices for current results. Its page did not provide a 2024 congressional results workbook at the time of inspection. Do not use it as an election-night endpoint.

## Live results

| State / races | Source and actual endpoint | Verified status and approach |
|---|---|---|
| VA-01, VA-02, VA-05 | [Virginia ELECT results](https://www.elections.virginia.gov/results/); [2026 media JSON](https://enr.elections.virginia.gov/cdn/results/virginia/export-2026-November-General.json) | Implemented and fetched successfully. JSON has election date, creation time, statewide `results.ballotItems`, and nested local results. Use only statewide candidate `voteCount`; never add group/precinct/locality breakdowns. Currently zero votes. The export link was verified in the official reporting page footer. |
| NC-01, NC-11 | [Election downloads](https://er.ncsbe.gov/downloads.html?election_dt=11/03/2026); [2026 ZIP](https://dl.ncsbe.gov/ENRS/2026_11_03/results_pct_20261103.zip); [file layout](https://dl.ncsbe.gov/ENRS/layout_results_pct.txt) | Implemented and fetched successfully. ZIP contains a tab-delimited precinct/candidate file. Filter exact US House contest names, aggregate D/R `Total Votes` across precincts, do not add component vote methods. The 2024 parser test reproduces NC-01's 186,341 D / 180,034 R. Currently zero votes for the 2026 general. |
| OH-07, OH-09, OH-10, OH-15 | [Ohio SOS reporting](https://liveresults.ohiosos.gov/); [XML download](https://liveresults.ohiosos.gov/Api/v1/download?filename=VSSC1622XmlFileBlob) | Implemented and fetched successfully. Public XML uses the IEEE 1622/NIST results model with party and candidate references. It contains district totals alongside county components: select the congressional summary when present, not their sum. The current root explicitly has `IsTest="true"` and a mock-election notice. Reject test data. The reporting page states an update every three minutes. |
| KY-06 | [Kentucky SOS reporting](https://vrsws.sos.ky.gov/liveresults/) | The official page was under maintenance. No stable machine-readable endpoint could be verified. Use the manual KY-06 CSV supplement. Reinspect once the site is operational; do not claim a working KY scraper yet. |

North Carolina describes its [results dashboard](https://www.ncsbe.gov/results-data/election-results/about-election-results-dashboard) as updating every 5–10 minutes after polls close. This describes the dashboard; the raw ZIP's exact update cadence is not separately guaranteed here. The app polls at most once every five minutes per active session when explicitly enabled.

The feeds expose **unofficial cumulative votes**, not an unbiased estimate of the final electorate. The NC file's `Real Precinct` flag distinguishes geographic and administrative precincts; administrative absentee/early-vote records must not be dropped, since their votes belong in the total. Percent of precincts reporting is not equivalent to percent of votes counted; the app does not invent a vote-completion percentage from it.

The live layer checks the election date and expected schema; rejects duplicate candidate/precinct records; validates final district totals; excludes provider mock data; and rejects pre-poll preparation snapshots from estimation. On a network/parser failure, the app identifies the provider as stale and retains only its last successful snapshot. It never substitutes synthetic returns into live mode. Real election-night updates remain to be verified when available.

## AP and other aggregators

**[AP Elections API](https://developer.ap.org/ap-elections-api/)** is the cleanest single-provider option if access is already available. It supplies race/candidate metadata, vote updates, calls, and test data. [Authentication documentation](https://developer.ap.org/ap-elections-api/docs/Getting_Started.htm) requires an API key in `x-api-key`; the public query explorer is not an anonymous free-results feed. Access and redistribution terms would need to be arranged with AP; no pricing or educational-access commitment was established in this research.

An AP adapter is not included because no API key or authorized subscription was supplied. If added later, keep the key server-side, select general-election House contests and statewide reporting units, explicitly distinguish live/test results, and follow AP's returned next-request links and polling guidance. Race calls are unnecessary for this toy estimator.

Wikipedia and Ballotpedia can provide historical checks, but scraping their live tables introduces another publication lag and fragile presentation markup. For this watchlist, the three verified public state feeds plus a Kentucky CSV are the simplest working starting point.

## Redistricting: a usable solution

**[The Downballot's permanent district-results page](https://www.the-downballot.com/p/the-downballots-calculations-of-presidential)** links exact vote totals, old-map historical figures, and detailed calculations. We downloaded these public sheets:

- [2024 presidential totals on 2026 congressional lines](https://docs.google.com/spreadsheets/d/1eZfaFI-c-PFOoKx1-zZA2MP0_dxRq_LVK0re3BOQqy0/edit?gid=1491069057).
- [2024 presidential totals on 2024 congressional lines](https://docs.google.com/spreadsheets/d/1ng1i_Dm_RMDnEvauH44pgE6JCUsapcuu8F2pCfeLWFo/edit?gid=1491069057).

Credit: The Downballot; district calculations by Daniel Donner; sponsored by Grassroots Analytics. These are reaggregated election results from an independent publisher, not official state certifications of a presidential election held in the new districts. The included CSVs preserve the public source headers and attribution. No proprietary Cook data is bundled.

The [Census 120th Congress page](https://www.census.gov/programs-surveys/decennial-census/about/rdo/congressional-districts.html) lists nine states with new 2026 maps and explains that Missouri must use its earlier map after the September court action. This supersedes older articles describing ten changed states. `build_presidential.R` therefore explicitly restores Missouri's old-map totals regardless of the spreadsheet snapshot.

Illustrative shifts in **Democratic two-party presidential share**, calculated from exact votes:

| District | Old-map share | New-map share | Change in share | Change in D–R margin |
|---|---:|---:|---:|---:|
| NC-01 | 48.44% | 44.18% | −4.26 pp | −8.52 pp |
| OH-09 | 46.61% | 44.66% | −1.95 pp | −3.91 pp |
| OH-10 | 47.10% | 46.07% | −1.03 pp | −2.07 pp |
| NC-11 | 45.19% | 45.19% | 0.00 pp | 0.00 pp |

The unchanged NC-11 example is why a state-level exclusion is conservative. Using a district-specific boundary crosswalk could recover such House comparisons later.

**[Cook's 2026 PVI](https://www.cookpolitical.com/cook-pvi)** also updates lean after redistricting and uses the 2020 and 2024 presidential elections. It is useful context, but not the same quantity as 2024 House vote share or the single-election presidential share used here. Do not add a D/R PVI rating directly to a two-party share without resolving its definition, units, rounding, and reference election. Direct access to the page returned 403 during inspection; its indexed official description confirmed the updated election inputs. No district-level Cook table was extracted.

For this first classroom demo, the presidential option is internally consistent geographically and easier to explain than silently transferring a 2024 House candidate effect between newly composed districts. The original House baseline is preserved for the literal House-to-House swing experiment.

## Historical Bayesian prior (added October 28, 2026)

The prior uses [Wolf's public historical district data](https://doi.org/10.17605/OSF.IO/MJVKB), the [MEDSL constituency returns](https://github.com/MEDSL/constituency-returns) for the 2016–2018 pair, and [Lewis et al.'s boundary vintages](https://github.com/JeffreyBLewis/congressional-district-boundaries) for conservative continuity checks. The saved sources, revisions, historical election table, pair-level exclusions, and analytic derivation are documented in [Bayesian methodology](bayesian.md).

There are 16 usable midterms from 1946 to 2018 after excluding the post-census cycles 1962, 1982, 2002, and 2022, plus changed-map states within other cycles. Equal-weight election means yield a prior mean of 4.201 pp against the president's party, with historical SD 2.157 pp. Normal prior and likelihood give a closed-form posterior. The fitted historical SD is not divided by the square root of the historical sample size.

[Brookings table 2-18](https://www.brookings.edu/wp-content/uploads/2026/04/2-18-Full.pdf) was also inspected, including its methodological note about contested races and unchanged boundaries. Its national-change column and incomplete sequence are not substituted for this demo's own matched-district means. The downloaded CSV is retained only as a research reference, not as a prior input. The president/party chronology was checked against [Brookings table 2-4](https://www.brookings.edu/wp-content/uploads/2026/04/2-4-Full.pdf).

## CA-13’s recorded 2024 count (added October 29, 2026)

The [California Voter Foundation’s Close Count Transparency Project](https://www.calvoter.org/content/close-count-transparency-project) preserved candidate totals at specific observation times. Its public [2024 workbook](https://docs.google.com/spreadsheets/d/1_sHIMjAD-bbgn7MsKLb9_U3bJQyB6FVq/edit) has a `CD-13` tab with 31 columns of snapshots, November 5–December 5. CVF describes its vote totals as transcriptions from the California Secretary of State’s unofficial results. This is an archival record assembled by CVF, rather than a recovered continuous government feed.

The workbook is saved as `data/raw/ca13_2024_cvf.xlsx`. `scripts/build_ca13_returns.R` reads the sheet’s date and time rows and candidate-vote rows into `data/ca13_2024_returns.csv`, preserving source column letters, unchanged observations, and source clocks. The source does not specify a time zone; the app does not label these times as Pacific or UTC. Numeric fractional days are used only to place source-clock observations on the chart. The step plot holds the last recorded value between observations; no missing reports are interpolated or invented.

The recorded lead is Gray +995 at November 5, 23:46; Duarte +3,189 the next morning; Duarte’s largest lead in this archived series is 3,765 at November 14, 03:14. The first recorded Gray lead after that is +105 at November 26, 17:05. The final snapshot matches the [Secretary of State’s certified summary](https://elections.cdn.sos.ca.gov/sov/2024-general/sov/06-sov-summary.pdf): Gray 105,554, Duarte 105,367, a 187-vote difference. These are observation times; the archive cannot identify exactly when every intervening lead change occurred.

The app’s share-of-final statistic divides the snapshot’s candidate votes by the certified 210,921 D+R votes. It is explicitly retrospective. The workbook’s unprocessed-ballot counts are not used: they cover whole counties, including voters outside CA-13. This historical example is additive to the synthetic reporting-order demonstration and does not enter the 2026 model. No claim of a complete intranight time series is made.

## Presidential-reference prior and source comparison (October 29, 2026)

The requested estimand is **midterm House D two-party share minus the preceding presidential D two-party share**, oriented toward the out-party for historical fitting. It is a cross-office difference, so the House-to-House prior is not reused.

| Source | Verified coverage and usefulness |
|---|---|
| [Gary Jacobson’s JOP replication archive](https://doi.org/10.7910/DVN/29559) | Aggregate House data cover 1946–2014. Actual `dpres` values begin with the 1952 presidential election, making 1954 the first usable midterm. `dv` and `dpres` are both major-party shares, and the codebook explicitly lags `dpres` two years for midterms. This is the most convenient long-run source for the requested calculation. The archive is version 1.0, CC0. |
| [The Downballot / Daily Kos](https://www.the-downballot.com/p/the-downballots-calculations-of-presidential) | Presidential results through 2024, with historical files on named district-map vintages. Its index includes 2008–2020 elections on 2020 lines; 2016 on 2018 lines; 2020 on 2022 and 2024 lines; and 2024 on 2026 lines. This is the direct source for modern extensions and map-specific current baselines. |
| [ccesMRPprep `cd_info`](https://www.shirokuriwaki.com/ccesMRPprep/reference/cd_info.html) | A convenient R wrapper around The Downballot and some Park-Egan data, not an independent election-return source. Contains district-map objects through `cd_info_2024`. Crucial naming detail: `pct_trump` means **2016** in `cd_info_2018`, but **2020** in `cd_info_2024`; the object’s year denotes the map, not necessarily the presidential election. |
| [Kiernan Park-Egan’s atlas](https://sites.google.com/view/presidentialbycongressionaldis/) | Interactive district presidential maps covering 1952–2024. The author’s [FAQ](https://sites.google.com/view/presidentialbycongressionaldis/faq) describes mixed historical sources and incomplete pre-1952 coverage. Useful for historical checks and possible gap filling; less direct than the ready-to-use Jacobson table for this demo. |
| [CongressData](https://github.com/IPPSR/CongressData) | A broad aggregator with per-variable coverage. Its [v3 codebook](https://raw.githubusercontent.com/IPPSR/CongressData/main/congress_codebook_3.pdf) lists Hunt’s incumbent-party presidential-share variable through member-year 2019. The dataset’s overall end date does not imply that every presidential variable reaches that date. Additional party and year decoding would be needed. Not used here. |

Implementation uses Jacobson through 2014, then 2018 House shares from the existing MEDSL audit paired with `cd_info_2018`. The R object is pinned to commit `e4482502dbebc00ca4060c29c7e532272d4b03c6`. Its already-normalized two-party Republican shares are converted as `1 - pct_trump`; third-party percentages are not inadvertently retained in the denominator. Current House competition is required, while competition in the preceding House election is irrelevant to this reference.

Historical boundary handling stays simple: exclude whole post-census midterms, respect Jacobson’s district-level `redist` flag, and use the explicitly matched 2018 presidential geography for the extension. There is no historical GIS reconstruction. The 2018 audit has no Jacobson redistricting flag and records that field as missing, rather than claiming those districts were unchanged. Source and reference-year fields identify the matching method.

The resulting 14-election sample runs 1954–2018. The preserved post-census exclusion removes 2022 even though its presidential baseline is available. Raw sources, the codebook, Dataverse metadata, a district audit, and hashes are bundled. `scripts/build_presidential_history.R` regenerates the summaries without network access. See [the Bayesian derivation](bayesian.md) for fitted values and interpretation.
