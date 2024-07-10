{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = (import nixpkgs) {
          inherit system;
        };

        lintingRustFlags = "-D unused-crate-dependencies";
      in {
        devShell = pkgs.mkShell {
          packages = with pkgs; [
            rustup
            nodePackages.wrangler
            worker-build
            wasm-pack

            # Code formatting tools
            alejandra
            treefmt
          ];

          RUSTFLAGS = lintingRustFlags;
        };
      }
    );
}
