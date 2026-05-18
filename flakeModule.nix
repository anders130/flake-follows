{
    lib,
    config,
    ...
}: let
    inherit (lib) filterAttrs mapAttrs optionalAttrs mkDefault mkOption pipe;
    inherit (lib.types) listOf str path;
    inherit (builtins) fromJSON readFile foldl' isList length head elem attrNames;

    cfg = config.flake-follows;
    nodes = (fromJSON (readFile cfg.lockFile)).nodes;
    rootInputNodes = nodes.root.inputs or {};

    nodeRev = nodeName: (nodes.${nodeName} or {}).locked.rev or null;

    revToRootInput = foldl' (
        acc: name: let
            rev = nodeRev (rootInputNodes.${name} or name);
        in
            if rev != null && !(acc ? ${rev})
            then acc // {${rev} = name;}
            else acc
    ) {} (attrNames rootInputNodes);

    autoFollowsFor = name: let
        subInputs = (nodes.${rootInputNodes.${name} or name} or {}).inputs or {};
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
                    else let
                        match = revToRootInput.${nodeRev subNodeName} or null;
                    in
                        if match == null || match == name
                        then null
                        else match
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
