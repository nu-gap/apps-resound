# 0017. License: Apache-2.0 for the project's own content, 1998 notices in place

**Date:** 2026-11-01
**Status:** accepted

## Context

The original distribution contains components with different license terms:
Sean Luke's code, MiscKit components, and Jerome Genest's `FileType.subproj`
readers, whose original documentation restricts reuse and redistribution to
**non-profit purposes** unless permission is granted.  The nu-gap import
(2026-11-01) added a root `LICENSE` (Apache-2.0).  A blanket license applied
over the whole mixed tree would mis-license the 1998 components — the
import provenance file warns against exactly that.

## Decision

The root `LICENSE` (Apache-2.0) covers **only the project's own content** —
the port code, the build system, the documentation, and the tests.  Every
1998 component **keeps its respective file-level notice**, and the original
notices are retained in `README.html` and the source.  The Genest
non-profit restriction remains the **explicit warning** in the
documentation; it motivated removing the affected readers from the app
build (ADR 0013).  Contributors must preserve the original copyright and
license notices.

## Consequences

- Reuse of the tree is **per-file, not per-repo**: the root license does
  not authorize the 1998 sources.
- The boundary is stated in `README.md` (Licensing) so downstreams do not
  assume the Apache-2.0 root covers the tree.
- The historical `original-archive/` is provided as found, without
  guarantees of support.

## References

- `NU-GAP-IMPORT.md` — the original-licenses section.
- `README.md` — the Licensing section.
