# Election night: laptop collector cheat sheet

**Tuesday, November 3, 2026 · Brad’s Mac**

Your laptop collects Virginia, North Carolina, and Ohio returns and publishes a shared file. Both apps read that file. Keep one collector running, with the laptop open, plugged in, and online.

## 1. Open Terminal and go to the project

```sh
cd "/Users/bradleveck/Documents/ChatGPT/uniform_swing_forecasting_demo"
```

Run the commands below from this directory. You do not need to run the Shiny app locally, open RStudio, or push Git commits.

## 2. Check GitHub access and publish one snapshot

```sh
gh auth status
Rscript scripts/collect_results.R --once --publish
```

The second command fetches the states, saves a local copy, publishes it, and exits. Check **both** of these:

- The terminal reports `Published ...` with a commit ID and the shared-file URL.
- The provider lines show VA with **3 districts**, NC with **2**, and OH with **4**. Check for errors or stale data separately: successful publication can include a provider’s retained older totals.

If GitHub authentication has expired, run `gh auth login`, complete the interactive sign-in, then retry. The account needs write access to `bleveck/uniform-swing-election-lab`.

## 3. Keep collecting

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish
```

This collects immediately, then waits **300 seconds** between rounds. Expect repeated provider statuses, `Published ...`, and `Next collection in 300 seconds.`

**Leave this Terminal window open.** `caffeinate` prevents idle system sleep while the command runs; keep the laptop lid open. There is no automatic startup or scheduled collector. Run only one copy.

## 4. Check the app

- [Posit app](https://bradleveck-election-night-lab.share.connect.posit.cloud/)
- [Shinylive app](https://bleveck.github.io/uniform-swing-election-lab/) — use a Chromium browser; Safari stalled in our testing.

In either app:

1. Open **Election-night lab**.
2. Select **Shared laptop snapshots**.
3. Keep **2024 president · 2026 map** as the comparison baseline for the full watchlist.
4. Click **Load latest shared snapshot**, or leave the one-minute update check enabled.
5. Inspect the laptop collection time, each provider’s fetch time, provider publication timestamps, and the district table.

Nine districts arrive automatically. KY-06 can use manually downloaded XML or hand-entered totals. The model’s `n` counts qualifying districts: by default each needs at least **1,000 D+R votes**, must pass the test-data checks, and must not be excluded. In House-reference mode, changed-map exclusions can reduce `n` further.

**Preparation safeguard:** snapshots collected before **3 p.m. Pacific / 6 p.m. Eastern on November 3** are excluded. Provider test flags also cause exclusion, including after that time. A successful fetch of zeros or test data is not an eligible election return.

## 5. Stop

Press **Control+C** in the collector’s Terminal window. Use Control, not Command.

The last published snapshot stays available. It will be labeled stale as it ages; replay and historical examples continue working. To resume, run the command in step 3 again.

## Optional: add KY-06

### Import downloaded XML

Follow the [Kentucky download/import guide](kentucky-import.md) to save the six official XML files to `data/live/ky-downloads`. In Safari use **right-click → Download Linked File As…**, rather than copying the window of numbers.

Stop any collector with **Control+C**, then start it with:

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish --ky-dir=data/live/ky-downloads
```

The same collector now converts local KY XML automatically on each round. Manually save a fresh current-results XML to that folder when you want newer Kentucky totals; the collector does not request Kentucky files itself. The other five lookup files can normally stay in place. A one-off preview is `Rscript scripts/import_ky.R`, which writes `data/live/ky-import.csv` without publishing.

### Or enter the two totals yourself

If the collector is running, stop it with **Control+C** first.

Create `data/live/ky.csv` as a plain-text CSV. Create its folder if needed:

```sh
mkdir -p data/live
```

The file must contain exactly one district row:

```csv
district_id,d_votes_current,r_votes_current,election_date
KY-06,0,0,2026-11-03
```

**Replace both zeros with the current official cumulative Democratic and Republican totals before using it.** The [Kentucky reporting page](https://vrsws.sos.ky.gov/liveresults/) is the source listed in our feed notes. If it is unavailable, leave Kentucky out.

Direct script requests were blocked by Kentucky’s firewall in our October 30 check. The local XML importer above and this hand-entry option both avoid scripted requests to Kentucky. See the [source notes](data_sources.md#live-results).

Start the collector with the extra argument:

```sh
caffeinate -i Rscript scripts/collect_results.R --watch --publish --ky-file=data/live/ky.csv
```

Update and save that CSV as new official totals appear. Keep the same file name; no restart is needed for subsequent edits. Enter cumulative totals each time, not just the latest batch. The collector reads the file on each round. Its modification time determines Kentucky’s freshness, so rereading an unchanged file does not make it newer.

Without Kentucky, the nine automatic districts still work.

## If something goes wrong

| Symptom | What to do |
|---|---|
| `cannot open file 'R/model.R'` or similar | Repeat the `cd` command in step 1. |
| A required R package is missing | Run `Rscript scripts/install.R`, then retry. |
| GitHub publication fails | Check internet access and `gh auth status`. The snapshot stays local; watch mode retries on the next round. A local save alone does not update the hosted apps. |
| One state fails | Other states can still update. That state’s last good totals are retained, with the original retrieval time and an error status. |
| **STALE** in the app | Check the collector Terminal and the individual provider clocks. A provider error flags staleness immediately; successful fetches older than 15 minutes also become stale. Stale totals are **not automatically removed** from the model: exclude their districts if appropriate. |
| No visible update after publishing | Check the app’s collection timestamp and click **Load latest shared snapshot**. Allow for the next poll, the one-minute reader check, and caching delays. Compare provider publication times too: a new fetch can contain unchanged totals. |
| Computer sleeps or loses internet | Reconnect, keep the lid open, and restart the watch command if it has stopped. |
| `Collector lock exists` | Check for another running collector before removing anything; see below. |

### Only if a stopped collector left a lock

Read the recorded process ID:

```sh
cat data/live/collector/lock/pid
```

Check that ID, substituting the number printed above for `12345`:

```sh
ps -p 12345 -o pid=,command=
```

If it is a running collector, stop it in its own Terminal. **Only after confirming no collector is running**, remove the leftover lock and retry step 3:

```sh
Rscript -e 'unlink("data/live/collector/lock", recursive = TRUE)'
```

Local copies are in `data/live/collector/latest.json` and `data/live/collector/archive/`. Data publication updates the separate `codex/snapshots` branch; it does not rebuild either app or change your source checkout.

For more detail, see the [collector guide](collector.md).
