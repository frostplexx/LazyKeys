{
    description = "LazyKeys - Remap capslock to something useful";

    outputs = { ... }: {

        darwinModules.default  = {
            imports = [./lazykeys.nix];
        };
    };
}
