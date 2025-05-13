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

  srcMod = fetchFromGitHub {
    owner = "relief-melone";
    repo = "vscode-js-debug-nixpkgs-depencencies";
    rev = "v1.100.0";
    sha256 = "sha256-dxpI+Wkx4cb45PGB1LgfFxJXmnXeRN/GLtUEfxh02TA=";
  };
  nodePackage = buildNpmPackage (finalAttrs: {
    inherit src;

    pname = "vscode-js-debug";
    version = "v1.100.0";

    npmPackFlags = [ "--ignore-scripts" "--legacy-peer-deps" ];
    npmInstallFlags = [ "--legacy-peer-deps" "--omit=dev" "--ignore-scripts" ];
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

    prePatch = ''
      cp ${srcMod}/package.json .
      cp ${srcMod}/package-lock.json .
    '';

    NODE_OPTIONS = "--openssl-legacy-provider";


  });

  # def = import ./dependencies/default.nix;

  # nodePkgs = def { inherit system nodejs pkgs; };
  # nodeDependencies = ( nodePkgs // { }).nodeDependencies;

in
vimUtils.buildVimPlugin {
  inherit src nodePackage;
  # inherit nodeDependencies;

  pname = "vscode-js-debug";
  version = "v1.100.0";

  nativeBuildInputs = [ nodejs ];

  prePatch = ''
    cp ${srcMod}/package.json .
    cp ${srcMod}/package-lock.json .
  '';

  buildPhase = ''
    ln -s ${nodePackage}/lib/node_modules ./node_modules

    export PATH="${nodePackage}/bin:$PATH"
    export XDG_CACHE_HOME=$(pwd)/node-gyp-cache

    npx gulp dapDebugServer

    mv ./dist out
  '';
}
