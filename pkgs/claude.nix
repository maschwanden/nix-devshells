# Sandboxed Claude Code packages.
# Based on https://github.com/archie-judd/agent-sandbox.nix.
#
# Returns: { claude, claude-yolo, bash-sandboxed }
{
  pkgs,
  sandboxLib,
  llm-agents,
}:

let
  state-dirs = [ "$HOME/.claude" ];
  state-files = [
    "$HOME/.claude.json"
    "$HOME/.claude.json.lock"
  ];
  extra-env = {
    # Use literal strings for secrets to evaluate at runtime!
    # builtins.getEnv will leak your token into the /nix/store.
    CLAUDE_CODE_OAUTH_TOKEN = "$CLAUDE_CODE_OAUTH_TOKEN";
    GITHUB_TOKEN = "$GITHUB_TOKEN";
    TERM = "xterm-256color";
  };
  allowed-packages = [
    pkgs.coreutils
    pkgs.ncurses
    pkgs.which
    pkgs.git
    pkgs.ripgrep
    pkgs.fd
    pkgs.gnused
    pkgs.gnugrep
    pkgs.findutils
    pkgs.jq
  ];
  claude-sandboxed = sandboxLib.mkSandbox {
    pkg = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    binName = "claude";
    outName = "claude-sandboxed";

    allowedPackages = allowed-packages;
    stateDirs = state-dirs;
    stateFiles = state-files;
    extraEnv = extra-env;
  };
  claude-yolo = pkgs.writeShellScriptBin "claude-yolo" ''
    exec ${claude-sandboxed}/bin/claude-sandboxed --dangerously-skip-permissions "$@"
  '';
  # Useful for exploring the sandbox and debugging.
  bash-sandboxed = sandboxLib.mkSandbox {
    pkg = pkgs.bashNonInteractive;
    binName = "bash";
    outName = "bash-sandboxed";

    allowedPackages = allowed-packages;
    stateDirs = state-dirs;
    stateFiles = state-files;
    extraEnv = extra-env;
  };
in
{
  claude = claude-sandboxed;
  inherit claude-yolo bash-sandboxed;
}
