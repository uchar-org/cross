flake:
{ pkgs, inputs, ... }@attrs:
let
  system = pkgs.hostPlatform.system;
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  formatter = pkgs.alejandra;

  androidEmulator = pkgs.androidenv.emulateApp {
    name = "emulator";
    platformVersion = "36";
    abiVersion = "x86_64";
    systemImageType = "google_apis_playstore";
    configOptions = {
      "hw.gpu.enabled" = "yes";
      "hw.gpu.mode" = "swiftshader_indirect";
      "hw.keyboard" = "yes";
      "hw.kainKeys" = "yes";
    };
  };
  androidEmulatorNoGPU = pkgs.androidenv.emulateApp {
    name = "emulator";
    platformVersion = "36";
    abiVersion = "x86_64";
    systemImageType = "google_apis_playstore";
    configOptions = {
      "hw.gpu.enabled" = "yes";
      "hw.keyboard" = "yes";
      "hw.kainKeys" = "yes";
    };
  };

  pinnedFlutter = pkgs.flutter338;
  pinnedJDK = pkgs.jdk17_headless;
  androidCustomPackage = inputs.android-nixpkgs.sdk.${system} (
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

in pkgs.mkShell {
  packages = [
    pkgs.rustup
    pkgs.olm
    pkgs.yq-go
    formatter
    pinnedFlutter
    androidCustomPackage
    pinnedJDK
  ] ++ pkgs.lib.optionals isLinux [
    pkgs.webkitgtk_4_1
    pkgs.libsecret.dev
    (pkgs.callPackage ./shell_vodozemac.nix {})
    (pkgs.writeScriptBin "android-emulator" ''
      ${androidEmulator}/bin/run-test-emulator
    '')
    (pkgs.writeScriptBin "android-emulator-no-gpu" ''
      ${androidEmulatorNoGPU}/bin/run-test-emulator
    '')
  ];

  env = {
    ANDROID_HOME = "${androidCustomPackage}/share/android-sdk";
    ANDROID_SDK_ROOT = "${androidCustomPackage}/share/android-sdk";
    JAVA_HOME = pinnedJDK.home;
    FLUTTER_ROOT = "${pinnedFlutter}";
    GRADLE_OPTS =
      "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/35.0.0/aapt2";
  } // pkgs.lib.optionalAttrs isLinux {
    CMAKE_PREFIX_PATH = pkgs.lib.makeLibraryPath [ pkgs.libsecret.dev ];
    CHROME_EXECUTABLE = "${pkgs.google-chrome}/bin/google-chrome-stable";
  };

  shellHook = ''
    export PATH="$HOME/.cargo/bin:$PATH"
    ${pkgs.lib.optionalString isLinux "init-vodozemac"}

    echo "---------------------------------------------------------------------------------------------------"
    echo "in order to run android emulator, execute 'android-emulator' and 'android-emulator-no-gpu' commands"
    echo "---------------------------------------------------------------------------------------------------"
  '';
}
