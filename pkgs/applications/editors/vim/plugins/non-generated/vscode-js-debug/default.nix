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
  currentSystem = builtins.currentSystem;
  package_patch = {
    "picomatch" = "^4.0.2";
    "vsce" = "2.7.0";
    "merge2" = "1.4.1";
    "@esbuild/linux-x64" = "0.25.3";
    "@dprint/linux-x64-glibc" = "0.49.1";
  };

  specific_patches = {
    "x86_64-linux" = {
      "@esbuild/linux-x64" = "0.25.3";
      "@dprint/linux-x64-glibc" = "0.49.1";
    };
    "aarch64-linux" = {

    };
    x86
  };

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
    outputHash = lib.fakeSha256;

    makeCacheWritable = true;

    buildInputs = with pkgs; [ jq nodejs];

    env = {
      npm_config_cache = "$TMPDIR/.npm";
      npm_config_strict_ssl = "false";
    };

    buildPhase = ''
      echo "adding dependencies"
      jq '.dependencies += ${builtins.toJSON (package_patch // specific_patches.${currentSystem} )}' package.json > package-temp.json
      mv package-temp.json package.json

      echo "removing scripts"
      jq 'del(.scripts.prepare) | del(.scripts.postinstall)' package.json > package-temp.json
      mv package-temp.json package.json

      cat package.json
      npm i --package-lock-only

      ls
      cat package-lock.json

      mkdir $out
      cp ./package.json $out/
      cp ./package-lock.json $out/
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
    '';

    patchPhase = ''
      echo copiing patch...
      cp -r ${patch}/* ./
    '';

    installPhase = ''
      mkdir $out
      ls
      cat ./package.json

      echo "package-lock.json"
      cat ./package-lock.json

      cp ./package.json $out/
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
    echo "----nodePackages"
    ls ${nodePackage}/
    echo "----linking nodeModules..."
    ln -s ${nodePackage}/lib/node_modules ./node_modules
    echo "----node_modules contents"
    ls ./node_modules

    echo "setting env_vars..."
    export PATH="${nodePackage}/bin:$PATH"
    export XDG_CACHE_HOME=$(pwd)/node-gyp-cache

    echo "----package.json"
    cat ./package.json
    echo "----package-lock.json"
    cat ./package-lock.json

    echo "building dapDebugServer..."
    npx gulp dapDebugServer -- --verbose

    echo "copying dist to out..."
    mv ./dist out
  '';
}
