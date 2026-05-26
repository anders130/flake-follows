# flake-follows

A [flake-parts](https://flake.parts) module for use with [flake-file](https://github.com/denful/flake-file). It automatically adds `follows` for sub-inputs that already exist at the root of your flake.

If `nixpkgs` is a root input and `home-manager` also declares `nixpkgs` as an input, this module will write:

```nix
home-manager.inputs.nixpkgs.follows = "nixpkgs";
```

## Usage

Import the module in one of your flake-parts files and register the input so it ends up in the generated `flake.nix`:

```nix
{ inputs, ... }:
{
  imports = [ inputs.flake-follows.flakeModules.flake-follows ];

  flake-file.inputs.flake-follows.url = "github:anders130/flake-follows";
}
```

Run `nix run .#write-flake` to regenerate `flake.nix` with the follows applied.

## Options

### `flake-follows.exclude`

Sub-inputs to skip, in `"input/subInput"` form.

```nix
flake-follows.exclude = [
  "hyprland/nixpkgs"
  "caelestia-shell/nixpkgs"
];
```

Default: `[]`

### `flake-follows.autoLock`

Runs `nix flake lock` after writing `flake.nix` to lock any new inputs, then regenerates once if the lock changed.

Default: `true`
