# headscale-apt

[![Release](https://github.com/allddd/headscale-apt/actions/workflows/release.yml/badge.svg)](https://github.com/allddd/headscale-apt/actions/workflows/release.yml)
[![Test](https://github.com/allddd/headscale-apt/actions/workflows/test.yml/badge.svg)](https://github.com/allddd/headscale-apt/actions/workflows/test.yml)

Unofficial [Headscale](https://headscale.net) repository (Debian/Ubuntu) that automatically updates itself when a new release is available.

The automation code and the repository itself are hosted here. The idea is to keep things as simple as possible so that you can do the audit yourself in no time.

## Usage

1. Install dependencies
```sh
sudo apt update && \
sudo apt install -y ca-certificates curl gnupg
```

2. Add repository
```sh
sudo install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://allddd.github.io/headscale-apt/headscale-apt.key | sudo gpg --dearmor -o /etc/apt/keyrings/headscale-apt.gpg && \
sudo chmod 444 /etc/apt/keyrings/headscale-apt.gpg && \
echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/headscale-apt.gpg] https://allddd.github.io/headscale-apt/ stable main' | sudo tee /etc/apt/sources.list.d/headscale-apt.list
```

3. Install `headscale`
```sh
sudo apt update && \
sudo apt install -y headscale
```

4. Configure `unattended-upgrades` (*optional*)
```sh
sudo tee /etc/apt/apt.conf.d/98headscale-apt <<"EOF"
Unattended-Upgrade::Origins-Pattern {
        "origin=allddd.github.io/headscale-apt";
};
EOF
```
