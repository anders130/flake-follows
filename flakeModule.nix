{
    inputs,
    lib,
    config,
    ...
}: let
    inherit (lib) filterAttrs mapAttrs optionalAttrs mkDefault mkOption pipe elem;
    inherit (lib.types) listOf str bool;
    inherit (builtins) attrNames;

    cfg = config.flake-follows;
    rootInputs = filterAttrs (n: _: n != "self") inputs;

    autoFollowsFor = name:
        pipe (attrNames (inputs.${name}.inputs or {})) [
            (map (subName:
                lib.nameValuePair subName (
                    if elem "${name}.${subName}" cfg.exclude
                    then null
                    else if inputs ? ${subName}
                    then subName
                    else null
                )))
            lib.listToAttrs
            (filterAttrs (_: v: v != null))
        ];
in {
    options.flake-follows = {
        exclude = mkOption {
            type = listOf str;
            default = [];
            example = ["hyprland.nixpkgs"];
            description = "Sub-inputs to never auto-follow, in 'input.subInput' form.";
        };

        autoLock = mkOption {
            type = bool;
            default = true;
            description = "Run `nix flake lock` after writing flake.nix to lock any new inputs, then regenerate once if the lock changed.";
        };
    };

    config = {
        flake-file.inputs = mapAttrs (
            name: _: let
                auto = autoFollowsFor name;
            in
                optionalAttrs (auto != {}) {
                    inputs = mapAttrs (_: target: {follows = mkDefault target;}) auto;
                }
        )
        rootInputs;

        # Removed inputs linger in `inputs` from the old flake.nix; drop their orphaned follows.
        flake-file.preProcess = mkDefault (
            filterAttrs (_: v: v ? url || v ? follows)
        );

        flake-file.write-hooks = lib.mkIf cfg.autoLock [
            {
                index = 50;
                program = pkgs:
                    pkgs.writeShellApplication {
                        name = "flake-follows-auto-lock";
                        text = ''
                            # Guard against re-entry from the second write-flake below.
                            [ -n "''${FLAKE_FOLLOWS_REGEN:-}" ] && exit 0

                            # Fast path: if the lock already covers all inputs, nothing to do.
                            nix flake lock --no-update-lock-file 2>/dev/null && exit 0

                            export FLAKE_FOLLOWS_REGEN=1
                            nix flake lock
                            nix run .#write-flake
                        '';
                    };
            }
        ];
    };
}
