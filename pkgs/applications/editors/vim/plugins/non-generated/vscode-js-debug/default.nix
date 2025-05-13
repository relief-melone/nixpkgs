{
  pkgs,
  nodejs_20,
  buildNpmPackage,
  fetchFromGitHub,
  vimUtils,
  lib,
  system
}:
let

  nodejs = nodejs_20;

  src = pkgs.stdenv.mkDerivation {
    name = "vscode-js-debug-patched";
    src = fetchFromGitHub {
      owner = "microsoft";
      repo = "vscode-js-debug";
      rev = "v1.100.0";
      sha256 = "sha256-y3N54lOTI9IdRv2WgZd1e7ntUHh/qd9ybIi7Copd/wA=";
    };

    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = lib.fakeSha256;

    buildInputs = with pkgs; [ jq nodejs];

    buildPhase = ''
      echo "adding dependencies"
      jq '.dependencies += { "picomatch": "^4.0.2", "@esbuild/linux-x64-glibc": "^0.49.1" }' package.json > package-temp.json
      mv package-temp.json package.json

      echo "removing scripts"
      jq 'del(.scripts.prepare) | del(.scripts.postinstall)' package.json > package-temp.json
      mv package-temp.json package.json

      cat package.json
      npm i --package-lock-only
    '';
  };

  nodePackage = buildNpmPackage (finalAttrs: {
    inherit src;

    pname = "vscode-js-debug";
    version = "v1.100.0";

    npmPackFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmInstallFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];
    npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
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

    postInstall = ''
      echo "Folder contents"
      ls

      echo "node_modules content"
      ls node_modules
    '';


  });

  # def = import ./dependencies/default.nix;

  # nodePkgs = def { inherit system nodejs pkgs; };
  # nodeDependencies = ( nodePkgs // { }).nodeDependencies;

in
vimUtils.buildVimPlugin {
  inherit nodePackage;

  src = nodePackage;

  pname = "vscode-js-debug";
  version = "v1.100.0";

  nativeBuildInputs = [ nodejs ];

  buildPhase = ''
    ln -s ${nodePackage}/lib/node_modules ./node_modules

    export PATH="${nodePackage}/bin:$PATH"
    export XDG_CACHE_HOME=$(pwd)/node-gyp-cache

    ls ./node_modules
    cat ./package.json

    npx gulp dapDebugServer

    mv ./dist out
  '';
}
