#!/usr/bin/env bash

# Copyright (c) 2017 The Polymer Project Authors. All rights reserved. This
# code may only be used under the BSD style license found at
# http://polymer.github.io/LICENSE.txt The complete set of authors may be found
# at http://polymer.github.io/AUTHORS.txt The complete set of contributors may
# be found at http://polymer.github.io/CONTRIBUTORS.txt Code distributed by
# Google as part of the polymer project is also subject to an additional IP
# rights grant found at http://polymer.github.io/PATENTS.txt

# This script should typically be run from "npm publish".
#
# Bower installs directly from GitHub using version tags. That means our
# generated files (e.g. compiled TypeScript) needs to be committed somewhere
# for each release. However, we don't want to litter our master branch with
# build artifacts. So we instead use a separate "release" branch.
#
# We also want each commit on the "release" branch to have two parents: 1) the
# previous release, and 2) the "master" branch commit that this release was
# built from. This way our Git history encodes both the chain of releases, and
# the master branch commit corresponding to each release.

set -e
set -x

if [[ -z $npm_package_version ]]; then
  echo "ERROR: Must run as npm script, or define \$npm_package_version."
  exit 64
fi

if ! (git branch | grep --quiet "* master"); then
  echo "ERROR: Must be on master branch."
  exit 64
fi

if [[ -n $(git status --porcelain) ]]; then
  echo "ERROR: Git must be pristine."
  exit 64
fi

echo "Creating $npm_package_version release commit."

# This is our special branch where we commit generated files for Bower.
git checkout release

# Start a merge with "master" so that our commit will have two parents, but
# don't commit yet. Use the "ours" strategy because it can never fail (we don't
# actually care what the result of the merge is, because we're going to clobber
# the index in the next step anyway).
git merge --strategy ours --no-commit master

# Read the master branch directly into the index, clobbering whatever the
# result of the merge was.
git read-tree master

# Copy everything from index to working directory.
# TODO There must be a simpler way to do these last two steps.
git checkout-index --all --force

# Make sure our tests still pass. Note that this also runs build, so our
# generated files will be in the working directory after this.
npm install && npm run build

# Add our generated files to the commit. We need to use --force because these
# files are in our .gitignore.
git add --force global.{js,d.ts}

# Ready to release.
git commit --message "Release $npm_package_version"
tag="v$npm_package_version"
git tag "$tag"
git push
git push origin "$tag"

# read-tree wrote directly to the index, so our working directly still
# corresponds to the merge step, which we don't care about. Clean that up.
git reset --hard
git clean -d --force

git checkout master

echo "Done."
