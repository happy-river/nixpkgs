let
  pkgs = import <nixpkgs> {};
in
  pkgs.fetchFromGitHub {
    owner = "tootsuite";
    repo = "mastodon";
    rev = "a033679eed02cb5ebba06373d1166d8a1fa82675";
    sha256 = "0nc35m50crmlbza3y9clpxhwhncrp7xlg87594pkdjbh36h5wbqg";
  }