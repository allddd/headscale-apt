#!/bin/bash

set -eEo pipefail

RESPONSE=$(curl -s https://api.github.com/repos/juanfont/headscale/releases/latest)
LOCAL_VER=$(cat ./VERSION)
REMOTE_VER=$(echo "${RESPONSE}" | jq -er .tag_name)

_check() {
    if [[ "${LOCAL_VER}" != "${REMOTE_VER}" ]]; then
        echo 'Newer version available.'
        exit 1
    else
        echo 'Remote version does not differ from local version.'
    fi
}

_get() {
    local URL
    echo 'Downloading package...'
    URL=$(echo "${RESPONSE}" | jq -er '.assets[].browser_download_url | match(".*linux_amd64.deb$").string')
    wget -nv "${URL}"
}

_verify_hash() {
    local URL
    echo 'Downloading checksums...'
    URL=$(echo "${RESPONSE}" | jq -er '.assets[].browser_download_url | match(".*checksums.txt$").string')
    wget -nv "${URL}"
    echo 'Verifying checksum...'
    grep 'linux_amd64.deb' checksums.txt | sha256sum -c
}

_gpg() {
    if [ -z "${GPG_KEY}" ]; then
        echo 'ERROR: GPG_KEY is not defined.'
        exit 1
    fi
    mkdir -p ~/.gnupg/
    echo -n "${GPG_KEY}" | base64 --decode > ~/.gnupg/private.key
    gpg --import ~/.gnupg/private.key
}

_repo() {
    reprepro --basedir ./meta includedeb stable ./*.deb
    rm -rf ./dists ./pool
    mv ./meta/dists ./meta/pool ./
    echo -n "${REMOTE_VER}" > ./VERSION
}

_push() {
    if [ -z "${SSH_KEY}" ]; then
        echo 'ERROR: SSH_KEY is not defined.'
        exit 1
    fi
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
}

case ${1} in
    --check)
        _check
        ;;
    --get)
        _get
        ;;
    --verify-hash)
        _verify_hash
        ;;
    --gpg)
        _gpg
        ;;
    --repo)
        _repo
        ;;
    --push)
        _push
        ;;
    *)
        exit 1
        ;;
esac

# vim: ts=4 sw=4 et:
