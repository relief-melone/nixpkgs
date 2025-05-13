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
  srcOriginal = fetchFromGitHub {
    owner = "microsoft";
    repo = "vscode-js-debug";
    rev = "v1.100.0";
    sha256 = "sha256-y3N54lOTI9IdRv2WgZd1e7ntUHh/qd9ybIi7Copd/wA=";
  };

  srcPatched = pkgs.stdenv.mkDerivation {
    name = "vscode-js-debug-patched";
    src = fetchFromGitHub {
      owner = "relief-melone";
      repo = "vscode-js-debug-nixpkgs-depencencies";
      rev = "v1.100.0";
      sha256 = "sha256-dxpI+Wkx4cb45PGB1LgfFxJXmnXeRN/GLtUEfxh02TA=";
    };

    installPhase = ''
      mkdir $out
      mkdir $out/src
      cp -r ${srcOriginal}/src $out/src

      cp ./package.json $out/
      cp ./package-lock.json $out/
    '';
  };
  nodePackage = buildNpmPackage (finalAttrs: {
    src = srcPatched;

    pname = "vscode-js-debug";
    version = "v1.100.0";

    npmPackFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmInstallFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];
    npmFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmDepsHash = "sha256-E8R7YjzWTsjGisNQUfahTmw/9M1xVFTsPkc7TpVt8nM=";
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
  inherit nodePackage;
  src = srcPatched;

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
