# Resound source import into nu-gap

Imported on November 1, 2026 from [IOOI-SqAR/Resound](https://github.com/IOOI-SqAR/Resound).

- Destination: [nu-gap/apps-resound](https://github.com/nu-gap/apps-resound)
- Upstream branch: `main`
- Upstream commit: `48ffb8bbdea85b515597089702c9262d16cf5f77`
- All three upstream commits, their authors and timestamps, and the `Resound-3.0-P-bs` tag are preserved without rewriting.
- At import, the upstream source, bundled application, modules, API documentation, and original archive were unchanged; this provenance file was the only added file. The root `README.md` was subsequently expanded with nu-gap project documentation.

## Status and build requirements

Resound 3.0 is Sean Luke’s historical sound editor for Rhapsody, with editing and effects modules. This is a source preservation import for future GNUstep work, not a completed GNUstep port or a tested release. No build or runtime verification was performed.

Read `README.html` for the original distribution documentation and `Source/README.COMPILING` for historical build instructions. The source uses Rhapsody SoundKit, AppKit, Project Builder makefiles, and legacy interface files. The bundled binaries target Rhapsody PPC/Intel; they are not modern GNUstep binaries. A GNUstep port will require audio-framework, build-system, and interface work.

## Original licenses

All original notices remain in place. The distribution has multiple component licenses; do not apply a blanket license to the repository. In particular, `README.html` describes Jerome Genest’s `FileType.subproj` reader as reusable and redistributable only for non-profit purposes unless permission is granted. Consult the original notices in each source file before reuse or redistribution. Original authorship and copyright remain with the respective authors.

## Upstream

The original repository remains at https://github.com/IOOI-SqAR/Resound. The nu-gap copy preserves its history independently; future upstream changes can be fetched from that URL.
