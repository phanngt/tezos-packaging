# SPDX-FileCopyrightText: 2019 TQ Tezos <https://tqtezos.com/>
#
# SPDX-License-Identifier: MPL-2.0
{ pkgs ? import <nixpkgs> { }, timestamp ? "19700101", mainnetInfo ? {
  url = "https://gitlab.com/tezos/tezos.git";
  rev = "94f779a7";
  sha256 = "16lxilng5q8fr2ll6h4hf7wlvac6nmw4cx10cbgzj5ks090bl97r";
}, babylonnetInfo ? {
  url = "https://gitlab.com/tezos/tezos.git";
  rev = "b8731913";
  sha256 = "1pakf1s6bg76fq42mb8fj1immz9g9wwimd522cpx8k28zf0hkl5i";
} }:
with pkgs;

let
  root = ./.;
  mainnet = mainnetInfo // { patchFile = ./nix/fix-mainnet.patch; };
  babylonnet = babylonnetInfo // { patchFile = ./nix/fix-babylonnet.patch; };
  tezos-client-static-mainnet = import ./nix/static.nix mainnet;
  tezos-client-static-babylonnet = import ./nix/static.nix babylonnet;
  binary-mainnet = "${tezos-client-static-mainnet}/bin/tezos-client";
  binary-babylonnet = "${tezos-client-static-babylonnet}/bin/tezos-client";
  packageDesc-mainnet = {
    project = "tezos-client-mainnet";
    version = toString timestamp;
    bin = binary-mainnet;
    arch = "amd64";
    license = "MPL-2.0";
    dependencies = "";
    maintainer = "Serokell https://serokell.io";
    licenseFile = "${root}/LICENSES/MPL-2.0.txt";
    description = "CLI client for interacting with tezos blockchain";
    gitRevision = mainnet.rev;
    branchName = "mainnet";
  };

  packageDesc-babylonnet = packageDesc-mainnet // {
    project = "tezos-client-babylonnet";
    bin = binary-babylonnet;
    gitRevision = babylonnet.rev;
    branchName = "babylonnet";
  };

  buildDeb = import ./packageDeb.nix { inherit stdenv writeTextFile dpkg; };
  buildRpm = packageDesc:
    import ./packageRpm.nix {
      inherit stdenv writeTextFile gnutar rpm buildFHSUserEnv;
    } (packageDesc // { arch = "x86_64"; });

  mainnet-rpm-package = buildRpm packageDesc-mainnet;

  mainnet-deb-package = buildDeb packageDesc-mainnet;

  babylonnet-rpm-package = buildRpm packageDesc-babylonnet;

  babylonnet-deb-package = buildDeb packageDesc-babylonnet;

  tezos-client-mainnet = stdenv.mkDerivation rec {
    name = "tezos-client-mainnet-${mainnet.rev}";
    phases = "copyPhase";
    copyPhase = ''
      mkdir -p $out
      cp ${binary-mainnet} $out/${name}
    '';
  };
  tezos-client-babylonnet = stdenv.mkDerivation rec {
    name = "tezos-client-babylonnet-${babylonnet.rev}";
    phases = "copyPhase";
    copyPhase = ''
      mkdir -p $out
      cp ${binary-babylonnet} $out/${name}
    '';
  };

in rec {
  inherit tezos-client-mainnet tezos-client-babylonnet mainnet-deb-package
    mainnet-rpm-package babylonnet-rpm-package babylonnet-deb-package;
}
