{ inputs, system, lib, stdenv, fetchFromGitHub, fetchzip, imagemagick, libgbm
, libdrm, flutter341, pulseaudio, webkitgtk_4_1, copyDesktopItems
, makeDesktopItem, jdk17_headless, google-chrome, callPackage, runCommand, yj
, vodozemac-wasm ? callPackage ./vodozemac-wasm.nix { flutter = flutter341; }
, targetFlutterPlatform ? "linux", }:

let
  pubspecLock = lib.importJSON ./pubspec.lock.json;
  libwebrtcRpath = lib.makeLibraryPath [ libgbm libdrm ];
  libwebrtc = fetchzip {
    url =
      "https://github.com/flutter-webrtc/flutter-webrtc/releases/download/v1.3.0/libwebrtc.zip";
    sha256 = "sha256-lGvWAicdKbNdMZAQS9Qyxv737G/sBI/hKbge/Xw5bDM=";

  };

  pinnedFlutter = flutter341;

  androidCustomPackage = inputs.android-nixpkgs.sdk.${system} (
    # show all potential values with
    # nix flake show github:tadfisher/android-nixpkgs
    sdkPkgs:
    with sdkPkgs; [
      cmdline-tools-latest
      cmake-3-22-1
      build-tools-35-0-0
      ndk-27-0-12077973
      ndk-28-2-13676358
      platform-tools
      emulator
      platforms-android-31
      platforms-android-33
      platforms-android-34
      platforms-android-35
      platforms-android-36
      system-images-android-36-google-apis-playstore-x86-64
    ]);

  pinnedJDK = jdk17_headless;

in pinnedFlutter.buildFlutterApplication (rec {
  pname = "uchar-${targetFlutterPlatform}";
  version = "2.4.1";

  src = ../.;

  inherit pubspecLock;

  gitHashes = {
    flutter_web_auth_2 = "sha256-3aci73SP8eXg6++IQTQoyS+erUUuSiuXymvR32sxHFw=";
    flutter_secure_storage_linux =
      "sha256-cFNHW7dAaX8BV7arwbn68GgkkBeiAgPfhMOAFSJWlyY=";
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
    maintainers = with lib.maintainers; [ mkg20001 tebriel aleksana ];
    badPlatforms = lib.platforms.darwin;
  } // lib.optionalAttrs (targetFlutterPlatform == "linux") {
    mainProgram = "uchar";
  };
} // lib.optionalAttrs (targetFlutterPlatform == "linux") {
  nativeBuildInputs = [ imagemagick copyDesktopItems webkitgtk_4_1 ];

  runtimeDependencies = [ pulseaudio ];

  env.NIX_LDFLAGS = "-rpath-link ${libwebrtcRpath}";

  desktopItems = [
    (makeDesktopItem {
      name = "uchar";
      exec = "uchar";
      icon = "uchar";
      desktopName = "uchar";
      genericName = "Chat with your friends (matrix client)";
      categories = [ "Chat" "Network" "InstantMessaging" ];
    })
  ];

  customSourceBuilders = {
    flutter_webrtc = { version, src, ... }:
      stdenv.mkDerivation {
        pname = "flutter_webrtc";
        inherit version src;
        inherit (src) passthru;

        postPatch = ''
          substituteInPlace third_party/CMakeLists.txt \
            --replace-fail "\''${CMAKE_CURRENT_LIST_DIR}/downloads/libwebrtc.zip" ${libwebrtc}
            ln -s ${libwebrtc} third_party/libwebrtc
        '';

        installPhase = ''
          runHook preInstall

          mkdir $out
          cp -r ./* $out/

          runHook postInstall
        '';
      };
  };

  # Temporary fix for json deprecation error
  # https://github.com/juliansteenbakker/flutter_secure_storage/issues/965
  postPatch = ''
    substituteInPlace linux/CMakeLists.txt \
      --replace-fail \
      "PRIVATE -Wall -Werror" \
      "PRIVATE -Wall -Werror -Wno-deprecated"
  '';

  postInstall = ''
    FAV=$out/app/uchar-linux/data/flutter_assets/assets/favicon.png
    ICO=$out/share/icons

    for size in 24 32 42 64 128 256 512; do
      D=$ICO/hicolor/''${size}x''${size}/apps
      mkdir -p $D
      magick $FAV -resize ''${size}x''${size} $D/uchar.png
    done

    patchelf --add-rpath ${libwebrtcRpath} $out/app/uchar-linux/lib/libwebrtc.so
  '';
} // lib.optionalAttrs (targetFlutterPlatform == "web") {
  preBuild = ''
    cp -r ${vodozemac-wasm}/* ./assets/vodozemac/
  '';
}

  // lib.optionalAttrs (targetFlutterPlatform == "apk") {
    targetFlutterPlatform = "universal";

    ANDROID_SDK_ROOT = "${androidCustomPackage}/share/android-sdk";
    JAVA_HOME = pinnedJDK;
    FLUTTER_ROOT = "${pinnedFlutter}";
    CHROME_EXECUTABLE = "${google-chrome}/bin/google-chrome-stable";
    GRADLE_OPTS =
      "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/35.0.0/aapt2";

    nativeBuildInputs = [ androidCustomPackage pinnedJDK ];

    # installPhase = ''
    #   runHook preInstall

    #   mkdir $out
    #   cp -r ./* $out/

    #   runHook postInstall
    # '';

    buildPhase = ''
      runHook preBuild

      mkdir -p $out/build/flutter_assets/fonts

      flutter build apk -v --split-debug-info="$debug" $flutterBuildFlags

      runHook postBuild
    '';
  })

