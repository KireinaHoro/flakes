# This file was generated by nvfetcher, please do not modify it manually.
{ fetchgit, fetchurl }:
{
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