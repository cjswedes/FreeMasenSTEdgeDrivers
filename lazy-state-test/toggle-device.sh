#!/bin/bash

# Default values
uuids=""
delay=1

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --uuid)
        uuids="$2"
        shift
        shift
        ;;
        --delay)
        delay="$2"
        shift
        shift
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Check if UUIDs are provided
if [ -z "$uuids" ]; then
    if [ -n "$UUIDS" ]; then
        uuids="$UUIDS"
    else
        echo "Error: UUIDs not provided."
        exit 1
    fi
fi

# Split the comma-separated list of UUIDs into an array
IFS=',' read -r -a uuid_array <<< "$uuids"

while true; do
    for uuid in "${uuid_array[@]}"; do
        # Turn off the switch
        smartthings devices:commands "$uuid" switch:off
        echo "off for $uuid"
    done
    sleep "$delay"
    for uuid in "${uuid_array[@]}"; do
        # Turn on the switch
        smartthings devices:commands "$uuid" switch:on
        echo "on for $uuid"
    done
    sleep "$delay"
done

