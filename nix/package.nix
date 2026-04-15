{
  pkgs,
  inputs,
  system,
  formatter,
  stdenv,
  lib,
  targetFlutterPlatform ? "linux",
}:

let
  pinnedFlutter = pkgs.flutter341;
  pinnedJDK = pkgs.jdk17_headless;

  pubspecLock = lib.importJSON ./pubspec.lock.json;

  head = {
    pname = "uchar-${targetFlutterPlatform}";
    version = "2.4.1";

    src = ../.;

    inherit pubspecLock;

    gitHashes = {
      flutter_web_auth_2 = "sha256-3aci73SP8eXg6++IQTQoyS+erUUuSiuXymvR32sxHFw=";
      flutter_secure_storage_linux = "sha256-cFNHW7dAaX8BV7arwbn68GgkkBeiAgPfhMOAFSJWlyY=";
      webcrypto = "sha256-yPhL0LoSIaJ9e9wrLtdPuTBRvXft1DQM9KR7WdNcj68=";
    };

    inherit targetFlutterPlatform;

    flutterBuildFlags = [
      # Required since v2.4.0
      "--enable-experiment=dot-shorthands"
    ];

    meta = {
      description = "Chat with your friends (matrix client)";
      homepage = "https://uchar.im/";
      license = lib.licenses.agpl3Plus;
      maintainers = with lib.maintainers; [
        mkg20001
        tebriel
        aleksana
      ];
      badPlatforms = lib.platforms.darwin;
    }
    // lib.optionalAttrs (targetFlutterPlatform == "linux") {
      mainProgram = "uchar";
    };
  };

  platforms = {
    web = import ./platforms/web.nix { inherit pkgs pinnedFlutter; };
    linux = import ./platforms/linux.nix {
      inherit
        pkgs
        pinnedFlutter
        stdenv
        lib
        ;
    };
    apk = import ./platforms/apk.nix {
      inherit
        pkgs
        pinnedFlutter
        pinnedJDK
        system
        ;
    };
  };

in
(pinnedFlutter.buildFlutterApplication (
  head
  // lib.optionalAttrs (targetFlutterPlatform == "linux") platforms.linux
  // lib.optionalAttrs (targetFlutterPlatform == "web") platforms.web
  // lib.optionalAttrs (targetFlutterPlatform == "apk") platforms.apk
)).overrideAttrs
  (old: {
    # extraIncludes = break [ pkgs.fribidi.dev ];
    # flutterBuildFlags = [
    #   "--cmake-args"
    #   "-CXXFLAGS=\"-I${pkgs.fribidi.dev}/include\""
    # ];
  })
