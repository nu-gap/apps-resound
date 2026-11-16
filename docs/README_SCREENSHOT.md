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
   - the **background**: `xsetroot -solid "#666695"` paints the root
     window the brand purple (102,102,149) right after openbox
     starts — the X server leaves the root black and openbox does not
     paint it, so without this the inter-window gaps would be black,
   - the 1998 menu bar (the ~86x182 window named `Resound`) is moved
     to (1030,300) — where its submenus fit inside the canvas — and
     raised, so nothing can sit over the bar rows,
   - **staging**: openbox (Smart + center placement) puts the app's
     *managed* windows wherever it likes, so the tone document and
     the console are already moved to their tile spots before the
     menu dances — where openbox lands them they could otherwise sit
     over the bar rows or the popups and swallow the dance's press
     or release.  (The main model and the six inspectors are
     override-redirect, so openbox leaves them at their nib
     positions, which fall off the canvas.)
   - two menu selections open their panels: `xdotool` presses a bar
     row, slides to the next so the 1998 bar attaches the submenu,
     finds the popup by id diff among the new windows — and
     `windowraise`s it (openbox does not manage the
     override-redirect popup, so a plain `XRaiseWindow` pins it
     above whatever stacked over it; the raise is repeated after
     the aim move) — then releases on the popup's last row:
     **Tools → Record Format**, then **Edit → Preferences**.  Two
     quirks are handled here: the app blocks its event loop for a
     few seconds after the bar maps (module loading, audio
     probing), so the press is retried (up to 8 times) until a
     *viewable* popup actually appears; and the Edit menu renders
     in a 147x362 (17-row) and a 170x302 (14-row) twin in the same
     session, with the viewable twin varying run to run (a GUI
     library layout race at nib-load time) — the 14-row twin makes
     the last row, Preferences, unreachable, so the dance selects
     the tallest *viewable* twin, and a scene without the panel
     fails verification below.  Right after the Record panel opens
     it is moved to its final tile spot (359,330) — openbox's
     placement of this managed window could otherwise cover the
     bar's Edit row for the second dance,
   - **verification**: the scene is only accepted when the menu
     bar, the Record panel, and the Preferences panel are all
     present *and mapped* (a name match on an unmapped window does
     not count).  A failed scene is relaunched from scratch (a new
     nib load re-rolls the layout race), up to 5 times,
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
   a flaky display must not mask a build result.  But nothing in the
   scene is "best effort" anymore: a scene that fails verification is
   relaunched from scratch (up to 5 times), and a captured frame whose
   pixels do not show the staged scene — the backdrop must be the
   brand purple, the bar, the tone document, and the preferences
   panel must be visible at their tile spots — is re-taken (up to 6
   times).  If the scene never verifies the step writes **no**
   screenshot and exits 0: the publish step skips an empty capture,
   so the README keeps the last published image instead of a degraded
   one, and the log carries a loud `LOUD:` line saying so.
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
- When a scene never verifies (five failed attempts) the step writes
  no screenshot at all: the publish skips, the README keeps the last
  published image, and the run log carries the `LOUD:` line with the
  reason.
- The README image carries `style="max-width:100%"`, so a large
  future window scales down to the text column instead of spilling
  out of it.
