# Example: sandboxed Claude with extra packages via shell.nix
#
# Usage (requires --impure for builtins.getFlake):
#   nix-shell --impure --run claude-sandboxed
#   nix-shell --impure --run "claude-sandboxed-yolo --model sonnet"
#   nix-shell --impure --run bash-sandboxed   # debug shell to inspect the sandbox
#
# To update the pin, replace the rev below with a specific commit hash.
# Transitive dependencies (nixpkgs, etc.) are pinned by the flake.lock at that commit.
let
  claude-sandboxed = builtins.getFlake
    "github:maschwanden/claude-sandboxed/main"; # replace "main" with a commit rev to pin
  system = builtins.currentSystem;
  pkgs = import claude-sandboxed.inputs.nixpkgs { inherit system; };
  claudePkgs = claude-sandboxed.lib.${system}.mkSandboxedClaude {
    extraPackages = [
      pkgs.go
      pkgs.python3
    ];
  };
in
pkgs.mkShell {
  packages = [
    claudePkgs.claude-sandboxed
    claudePkgs.claude-yolo-sandboxed
    claudePkgs.bash-sandboxed
  ];
}
