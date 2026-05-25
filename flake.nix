{
    outputs = _: {
        flakeModules = rec {
            flake-follows = import ./flakeModule.nix;
            default = flake-follows;
        };
    };
}
