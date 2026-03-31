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
        import ./pkgs/claude.nix {
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

      packages = forAllSystems (system: (mkClaudeFor system) { });
    };
}
