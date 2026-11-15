# 0018. The README screenshot: a staged whole-screen CI scene, published to a `screenshot` branch

**Date:** 2026-11-09 (pipeline); the staged scene 2026-11-15
**Status:** accepted

## Context

The README needs a live picture of the app, but the app is a 1998 GUI whose
windows open at 1998 nib positions, and the UI grows with every port unit.
A hand-updated screenshot would go stale immediately; a per-window capture
is unreliable (app windows fail a per-window capture with a bad X resource,
while the root window is capturable in every state).

## Decision

The CI launch-check step (xvfb + openbox, 1280×800) **doubles as the scene
rig**.  Before the capture:

- the app is launched with `test/Tone.wav` as a file argument — GNUstep
  hands non-dash arguments to `application:openFile:`, so the tone comes up
  as an open document;
- the root window is painted the **brand purple (102,102,149)** with
  `xsetroot -solid` — the X server leaves it black and openbox does not
  paint it, so without this the inter-window gaps would be black;
- the 1998 menu bar is moved to (1030,300) — where its submenus fit — and
  raised; openbox's Smart+center placement puts the app's *managed*
  windows wherever it likes, so the tone document and the console are
  pre-tiled to their final spots and the record panel is moved to its tile
  spot right after it opens, taking each out of the bar/popup zone where
  openbox's placement could otherwise swallow a dance press or release;
- two menu selections open their panels, driven by xdotool mouse events on
  the bar (press a row, slide down one so the 1998 bar attaches the
  submenu, find the nameless popup by window-id diff, `windowraise` it —
  openbox does not manage the override-redirect popup, so a plain
  `XRaiseWindow` pins it — release on its last row: **Tools → Record
  Format**, then **Edit → Preferences**, each retried twice);
- the five windows are tiled (document, console, record, preferences, bar)
  and the **whole screen** is captured with `import -window root -strip`.

**Publishing**: the PNG is shipped to a dedicated **`screenshot` branch**
(the README links its raw URL) with the workflow token — `contents: write`
declared, no custom secret; a fallback to a `SCREENSHOT_PUSH_TOKEN` secret
is built in.  The capture is compared **byte-for-byte** against the
existing PNG, so a stable UI costs no bot commits;
`push.branches-ignore: [screenshot]` keeps the bot's own pushes from
re-running the build; pull requests and manual dispatch skip publishing.
The whole step is **non-fatal**, like the launch check: a flaky display
must not mask a build result.

## Consequences

- The README image fills in as the port adds UI, with no README edit and
  no manual re-trigger in between; forcing a refresh means deleting the
  PNG on the branch.
- openbox's non-determinism is **contained, not fought**: managed windows
  are moved to where the picture wants them (the final tile list is
  idempotent with the staging moves), and the override-redirect windows
  keep their nib positions, which fall off the 1280×800 canvas by design.
- The scene's choreography — background, staging, raises, retries, the
  `set -x` trace for diagnostics — is documented in
  `docs/README_SCREENSHOT.md`.

## References

- `docs/README_SCREENSHOT.md` — the full pipeline description.
- `.github/workflows/build.yml` — the capture step.
