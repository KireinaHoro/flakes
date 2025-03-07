{ pkgs, ... }:

{
  # setup zsh global profile (nix path, etc.)
  programs.zsh.enable = true;

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes ca-derivations
      extra-platforms = x86_64-darwin
      use-case-hack = true
    '';
  };
}
