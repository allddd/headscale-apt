#!/usr/bin/env bash

set -Eeuxo pipefail

CURL=(curl -sS --fail-with-body --retry-all-errors --retry 10 --retry-delay 60 --connect-timeout 15)

declare -A CODENAMES
CODENAMES['unstable']='sort_by(.published_at | fromdateiso8601) | reverse | .[0].tag_name'
CODENAMES['stable']='[.[] | select(.prerelease == false)] | '"${CODENAMES['unstable']}"

_release() {
    RESPONSE=$("${CURL[@]}" 'https://api.github.com/repos/juanfont/headscale/releases')

    declare -A LATEST OUTDATED
    for CODENAME in "${!CODENAMES[@]}"; do
        LATEST[${CODENAME}]=$(jq -er "${CODENAMES[${CODENAME}]}" <<<"${RESPONSE}")
        [[ "$(<"./${CODENAME^^}")" == "${LATEST[${CODENAME}]}" ]] || OUTDATED["${LATEST[${CODENAME}]}"]+="${CODENAME} "
    done
    [[ ${!OUTDATED[*]} ]] || exit 0

    sudo apt-get update
    sudo apt-get install -y reprepro

    base64 -d <<<"${GPG_KEY}" | gpg --import

    for VERSION in "${!OUTDATED[@]}"; do
        jq -er --arg v "$VERSION" '.[] | select(.tag_name==$v) | .assets[].browser_download_url | select(endswith("/checksums.txt") or test("linux_(amd64|arm64)\\.deb$"))' <<<"${RESPONSE}" | xargs -r -n1 -P0 "${CURL[@]}" -LO

        sha256sum -c --ignore-missing ./checksums.txt

        for CODENAME in ${OUTDATED["${VERSION}"]}; do
            reprepro includedeb "${CODENAME}" ./*.deb

            printf '%s' "${VERSION}" >"./${CODENAME^^}"
        done

        rm -f ./checksums.txt ./*.deb
    done

    git config --global user.email '117767298+github-actions[bot]@users.noreply.github.com'
    git config --global user.name 'github-actions[bot]'
    # shellcheck disable=SC2046
    git add ./db ./dists ./pool $(for CODENAME in "${!CODENAMES[@]}"; do printf './%s ' "${CODENAME^^}"; done)
    git commit -m "$(for CODENAME in "${!CODENAMES[@]}"; do printf '%s=%s ' "${CODENAME}" "${LATEST[${CODENAME}]}"; done)"
    git push
}

_test() {
    KEY_DIR='/etc/apt/keyrings'
    KEY_NAME='headscale-apt.gpg'
    REPO_URL='https://allddd.github.io/headscale-apt/'

    sudo mkdir -p "${KEY_DIR}"

    "${CURL[@]}" "${REPO_URL}${KEY_NAME}" | sudo gpg --dearmor -o "${KEY_DIR}/${KEY_NAME}"
    sudo chmod 444 "${KEY_DIR}/${KEY_NAME}"

    for CODENAME in "${!CODENAMES[@]}"; do
        sudo tee /etc/apt/sources.list.d/headscale-apt.list <<<"deb [arch=$(dpkg --print-architecture) signed-by=${KEY_DIR}/${KEY_NAME}] ${REPO_URL} ${CODENAME} main"

        sudo apt-get update
        sudo apt-get install -y headscale

        [[ "$(<"./${CODENAME^^}")" == "$(headscale version -o json-line | jq -er '.version')" ]] || exit 1

        sudo apt-get purge -y headscale
    done
}

_main() {
    case "${1}" in
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
