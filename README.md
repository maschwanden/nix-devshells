# nix-devshells

A collection of ready-to-use Nix development shells for various purposes.

## Available shells

### Claude Code

A sandboxed environment for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code), using [agent-sandbox.nix](https://github.com/archie-judd/agent-sandbox.nix) to restrict filesystem and tool access. Only explicitly allowed tools (git, ripgrep, fd, jq, etc.) are available inside the sandbox.

| Package | Description |
|---|---|
| `claude` | Sandboxed Claude Code |
| `claude-yolo` | Sandboxed Claude Code with `--dangerously-skip-permissions` |
| `bash-sandboxed` | Sandboxed bash for debugging the sandbox environment |

Enter the dev shell (all packages available as commands):

```sh
nix develop .#claude
```

Environment variables `CLAUDE_CODE_OAUTH_TOKEN` and `GITHUB_TOKEN` are passed through to the sandbox. Make sure these are set before launching.

## Standalone usage

Each package definition under `pkgs/` is self-contained with pinned dependencies and can be used without the flake or a local clone.

### `nix run`

Run packages directly from GitHub:

```sh
nix run github:maschwanden/nix-devshells#claude
nix run github:maschwanden/nix-devshells#claude-yolo
nix run github:maschwanden/nix-devshells#bash-sandboxed
```

### `nix-build`

Copy a package file (e.g. `pkgs/claude.nix`) anywhere and build it:

```sh
nix-build pkgs/claude.nix -A claude
nix-build pkgs/claude.nix -A claude-yolo

# Run it directly
$(nix-build pkgs/claude.nix -A claude --no-out-link)/bin/claude-sandboxed
```

Or import it from another Nix expression:

```nix
let
  claudePkgs = import ./pkgs/claude.nix { };
in
  # claudePkgs.claude
  # claudePkgs.claude-yolo
  # claudePkgs.bash-sandboxed
```

You can override `pkgs` and `sandboxLib` if needed; otherwise they fall back to pinned versions of nixpkgs and agent-sandbox.nix.
