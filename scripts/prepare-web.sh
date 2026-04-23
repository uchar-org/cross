#!/bin/sh -ve

rm -rf .vodozemac
version=$(yq ".dependencies.flutter_vodozemac" < pubspec.yaml)
version=$(printf "%s" "$version" | tr -d '"^')
git clone https://github.com/famedly/dart-vodozemac.git -b ${version} .vodozemac
cd .vodozemac
cargo install flutter_rust_bridge_codegen
flutter_rust_bridge_codegen build-web --dart-root dart --rust-root $(readlink -f rust) --release
cd ..
rm -f ./assets/vodozemac/vodozemac_bindings_dart*
mv .vodozemac/dart/web/pkg/vodozemac_bindings_dart* ./assets/vodozemac/
rm -rf .vodozemac

flutter pub get
dart compile js ./web/native_executor.dart -o ./web/native_executor.js -m

# Download native_imaging for web (Imaging.js + Imaging.wasm).
# Without these, custom_image_resizer.dart's `await native.init()` crashes
# with "dart.global.Imaging is undefined" and image upload fails.
version=$(yq ".dependencies.native_imaging" < pubspec.yaml)
version=$(printf "%s" "$version" | tr -d '"^')
curl -L "https://github.com/famedly/dart_native_imaging/releases/download/v${version}/native_imaging.zip" > native_imaging.zip
unzip -o native_imaging.zip
mv js/* web/
rmdir js
rm native_imaging.zip