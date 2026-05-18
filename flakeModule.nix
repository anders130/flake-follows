{
    lib,
    config,
    ...
}: let
    inherit (lib) filterAttrs mapAttrs optionalAttrs mkDefault mkOption pipe;
    inherit (lib.types) listOf str path;
    inherit (builtins) fromJSON readFile isList length head elem;

    cfg = config.flake-follows;
    nodes = (fromJSON (readFile cfg.lockFile)).nodes;
    rootInputNodes = nodes.root.inputs or {};

    autoFollowsFor = name: let
        nodeRef = rootInputNodes.${name} or name;
        subInputs = if isList nodeRef then {} else (nodes.${nodeRef} or {}).inputs or {};
    in
        pipe subInputs [
            (mapAttrs (
                subName: subNodeName:
                    if elem "${name}.${subName}" cfg.exclude
                    then null
                    else if isList subNodeName
                    then
                        if length subNodeName == 1
                        then head subNodeName
                        else null
                    else if rootInputNodes ? ${subName}
                    then subName
                    else null
            ))
            (filterAttrs (_: v: v != null))
        ];
in {
    options.flake-follows = {
        lockFile = mkOption {
            type = path;
            description = "Path to the flake.lock file.";
        };
        exclude = mkOption {
            type = listOf str;
            default = [];
            example = ["hyprland.nixpkgs"];
            description = "Sub-inputs to never auto-follow, in 'input.subInput' form.";
        };
    };

    config.flake-file.inputs = mapAttrs (
        name: _: let
            auto = autoFollowsFor name;
        in
            optionalAttrs (auto != {}) {
                inputs = mapAttrs (_: target: {follows = mkDefault target;}) auto;
            }
    )
    rootInputNodes;
}
