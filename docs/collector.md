# Laptop collector

For the short operational sequence on Brad’s Mac, see the [election-night cheat sheet](election-night-cheat-sheet.md).

One instructor laptop fetches the official VA, NC, and OH feeds. It publishes one small public JSON snapshot to the separate [`codex/snapshots` branch](https://github.com/bleveck/uniform-swing-election-lab/tree/codex/snapshots). The hosted app reads that file instead of contacting the states from Posit. Data publications do not rebuild or redeploy the app.

## Start on election night

Open Terminal in the project directory. R and the app dependencies must be installed, and GitHub CLI must be signed in to an account with permission to update this repository:

```sh
gh auth status
Rscript scripts/collect_results.R --once --publish
```

That command collects and publishes one snapshot, then exits. Check the printed provider status. To keep collecting every five minutes on this Mac:

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish
```

Leave Terminal and the laptop open and connected to the internet. `caffeinate -i` prevents idle system sleep while the command runs; it does not make a closed laptop lid safe for collection. **Ctrl+C stops collection.** This setup creates no scheduled task, startup service, or background automation. It is stopped until you run the command.

In the hosted app choose **Election-night lab → Shared laptop snapshots**. It loads the published file immediately and checks for updates every minute by default. The minimum collection interval is five minutes; change it with `--interval=600`, for example, for ten minutes. The app's checks only read the shared file and create no additional requests to the states.

## Optional Kentucky XML import

The [Kentucky import guide](kentucky-import.md) explains how to use Safari’s **Download Linked File As…** command to save six official XML datasets in `data/live/ky-downloads`. This manual route was verified with the 2026 preparation files on October 30. Start the collector with:

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish --ky-dir=data/live/ky-downloads
```

Each round transforms local files into `data/live/ky-import.csv` and includes KY-06 in the shared snapshot. It makes no Kentucky network requests. Refresh the current-results file manually; the importer preserves its download modification time. Missing or invalid files retain the last valid KY totals with an error status, while the other states can update. For a standalone conversion without fetching states or publishing, run `Rscript scripts/import_ky.R`.

## Optional Kentucky hand entry

Alternatively, create a CSV containing exactly KY-06, using the same required columns as the app's CSV template. Choose either `--ky-file` or `--ky-dir`, not both:

```csv
district_id,d_votes_current,r_votes_current,election_date
KY-06,0,0,2026-11-03
```

Replace the zeros with the current official cumulative D and R totals, then run:

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish --ky-file=data/live/ky.csv
```

Edit and save that file when Kentucky updates. Its modification time is used as the manual entry's retrieval time, so polling an unchanged CSV does not make old numbers look fresh. The source is labeled as a manual KY SOS entry. Without the file, KY-06 is explicitly missing. If a previously supplied file is removed or invalid, the previous entry is retained and marked stale.

## Failure handling and clocks

- Each poll replaces a provider's cumulative totals; successive polls are never added together.
- A failed download, invalid schema, or missing expected district retains that provider's last good totals and its original retrieval time. Other providers can update normally.
- The app labels a provider **STALE** after 15 minutes without a successful retrieval, or immediately after a reported provider error. Stale totals remain in the model, consistent with direct-feed mode; users can exclude their districts.
- If the laptop stops, the shared file stays available and becomes stale. If the app cannot read GitHub, it retains its last successfully loaded file and displays an error.
- Provider publication clocks stay in `source_updated_at`. Retrieval clocks and the laptop's collection time are stored separately in UTC.
- Before November 3 at 6 p.m. Eastern, totals are marked as preparation data. Preparation snapshots remain excluded even if someone reads them later. Provider test flags are also preserved.

Local snapshots are saved atomically in `data/live/collector/latest.json`, with a timestamped archive in `data/live/collector/archive/`. These files are git-ignored. A restarted collector loads its local cache, or tries the published snapshot when no local cache exists, before fetching new totals.

Publishing uses the existing `gh` authentication; no token is written into the snapshot, app code, or GitHub Actions secrets. Only public watchlist vote totals, source names/times, test flags, and provider status are uploaded. Detailed local errors remain in the terminal; public error messages omit local file paths. The normal app source branch and working checkout are not changed by the collector.

The publisher uses GitHub's file SHA to reject conflicting updates, and refuses to replace a newer snapshot with an older one. Run one collector at a time. A local lock prevents two copies using the same cache. If the process is killed unexpectedly and leaves a lock behind, first make sure no collector is running, then remove `data/live/collector/lock` and restart. Normal exit or Ctrl+C removes the lock.

GitHub delivery can add some caching delay. The reader uses a shared minute-based query to limit old cached responses, and the displayed times let students inspect freshness rather than assume a click always means new source totals.

## Files and manual validation

- `R/collector.R`: shared schema validation, public-file reader, freshness labels, and repository/URL configuration.
- `scripts/collector_functions.R`: laptop fetch, local persistence, and GitHub publication helpers.
- `scripts/collect_results.R`: one-shot and foreground polling commands.
- `tests/test_collector.R`: preparation flags, outages, stale clocks, malformed data, KY entry times, publication conflicts, and Shiny integration.

For a local-only collection, omit `--publish`. The JSON snapshot is still saved and can be inspected in R. The existing `scripts/fetch_live.R` remains available for a CSV export suitable for manual upload. Both hosted versions use the same public snapshot reader's basic `download.file()` GET; see the [Shinylive guide](shinylive.md) for browser hosting.
