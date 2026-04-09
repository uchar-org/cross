{
  pkgs,
  pinnedJDK,
  pinnedFlutter,
  system,
}:
let
  androidCustomPackage = pkgs.android.sdk.${system} (
    # show all potential values with
    # nix flake show github:tadfisher/android-nixpkgs
    sdkPkgs: with sdkPkgs; [
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
    ]
  );
in
{
  targetFlutterPlatform = "universal";

  ANDROID_SDK_ROOT = "${androidCustomPackage}/share/android-sdk";
  JAVA_HOME = pinnedJDK;
  FLUTTER_ROOT = "${pinnedFlutter}";
  CHROME_EXECUTABLE = "${pkgs.google-chrome}/bin/google-chrome-stable";
  GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/35.0.0/aapt2";

  nativeBuildInputs = [
    androidCustomPackage
    pinnedJDK
  ];

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
}
