{ pkgs, pinnedFlutter, ... }:
let
  vodozemac-wasm = pkgs.callPackage ../vodozemac { flutter = pinnedFlutter; };
in
{
  preBuild = ''
    cp -r ${vodozemac-wasm}/* ./assets/vodozemac/
  '';
}
