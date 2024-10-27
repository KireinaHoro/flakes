{ source, rustPlatform, lib }:

rustPlatform.buildRustPackage {
  inherit (source) pname version src;

  cargoHash = lib.fakeHash;

  meta = with lib; {
    description = "swan-updown helps create XFRM interfaces on demand";
    homepage = "https://github.com/6-6-6/swan-updown";
    license = licenses.mit;
  };
}
