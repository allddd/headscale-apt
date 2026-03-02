# headscale-apt

[![Release](https://github.com/allddd/headscale-apt/actions/workflows/release.yml/badge.svg)](https://github.com/allddd/headscale-apt/actions/workflows/release.yml)
[![Test](https://github.com/allddd/headscale-apt/actions/workflows/test.yml/badge.svg)](https://github.com/allddd/headscale-apt/actions/workflows/test.yml)

Unofficial [Headscale](https://headscale.net) APT (Debian/Ubuntu) repository that automatically updates itself when a new release is available.

To use the repository first install the dependencies:

```sh
sudo apt update && \
sudo apt install -y ca-certificates curl gnupg
```

Then add the repo (by default the command below will configure the `stable` channel):

- `stable`: Only stable releases (e.g. `v0.27.1` -> `v0.28.0`)
- `unstable`: All releases (e.g. `v0.27.1` -> `v0.28.0-alpha.1` -> `v0.28.0-beta.1` -> `v0.28.0-rc.1` -> `v0.28.0`)

```sh
sudo mkdir -p /etc/apt/keyrings && \
curl -fsSL https://allddd.github.io/headscale-apt/headscale-apt.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/headscale-apt.gpg && \
sudo chmod 444 /etc/apt/keyrings/headscale-apt.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/headscale-apt.gpg] https://allddd.github.io/headscale-apt/ stable main" | sudo tee /etc/apt/sources.list.d/headscale-apt.list
```

> [!note]
> To also get alpha, beta and release candidate versions, replace `stable` with `unstable` in `/etc/apt/sources.list.d/headscale-apt.list`.

Finally, install `headscale`:

```sh
sudo apt update && \
sudo apt install -y headscale
```

If you want automatic updates, which is probably not a good idea due to potential breaking changes, configure `unattended-upgrades`:

```sh
sudo tee /etc/apt/apt.conf.d/98headscale-apt <<"EOF"
Unattended-Upgrade::Origins-Pattern {
        "origin=allddd.github.io/headscale-apt";
};
EOF
```
