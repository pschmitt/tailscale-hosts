# tailscale-hosts

# Requirements

- [bash](https://www.gnu.org/software/bash/)
- [jq](https://stedolan.github.io/jq/)
- [tailscale](https://tailscale.com/download)

# Installation

Just grab `tailscale-hosts.sh`, `chmod +x` it and go.

# Usage

```
tailscale-hosts.sh [--suffix SUFFIX] [-o FILE]
```

# OpenWRT setup

## CronJob

Setup a cronjob to run this periodically:

```shell
# Update tailscale hosts file ever hour
0 * * * * /usr/bin/tailscale-hosts.sh --suffix wg --output /tmp/hosts.tailscale
```

## DNS Setup

Now you can point your DNS server to the new file.

For a Turris Omnia:

```shell
uci add_list resolver.kresd.hostname_config=/tmp/hosts.tailscale
uci commit resolver
/etc/init.d/resolver restart
```

# Similar projects

- https://gitlab.com/jhamberg/tailscale-hosts
