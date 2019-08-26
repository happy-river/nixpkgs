{ lib, writeScript, fetchFromGitHub, nix-prefetch-github, yarn2nix-moretea, bundix, coreutils, jq, curl, nix, git, gawk, gnused }:

let
  # until submodules support gets merged
  bundix_with_submodules = bundix.overrideAttrs (attrs: {
    src = fetchFromGitHub {
      owner = "petabyteboy";
      repo = "bundix";
      rev = "feature/submodules";
      sha256 = "1xih4mz1mwba3vrynmgp6h6xnlddjjdhswx94jqrn438jj757145";
    };
  });

in writeScript "update-mastodon" ''
  PATH=${lib.makeBinPath [nix-prefetch-github yarn2nix-moretea.yarn2nix bundix_with_submodules coreutils jq curl nix git gawk gnused]}

  OWNER="tootsuite"
  REPO="mastodon"

  rm -f gemset.nix yarn.nix version.nix source-unpatched.nix package.json
  TARGET_DIR="$PWD"
  VERSION="$(curl https://api.github.com/repos/$OWNER/$REPO/releases/latest | jq -r .tag_name)"
  echo \"$VERSION\" > version.nix
  # TODO fetch right tag
  nix-prefetch-github tootsuite mastodon --nix > "$TARGET_DIR/source-unpatched.nix"
  SOURCE_DIR="$(nix-build -E '(import <nixpkgs> {}).callPackage ./source-patched.nix {}')"

  # create gemset.nix
  bundix --lockfile="$SOURCE_DIR/Gemfile.lock" --gemfile="$SOURCE_DIR/Gemfile"

  # create yarn.nix
  cd "$SOURCE_DIR"
  yarn2nix > "$TARGET_DIR/yarn.nix"
  sed "s/https___.*_//g" -i "$TARGET_DIR/yarn.nix"

  # create package.json
  cp "$SOURCE_DIR/package.json" "$TARGET_DIR/package.json"
''

