# icupkg (PORT, not upstream)

`icupkg.gni` builds ICU's `icupkg` tool for the host. Chromium never builds
it -- it ships prebuilt `icudtl.dat` variants and generates them offline with
a Unix toolchain (see `//third_party/icu/scripts/`) -- so this is new GN
plumbing, not a vendored target.

Two source bugs were fixed to get it compiling under Chromium's warning set
(`pkg_gencmn.cpp`, `package.cpp`): both are the first time this code has ever
been built with `-Werror`, since nothing in Chromium built it before.

## Why it exists, and why the obvious use of it does not work

The motivating question was: can `icudtl.dat` (10.4 MB, ~2360 locale/data
items) be trimmed post-hoc, keeping only English and Chinese, using `icupkg
-r` the way Android trims its own ICU data? Built the tool to try it.

**Verdict: no, not by editing the file after the fact.** Even a pure no-op
round-trip through `icupkg` -- read the file, remove nothing, write it back
out -- produces a `.dat` that fails at runtime: `Calendar::createInstance`
keeps working, but `NumberFormat::createInstance` returns
`U_MISSING_RESOURCE_ERROR` for every locale, including ones nothing was
removed from.

This was narrowed down, not just observed:

  - Individual items extracted from the round-tripped file are byte-identical
    to the originals (checked `en_US.res`, `root.res`,
    `numberingSystems.res`, `supplementalData.res`).
  - The file's TOC item names are intact and complete (2361 names, same as
    the original).
  - The first 64 bytes of the `UDataInfo` header are identical.
  - Yet 8.8 of 10.9 million bytes differ between the two files overall --
    `icupkg` lays out item offsets completely differently on write.

That last point is the likely cause: ICU's "pool bundle" mechanism (present
here as the `pool.res` file in several categories) lets sibling locale
bundles share one string table via *byte offsets*, computed by the original
`gennorm`/`genrb`/`gencmn` build. `icupkg`'s copy-each-item-verbatim model
does not appear to preserve whatever relationship `NumberFormat`'s data path
depends on, even though the copied bytes are correct in isolation. This
matches ICU's own documentation caution that `icupkg` editing is for
independent items, not files built with cross-item sharing enabled.

The change that *would* work is what Chromium's own engineers use: rebuild
`icudtl.dat` from CLDR source via the real data pipeline (`genrb` + `gencmn`
+ `pkgdata`, driven by one of the JSON filters in `//third_party/icu/filters/`
-- `common.json` is the one this checkout's `icudtl.dat` was built from).
That path requires a Unix toolchain and the full ICU data sources, which are
not part of this port, and takes on the order of hours. It was not attempted
here.

## What is kept

`icupkg.exe` and the `icu_package_tool` GN template, because the tool itself
is correctly built and works for its documented uses (listing, extracting,
byte-order swapping) -- the finding above is specifically about post-hoc
*removal* on this particular pool-bundle-enabled data file, not about the
tool being broken.

`verify_trim.cc` is kept as the harness that did the narrowing-down above: it
calls `base::i18n::InitializeICU()` (required -- ICU's own data-directory
search is not what Chromium uses) and then exercises `Calendar`,
`DateFormat` and `NumberFormat` for a handful of locales, printing exactly
which stage fails. Point it at a candidate `icudtl.dat` by copying that file
next to `verify_trim.exe` before running it.

Neither is wired into the default build or `//app`'s payload, and GN only
parses `BUILD.gn` files reachable from the dependency graph -- an unreferenced
target cannot be built by name even directly. To build these, add a temporary
dependency on them from somewhere already in the graph (the root
`//BUILD.gn`'s `default` group, for instance), `gn gen`, build, then revert
the dependency.
