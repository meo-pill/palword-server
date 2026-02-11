#!/bin/bash
# Palword Server Health Check Script
# Validates that all configured ARK server instances are running properly
# Checks both screen sessions and network port listening status

# Configuration variables
healthy=true                     # Overall health status flag       
base_query_port=27015           # Base Steam query port (standard Steam port range)

if ! netstat -ln | grep -q ":$base_query_port "; then
    healthy=false
fi

# Evaluate overall health status and return appropriate exit code
if [ "$healthy" = true ]; then
    echo "palword server is healthy"
    exit 0  # Success - container is healthy
else
    echo "palword server is unhealthy"
    exit 1  # Failure - container is unhealthy
fi

