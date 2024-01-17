{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    direnv
  ];

  programs.zsh = {
    enable = true;
    enableSyntaxHighlighting = true;
  };

  services.nix-daemon.enable = true;
  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes ca-derivations
      extra-platforms = x86_64-darwin
    '';
  };
}
