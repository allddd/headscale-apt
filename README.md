# headscale-apt

Unofficial [Headscale](https://headscale.net) repository (Debian/Ubuntu) that automatically checks for updates several times a day.

The code and the repository itself are hosted here.
I have tried to keep it as simple as possible so that you can audit it yourself in a short amount of time.

## Install

1. Install dependencies
```sh
sudo apt update && \
sudo apt install -y ca-certificates curl gnupg
```

2. Add `headscale-apt` repository
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
