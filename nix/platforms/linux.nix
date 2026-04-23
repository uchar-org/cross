{
  pkgs,
  pinnedFlutter,
  stdenv,
  lib,
  ...
}:
let
  libwebrtcRpath = lib.makeLibraryPath [
    pkgs.libgbm
    pkgs.libdrm
  ];
  vodozemac-wasm = pkgs.callPackage ../vodozemac { flutter = pinnedFlutter; };
in
{
  nativeBuildInputs = with pkgs; [
    imagemagick
    copyDesktopItems
    webkitgtk_4_1
    pkg-config
    llvmPackages.bintools
    clang
    gnumake
    cmake
    llvm
    # IMPORTANT: Never use glibc in buildInputs/etc. Because it breaks ld paths
    # glibc
    glib
    pkg-config
    gcc
  ];

  buildInputs = [
    vodozemac-wasm
    pkgs.openssl
    pkgs.zlib

    pkgs.llvm
    pkgs.rustup
    pkgs.libpq
  ];

  runtimeDependencies = with pkgs; [
    pulseaudio
    vodozemac-wasm
  ];

  env.NIX_LDFLAGS = "-rpath-link ${libwebrtcRpath}";
  NIX_LD = lib.fileContents "${stdenv.cc}/nix-support/dynamic-linker";

  env.CPATH = "${pkgs.fribidi.dev}/include/fribidi";



  shellHook = ''
    ls ${pkgs.gnumake}/
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:./build/linux/x64/debug/bundle/lib/"
  '';
    # export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.openssl ]}:$LD_LIBRARY_PATH"

  desktopItems = [
    (pkgs.makeDesktopItem {
      name = "uchar";
      exec = "uchar";
      icon = "uchar";
      desktopName = "uchar";
      genericName = "Chat with your friends (matrix client)";
      categories = [
        "Chat"
        "Network"
        "InstantMessaging"
      ];
    })
  ];

  customSourceBuilders = {
    flutter_webrtc =
      { version, src, ... }:
      stdenv.mkDerivation {
        pname = "flutter_webrtc";
        inherit version src;
        inherit (src) passthru;

        # postPatch = ''
        #   substituteInPlace third_party/CMakeLists.txt \
        #     --replace-fail "\''${CMAKE_CURRENT_LIST_DIR}/downloads/libwebrtc.zip" ${libwebrtc}
        #     ln -s ${libwebrtc} third_party/libwebrtc
        # '';

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
}
