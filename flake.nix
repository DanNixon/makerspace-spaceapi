{
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk.url = "github:nix-community/naersk";
  };

  outputs = { self, nixpkgs, flake-utils, fenix, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (import nixpkgs) {
          inherit system;
        };

        toolchain = fenix.packages.${system}.toolchainOf {
          channel = "1.72";
          sha256 = "Q9UgzzvxLi4x9aWUJTn+/5EXekC98ODRU1TwhUs9RnY=";
        };

        naersk' = pkgs.callPackage naersk {
          cargo = toolchain.rust;
          rustc = toolchain.rust;
        };

        cargo_toml = builtins.readFile ./Cargo.toml;
        cargo = builtins.fromTOML cargo_toml;
        version = cargo.package.version;

        nativeBuildInputs = with pkgs; [ cmake pkg-config ];
        buildInputs = with pkgs; [ openssl ];

      in {
        devShell = pkgs.mkShell {
          nativeBuildInputs = nativeBuildInputs ++ [ toolchain.toolchain ];
          buildInputs = buildInputs;
          packages = with pkgs; [ skopeo ];
        };

        packages = rec {
          default = naersk'.buildPackage {
            name = "makerspace-spaceapi";
            version = version;

            src = ./.;

            nativeBuildInputs = nativeBuildInputs;
            buildInputs = buildInputs;
          };

          container-image = pkgs.dockerTools.buildImage {
            name = "makerspace-spaceapi";
            tag = "latest";
            created = "now";

            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = with pkgs; [ bashInteractive coreutils ];
              pathsToLink = [ "/bin" ];
            };

            config = {
              Entrypoint = [ "${pkgs.tini}/bin/tini" "--" "${default}/bin/makerspace-spaceapi" ];
              ExposedPorts = {
                "8080/tcp" = {};
                "9090/tcp" = {};
              };
              Env = [
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "API_ADDRESS=0.0.0.0:8080"
                "OBSERVABILITY_ADDRESS=0.0.0.0:9090"
              ];
            };
          };

          fmt = naersk'.buildPackage {
            src = ./.;
            nativeBuildInputs = nativeBuildInputs;
            buildInputs = buildInputs;
            mode = "fmt";
          };

          clippy = naersk'.buildPackage {
            src = ./.;
            nativeBuildInputs = nativeBuildInputs;
            buildInputs = buildInputs;
            mode = "clippy";
          };

          test = naersk'.buildPackage {
            src = ./.;
            nativeBuildInputs = nativeBuildInputs;
            buildInputs = buildInputs;
            mode = "test";
            # Ensure detailed test output appears in nix build log
            cargoTestOptions = x: x ++ ["1>&2"];
          };
        };
      }
    );
}
