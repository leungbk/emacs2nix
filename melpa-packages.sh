#!/usr/bin/env nix-shell
#!nix-shell -i bash -p haskellPackages.cabal-install nix-prefetch-scripts git subversion cvs mercurial bazaar darcs fossil

# usage: ./melpa-packages.sh PATH_TO_MELPA_CLONE

nix-shell -A env --run "cabal run melpa2nix -- -o melpa-packages.json --work /tmp/melpa2nix --melpa $1"