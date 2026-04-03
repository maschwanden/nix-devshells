# Example: sandboxed Claude with extra packages via flake
#
# Usage:
#   nix run .#claude          — sandboxed Claude with Go and Python available
#   nix run .#claude-yolo     — same, with --dangerously-skip-permissions
#   nix run .#bash-sandboxed  — debug shell to inspect the sandbox
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-sandboxed.url = "github:maschwanden/claude-sandboxed";
  };

  outputs =
    { nixpkgs, claude-sandboxed, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      claudePkgs = claude-sandboxed.lib.${system}.mkSandboxedClaude {
        extraPackages = [
          pkgs.go
          pkgs.python3
        ];
      };
    in
    {
      packages.${system} = {
        claude = claudePkgs.claude-sandboxed;
        claude-yolo = claudePkgs.claude-yolo-sandboxed;
        bash-sandboxed = claudePkgs.bash-sandboxed;
      };
    };
}
