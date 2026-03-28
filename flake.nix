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
  };

  outputs =
    {
      nixpkgs,
      sandbox,
      llm-agents,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    let
      claudePkgsFor =
        system:
        let
          pkgs = import nixpkgs {
            system = system;
            config.allowUnfree = true;
          };
        in
        import ./pkgs/claude.nix {
          inherit pkgs llm-agents;
          sandboxLib = sandbox.lib.${system};
        };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            system = system;
            config.allowUnfree = true;
          };
          claudePkgs = claudePkgsFor system;
        in
        {
          claude = pkgs.mkShell {
            packages = [
              claudePkgs.claude
              claudePkgs.claude-yolo
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

      packages = forAllSystems (system: claudePkgsFor system);
    };
}
