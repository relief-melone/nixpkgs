{
  pkgs,
  nodejs_20,
  buildNpmPackage,
  fetchFromGitHub,
  vimUtils,
  lib,
  system,
  importNpmLock
}:
let

  nodejs = nodejs_20;
  general_patches = {
    "picomatch" = "^4.0.2";
    "vsce" = "2.7.0";
    "merge2" = "1.4.1";
  };

  specific_patches = {
    "x86_64-linux" = {
      "@dprint/linux-x64-glibc" = "0.49.1";
      "@esbuild/linux-x64" = "0.25.3";
    };
    "aarch64-linux" = {
      "@dprint/linux-arm64-glibc" = "0.49.1";
      "@esbuild/linux-arm" = "0.25.3";

    };
    "x86_64-darwin" = {
      "@dprint/darwin-x64" = "0.49.1";
      "@esbuild/darwin-x64" = "0.25.3";
    };
    "aarch64-darwin" = {
      "@dprint/darwin-arm64" = "0.49.1";
      "@esbuild/darwin-arm64" = "0.25.3";
    };
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
    outputHash = "sha256-ciln0SMeHcOWrJwvMhQclp/6W+XIvSFSneLVrE9q2vE=";

    makeCacheWritable = true;

    buildInputs = with pkgs; [ jq nodejs];

    env = {
      npm_config_cache = "$TMPDIR/.npm";
      npm_config_strict_ssl = "false";
    };

    buildPhase = ''
      echo "adding dependencies"
      jq '.dependencies += ${builtins.toJSON (general_patches // specific_patches.${system} )}' package.json > package-temp.json
      mv package-temp.json package.json

      echo "removing scripts"
      jq 'del(.scripts.prepare) | del(.scripts.postinstall)' package.json > package-temp.json
      mv package-temp.json package.json

      npm i --package-lock-only

      cp ./package.json $out/
      cp ./package-lock.json $out/
    '';
  };

  #nodePackage = buildNpmPackage (finalAttrs: {
  #  pname = "vscode-js-debug-npm";
  #  version = "v1.100.0";
  #  src = srcOriginal;

  #  npmPackFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
  #  npmInstallFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];
  #  npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
  #  npmDepsHash = lib.fakeHash;

  #  npmDeps = importNpmLock {
  #    package = lib.importJSON "${patch}/package.json";
  #    packageLock = lib.importJSON "${patch}/package-lock.json";
  #  };

  #  dontNpmBuild = true;
  #  makeCacheWritable = true;

  #  env = {
  #    npm_config_cache= "$HOME/.npm";
  #  };

  #  nativeBuildInputs = with pkgs; [
  #    pkg-config
  #    libsecret
  #    gcc
  #    node-gyp
  #    jq
  #  ];

  #  buildInputs = with pkgs; [
  #    pkg-config
  #    libsecret
  #    gcc
  #    node-gyp
  #    jq
  #  ];

  #  NODE_OPTIONS = "--openssl-legacy-provider";

  #  patchPhase = ''
  #    echo listing patch contents...
  #    ls ${patch}/
  #    echo copying files from patches...
  #    cp ${patch}/package.json ./package.json
  #    cp ${patch}/package-lock.json ./package-lock.json
  #  '';
  #});

  # def = import ./dependencies/default.nix;

  # nodePkgs = def { inherit system nodejs pkgs; };
  # nodeDependencies = ( nodePkgs // { }).nodeDependencies;
  vscode-js-debug = pkgs.vscode-js-debug;
in
vimUtils.buildVimPlugin {
  src = pkgs.vscode-js-debug;

  pname = "vscode-js-debug";
  version = "v1.100.0";

  nativeBuildInputs = [ nodejs ];

  buildPhase = ''
    echo "----nodePackages"
    ls ${vscode-js-debug}/
    echo "----linking nodeModules..."
    ln -s ${vscode-js-debug}/lib/node_modules ./node_modules
    echo "----node_modules contents"
    ls ./node_modules

    echo "setting env_vars..."
    export PATH="${vscode-js-debug}/bin:$PATH"
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
