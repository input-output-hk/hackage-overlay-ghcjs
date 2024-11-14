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
    8a783638a6101250e7d94763cc4902153339372ea220929719b8dad324c16485
    c0b3e5df0672b1c91b7b3f123fb3bfb42745cf8bdb49b7e2c0f30fa1780697d6
    c63cca9b4f06cbf95b1c36c045c60c820a776245118fb73073017febf5b75f0f
  key-threshold: 3
```

This overlay is now using the code foliage in a similar way to
https://github.com/IntersectMBO/cardano-haskell-packages

