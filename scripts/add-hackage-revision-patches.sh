#!/usr/bin/env bash

set -o errexit
set -o pipefail

WORK=$(mktemp -d)

cd _sources
for pkg in *; do
  (
  cd $pkg
  for ver in *; do
    (
    cd $ver
    PATCH=$(pwd)/patches/00-revision.patch
      (
      cd $WORK
      TAR_URL="https://hackage.haskell.org/package/$pkg-$ver/$pkg-$ver.tar.gz"
      if ! curl --fail --silent --location --remote-name "$TAR_URL"; then
        warning "Failed to download $TAR_URL"
        exit 1
      fi
      tar xzf $pkg-$ver.tar.gz
      mv $pkg-$ver $pkg-$ver-r0
      cabal unpack $pkg-$ver
      dos2unix $pkg-$ver-r0/$pkg.cabal 
      dos2unix $pkg-$ver/$pkg.cabal 
      if ! diff -u $pkg-$ver-r0/$pkg.cabal $pkg-$ver/$pkg.cabal; then
        (diff -u $pkg-$ver-r0/$pkg.cabal $pkg-$ver/$pkg.cabal || true) > $PATCH
      fi
      )
    )
  done
  )
done

