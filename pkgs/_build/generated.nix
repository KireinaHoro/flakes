# This file was generated by nvfetcher, please do not modify it manually.
{ fetchgit, fetchurl }:
{
  ariang = {
    pname = "ariang";
    version = "f826684b98c914758198d85841c7807886b15764";
    src = fetchgit {
      url = "https://github.com/KireinaHoro/AriaNg";
      rev = "f826684b98c914758198d85841c7807886b15764";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sha256 = "0ilxa8xx6722ik7169r346i5ss3kkrv38pn47xxny0rydhz7vq4i";
    };
    
  };
  dnsmasq-china-list = {
    pname = "dnsmasq-china-list";
    version = "29427213ce3a3e1c49ec075c8b8da356d4017014";
    src = fetchgit {
      url = "https://github.com/felixonmars/dnsmasq-china-list";
      rev = "29427213ce3a3e1c49ec075c8b8da356d4017014";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sha256 = "087s1r22pdb17fc8araq03afw0kr78xnmxk26yq2szrh384xdmqb";
    };
    
  };
  rait = {
    pname = "rait";
    version = "19076c4a9e52c75c5b5a259f3b47bc3ef703eeb4";
    src = fetchgit {
      url = "https://gitlab.com/NickCao/RAIT";
      rev = "19076c4a9e52c75c5b5a259f3b47bc3ef703eeb4";
      fetchSubmodules = false;
      deepClone = false;
      leaveDotGit = false;
      sha256 = "020gz8z4sn60kv9jasq682s8abmdlz841fwvf7zc86ksb79z4m99";
    };
    
  };
}
