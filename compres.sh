#!/bin/bash

# Palword Docker Build Archive Creation Script
# Creates a tar archive containing all necessary files for Docker image building
# Validates file presence before creating the archive to ensure build consistency

echo "Creating tar archive for Palword Docker build..."

# Required files list for Docker image creation
# These files must be present in the current directory for a successful build
REQUIRED_FILES=(
    "Dockerfile"                    # Main Docker image definition
    "docker-compose.yml"            # Docker Compose configuration
    "app"                           # Application scripts directory
    "entrypoint.sh"                 # Container startup script
    "healthcheck.sh"                # Health monitoring script
    "config"                        # Configuration files directory
)

echo "Validating required files presence..."
MISSING_FILES=()

# Check each required file/directory exists
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "$file" ]; then
        MISSING_FILES+=("$file")
        echo "❌ Missing: $file"
    else
        echo "✅ Found: $file"
    fi
done

# Exit with error if any required files are missing
if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "❌ Error: Missing required files detected:"
    printf '%s\n' "${MISSING_FILES[@]}"
    exit 1
fi

# Create the tar archive with all required files
echo "Creating palword-image.tar archive..."
tar -cf palword-image.tar "${REQUIRED_FILES[@]}"

# Validate archive creation and display results
if [ $? -eq 0 ]; then
    echo "✅ Archive created successfully!"
    echo "Archive contents:"
    tar -tf palword-image.tar
    echo ""
    echo "Archive size:"
    ls -lh palword-image.tar
else
    echo "❌ Error occurred during archive creation"
    exit 1
fi