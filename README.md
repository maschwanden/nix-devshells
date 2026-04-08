# claude-sandboxed

Sandboxed [Claude Code](https://docs.anthropic.com/en/docs/claude-code) for Nix, using [agent-sandbox.nix](https://github.com/archie-judd/agent-sandbox.nix) to restrict filesystem and tool access. Only explicitly allowed tools (git, ripgrep, fd, jq, etc.) are available inside the sandbox.

Environment variables `CLAUDE_CODE_OAUTH_TOKEN` and `GITHUB_TOKEN` are passed through to the sandbox. Make sure these are set before launching.

## Packages

| Package | Description |
|---|---|
| `claude` | Sandboxed Claude Code |
| `claude-yolo` | Sandboxed Claude Code with `--dangerously-skip-permissions` |
| `bash` | Sandboxed bash for debugging the sandbox environment |

## Quick start

Run directly from GitHub:

```sh
nix run github:maschwanden/claude-sandboxed#claude
nix run github:maschwanden/claude-sandboxed#claude-yolo
```

## Voice support

By default, voice dependencies (sox, alsa-utils) are not included to keep the closure small. Use the `*-with-voice` variants to enable voice support:

| Package | Description |
|---|---|
| `claude-with-voice` | Sandboxed Claude with voice support |
| `claude-yolo-with-voice` | Same, with `--dangerously-skip-permissions` |
| `bash-with-voice` | Sandboxed bash with voice packages (for debugging) |

```sh
nix run github:maschwanden/claude-sandboxed#claude-with-voice
```

When using `mkSandboxedClaude` directly, pass `enableVoice = true`.

## With project devShell packages

The `*-with-shell` wrappers run sandboxed Claude with all packages from another flake's `devShells.<system>.default` available inside the sandbox. The project doesn't need to know about Claude at all.

| Package | Description |
|---|---|
| `claude-with-shell` | Sandboxed Claude + project devShell packages |
| `claude-yolo-with-shell` | Same, with `--dangerously-skip-permissions` |
| `bash-with-shell` | Sandboxed bash + project devShell packages (for debugging) |

```sh
# Launch Claude with all tools from your project's devShell
nix run github:maschwanden/claude-sandboxed#claude-with-shell -- ~/code/myproject

# Same but skip permission checks
nix run github:maschwanden/claude-sandboxed#claude-yolo-with-shell -- ~/code/myproject

# Debug: check which tools are available
nix run github:maschwanden/claude-sandboxed#bash-with-shell -- ~/code/myproject

# Pass extra arguments to claude after a second --
nix run github:maschwanden/claude-sandboxed#claude-with-shell -- ~/code/myproject -- --model sonnet

# Remote flakes work too
nix run github:maschwanden/claude-sandboxed#claude-with-shell -- github:owner/repo
```

The wrapper extracts `buildInputs` and `nativeBuildInputs` from the project's devShell and passes them as extra allowed packages to the sandbox. The project's own dependency pinning is respected. Requires `--impure` (handled automatically by the wrapper).

## With individual nixpkgs packages

The `*-with-pkgs` wrappers add individual packages by nixpkgs attribute name, without needing a project flake.

| Package | Description |
|---|---|
| `claude-with-pkgs` | Sandboxed Claude + specified nixpkgs packages |
| `claude-yolo-with-pkgs` | Same, with `--dangerously-skip-permissions` |
| `bash-with-pkgs` | Sandboxed bash + specified nixpkgs packages (for debugging) |

```sh
# Add cargo to the sandbox
nix run github:maschwanden/claude-sandboxed#claude-with-pkgs -- cargo

# Add multiple packages
nix run github:maschwanden/claude-sandboxed#claude-yolo-with-pkgs -- go python3 cargo

# Pass extra arguments to claude after --
nix run github:maschwanden/claude-sandboxed#claude-with-pkgs -- go -- --model sonnet
```

Package names are top-level nixpkgs attributes (the same names you'd use with `nix-shell -p`).

## Using `mkSandboxedClaude` from another flake

For direct integration, this flake exposes `lib.<system>.mkSandboxedClaude`:

```nix
{
  inputs.nix-devshells.url = "github:maschwanden/claude-sandboxed";

  outputs = { nix-devshells, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      claudePkgs = nix-devshells.lib.${system}.mkSandboxedClaude {
        extraPackages = [ pkgs.go pkgs.python3 ];
      };
    in {
      packages.${system}.claude = claudePkgs.claude;
    };
}
```
