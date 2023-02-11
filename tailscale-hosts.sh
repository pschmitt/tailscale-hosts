#!/usr/bin/env bash

usage() {
  echo "Usage: $(basename "$0") [--cron] [--suffix SUFFIX] [--include-default-suffix] [-o FILE]"
}

echo_info() {
  if [[ -n "$CRON" ]]
  then
    return 0
  fi

  echo "🔵 $*" >&2
}

echo_success() {
  if [[ -n "$CRON" ]]
  then
    return 0
  fi

  echo "🟢 $*" >&2
}

echo_error() {
  # always write error messages to stderr, even when CRON is defined
  echo "🔴 $*" >&2
}

is_openwrt() {
  local ID
  eval "$(grep -m 1 '^ID=' /etc/os-release)"

  case "$ID" in
    openwrt*|turris*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

get_ts_hosts() {
  # NOTE Here we extract the hostname from the DNS name to avoid having to deal
  # with multi-word hostnames (eg: Xiaomi Mi Mix 2S)
  # Also, we do filter out items that have an empty DNSName which allows us to
  # skip services (eg: hello.ipn.dev)
  tailscale status --json | \
    jq -r '[.Self, .Peer[]] |
           sort_by(.DNSName)[] |
           select(.DNSName != "") |
           .TailscaleIPs[0] + " " + ((.DNSName | split("."))[0])'
}

get_ts_net() {
   tailscale status --json | jq -er '.MagicDNSSuffix'
}

generate_hosts_file() {
  local suffix="$1"
  local hosts
  hosts="$(get_ts_hosts)"

  if [[ -z "$hosts" ]]
  then
    echo_error "Failed to generate tailscale hosts file"
    return 1
  fi

  if [[ -n "$suffix" ]]
  then
    # shellcheck disable=2001
    sed "s/\$/.${suffix}/g" <<< "$hosts"
  else
    # No suffix
    echo "$hosts"
  fi
}

restart_resolver_service() {
  if is_openwrt
  then
    echo_info " OpenWRT detected. Restarting resolver service"
    /etc/init.d/resolver restart
  else
    echo_error "Unknown OS. I don't know how to restart the resolver service"
    return 7
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  set -eu -o pipefail

  # stdout
  DEFAULT_OUTPUT="/proc/self/fd/1"
  # no suffix by default
  DEFAULT_SUFFIX="$(get_ts_net)"

  # Initialize vars with env var values
  OUTPUT="${OUTPUT:-${DEFAULT_OUTPUT}}"
  SUFFIX="${SUFFIX:-${DEFAULT_SUFFIX}}"
  CRON="${CRON:-}"
  INCLUDE_DEFAULT_SUFFIX="${INCLUDE_DEFAULT_SUFFIX:-}"
  RESTART_RESOLVER="${RESTART_RESOLVER:-}"

  while [[ -n "$*" ]]
  do
    case "$1" in
      help|h|-h|--help)
        usage
        exit 0
        ;;
      -c|--cron)
        CRON=1
        shift
        ;;
      -r|--restart|--restart-resolver)
        RESTART_RESOLVER=1
        shift
        ;;
      -s|--suffix)
        SUFFIX="$2"
        shift 2
        ;;
      -t|--tailscale-suffix|--default-suffix|--include-default-suffix|--both)
        INCLUDE_DEFAULT_SUFFIX=1
        shift
        ;;
      -o|--output)
        OUTPUT="$2"
        shift 2
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
  done

  NEW_HOSTS=$({
    if [[ -n "$INCLUDE_DEFAULT_SUFFIX" ]] && \
       [[ "$SUFFIX" != "$DEFAULT_SUFFIX" ]]
    then
      generate_hosts_file "$DEFAULT_SUFFIX"
    fi

    generate_hosts_file "$SUFFIX"
  })

  # Check if we are writing to stdout (DEFAULT_OUTPUT)
  if [[ "$OUTPUT" == "$DEFAULT_OUTPUT" ]]
  then
    echo "$HOSTS_FILE" > "$DEFAULT_OUTPUT"
    exit 0
  fi

  # Check if file has changed
  if diff "$OUTPUT" - <<< "$NEW_HOSTS"
  then
    echo_success "Hosts file did not change"
    exit 0
  fi

  # Write file
  echo "$NEW_HOSTS" > "$OUTPUT"
  echo_info "✏️ Wrote tailscale hosts file to $OUTPUT"

  if [[ -n "$RESTART_RESOLVER" ]]
  then
    restart_resolver_service
  else
    exit 0
  fi
fi
