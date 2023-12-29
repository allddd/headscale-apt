#!/bin/bash

set -eo pipefail

[[ -n "${GPG_KEY}" ]] || { echo 'GPG_KEY is not defined, exiting...'; exit 1; }
curl='curl -fs --retry 10 --retry-delay 60 --retry-all-errors'

echo 'Looking for a new release...'
RESPONSE=$(${curl} https://api.github.com/repos/juanfont/headscale/releases/latest)
LOCAL_VER=$(cat ./VERSION)
REMOTE_VER=$(jq -er .tag_name <<< "${RESPONSE}")
[[ "${LOCAL_VER}" != "${REMOTE_VER}" ]] || { echo 'No new release, exiting...'; exit; }

echo 'Installing dependencies...'
sudo apt-get update
sudo apt-get install -y reprepro

echo 'Downloading package...'
PKG_URL=$(jq -er '.assets[].browser_download_url | match(".*linux_amd64.deb$").string' <<< "${RESPONSE}")
${curl} -LO "${PKG_URL}"

echo 'Verifying checksum...'
SUM_URL=$(jq -er '.assets[].browser_download_url | match(".*checksums.txt$").string' <<< "${RESPONSE}")
${curl} -L "${SUM_URL}" | sha256sum -c --ignore-missing

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
