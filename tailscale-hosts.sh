#!/usr/bin/env bash

usage() {
  echo "Usage: $(basename "$0") [--suffix SUFFIX] [-o FILE]"
}

get_ts_hosts() {
  # NOTE Here we extract the hostname from the DNS name to avoid having to deal
  # with multi-word hostnames (eg: Xiaomi Mi Mix 2S)
  # Also, we do filter out items that have an empty DNSName which allows us to
  # skip services (eg: hello.ipn.dev)
  tailscale status --json | \
    jq -r '.Self, .Peer[] | select(.DNSName != "") | .TailAddr + " " + .DNSName' | \
    sed -nr 's/^([^ ]+) ([^\.]+)\..*/\1 \2/p'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  set -eu -o pipefail

  # stdout
  DEFAULT_OUTPUT="/proc/self/fd/1"
  # no suffix by default
  DEFAULT_SUFFIX=""

  # Use OUTPUT and SUFFIX env values
  OUTPUT="${OUTPUT:-${DEFAULT_OUTPUT}}"
  SUFFIX="${SUFFIX:-${DEFAULT_SUFFIX}}"

  while [[ -n "$*" ]]
  do
    case "$1" in
      help|h|-h|--help)
        usage
        exit 0
        ;;
      -s|--suffix)
        SUFFIX="$2"
        shift 2
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

  hosts="$(get_ts_hosts)"

  if [[ -z "$hosts" ]]
  then
    echo "Failed to generate tailscale hosts file" >&2
    exit 1
  fi

  {
    if [[ -n "$SUFFIX" ]]
    then
      # shellcheck disable=2001
      sed "s/\$/.${SUFFIX}/g" <<< "$hosts"
    else
      # No suffix
      echo "$hosts"
    fi
  } > "$OUTPUT"

  if [[ "$OUTPUT" != "$DEFAULT_OUTPUT" ]]
  then
    echo "Wrote tailscale hosts file to $OUTPUT" >&2
  fi
fi
