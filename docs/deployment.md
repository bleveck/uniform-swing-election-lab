# Publishing through GitHub and Posit Connect Cloud

Repository: [bleveck/uniform-swing-election-lab](https://github.com/bleveck/uniform-swing-election-lab). The initial Linux checks passed and created `codex/publish` on October 29, 2026.

[Public app](https://bradleveck-election-night-lab.share.connect.posit.cloud/) · [Posit content administration](https://connect.posit.cloud/bradleveck/content/01a18994-b6cc-bced-bec2-7a672ba20d82)

First published October 29, 2026, from `codex/publish`, with `app.R` as the primary file and automatic publication on push enabled. The GitHub App installation is restricted to this repository, with read access to code and metadata. Posit uses the Google-authenticated account. The public introduction, charts, actual CA-13 replay, both Bayesian reference options, and ten-row calculation CSV download were verified in a fresh browser session.

## Live-feed access from the hosted app

The hosted app now supports **Shared laptop snapshots**, published independently of app code. See [the collector guide](collector.md) for startup, stop, Kentucky entry, and failure handling. Use this source to obtain all nine automatic watchlist districts through the laptop's network connection.

On October 29, the same `fetch_feed()` code succeeded for Virginia, North Carolina, and Ohio on the local computer. On Posit, North Carolina succeeded; Virginia and Ohio returned HTTP 403. The hosted app reports those providers as unavailable and retains a previous successful snapshot if one exists. The differing behavior is consistent with provider filtering of hosting networks or automated clients; the specific filtering rule has not been established.

To fetch from a computer that can reach the feeds:

```sh
Rscript scripts/fetch_live.R
```

This writes one cumulative `data/live/snapshot-*.csv` file. In the hosted app choose **Upload a CSV** and upload that file. Add a KY-06 row separately if desired; it has no automatic connector. Later snapshots replace the earlier totals. Pre-election/test flags are retained, so preparation files remain excluded.

## Browser-only version on GitHub Pages

The [Shinylive app](https://bleveck.github.io/uniform-swing-election-lab/) runs the same calculations and historical charts in each student's browser. It reads the same public laptop snapshot as Posit, with no direct state requests from the browser. See [the Shinylive guide](shinylive.md) for the build, package versions, data path, and limitations.

The source workflow validates the R app, builds the static site, and deploys it through GitHub Pages. Snapshot publications remain on `codex/snapshots` and do not trigger either deployment.

## Readable Posit URL

The configured alias is [bradleveck-election-night-lab.share.connect.posit.cloud](https://bradleveck-election-night-lab.share.connect.posit.cloud/). In content **Settings → URL**, **Customize your URL** is enabled with custom name `election-night-lab`. The original content-ID URL remains available. Connect Cloud prefixes aliases with the account name; a domain you own requires a plan with custom-domain support. [Posit documents these URL settings](https://docs.posit.co/connect-cloud/user/manage/content_settings.html).

## First publication

1. Sign in at [Posit Connect Cloud](https://connect.posit.cloud/). The account used to sign in to Posit can be separate from the GitHub account containing the code. If GitHub sign-in fails, an existing Posit email or Google login is another option; use the identity associated with your Posit account.
2. Click **Publish**. If prompted, install/connect the **Posit Connect Cloud GitHub App**. Select only this repository when GitHub offers a repository choice.
3. Choose **Shiny** and this project's GitHub repository.
4. Set **Branch** to **`codex/publish`**. This branch appears after the first successful GitHub Actions run.
5. Set **Primary file** to **`app.R`**.
6. Leave **Automatically publish on push** enabled. No environment variables, API keys, or database are required for the app.
7. Click **Publish** and watch the package installation and app startup logs. Keep the resulting share URL; subsequent publications update the same app.
8. Open the share URL in a fresh browser session. Check the introduction, CA-13 replay, and presidential and House Bayesian options. An initial visit after the app sleeps may take longer.

The free plan requires a public source repository. Source data are already bundled: hosting does not run the historical download/build scripts. Live feed requests use outbound HTTPS only when explicitly requested in the lab. Automatic polling is off by default.

## Updates

Work on `main` or open a pull request. After a runtime code/data/package change, regenerate the manifest and run the checks from the project root:

```sh
Rscript scripts/write_manifest.R
Rscript scripts/check_deployment.R
Rscript tests/run_tests.R
```

To install the manifest-writing helper if needed:

```r
install.packages("rsconnect", repos = "https://cloud.r-project.org")
```

Commit the source change together with `manifest.json`, then push `main`. GitHub Actions installs the manifest's runtime versions, validates its checksums, loads a bundle containing only runtime files, and runs the existing tests on Linux. If those checks succeed, it advances `codex/publish`. Connect Cloud watches that branch and republishes. Failed checks leave the publishing branch at its last successful commit.

The workflow uses GitHub's short-lived repository token to advance the branch; it stores no Posit credentials. GitHub Actions success means the checks passed and the branch advanced, not that the subsequent Connect Cloud build succeeded. Verify Connect Cloud's deployment log and the share URL after a publication.

Do not edit `codex/publish` directly. It follows checked commits from `main`, using a normal fast-forward push. If no publication follows a successful workflow, check the selected branch, automatic-publishing setting, and GitHub App repository access in Connect Cloud. The initial GitHub App connection is a user authentication step.

The manifest deliberately omits raw archives, build tools, tests, local outputs, and screenshots from the hosted bundle. They remain in the source repository for reproducibility. Adding a runtime file requires adding it to `scripts/deployment_files.R` and regenerating the manifest.

## Reference

- [Posit's Shiny for R deployment guide](https://docs.posit.co/connect-cloud/how-to/r/shiny-r.html)
- [Publishing from GitHub](https://docs.posit.co/connect-cloud/user/publish/github.html)
- [R dependency files](https://docs.posit.co/connect-cloud/how-to/r/dependencies.html)

Prepared and initially published October 29, 2026. Hosting is verified for an individual browser session; class-sized concurrency has not been load-tested.
