#!/bin/bash

# =============================================================================
# Script Name: prepare_offline.sh
# Description: Downloads Docker image and Trivy DBs for offline use.
# Usage: ./prepare_offline.sh
# =============================================================================

# 1. Configuration
TRIVY_IMAGE="aquasec/trivy:latest"
OUTPUT_DIR="trivy_offline_assets"
CACHE_DIR="$(pwd)/trivy-cache"

echo "=========================================="
echo "Starting Offline Assets Preparation"
echo "=========================================="

# Create directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$CACHE_DIR"

# 2. Download Docker Image
echo "[1/4] Pulling Docker Image: $TRIVY_IMAGE..."
docker pull "$TRIVY_IMAGE"

echo "[2/4] Saving Docker Image to tar file..."
docker save -o "$OUTPUT_DIR/trivy_image.tar" "$TRIVY_IMAGE"
echo "  -> Saved to $OUTPUT_DIR/trivy_image.tar"

# 3. Download Trivy Vulnerability DB and Java DB
echo "[3/4] Downloading Trivy Databases..."

# We run a temporary container to download the DBs into our local cache directory.
# The 'image' command triggers the DB download.
# We scan a dummy file (the script itself) to force DB download.

docker run --rm \
  -v "$CACHE_DIR":/root/.cache/trivy \
  -v "$(pwd)":/scan_target \
  "$TRIVY_IMAGE" \
  image --download-db-only

echo "  -> Vulnerability DB downloaded."

docker run --rm \
  -v "$CACHE_DIR":/root/.cache/trivy \
  -v "$(pwd)":/scan_target \
  "$TRIVY_IMAGE" \
  image --download-java-db-only

echo "  -> Java DB downloaded."

# 4. Compress Cache Directory
echo "[4/4] Compressing Trivy Cache..."

# Use tar to compress the cache folder
tar -czf "$OUTPUT_DIR/trivy_cache.tar.gz" -C "$(dirname "$CACHE_DIR")" "$(basename "$CACHE_DIR")"

echo "  -> Compressed to $OUTPUT_DIR/trivy_cache.tar.gz"

echo "=========================================="
echo "Preparation Completed!"
echo "Assets are located in: ./$OUTPUT_DIR"
echo ""
echo "Files to transfer to offline server:"
echo "1. generate_sbom.sh"
echo "2. $OUTPUT_DIR/trivy_image.tar"
echo "3. $OUTPUT_DIR/trivy_cache.tar.gz"
echo "=========================================="
