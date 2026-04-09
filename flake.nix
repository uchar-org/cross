{
  description = "A beginning of an awesome project bootstrapped with github:bleur-org/templates";

  inputs = {
    # Stable for keeping thins clean
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Fresh and new for testing
    nixpkgs.url = "github:xinux-org/upstream?ref=flutter-vodozemac";

    # The flake-parts library
    flake-parts.url = "github:hercules-ci/flake-parts";

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

  };

  outputs =
    { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];

        perSystem =
          { pkgs, system, ... }:
          rec {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
              config.android_sdk.accept_license = true;
              config.permittedInsecurePackages = [ "olm-3.2.16" ];
              overlays = [
                (final: prev: {
                  android = inputs.android-nixpkgs;
                })
              ];
            };

            # Nix script formatter
            formatter = pkgs.alejandra;

            # Development environment
            devShells.default = import ./nix/shell.nix {
              inherit
                pkgs
                inputs
                system
                formatter
                ;
            };

            # Output package
            packages = {
              linux = pkgs.callPackage ./nix/package.nix {
                inherit
                  pkgs
                  inputs
                  system
                  formatter
                  ;
              };
              web = pkgs.callPackage ./nix/package.nix {
                targetFlutterPlatform = "web";
                inherit inputs;
              };
              apk = pkgs.callPackage ./nix/package.nix {
                targetFlutterPlatform = "apk";
                inherit inputs system;
              };
            };
          };
      }
    );
}
