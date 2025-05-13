{
  pkgs,
  nodejs_20,
  buildNpmPackage,
  fetchFromGitHub,
  vimUtils,
  system
}:
let

  nodejs = nodejs_20;
  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "vscode-js-debug";
    rev = "v1.100.0";
    sha256 = "sha256-y3N54lOTI9IdRv2WgZd1e7ntUHh/qd9ybIi7Copd/wA=";
  };

  modifiedSrc = pkgs.stdenv.mkDerivation {
    inherit src;
    name = "vscode-js-debug-mod";

    nativeBuildInputs = with pkgs;[
      jq
    ];
    buildPhase = ''
      echo "Running modifications on package.json scripts"
      jq 'del(.scripts.prepare) | del(.scripts.postinstall)' package.json > tmp-package.json
      mv tmp-package.json package.json

      jq '.dependencies += { "merge2": "^1.4.1", "vsce":"^2.7.0", "@dprint/linux-x64-glibc": "^0.49.1", "@esbuild/linux-x64": "0.25.4" }' package.json > tmp-package.json
      mv tmp-package.json package.json

      mkdir $buildPhase
      cp -r ./* $buildPhase/
    '';

    installPhase = ''
      mkdir $out;
      cp -r $buildPhase $out
    '';
  };

  nodePackage = buildNpmPackage (finalAttrs: {
    src = modifiedSrc;

    pname = "vscode-js-debug";
    version = "v1.100.0";

    npmDepsHash = "sha256-4SweyCohiTAMhGFwqmtQtmyic3/34azMTou6vpM2Bqo=";
    npmPackFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmInstallFlags = [ "--legacy-peer-deps" "--omit=dev" "--ignore-scripts" ];
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;
    makeCacheWritable = true;

    nativeBuildInputs = with pkgs; [
      pkg-config
      libsecret
      gcc
      node-gyp
      jq
    ];

    buildInputs = with pkgs; [
      pkg-config
      libsecret
      gcc
      node-gyp
      jq
    ];

    NODE_OPTIONS = "--openssl-legacy-provider";


  });

  # def = import ./dependencies/default.nix;

  # nodePkgs = def { inherit system nodejs pkgs; };
  # nodeDependencies = ( nodePkgs // { }).nodeDependencies;

in
vimUtils.buildVimPlugin {
  inherit src;
  # inherit nodeDependencies;

  pname = "vscode-js-debug";
  version = "v1.100.0";

  nativeBuildInputs = [ nodejs ];

  buildPhase = ''
    ln -s ${nodePackage}/lib/node_modules ./node_modules

    export PATH="${nodePackage}/bin:$PATH"
    export XDG_CACHE_HOME=$(pwd)/node-gyp-cache

    npx gulp dapDebugServer

    mv ./dist out
  '';
}
