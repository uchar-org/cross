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
  vodozemac-wasm-path = "${vodozemac-wasm}/vodozemac_bindings_dart_bg.wasm";
in
{
  nativeBuildInputs = with pkgs; [
    imagemagick
    copyDesktopItems
    webkitgtk_4_1
    rustup
  ];

  buildInputs = [ vodozemac-wasm ];

  runtimeDependencies = with pkgs; [
    pulseaudio
    vodozemac-wasm
  ];

  env.NIX_LDFLAGS = "-rpath-link ${libwebrtcRpath}";

  env.CPATH = "${pkgs.fribidi.dev}/include/fribidi";

  # shellHook = ''
  #   mkdir -p build/flutter_assets/fonts

  #   flutter build linux -v --split-debug-info="$debug"

  #   built=build/linux/*/$flutterMode/bundle

  #   mkdir -p $out/bin
  #   mkdir -p $out/app
  #   mv $built $out/app/$pname

  #   for f in $(find $out/app/$pname -maxdepth 1 -type f); do
  #     ln -s $f $out/bin/$(basename $f)
  #   done

  #   find $out/app/$pname -iname "*.so" -type f -exec chmod +x {} +

  #   for f in $(find $out/app/$pname -executable -type f); do
  #     if patchelf --print-rpath "$f" | grep /build; then
  #       echo "strip RPath of $f"
  #       newrp=$(patchelf --print-rpath $f | sed -r "s|/build.*ephemeral:||g" | sed -r "s|/build.*profile:||g")
  #       patchelf --set-rpath "$newrp" "$f"
  #     fi
  #   done
  # '';

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
