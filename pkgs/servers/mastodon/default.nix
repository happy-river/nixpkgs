{ nodejs-slim, yarn2nix-moretea, fetchFromGitHub, bundlerEnv,
  stdenv, yarn, lib, callPackage, ... }:

let
  version = import ./version.nix;
  src = callPackage ./source-patched.nix {};

  mastodon-gems = bundlerEnv {
    name = "mastodon-gems";
    inherit version;
    gemdir = src;
    gemset = ./gemset.nix;
  };

  mastodon-js-modules = yarn2nix-moretea.mkYarnPackage {
    name = "mastodon-modules";
    yarnNix = ./yarn.nix;
    packageJSON = ./package.json;
    inherit src;
    inherit version;
  };

  mastodon-assets = stdenv.mkDerivation {
    pname = "mastodon-assets";
    inherit src version;

    buildInputs = [
      mastodon-gems nodejs-slim yarn
    ];

    buildPhase = ''
      cp -r "${mastodon-js-modules}/libexec/mastodon/node_modules" "node_modules"
      chmod -R u+w node_modules
      rake assets:precompile
    '';

    installPhase = ''
      mkdir -p $out/public
      cp -r public/assets $out/public
      cp -r public/packs $out/public
    '';
  };

in stdenv.mkDerivation {
  pname = "mastodon";
  inherit src version;

  passthru.updateScript = callPackage ./update.nix {};

  buildPhase = ''
    ln -s ${mastodon-js-modules}/libexec/mastodon/node_modules node_modules
    ln -s ${mastodon-assets}/public/assets public/assets
    ln -s ${mastodon-assets}/public/packs public/packs

    for b in $(ls ${mastodon-gems}/bin/)
    do
      rm -f bin/$b
      ln -s ${mastodon-gems}/bin/$b bin/$b
    done

    rm -rf log
    ln -s /var/log/mastodon log
    ln -s /tmp tmp
  '';
  propagatedBuildInputs = [ imagemagick ffmpeg file ];
  installPhase = ''
    mkdir -p $out
    cp -r * $out/
  '';

  meta = {
    description = "Self-hosted, globally interconnected microblogging software based on ActivityPub";
    homepage = https://joinmastodon.org;
    license = lib.licenses.agpl3;
    maintainers = [ lib.maintainers.petabyteboy ];
  };
}
