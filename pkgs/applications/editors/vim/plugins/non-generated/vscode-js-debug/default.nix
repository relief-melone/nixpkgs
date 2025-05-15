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

  srcOriginal = fetchFromGitHub {
    owner = "microsoft";
    repo = "vscode-js-debug";
    rev = "v1.100.0";
    sha256 = "sha256-y3N54lOTI9IdRv2WgZd1e7ntUHh/qd9ybIi7Copd/wA=";
  };


  patch = pkgs.stdenv.mkDerivation {
    name = "vscode-js-debug-patched";
    src = srcOriginal;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-SWTb483xxqowqgmuO5RzKTcfaF3wI15kIvAFN0CrSH8=";
    makeCacheWritable = true;

    buildInputs = with pkgs; [ jq nodejs];

    buildPhase = ''
      export npm_config_strict_ssl="false"
      export npm_config_cache=$TMPDIR/.npm

      echo "adding dependencies"
      jq '.dependencies += {
        "picomatch": "^4.0.2",
        "@esbuild/linux-x64": "0.25.3",
        "@dprint/linux-x64-glibc": "0.49.1",
        "vsce": "2.7.0",
        "merge2": "1.4.1"
      }' package.json > package-temp.json
      mv package-temp.json package.json

      echo "removing scripts"
      jq 'del(.scripts.prepare) | del(.scripts.postinstall)' package.json > package-temp.json
      mv package-temp.json package.json

      cat package.json

      npm i --package-lock-only

      mkdir $out
      cp -r ./package.json ./package-lock.json $out/
    '';
  };

  nodePackage = buildNpmPackage (finalAttrs: {
    pname = "vscode-js-debug-npm";
    version = "v1.100.0";
    src = srcOriginal;

    npmPackFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmInstallFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];
    npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmDepsHash = "sha256-4SweyCohiTAMhGFwqmtQtmyic3/34azMTou6vpM2Bqo=";

    dontNpmBuild = true;
    makeCacheWritable = true;

    env = {
      npm_config_cache= "$TMPDIR/.npm";
    };

    buildPhase = ''
      echo EXITING before install
      echo "environment"
      env

      echo "package.json"
      cat ./package.json

      echo exiting to stop
      exit 1
    '';

    patchPhase = ''
      echo copig patch...
      cp -r ${patch}/* ./
    '';

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
    ls ${nodePackage}/
    ln -s ${nodePackage}/lib/node_modules ./node_modules

    export PATH="${nodePackage}/bin:$PATH"
    export XDG_CACHE_HOME=$(pwd)/node-gyp-cache

    ls ./node_modules
    cat ./package.json

    npx gulp dapDebugServer

    mv ./dist out
  '';
}
