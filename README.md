# IOG ghcjs hackage overlay

This repo contains patches to various hackage packages to make them a bit more
compatible with GHCJS.  This allow us--in the interim--to avoid polluting other
repositories with ghcjs specific patches.

This repo can be used by adding it to the `cabal.project`:
```
repository ghcjs-overlay
  url: https://input-output-hk.github.io/hackage-overlay-ghcjs/
  secure: True
  root-keys:
    3838d0dfa046bb3d16de9ae0823dab1dd937ee336f9bcaa87c85b36443aee7f6
    92e8a83a0df4f99ff0372b6dcdb008c52971d1d53b1df621630f5a650fbf1f0a
    d5f108840fa2addca04caa82bc4c60ce41df7c0d3133baf6716b05a4dce11b6c
  key-threshold: 3
```

This overlay is now using the code foliage in a similar way to
https://github.com/IntersectMBO/cardano-haskell-packages

