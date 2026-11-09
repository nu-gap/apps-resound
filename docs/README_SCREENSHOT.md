# README screenshot (auto-updated by CI)

The README links a screenshot of the app running under GNUstep:

```
https://raw.githubusercontent.com/nu-gap/apps-resound/screenshot/Resound-screenshot.png
```

…which lives on the dedicated `screenshot` branch, maintained by the
build workflow — never by a hand edit.  The app currently shows a 1x1
window (no main nib yet), so the image is a blank desktop for now; the
same capture shows the UI as the ported units land, with no README
edit and no manual re-trigger in between.

## How it works (`.github/workflows/build.yml`)

1. **Capture** (after the launch check): the freshly built app runs
   under `xvfb-run` (1280x800x24) + openbox on the runner; the step
   waits for the app to have at least one window
   (`xdotool search --name Resound`), then captures the **whole
   screen** with ImageMagick's `import -window root -strip` into
   `$RUNNER_TEMP/Resound-screenshot.png`.  Whole screen (not the app
   window) on purpose: once the app shows several windows, they all
   belong in the picture — and the root window is capturable in every
   state, while the current 1x1 window fails a per-window capture with
   a bad X resource.  Non-fatal, like the launch check — a flaky
   display environment must not mask a build result.
2. **Publish** (push events only): a scratch `git init` directory
   fetches the `screenshot` branch, compares the capture byte-for-byte
   against the existing PNG (so a stable UI costs **no** bot commits),
   and pushes an updated PNG with the workflow's token.  The branch
   contains only the PNG.
3. **Triggers**: `push.branches-ignore: [screenshot]` keeps the bot's
   own pushes from re-running the build; the publish step is skipped
   for pull requests (fork PRs could not push anyway) and for manual
   dispatch.

## The token: no custom secret needed

GitHub Actions injects a per-run `GITHUB_TOKEN` automatically, but it
is **read-only by default** for new workflows — so the workflow
declares

```yaml
permissions:
  contents: write
```

at the top.  That alone is all the publish step needs; there is
nothing to create in the repository settings.

*Optional:* if you prefer your own token (e.g. a fine-grained
personal access token scoped to this one repository with *Contents:
Read and write*, that expires when the feature is retired): create
it, save it as the repository secret `SCREENSHOT_PUSH_TOKEN`
(Settings → Secrets and variables → Actions), and change the publish
step's remote URL to use `${{ secrets.SCREENSHOT_PUSH_TOKEN }}`
instead of `${{ GITHUB_TOKEN }}`.  Not required for the default setup.

## Behaviour notes

- The capture runs on **every push** (on any branch with the build
  system); the bot only commits when the pixels change.
- To force a refresh without any UI change: delete
  `Resound-screenshot.png` on the `screenshot` branch; the next build
  recreates it.
- The README image carries `style="max-width:100%"`, so a large
  future window scales down to the text column instead of spilling
  out of it.
