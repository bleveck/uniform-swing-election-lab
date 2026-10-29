# Publishing through GitHub and Posit Connect Cloud

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

Prepared October 29, 2026. Account login, GitHub App authorization, and the initial Connect Cloud publication must be completed before a hosted URL exists.
