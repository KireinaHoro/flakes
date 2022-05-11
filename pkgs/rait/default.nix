{ source, buildGoModule, fetchFromGitLab, lib }:

buildGoModule rec {
  inherit (source) pname version src;

  vendorSha256 = "sha256-SyiXhWnsECnn3ObaUl/5coq7jk7dYd66WlNihMpoCrI=";

  subPackages = [ "cmd/rait" ];

  meta = with lib; {
    description = "Redundant Array of Inexpensive Tunnels";
    homepage = "https://gitlab.com/NickCao/RAIT";
    license = licenses.asl20;
  };
}
