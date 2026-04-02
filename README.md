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

## Using sandboxed Claude with any project

The `*-with-shell` wrappers let you run sandboxed Claude (or bash) with all packages from another flake's devShell available inside the sandbox. This requires no changes to the project's `flake.nix` -- the project doesn't need to know about Claude at all.

| Package | Description |
|---|---|
| `claude-with-shell` | Sandboxed Claude Code + project devShell packages |
| `claude-yolo-with-shell` | Same, with `--dangerously-skip-permissions` |
| `bash-with-shell` | Sandboxed bash + project devShell packages (for debugging) |

### Usage

Point any wrapper at a flake that has a `devShells.<system>.default` output:

```sh
# Launch Claude with all tools from ~/code/myproject's devShell in the sandbox
nix run github:maschwanden/nix-devshells#claude-with-shell -- ~/code/myproject

# Same but skip permission checks
nix run github:maschwanden/nix-devshells#claude-yolo-with-shell -- ~/code/myproject

# Debug: open a bash shell to verify which tools are available
nix run github:maschwanden/nix-devshells#bash-with-shell -- ~/code/myproject

# Pass extra arguments to claude after a second --
nix run github:maschwanden/nix-devshells#claude-with-shell -- ~/code/myproject -- --model sonnet

# Remote flakes work too
nix run github:maschwanden/nix-devshells#claude-with-shell -- github:owner/repo
```

## Adding individual nixpkgs packages to the sandbox

The `*-with-pkgs` wrappers let you add individual packages by their nixpkgs attribute name, without needing a project flake at all.

| Package | Description |
|---|---|
| `claude-with-pkgs` | Sandboxed Claude Code + specified nixpkgs packages |
| `claude-yolo-with-pkgs` | Same, with `--dangerously-skip-permissions` |
| `bash-with-pkgs` | Sandboxed bash + specified nixpkgs packages (for debugging) |

```sh
# Add cargo to the sandbox
nix run github:maschwanden/nix-devshells#claude-with-pkgs -- cargo

# Add multiple packages
nix run github:maschwanden/nix-devshells#claude-yolo-with-pkgs -- go python3 cargo

# Debug: verify the packages are available
nix run github:maschwanden/nix-devshells#bash-with-pkgs -- cargo rustc

# Pass extra arguments to claude after a second --
nix run github:maschwanden/nix-devshells#claude-with-pkgs -- go -- --model sonnet
```

Package names are top-level nixpkgs attributes (the same names you'd use with `nix-shell -p`). Packages are pinned to this flake's nixpkgs version.

### How it works

The wrapper evaluates the target project's `devShells.<system>.default`, extracts its `buildInputs` and `nativeBuildInputs`, and passes them as extra allowed packages to the Claude sandbox. The project's own dependency pinning is respected -- updating this flake does **not** change the versions of project tools like `go`, `python`, etc. Only the base sandbox tools (`git`, `ripgrep`, `jq`, ...) and Claude Code itself are pinned by this flake.

Requires `--impure` (handled automatically by the wrapper) because the project flake path is resolved at runtime.

### Using `mkClaude` from another flake

If you prefer to integrate directly rather than using the wrappers, this flake exposes `lib.<system>.mkClaude`:

```nix
# In your project's flake.nix
{
  inputs.nix-devshells.url = "github:maschwanden/nix-devshells";

  outputs = { nix-devshells, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      claudePkgs = nix-devshells.lib.${system}.mkClaude {
        extraPackages = [ pkgs.go pkgs.python3 ];
      };
    in {
      packages.${system}.claude = claudePkgs.claude-sandboxed;
    };
}
```

## Standalone usage

Each package definition is self-contained with pinned dependencies and can be used without a local clone.

### `nix run`

Run packages directly from GitHub:

```sh
nix run github:maschwanden/nix-devshells#claude-sandboxed
nix run github:maschwanden/nix-devshells#claude-yolo-sandboxed
nix run github:maschwanden/nix-devshells#bash-sandboxed
```
