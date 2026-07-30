#!/bin/bash
# Palworld Server Health Check
# Vérifie que le processus serveur est actif

if pgrep -f "PalServer" > /dev/null 2>&1; then
    echo "Palworld server is healthy"
    exit 0
else
    echo "Palworld server is unhealthy"
    exit 1
fi

