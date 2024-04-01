#!/usr/bin/env bash

set -eEo pipefail

CURL='curl -fsS --retry 10 --retry-delay 60 --retry-all-errors'

_release() {
    [[ -n "${GPG_KEY}" ]] || { echo 'ERROR: GPG_KEY variable is not set.'; exit 1; }
    local RESPONSE REMOTE_VER PKG_URL SUM_URL
    
    echo 'INFO: Comparing local and remote releases...'
    RESPONSE=$(${CURL} https://api.github.com/repos/juanfont/headscale/releases/latest)
    REMOTE_VER=$(jq -er .tag_name <<< "${RESPONSE}")
    [[ "$(cat ./VERSION)" != "${REMOTE_VER}" ]] || { echo 'INFO: Newer release not available.'; exit; }
    
    echo 'INFO: Updating APT cache...'
    sudo apt-get update

    echo 'INFO: Installing reprepro...'
    sudo apt-get install -y reprepro
    
    echo 'INFO: Downloading deb package...'
    PKG_URL=$(jq -er '.assets[].browser_download_url | match(".*linux_amd64.deb$").string' <<< "${RESPONSE}")
    ${CURL} -LO "${PKG_URL}"
    
    echo 'INFO: Verifying checksum...'
    SUM_URL=$(jq -er '.assets[].browser_download_url | match(".*checksums.txt$").string' <<< "${RESPONSE}")
    ${CURL} -L "${SUM_URL}" | sha256sum -c --ignore-missing
    
    echo 'INFO: Importing GPG key...'
    base64 -d <<< "${GPG_KEY}" | gpg --import
    
    echo 'INFO: Updating repository...'
    reprepro -b ./meta includedeb stable ./*.deb
    rm -rf ./dists ./pool
    mv ./meta/dists ./meta/pool ./
    echo -n "${REMOTE_VER}" > ./VERSION
    
    echo 'INFO: Pushing changes...'
    git config --global user.email '117767298+github-actions[bot]@users.noreply.github.com'
    git config --global user.name 'github-actions[bot]'
    git add dists pool VERSION
    git commit -m "${REMOTE_VER}"
    git push
}

_test() {
    local KEY_DIR='/etc/apt/keyrings'
    local KEY_NAME='headscale-apt.gpg'
    local REPO_URL='https://allddd.github.io/headscale-apt/'

    echo 'INFO: Creating keyrings directory...'
    sudo install -m 0755 -d ${KEY_DIR}

    echo 'INFO: Obtaining GPG key...'
    ${CURL} ${REPO_URL}${KEY_NAME} | sudo gpg --dearmor -o ${KEY_DIR}/${KEY_NAME}

    echo 'INFO: Fixing permissions...'
    sudo chmod 444 ${KEY_DIR}/${KEY_NAME}

    echo 'INFO: Adding repository...'
    sudo tee /etc/apt/sources.list.d/headscale-apt.list <<< "deb [arch=amd64 signed-by=${KEY_DIR}/${KEY_NAME}] ${REPO_URL} stable main"

    echo 'INFO: Updating APT cache...'
    sudo apt-get update

    echo 'INFO: Installing headscale...'
    sudo apt-get install -y headscale

    echo 'INFO: Comparing versions...'
    [[ "$(sed 's/[^0-9.]*//g' < ./VERSION)" == "$(apt-cache policy headscale | awk '/Installed:/ {print $2}')" ]] || { echo 'ERROR: Version mismatch.'; exit 1; }
}

_main() {
    case ${1} in
        --release)
            echo 'INFO: Initiating _release...'
            _release
            ;;
        --test)
            echo 'INFO: Initiating _test...'
            _test
            ;;
        *)
            echo "ERROR: Option ${1} unrecognized."
            exit 1
            ;;
    esac
}

[[ -n ${1:-} ]] || { echo 'ERROR: No option specified.'; exit 1; }
_main "${@}"

# vim: ts=4 sw=4 et:
