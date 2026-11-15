# README screenshot (auto-updated by CI)

The README links a screenshot of the app running under GNUstep:

```
https://raw.githubusercontent.com/nu-gap/apps-resound/screenshot/Resound-screenshot.png
```

…which lives on the dedicated `screenshot` branch, maintained by the
build workflow — never by a hand edit.  The build stages a scene
before capturing (the tone as an open document, the console, the
record and preferences panels, the 1998 menu bar — see below), and
the same capture shows the UI further as the ported units land, with
no README edit and no manual re-trigger in between.

## How it works (`.github/workflows/build.yml`)

1. **Capture** (after the launch check): the freshly built app runs
   under `xvfb-run` (1280x800x24) + openbox on the runner, launched
   with `test/Tone.wav` as a file argument — GNUstep hands non-dash
   arguments to `application:openFile:`, so the app comes up with the
   tone as an open document.  The step waits for the app to have at
   least one window, then for the tone document window, and stages a
   scene before capturing the **whole screen** with ImageMagick's
   `import -window root -strip`:
   - the 1998 menu bar (the ~86x182 window named `Resound`) is moved
     to (1030,300) — where its submenus fit inside the canvas,
   - two menu selections open their panels: `xdotool` presses a bar
     row, slides to the next so the 1998 bar attaches the submenu,
     finds the popup by id diff and releases on its last row —
     **Tools → Record Format**, then **Edit → Preferences** (each
     retried once if the panel did not appear),
   - the five windows are tiled: tone document (39,40), console
     (39,330), record panel (359,330), preferences panel (679,40),
     menu bar (1030,300).  Windows are moved by their frame id (the
     taller of the name matches) via `xdotool windowmove`;
     `xdotool getwindowgeometry` reports true absolute coordinates
     for undecorated windows, so the menu bar and popups — but not
     the reparented client areas — are positioned from it.
   The 1998-nib positions of the remaining windows (the main model,
   the six inspectors) fall off the 1280x800 canvas and stay out of
   the picture.  Whole screen (not the app windows) on purpose: every
   window the app shows belongs in the picture, and the root window
   is capturable in every state, while app windows fail a per-window
   capture with a bad X resource.  Non-fatal, like the launch check —
   a flaky display must not mask a build result; every scene step is
   best effort, so a flaky piece degrades the picture (fewer windows)
   instead of the build.
2. **Publish** (push events only): a scratch `git init` directory
   whose local branch is named `screenshot` (so the very first commit
   creates the branch); if the branch already exists, it is fetched
   and the capture is compared byte-for-byte against the existing PNG
   (so a stable UI costs **no** bot commits); an updated PNG is
   pushed with the workflow's token.  The branch contains only the
   PNG.
3. **Triggers**: `push.branches-ignore: [screenshot]` keeps the bot's
   own pushes from re-running the build; the publish step is skipped
   for pull requests (fork PRs could not push anyway) and for manual
   dispatch.

## The token: no custom secret needed

GitHub Actions creates a per-run `GITHUB_TOKEN` automatically, but it
is **read-only by default** for new workflows — so the workflow
declares

```yaml
permissions:
  contents: write
```

at the top.  The publish step receives the token through

```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

(The **secrets context** is the canonical access: the bare
`$GITHUB_TOKEN` in a `run` block expands to nothing, because the
token is not auto-injected as a shell environment variable.)  There
is nothing to create in the repository settings.

*Optional:* if you prefer your own token (e.g. a fine-grained
personal access token scoped to this one repository with *Contents:
Read and write*, that expires when the feature is retired): save it
as the repository secret `SCREENSHOT_PUSH_TOKEN` (Settings → Secrets
and variables → Actions).  The step's `env:` uses it as a fallback
automatically — `GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN ||
secrets.SCREENSHOT_PUSH_TOKEN }}` — so it only takes effect when the
built-in workflow token is unavailable.  If neither is available the
step skips with a clear log line instead of failing.

## Behaviour notes

- The capture runs on **every push** (on any branch with the build
  system); the bot only commits when the pixels change.
- To force a refresh without any UI change: delete
  `Resound-screenshot.png` on the `screenshot` branch; the next build
  recreates it.
- The README image carries `style="max-width:100%"`, so a large
  future window scales down to the text column instead of spilling
  out of it.
