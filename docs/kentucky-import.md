# Kentucky: save XML files and import KY-06

Kentucky’s normal download links can open a window containing a long line of numbers. Safari is displaying the XML values without a useful layout. **Use the link’s download command to save the original XML. Do not copy the visible numbers, save a screenshot, or use Web Archive/PNG.**

This workflow uses manual browser downloads. The R importer reads local files only; it does not contact Kentucky or work around its firewall.

## Download the six files

1. Open the [official data page](https://vrsws.sos.ky.gov/liveresults/Data). Confirm the heading says **2026 General Election Data** and the date is **November 03, 2026**.
2. In Safari, **Control-click or right-click “Click to Download” → Download Linked File As…**. This was tested successfully on this Mac. It may take a while for the save dialog to appear.
3. Save each file in this folder, which has already been created:

```text
/Users/bradleveck/Documents/ChatGPT/uniform_swing_forecasting_demo/data/live/ky-downloads
```

In the save dialog, **Command+Shift+G** opens “Go to Folder”; paste that path and press Return. Keep the `.xml` extension.

| Download-menu row | Normal saved filename | When to download |
|---|---|---|
| **Current Results (Excludes Local Contests)** | `CurrentResultsExcludeLocal.xml` | Each time you want a fresh snapshot |
| Elections | `Elections.xml` | Initial setup |
| Political Parties | `PoliticalParties.xml` | Initial setup |
| Geopolitical Units | `GeopoliticalUnits.xml` | Initial setup |
| Contests | `Contests.xml` | Initial setup |
| Candidates | `Candidates.xml` | Initial setup |

Download all six from the same election’s page. The larger files may be slow. The **All Contests** current-results file is also supported, but the version excluding local contests is sufficient and smaller. You do not need both.

For later updates, replace the current-results XML in that folder. Browser-numbered copies such as `CurrentResultsExcludeLocal (1).xml` also work: the importer selects the newest file of each dataset type by modification time. Refresh the lookup files too if Kentucky revises the contest or candidate metadata. Keep unrelated XML files outside this folder.

If you already opened the window of numbers, go back to the menu and use **Download Linked File As…**. Safari also offers **Page Source** in File → Save As, but the direct-link route is the one verified to produce usable files here.

## Preview the conversion once

Open Terminal:

```sh
cd "/Users/bradleveck/Documents/ChatGPT/uniform_swing_forecasting_demo"
Rscript scripts/import_ky.R
```

The converter identifies the KY-06 contest and its Democratic and Republican candidates, selects non-overlapping reporting units, and writes:

```text
data/live/ky-import.csv
```

It prints the totals, download time, test flag, and reporting-unit count. **This command does not publish anything.** The CSV can also be loaded through the app’s **Upload a CSV** option.

On October 30, the real six-file preparation bundle was successfully imported as KY-06, D = 0, R = 0, with `is_test = TRUE`. This verifies the published file format, not election-night behavior or nonzero live totals.

## Include it in the shared collector

Stop any running collector with **Control+C**, then run:

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish --ky-dir=data/live/ky-downloads
```

Leave this one Terminal window running. On each five-minute round it fetches VA, NC, and OH, imports the latest manually downloaded Kentucky files, and publishes the combined snapshot. In either hosted app, choose **Election-night lab → Shared laptop snapshots**.

When Kentucky updates, manually download a new **Current Results (Excludes Local Contests)** file into the same folder. The next collector round picks it up; no restart is needed. The collector does **not** download new Kentucky files itself. You can click **Load latest shared snapshot** in the app after publication.

To collect and publish only once:

```sh
Rscript scripts/collect_results.R --once --publish --ky-dir=data/live/ky-downloads
```

Use either `--ky-dir` for downloaded XML or `--ky-file` for hand-entered totals. Do not specify both. The original `data/live/ky.csv` hand-entry option remains available.

## Checks and failure handling

- The election must be the November 3, 2026 general election. Candidate and reporting-unit IDs must match the lookup files.
- Only **TotalVotes** is used. Election-day votes are already part of that total.
- A state summary takes precedence over its county/precinct components. Without a state summary, the importer selects the highest available totals in each reporting-unit branch, avoiding double counting.
- Missing files, incomplete XML, ambiguous contests, duplicate records, invalid counts, or mismatched IDs stop the Kentucky import. In collector mode the last good KY entry is retained and marked with an error; the other states can still update.
- Freshness comes from the current-results file’s modification time. Reprocessing the same saved file does not make it newer. Older downloads cannot replace a newer imported snapshot.
- Pre-election downloads and explicit provider test flags are excluded from estimation. The standalone converter also accepts `--test` to mark a practice import. The file format does not guarantee a test flag will always be present; only use genuine general-election returns on election night.

The saved raw files and converted CSV stay under git-ignored `data/live/`. Only the normal shared snapshot is published when you explicitly run the collector with `--publish`.

Sources: [Kentucky download menu](https://vrsws.sos.ky.gov/liveresults/Data), [2026 Data Website Guide v6](https://vrsws.sos.ky.gov/liveresults/Documentation/DataWebsiteGuidev6.pdf). See also the [election-night cheat sheet](election-night-cheat-sheet.md).
