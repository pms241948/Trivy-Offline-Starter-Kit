#!/bin/bash

# =============================================================================
# Script Name: generate_sbom.sh
# Description: Generates SBOM for a specified target using Trivy.
#              - Supports Project/Directory scanning (Service-based SBOM)
#              - Supports Docker Image scanning (.tar, .tar.gz, .tgz)
#              - Supports Single File scanning (.jar, .war, .lock, etc.)
# Usage: ./generate_sbom.sh <TARGET_PATH>
# =============================================================================

# 1. Input Validation
if [ -z "$1" ]; then
  echo "Error: Target path is required."
  echo "Usage: $0 <TARGET_PATH>"
  exit 1
fi

TARGET_INPUT="$1"

# Convert to absolute path
if [[ "$TARGET_INPUT" != /* ]] && [[ "$TARGET_INPUT" != ?:* ]]; then
    TARGET_INPUT="$(pwd)/$TARGET_INPUT"
fi

# 2. Configuration
DATE_STR=$(date +"%Y%m%d")

# Adaptive Output Directory
if [ -d "/app/trivy-sbom" ]; then
    BASE_OUTPUT_DIR="/app/trivy-sbom/output"
else
    BASE_OUTPUT_DIR="$(pwd)/output"
    echo "  [Info] /app/trivy-sbom not found. Using local output: $BASE_OUTPUT_DIR"
fi

TODAY_OUTPUT_DIR="$BASE_OUTPUT_DIR/$DATE_STR"
CACHE_DIR="$(pwd)/trivy-cache"

# Create directories
mkdir -p "$TODAY_OUTPUT_DIR"
mkdir -p "$CACHE_DIR"

# Check Docker
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not accessible."
  exit 1
fi

# =============================================================================
# Function: validate_sbom
# Description: Checks if the generated SBOM contains valid components.
# =============================================================================
validate_sbom() {
    local SB_FILE="$1"
    
    if [ ! -f "$SB_FILE" ]; then
        echo "  [ERROR] SBOM file was not generated."
        return 1
    fi

    # Check for empty components using grep (simple check)
    # Looks for '"components": []' pattern.
    if grep -q '"components": \[\]' "$SB_FILE"; then
        echo "  [WARNING] Generated SBOM is EMPTY (No components found)."
        echo "            Target might not contain supported dependencies or is not a valid project root."
        return 0 # It's technically a success in execution, but semantically empty
    else
        # Basic check passed
        echo "  [SUCCESS] SBOM Generated: $SB_FILE"
        # Count components (rough estimate)
        local COMP_COUNT=$(grep -c '"type":' "$SB_FILE")
        echo "            (Approx. $COMP_COUNT components found)"
        return 0
    fi
}

# =============================================================================
# Function: run_trivy_scan
# Description: Executes Trivy via Docker
# =============================================================================
run_trivy_scan() {
    local TYPE="$1"        # 'filesystem' or 'image'
    local TARGET_PATH="$2" # Path to file or directory on host
    local INPUT_ARG="$3"   # Optional: --input argument for image
    local OUTPUT_FILE="$4"
    
    # Mount logic
    # We mount the directory containing the target to /scan_target
    local MOUNT_DIR=""
    local CONTAINER_TARGET=""
    
    if [ -d "$TARGET_PATH" ]; then
        MOUNT_DIR="$TARGET_PATH"
        CONTAINER_TARGET="/scan_target"
    else
        MOUNT_DIR=$(dirname "$TARGET_PATH")
        local FNAME=$(basename "$TARGET_PATH")
        CONTAINER_TARGET="/scan_target/$FNAME"
    fi

    # Adjust CONTAINER_TARGET if using --input
    local FINAL_ARGS=""
    if [ "$TYPE" == "image" ]; then
        # For image scan with input, we pass --input /scan_target/filename
        # And usually no positional argument is needed for 'image --input'
        # But INPUT_ARG usually contains the flag.
        # We need to ensure correct path mapping.
        
        # If we passed "--input", we reconstruct it for container path
        if [[ "$INPUT_ARG" == --input* ]]; then
             local FNAME=$(basename "$TARGET_PATH")
             FINAL_ARGS="--input /scan_target/$FNAME"
        else
             # Standard image scan (from registry) - not used here but handled
             FINAL_ARGS="$CONTAINER_TARGET"
        fi
    else
        # Filesystem
        FINAL_ARGS="$CONTAINER_TARGET"
    fi

    echo "  -> Running Trivy ($TYPE)..."

    docker run --rm \
      -v "$MOUNT_DIR":/scan_target:ro \
      -v "$TODAY_OUTPUT_DIR":/output \
      -v "$CACHE_DIR":/root/.cache/trivy \
      aquasec/trivy:latest $TYPE \
      --format cyclonedx \
      --offline-scan \
      --skip-db-update \
      --scanners vuln,secret,license \
      --output "/output/$(basename "$OUTPUT_FILE")" \
      $FINAL_ARGS
      
    return $?
}

# =============================================================================
# Main Logic
# =============================================================================

echo "=========================================="
echo "Starting SBOM Generation"
echo "Target: $TARGET_INPUT"
echo "Output: $TODAY_OUTPUT_DIR"
echo "=========================================="

# Case 1: Directory (Project Scan)
if [ -d "$TARGET_INPUT" ]; then
    DIR_NAME=$(basename "$TARGET_INPUT")
    OUTPUT_FILENAME="${DATE_STR}_${DIR_NAME}_Project_SBOM.json"
    OUTPUT_FULLPATH="$TODAY_OUTPUT_DIR/$OUTPUT_FILENAME"

    echo "Mode: Directory Scan (Project-based)"
    echo "  -> Scanning entire directory: $DIR_NAME"
    
    # Directory scan uses 'filesystem' mode
    run_trivy_scan "filesystem" "$TARGET_INPUT" "" "$OUTPUT_FULLPATH"
    RET=$?
    
    if [ $RET -eq 0 ]; then
        validate_sbom "$OUTPUT_FULLPATH"
    else
        echo "  [FAILED] Trivy execution failed (Exit Code: $RET)"
    fi

# Case 2: File (Archive or Single Dependency File)
elif [ -f "$TARGET_INPUT" ]; then
    FILE_NAME=$(basename "$TARGET_INPUT")
    OUTPUT_FILENAME="${DATE_STR}_${FILE_NAME}_SBOM.json"
    OUTPUT_FULLPATH="$TODAY_OUTPUT_DIR/$OUTPUT_FILENAME"
    
    # Check for Docker Archive
    # Extended support: .tar, .tar.gz, .tgz
    IS_ARCHIVE=false
    if [[ "$FILE_NAME" == *.tar ]] || [[ "$FILE_NAME" == *.tar.gz ]] || [[ "$FILE_NAME" == *.tgz ]]; then
        IS_ARCHIVE=true
    fi
    
    ARG_TYPE="filesystem"
    INPUT_ARG=""
    
    if [ "$IS_ARCHIVE" = true ]; then
        # Check Manifest to confirm it's a Docker image
        # Using tar -tf to peek inside.
        # Note: tar -tf works for both tar and tar.gz (modern tar handles compression auto or we might need flags)
        # We try simple tar -tf first (bsdtar/gnu tar usually auto detect). 
        # If strictly gzip needed, one might need -z, but sticking to standard approach.
        
        if tar -tf "$TARGET_INPUT" 2>/dev/null | grep -q "manifest.json"; then
             echo "Mode: Docker Image Scan (Archive Detected)"
             ARG_TYPE="image"
             INPUT_ARG="--input" 
        else
             echo "Mode: Single File Scan (Archive treated as Filesystem)"
             ARG_TYPE="filesystem"
        fi
    else
         echo "Mode: Single File Scan"
         ARG_TYPE="filesystem"
    fi
    
    run_trivy_scan "$ARG_TYPE" "$TARGET_INPUT" "$INPUT_ARG" "$OUTPUT_FULLPATH"
    RET=$?
    
    if [ $RET -eq 0 ]; then
        validate_sbom "$OUTPUT_FULLPATH"
    else
        echo "  [FAILED] Trivy execution failed (Exit Code: $RET)"
    fi

else
    echo "Error: Target '$TARGET_INPUT' is not a valid file or directory."
    exit 1
fi

echo "=========================================="
echo "Completed."
echo "=========================================="
