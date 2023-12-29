#!/bin/bash

set -eo pipefail

if [[ -z "${GPG_KEY}" ]]; then
    echo 'ERROR: GPG_KEY is not defined.'
    exit 1
fi

echo 'Looking for a new release...'
RESPONSE=$(curl -fs https://api.github.com/repos/juanfont/headscale/releases/latest)
LOCAL_VER=$(cat ./VERSION)
REMOTE_VER=$(jq -er .tag_name <<< "${RESPONSE}")
if [[ "${LOCAL_VER}" != "${REMOTE_VER}" ]]; then
    echo 'New release available.'
else
    echo 'No new release, exiting...'
    exit
fi

echo 'Installing dependencies...'
sudo apt-get update
sudo apt-get install -y reprepro

echo 'Downloading package...'
PKG_URL=$(jq -er '.assets[].browser_download_url | match(".*linux_amd64.deb$").string' <<< "${RESPONSE}")
wget -nv "${PKG_URL}"

echo 'Verifying checksum...'
SUM_URL=$(jq -er '.assets[].browser_download_url | match(".*checksums.txt$").string' <<< "${RESPONSE}")
curl -fsL "${SUM_URL}" | sha256sum -c --ignore-missing

echo 'Importing GPG key...'
mkdir -p ~/.gnupg/
base64 -d <<< "${GPG_KEY}" > ~/.gnupg/private.key
gpg --import ~/.gnupg/private.key

echo 'Updating repository...'
reprepro -b ./meta includedeb stable ./*.deb
rm -rf ./dists ./pool
mv ./meta/dists ./meta/pool ./
echo -n "${REMOTE_VER}" > ./VERSION

echo 'Pushing changes...'
git config --global user.email '117767298+github-actions[bot]@users.noreply.github.com'
git config --global user.name 'github-actions[bot]'
git add dists pool VERSION
git commit -m "${REMOTE_VER}"
git push

# vim: ts=4 sw=4 et:
