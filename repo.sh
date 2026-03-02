#!/usr/bin/env bash

set -Eeuxo pipefail

ARCHS=('amd64' 'arm64')
CODENAMES=('stable' 'unstable')
CURL='curl -sS --fail-with-body --retry-all-errors --retry 10 --retry-delay 60'

_release() {
    RESPONSE=$(${CURL} 'https://api.github.com/repos/juanfont/headscale/releases')

    STABLE_LOCAL=$(cat ./STABLE)
    STABLE_REMOTE=$(jq -er '[.[] | select(.prerelease == false)] | sort_by(.published_at | fromdateiso8601) | reverse | .[0].tag_name' <<<"${RESPONSE}")
    UNSTABLE_LOCAL=$(cat ./UNSTABLE)
    UNSTABLE_REMOTE=$(jq -er 'sort_by(.published_at | fromdateiso8601) | reverse | .[0].tag_name' <<<"${RESPONSE}")
    [[ ${STABLE_LOCAL} != "${STABLE_REMOTE}" || ${UNSTABLE_LOCAL} != "${UNSTABLE_REMOTE}" ]] || exit 0

    sudo apt-get update
    sudo apt-get install -y reprepro

    base64 -d <<<"${GPG_KEY}" | gpg --import

    declare -A VERSIONS
    for CODENAME in "${CODENAMES[@]}"; do
        LOCAL_VAR="${CODENAME^^}_LOCAL"
        REMOTE_VAR="${CODENAME^^}_REMOTE"
        [[ ${!LOCAL_VAR} == "${!REMOTE_VAR}" ]] || VERSIONS["${!REMOTE_VAR}"]+="${CODENAME} "
    done

    for VERSION in "${!VERSIONS[@]}"; do
        ${CURL} -LO "$(jq -er --arg v "${VERSION}" '[.[] | select(.tag_name == $v)] | .[0].assets[].browser_download_url | match(".*/checksums.txt$").string' <<<"${RESPONSE}")"

        for ARCH in "${ARCHS[@]}"; do
            ${CURL} -LO "$(jq -er --arg a "${ARCH}" --arg v "${VERSION}" '[.[] | select(.tag_name == $v)] | .[0].assets[].browser_download_url | match(".*linux_" + $a + ".deb$").string' <<<"${RESPONSE}")"
        done

        sha256sum -c --ignore-missing ./checksums.txt

        for CODENAME in ${VERSIONS["${VERSION}"]}; do
            reprepro includedeb "${CODENAME}" ./*.deb

            echo -n "${VERSION}" >"./${CODENAME^^}"
        done

        rm -f ./*.deb
    done

    git config --global user.email '117767298+github-actions[bot]@users.noreply.github.com'
    git config --global user.name 'github-actions[bot]'
    # shellcheck disable=SC2046
    git add ./dists ./pool $(printf "./%s " "${CODENAMES[@]^^}")
    git commit -m "$(for CODENAME in "${CODENAMES[@]}"; do
        REMOTE_VAR="${CODENAME^^}_REMOTE"
        printf "%s=%s " "${CODENAME}" "${!REMOTE_VAR}"
    done)"
    git push
}

_test() {
    KEY_DIR='/etc/apt/keyrings'
    KEY_NAME='headscale-apt.gpg'
    REPO_URL='https://allddd.github.io/headscale-apt/'

    sudo mkdir -p "${KEY_DIR}"

    ${CURL} "${REPO_URL}${KEY_NAME}" | sudo gpg --dearmor -o "${KEY_DIR}/${KEY_NAME}"

    for CODENAME in "${CODENAMES[@]}"; do
        sudo tee /etc/apt/sources.list.d/headscale-apt.list <<<"deb [arch=$(dpkg --print-architecture) signed-by=${KEY_DIR}/${KEY_NAME}] ${REPO_URL} ${CODENAME} main"

        sudo apt-get update
        sudo apt-get install -y headscale

        [[ "$(sed 's/[^0-9.]*//g' <"./${CODENAME^^}")" == "$(apt-cache policy headscale | awk '/Installed:/ {print $2}')" ]] || exit 1

        sudo apt-get purge -y headscale
    done
}

_main() {
    case ${1} in
        -r)
            _release
            ;;
        -t)
            _test
            ;;
        *)
            exit 1
            ;;
    esac
}

[[ ${#} -eq 1 ]] || exit 1
_main "${@}"

# vim: ts=4 sw=4 et:
