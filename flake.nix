# This flake provides various development shells for different purposes.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    sandbox.url = "github:archie-judd/agent-sandbox.nix";

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      sandbox,
      llm-agents,
      fenix,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      nixpkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ fenix.overlays.default ];
        };
      mkClaudeFor =
        system:
        import ./lib/claude.nix {
          pkgs = nixpkgsFor system;
          inherit llm-agents;
          sandboxLib = sandbox.lib.${system};
        };
    in
    {
      lib = forAllSystems (system: {
        mkClaude = mkClaudeFor system;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor system;
          mkClaude = mkClaudeFor system;
          claudePkgs = mkClaude { };
        in
        {
          claude = pkgs.mkShell {
            packages = [
              claudePkgs.claude-sandboxed
              claudePkgs.claude-yolo-sandboxed
              claudePkgs.bash-sandboxed
            ];
            shellHook = ''
              echo "Welcome to the sandboxed Claude development shell!"
              echo "Normal usage: claude [args...]"
              echo "Dangerous usage (no permissions checks, use with caution!): claude-yolo [args...]"

              alias claude='claude-sandboxed';

              export TERMINFO="${pkgs.ncurses}/share/terminfo";
              echo "${pkgs.ncurses}/share/terminfo is available at $TERMINFO"
            '';
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor system;
          claudePkgs = (mkClaudeFor system) { };

          # Nix expression with dependency store paths baked in at eval time.
          # Only the project flake ref and variant are resolved at runtime
          # (requires --impure for builtins.getFlake / builtins.currentSystem).
          withShellExpr = pkgs.writeText "with-shell-expr.nix" ''
            projectFlakeRef: attr:
            let
              projectFlake = builtins.getFlake projectFlakeRef;
              system = builtins.currentSystem;

              shell = projectFlake.devShells.''${system}.default;
              extraPkgs = (shell.buildInputs or [ ]) ++ (shell.nativeBuildInputs or [ ]);

              pkgs = import ${nixpkgs} {
                inherit system;
                config = { allowUnfree = true; };
              };
              sandboxFlake = builtins.getFlake "path:${sandbox}";
              llmAgentsFlake = builtins.getFlake "path:${llm-agents}";

              mkClaude = import ${./lib/claude.nix} {
                inherit pkgs;
                llm-agents = llmAgentsFlake;
                sandboxLib = sandboxFlake.lib.''${system};
              };
            in
              builtins.getAttr attr (mkClaude { extraPackages = extraPkgs; })
          '';

          # Nix expression that resolves nixpkgs attribute names to packages.
          # Package names are passed as a JSON array via the PKG_NAMES env var.
          withPkgsExpr = pkgs.writeText "with-pkgs-expr.nix" ''
            attr:
            let
              pkgNames = builtins.fromJSON (builtins.getEnv "PKG_NAMES");
              system = builtins.currentSystem;

              pkgs = import ${nixpkgs} {
                inherit system;
                config = { allowUnfree = true; };
              };
              sandboxFlake = builtins.getFlake "path:${sandbox}";
              llmAgentsFlake = builtins.getFlake "path:${llm-agents}";

              extraPkgs = map (name: pkgs.''${name}) pkgNames;

              mkClaude = import ${./lib/claude.nix} {
                inherit pkgs;
                llm-agents = llmAgentsFlake;
                sandboxLib = sandboxFlake.lib.''${system};
              };
            in
              builtins.getAttr attr (mkClaude { extraPackages = extraPkgs; })
          '';

          # Nix expression that accepts pre-resolved package store paths
          # via the PKG_STORE_PATHS env var (a JSON array of path strings).
          # Used on cache hit by the *-with-shell wrappers to avoid
          # re-evaluating (and re-copying) the project flake.
          withStorePathsExpr = pkgs.writeText "with-store-paths-expr.nix" ''
            attr:
            let
              pathStrings = builtins.fromJSON (builtins.getEnv "PKG_STORE_PATHS");
              system = builtins.currentSystem;

              pkgs = import ${nixpkgs} {
                inherit system;
                config = { allowUnfree = true; };
              };
              sandboxFlake = builtins.getFlake "path:${sandbox}";
              llmAgentsFlake = builtins.getFlake "path:${llm-agents}";

              extraPkgs = map builtins.storePath pathStrings;

              mkClaude = import ${./lib/claude.nix} {
                inherit pkgs;
                llm-agents = llmAgentsFlake;
                sandboxLib = sandboxFlake.lib.''${system};
              };
            in
              builtins.getAttr attr (mkClaude { extraPackages = extraPkgs; })
          '';

          # Helper to generate a *-with-shell wrapper for a given variant.
          # Caches discovered devShell package store paths by git rev so that
          # subsequent runs on the same commit skip the project flake evaluation
          # (and the expensive source-copy-to-store).
          mkWithShellWrapper =
            {
              name,
              attr,
              binName,
            }:
            pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = [
                pkgs.coreutils
                pkgs.git
                pkgs.jq
              ];
              text = ''
                if [[ $# -lt 1 ]]; then
                  echo "Usage: ${name} <project-flake-path> [-- args...]"
                  echo ""
                  echo "Launches sandboxed ${binName} with packages from the project's devShell."
                  echo ""
                  echo "Examples:"
                  echo "  ${name} ~/code/myproject"
                  echo "  ${name} github:owner/repo"
                  exit 1
                fi

                FLAKE_REF="$1"
                shift

                # Remove -- separator if present
                if [[ "''${1:-}" == "--" ]]; then
                  shift
                fi

                # --- Caching layer ---
                # For local git repos, cache the devShell package store paths
                # keyed by (absolute path, git rev).
                # On cache hit we skip the project flake evaluation entirely,
                # avoiding the expensive source-copy-to-store.
                CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-devshells"
                CACHE_HIT=false
                CACHE_KEY=""
                CACHE_FILE=""

                if [[ -d "$FLAKE_REF" ]]; then
                  ABS_DIR=$(realpath "$FLAKE_REF")

                  if git -C "$ABS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
                    GIT_REV=$(git -C "$ABS_DIR" rev-parse HEAD 2>/dev/null || true)

                    if [[ -n "$GIT_REV" ]]; then
                      CACHE_KEY=$(echo "$ABS_DIR-$GIT_REV" | sha256sum | cut -d' ' -f1)
                      CACHE_FILE="$CACHE_DIR/$CACHE_KEY.json"

                      if [[ -f "$CACHE_FILE" ]]; then
                        # Validate that every cached store path still exists
                        ALL_EXIST=true
                        while IFS= read -r p; do
                          if [[ ! -e "$p" ]]; then
                            ALL_EXIST=false
                            break
                          fi
                        done < <(jq -r '.[]' "$CACHE_FILE")

                        if [[ "$ALL_EXIST" == "true" ]]; then
                          CACHE_HIT=true
                        fi
                      fi
                    fi
                  fi
                fi

                if [[ "$CACHE_HIT" == "true" ]]; then
                  export PKG_STORE_PATHS
                  PKG_STORE_PATHS=$(cat "$CACHE_FILE")
                  RESULT=$(nix build --no-link --print-out-paths --impure \
                    --expr "import ${withStorePathsExpr} \"${attr}\"")
                else
                  # Resolve local directory paths to absolute flake references
                  if [[ -d "$FLAKE_REF" ]]; then
                    FLAKE_REF="path:$(realpath "$FLAKE_REF")"
                  fi

                  export FLAKE_REF
                  RESULT=$(nix build --no-link --print-out-paths --impure \
                    --expr "import ${withShellExpr} (builtins.getEnv \"FLAKE_REF\") \"${attr}\"")

                  # Cache the devShell package paths for next time
                  if [[ -n "$CACHE_KEY" ]]; then
                    SYSTEM=$(nix eval --impure --raw --expr builtins.currentSystem)
                    DISCOVERED=$(nix eval "$FLAKE_REF#devShells.$SYSTEM.default" \
                      --apply 'shell: map toString ((shell.buildInputs or []) ++ (shell.nativeBuildInputs or []))' \
                      --json 2>/dev/null || true)
                    if [[ -n "$DISCOVERED" && "$DISCOVERED" != "null" ]]; then
                      mkdir -p "$CACHE_DIR"
                      echo "$DISCOVERED" > "$CACHE_FILE"
                    fi
                  fi
                fi

                exec "$RESULT/bin/${binName}" "$@"
              '';
            };

          # Helper to generate a *-with-pkgs wrapper for a given variant.
          mkWithPkgsWrapper =
            {
              name,
              attr,
              binName,
            }:
            pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                if [[ $# -lt 1 ]]; then
                  echo "Usage: ${name} <pkg-name> [<pkg-name>...] [-- args...]"
                  echo ""
                  echo "Launches sandboxed ${binName} with extra nixpkgs packages in the sandbox."
                  echo ""
                  echo "Examples:"
                  echo "  ${name} cargo"
                  echo "  ${name} go python3 -- --model sonnet"
                  exit 1
                fi

                # Collect package names until -- or end of args
                PKG_NAMES_ARRAY=()
                while [[ $# -gt 0 && "$1" != "--" ]]; do
                  PKG_NAMES_ARRAY+=("$1")
                  shift
                done

                # Remove -- separator if present
                if [[ "''${1:-}" == "--" ]]; then
                  shift
                fi

                # Build JSON array: ["cargo","go"]
                PKG_NAMES="["
                first=true
                for pkg in "''${PKG_NAMES_ARRAY[@]}"; do
                  if [ "$first" = true ]; then
                    first=false
                  else
                    PKG_NAMES+=","
                  fi
                  PKG_NAMES+="\"$pkg\""
                done
                PKG_NAMES+="]"
                export PKG_NAMES

                RESULT=$(nix build --no-link --print-out-paths --impure \
                  --expr "import ${withPkgsExpr} \"${attr}\"")
                exec "$RESULT/bin/${binName}" "$@"
              '';
            };
        in
        claudePkgs
        // {
          claude-with-shell = mkWithShellWrapper {
            name = "claude-with-shell";
            attr = "claude-sandboxed";
            binName = "claude-sandboxed";
          };
          claude-yolo-with-shell = mkWithShellWrapper {
            name = "claude-yolo-with-shell";
            attr = "claude-yolo-sandboxed";
            binName = "claude-sandboxed-yolo";
          };
          bash-with-shell = mkWithShellWrapper {
            name = "bash-with-shell";
            attr = "bash-sandboxed";
            binName = "bash-sandboxed";
          };
          claude-with-pkgs = mkWithPkgsWrapper {
            name = "claude-with-pkgs";
            attr = "claude-sandboxed";
            binName = "claude-sandboxed";
          };
          claude-yolo-with-pkgs = mkWithPkgsWrapper {
            name = "claude-yolo-with-pkgs";
            attr = "claude-yolo-sandboxed";
            binName = "claude-sandboxed-yolo";
          };
          bash-with-pkgs = mkWithPkgsWrapper {
            name = "bash-with-pkgs";
            attr = "bash-sandboxed";
            binName = "bash-sandboxed";
          };
        }
      );
    };
}
