{ pkgs, pinnedFlutter, ... }:
let
  vodozemac-wasm = pkgs.callPackage ../vodozemac-wasm.nix { flutter = pinnedFlutter; };
in
{
  preBuild = ''
    cp -r ${vodozemac-wasm}/* ./assets/vodozemac/
  '';
}
