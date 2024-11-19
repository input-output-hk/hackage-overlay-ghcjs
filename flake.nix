{
  description = "Metadata for Cardano's Haskell package repository";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    flake-utils = { url = "github:numtide/flake-utils"; };

    foliage = {
      url = "github:input-output-hk/foliage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.hackage-nix.follows = "hackage-nix";
      inputs.flake-utils.follows = "flake-utils";
    };

    haskell-nix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.hackage.follows = "hackage-nix";
    };

    hackage-nix = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };

    CHaP = {
      url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
      flake = false;
    };

    iohk-nix = {
      url = "github:input-output-hk/iohk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, foliage, haskell-nix, CHaP, iohk-nix, ... }:
    let
      inherit (nixpkgs) lib;
      inherit (import ./nix/chap-meta.nix { inherit lib CHaP; }) chap-package-latest-versions chap-package-versions mkPackageTreeWith;

      smokeTestPackages = [
        "Cabal"
        "basement"
        "beam-sqlite"
        "cborg"
        "clock"
        "cryptonite"
        "digest"
        "direct-sqlite"
        "double-conversion"
        "entropy"
        "foundation"
        "gauge"
        "lzma"
        "memory"
        "mersenne-random-pure64"
        "network"
        "network-info"
        "scrypt"
        "terminal-size"
        "unix"
        "unix-bytestring"
        "unix-compat"
      ];

      # Using intersectAttrs like this is a cheap way to throw away everything
      # with keys not in smokeTestPackages
      smoke-test-package-versions =
        builtins.intersectAttrs
          (lib.genAttrs smokeTestPackages (pkg: { }))
          chap-package-latest-versions;

      # type CompilerName = String
      # compilers :: [CompilerName]
      compilers = [ "ghc810" "ghc96" "ghc98" ];
      # compilers which we don't build for by default
      experimental-compilers = [ "ghc98" ];

      # Add exceptions to the CI here.
      #
      # Currently the following attributes are supported:
      #
      # - <compiler-nix-name>.enabled = <predicate>
      #   Excludes compiling a package with <compiler-nix-name>. By default all
      #   compilers (defined above) are included.
      #
      exceptions = {
      };

      # Extra configurations (possibly compiler-dependent) to add to all projects.
      extraConfig = compiler:
        {
          modules = [
          ];
        };

      # mkCompilerPackageTreeWith
      # :: (Compiler -> PkgName -> PkgVersions -> a)
      # -> PkgVersions
      # -> Map Compiler (Map PkgName (Map PkgVersion a))
      mkCompilerPackageTreeWith = f: pkg-versions:
        lib.genAttrs compilers (compiler:
          let
            filtered-pkgs-versions =
              lib.mapAttrs
                (name: versions:
                  let predicate = lib.attrByPath
                    [ name compiler "enabled" ]
                    # the default setting depends on whether or not the compiler is
                    # experimental. Experimental compilers are disabled by default,
                    # non-experimental compilers are enabled by default
                    (v : !(builtins.elem compiler experimental-compilers))
                    exceptions;
                  in builtins.filter predicate versions)
                pkg-versions;
          in
          mkPackageTreeWith (f compiler) filtered-pkgs-versions);

      # flattenTree
      # :: Map Compiler (Map PackageName (Map PackageVersion a))
      # -> Map String a
      flattenTree =
        lib.concatMapAttrs (compiler:
          lib.concatMapAttrs (name:
            lib.concatMapAttrs (version:
              value: { "${compiler}/${name}/${version}" = value; }
            )));
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            inherit (haskell-nix) config;
            overlays = [
              haskell-nix.overlay
              iohk-nix.overlays.crypto
            ];
          };

          builder = import ./nix/builder.nix { inherit pkgs CHaP extraConfig; };

          # use a self + path reference to ensure this runs in the context of the
          # whole flake source, so can see the other scripts
          update-chap-deps = pkgs.writeShellScriptBin "update-chap-deps" ''
            ${self + "/scripts/update-chap-deps.sh"} ${CHaP} $@
          '';
        in
        rec {
          devShells.default = with pkgs; mkShellNoCC {
            name = "hackage-overlay-ghcjs";
            buildInputs = [
              bash
              coreutils
              curlMinimal.bin
              gitMinimal
              gnutar
              foliage.packages.${system}.default
            ];
          };

          haskellPackages =
            mkCompilerPackageTreeWith
              (compiler: name: version: (builder compiler name version).aggregate)
              chap-package-versions;

          smokeTestPackages =
            mkCompilerPackageTreeWith
              (compiler: name: version: (builder compiler name version).aggregate)
              smoke-test-package-versions;

          packages = flattenTree haskellPackages // {
            inherit update-chap-deps;

            allPackages = pkgs.releaseTools.aggregate {
              name = "all-packages";
              constituents = builtins.attrValues (flattenTree haskellPackages);
            };

            allSmokeTestPackages = pkgs.releaseTools.aggregate {
              name = "all-smoke-test-packages";
              constituents = builtins.attrValues (flattenTree smokeTestPackages);
            };
          };

          # The standard checks: build all the smoke test packages
          checks = flattenTree smokeTestPackages;

          hydraJobs =
            lib.optionalAttrs (system != "aarch64-linux")
              (mkCompilerPackageTreeWith builder smoke-test-package-versions)
            // { devShells = devShells; };
        });

  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://foliage.cachix.org"
    ];
    extra-trusted-substituters = [
      # If you have a nixbuild.net SSH key set up, you can pull builds from there
      # by using '--extra-substituters ssh://eu.nixbuild.net' manually, otherwise this
      # does nothing
      "ssh://eu.nixbuild.net"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "foliage.cachix.org-1:kAFyYLnk8JcRURWReWZCatM9v3Rk24F5wNMpEj14Q/g="
      "nixbuild.net/smart.contracts@iohk.io-1:s2PhQXWwsZo1y5IxFcx2D/i2yfvgtEnRBOZavlA8Bog="
    ];
    allow-import-from-derivation = true;
  };
}
