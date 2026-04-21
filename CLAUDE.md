# Dead Mall Tycoon — Claude Code Orientation

## Authoritative source tree

All Swift source files live at:

```
DeadMallTycoon/DeadMallTycoon/DeadMallTycoon/DeadMallTycoon/Sources/
```

That is the directory adjacent to the `.xcodeproj`. The project uses Xcode 16's
`PBXFileSystemSynchronizedRootGroup`, which means any file placed inside that
`Sources/` tree is automatically included in the app target — no manual
"Add Files to…" step is needed for new files.

**Do not create or edit Swift source at any other path.** Earlier in the
project's life, a parallel `DeadMallTycoon/Sources/` tree existed one level up.
It was never referenced by the Xcode project and has been deleted. Writing to
any path outside the authoritative tree above will silently fail to reach the
build.

## Tests

Test source lives at:

```
DeadMallTycoon/Tests/DeadMallTycoonTests/
```

The test target is **not yet wired** into `DeadMallTycoon.xcodeproj`. Adding
the target must be done in Xcode on a Mac — do not hand-author `pbxproj`.
Until the target is added, test files are static coverage docs, not runnable
via ⌘U.

## v8 / v9 annotation convention

- `// v8: ...` — pointer to the corresponding construct in `dead_mall_tycoon_v8.html`.
- `// v9: ...` — new mechanic or reshape introduced in the iOS port's v9 prompt
  sequence. When reshaping a v8 construct, leave the original `// v8:` comment
  adjacent to the new `// v9:` comment so the evolution is legible.

## Design-intent docs

- `DeadMallTycoon_Spec (1).md` — concept / pitch.
- `DeadMallTycoon_Mechanics (2).md` — detailed mechanics spec.
- `dead_mall_tycoon_v8.html` — the original browser prototype. Source of truth
  for mechanics *as of v8*; the v9 prompt sequence intentionally diverges in
  places (see commit history / `// v9:` annotations for the current state).
