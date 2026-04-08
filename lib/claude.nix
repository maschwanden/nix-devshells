# Sandboxed Claude Code helper.
# Based on https://github.com/archie-judd/agent-sandbox.nix.
#
# Usage: mkClaude = import ./lib/claude.nix { inherit pkgs sandboxLib llm-agents; };
#        mkClaude { extraPackages = [ pkgs.go ]; }
# Returns: { claude, claude-yolo, bash }
{
  pkgs,
  sandboxLib,
  llm-agents,
}:

{

  mkSandboxedClaude = (
    {
      extraPackages ? [ ],
      enableVoice ? false,
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
      ]
      ++ pkgs.lib.optionals enableVoice [
        pkgs.sox
        pkgs.alsa-utils
      ]
      ++ pkgs.lib.flatten extraPackages;
      claude = sandboxLib.mkSandbox {
        pkg = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
        binName = "claude";
        outName = "claude-sandboxed";

        allowedPackages = allowed-packages;
        stateDirs = state-dirs;
        stateFiles = state-files;
        extraEnv = extra-env;
      };
      claude-yolo = pkgs.writeShellScriptBin ("claude-sandboxed-yolo") ''
        exec ${claude}/bin/claude-sandboxed --dangerously-skip-permissions "$@"
      '';
      # Useful for exploring the sandbox and debugging.
      bash = sandboxLib.mkSandbox {
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
      inherit claude claude-yolo bash;
    }
  );
}
