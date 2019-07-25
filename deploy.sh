#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

SOURCE_BRANCH="master"
TARGET_BRANCH="gh-pages"
USERNAME="timothy@minahan.net"

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
#if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
#    echo "Skipping deploy; just doing a build."
#    exit 0
#fi

# Save some useful information
#REPO=`git config remote.origin.url`
#SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
#SHA=`git rev-parse --verify HEAD`

REPO="https://TimothyLuke:$GitHubPagesToken@github.com/TimothyLuke/GnomeSequencer-Enhanced.git"

echo "Using REPO $REPO"
# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deploy)

git config --global user.name "Travis CI"
git config --global user.email $USERNAME
#git config user.password $GitHubPagesToken

git clone $REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
cd ..

# Clean out existing contents
rm -rf out/**/* || exit 0

# Run our compile script
luadoc -d out/docs GSE/API/*.lua

# Now let's go have some fun with the cloned repo
cd out
# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if [ -z "$(git diff --exit-code)" ]; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

git remote rm origin
git remote add origin $REPO

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add -A .
git commit -m "Deploy to GitHub Pages: ${SHA}"

# Now that we're all set up, we can push.
git push $REPO $TARGET_BRANCH
