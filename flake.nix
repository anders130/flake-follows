{
    outputs = _: {
        flakeModules.flake-follows = import ./flakeModule.nix;
    };
}
