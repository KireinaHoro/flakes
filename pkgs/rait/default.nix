{ source, buildGoModule, fetchFromGitLab, lib }:

buildGoModule rec {
  inherit (source) pname version src;

  vendorSha256 = "sha256-EHkwSSuKrtS0px/a1TUBt13gBNGY8tlpm4sbsoZ1UsY=";

  subPackages = [ "cmd/rait" ];

  meta = with lib; {
    description = "Redundant Array of Inexpensive Tunnels";
    homepage = "https://gitlab.com/NickCao/RAIT";
    license = licenses.asl20;
  };
}
