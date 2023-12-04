#!/bin/bash

set -eo pipefail

if [[ -z "${GPG_KEY}" || -z "${SSH_KEY}" ]]; then
    echo 'ERROR: GPG/SSH_KEY is not defined.'
    exit 1
fi

echo 'Looking for a new release...'
RESPONSE=$(curl -fs https://api.github.com/repos/juanfont/headscale/releases/latest)
LOCAL_VER=$(cat ./VERSION)
REMOTE_VER=$(echo "${RESPONSE}" | jq -er .tag_name)
if [[ "${LOCAL_VER}" != "${REMOTE_VER}" ]]; then
    echo 'New release available.'
else
    echo 'No new release, exiting...'
    exit
fi

echo 'Downloading package...'
PKG_URL=$(echo "${RESPONSE}" | jq -er '.assets[].browser_download_url | match(".*linux_amd64.deb$").string')
wget -nv "${PKG_URL}"

echo 'Verifying checksum...'
SUM_URL=$(echo "${RESPONSE}" | jq -er '.assets[].browser_download_url | match(".*checksums.txt$").string')
curl -fsL "${SUM_URL}" | sha256sum -c --ignore-missing

echo 'Importing GPG key...'
mkdir -p ~/.gnupg/
echo -n "${GPG_KEY}" | base64 -d > ~/.gnupg/private.key
gpg --import ~/.gnupg/private.key

echo 'Updating repository...'
reprepro -b ./meta includedeb stable ./*.deb
rm -rf ./dists ./pool
mv ./meta/dists ./meta/pool ./
echo -n "${REMOTE_VER}" > ./VERSION

echo 'Pushing changes...'
eval "$(ssh-agent -s)"
echo "${SSH_KEY}" | ssh-add - > /dev/null
mkdir -p ~/.ssh
ssh-keyscan github.com > ~/.ssh/known_hosts
git remote set-url origin 'git@github.com:allddd/headscale-apt.git'
git config --global user.email '117767298+github-actions[bot]@users.noreply.github.com'
git config --global user.name 'github-actions[bot]'
git add dists pool VERSION
git commit -m "${REMOTE_VER}"
git push -u origin main

# vim: ts=4 sw=4 et:
