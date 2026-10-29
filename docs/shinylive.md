# Browser-only election-night lab

[GitHub Pages app](https://bleveck.github.io/uniform-swing-election-lab/) · [Posit app](https://bradleveck-election-night-lab.share.connect.posit.cloud/)

The Shinylive version uses the same `app.R`, model, prior fitting, charts, historical data, and synthetic replays. R runs in the student's browser through webR. GitHub Pages serves static files; no R server, student account, or API key is needed.

Choose **Election-night lab → Shared laptop snapshots** to load incoming returns. Both hosted versions read the same public `latest.json` on `codex/snapshots`. The instructor still starts the [laptop collector](collector.md). Publishing data does not rebuild the app. The collector is not started by visiting the website. A stopped laptop leaves the last file readable and labeled STALE after 15 minutes. Current preparation/test totals are excluded.

Direct state-feed mode is omitted from the browser build. North Carolina and Ohio do not currently allow the cross-origin requests a static browser app needs, and the ordinary R downloader uses `httr2`. The shared reader instead uses webR's supported simple `download.file()` GET. Students make no requests to the state feeds and need no GitHub credentials.

## Rebuild locally

Use R 4.5.2 and install the official CRAN build helper:

```r
install.packages("shinylive", repos = "https://cloud.r-project.org")
```

The build script requires **shinylive 0.5.0** and explicitly selects **web assets 0.10.12**. It copies only runtime files to a temporary directory, substitutes the shared validation helper for the direct-feed module, and enables the browser UI. It exports WebAssembly package binaries alongside the site. The build output is about 88 MB; it is ignored by Git and uploaded as a Pages artifact rather than committed to the source repository.

```sh
Rscript scripts/build_shinylive.R
Rscript -e 'httpuv::runStaticServer("outputs/shinylive-site", port=3839)'
```

Open the localhost address printed by the server. An exported app needs HTTP(S), rather than opening `index.html` from disk. The exporter uses relative paths so GitHub's project subdirectory works.

`manifest.json` pins the ordinary R server packages. The browser build uses the precompiled package versions supplied for the selected webR runtime; these need not all equal the server versions. Updating the Shinylive builder/assets should include another browser check of charts, both references, Bayesian arithmetic, shared snapshots, and CSV handling.

## Publishing

GitHub Pages is configured to use **GitHub Actions**. On a push to `main`, `.github/workflows/publish.yml` checks the deployment manifest and runs the tests, then builds and uploads the static site. A separate deployment job has only Pages and OIDC publishing permissions. The Posit publishing branch is advanced after the same checks. Pull requests run checks without publishing either app.

The workflow uses GitHub's short-lived token, with no Posit credentials or collector credentials in the site. Source data, scripts, and tests remain in the repository; the exported browser bundle contains only the teaching app's runtime data and code.

The first visit downloads R and its packages and takes longer than an ordinary page. The app opens in synthetic replay mode. Historical examples do not require the collector; shared incoming returns require an internet connection and a running collector for fresh data. Browser computations use each student's device. Test the intended classroom browsers before class; large district-label plots can take longer on slower devices.

References: [Shinylive for R](https://posit-dev.github.io/r-shinylive/), [webR networking](https://docs.r-wasm.org/webr/latest/networking.html), and [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
