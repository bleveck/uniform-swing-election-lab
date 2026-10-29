# A short classroom sequence

Begin on **Start here** with the premise: a political scientist has slept through the election cycle and wakes up on election night.

The introduction defaults to the preceding presidential vote. Explain that its difference is midterm House share minus presidential share, not a presidential election held during the midterm. Switch to the preceding House election to compare the two definitions and their separately fitted priors. Presidential history has 14 usable midterms from 1954–2018; the House alternative has 16 from 1946–2018.

- **A common swing:** Read the annotated 2008–2010 scatter plot. Identify the no-change diagonal, the parallel uniform-swing line, and departures by individual districts. Compare the 2006, 2010, 2014, and 2018 panels. Their samples use the existing matched-boundary and contested-election screens.
- **History and local variation:** Compare the time plot with the histogram of the same 16 midterm averages. Then inspect the stacked district-label histogram for one cycle. Ask why the across-election SD and the within-election district SD answer different questions. Try highlighting CA-10 and switching cycles. The sign of the out-party axis stays consistent across presidents.
- **An unfinished count:** In the controlled toy example, choose D-leaning batches first, R-leaning batches first, and alternating batches. Move the count slider from zero to ten. Every order contains exactly the same 10,000 votes and ends at 55% D; the first impressions differ. The final total and the future paths are known only because this example is synthetic.
- **A local historical count:** Continue to CA-13’s actual 2024 replay. Slide to snapshot 1 (Gray +995), then 2 (Duarte +3,189), 12 (Duarte +3,765), 24 (Gray +105), and 31 (Gray +187). Switch between the vote lead and Democratic-share views. Explain that a recording time is an observation of the count, and that a retrospective share of final votes would not have been known then. The archive is irregular and includes repeated totals.
- **Interpret the first results:** Reveal replay snapshots 0, 1, 3, 6, and 12. Compare the raw and Bayesian estimates and their weights. The chart reveals no future snapshots. Use **Continue with this snapshot in the election-night lab** to inspect the district arithmetic and seat implications. This resets the lab to the replay defaults so its estimate matches the introduction.

In the full **Election-night lab**, continue with:

1. Start the synthetic replay at snapshot 0. Ask why the app shows no estimate instead of a zero swing.
2. Advance to snapshot 1. Write down the current D-share change and implied seat split. Ask whether one early district should stand in for the country.
3. Advance through snapshots 3, 6, and 12. Explain that the totals are cumulative and that composition of reporting ballots changes the apparent swing.
4. At snapshot 6, compare each district's dot with the common average. Exclude KY-06 and observe the national seat count. Restore it and raise the minimum-vote threshold.
5. Trace a +3 percentage-point Democratic share shift through the seat curve. Explain why that means +6 points in the D-minus-R margin, and why seats respond in steps.
6. Open Redistricting. Compare NC-01 and NC-11. Discuss why matching the same district number does not establish matching geography.
7. Select Bayesian: history + results. Open Bayesian update and compare the prior, likelihood, and posterior at snapshots 0, 1, 6, and 12. At zero, the estimate is explicitly prior only. Ask why the historical prior SD is not divided by the square root of 16.
8. Increase the prior SD multiplier and observe how weakening the prior gives the incoming data more weight. Explain the assumption that district swings are independent conditional on the common swing, and why another cumulative update from the same district is not another independent district observation.
9. On election night, the instructor starts the [laptop collector](collector.md). Students using the hosted app select **Shared laptop snapshots**. It reads the same public file for everyone; the laptop handles the state requests. The default presidential reference compares with Harris’s share on 2026 lines and supports both raw and Bayesian estimates. The House alternative retains its original boundary exclusions. Inspect provider timestamps, laptop retrieval times, stale statuses, and inclusion decisions.
10. End by listing what this toy model leaves out: selective early reporting, local candidates, turnout differences, district selection, unopposed races, and uncertainty about the final vote. A model-conditional credible interval is not evidence of forecast calibration.

The final raw synthetic scenario is D +3 pp relative to the selected reference: D 221 / R 214 on the 2026 presidential-reference map, or D 231 / R 204 for the House-reference scenario on the 2024 map. These are authored classroom scenarios.
