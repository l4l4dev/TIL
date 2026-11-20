#!/bin/sh
# usage: ./run.sh <server mode> <client mode> [attempts] [Last-Modified age in seconds]
# Starts the server, runs the client against it, then prints how many requests reached the server.
set -eu
cd "$(dirname "$0")"
port=$((20000 + $$ % 10000))
log=$(mktemp)
MODE="$1" AGE_SECONDS="${4:-2592000}" python3 server.py "$port" 2>"$log" &
server=$!
trap 'kill "$server" 2>/dev/null; rm -f "$log"' EXIT
sleep 1
swift client.swift "$port" "$2" "${3:-3}"
echo "server: $(grep -c request "$log") request(s) arrived"
