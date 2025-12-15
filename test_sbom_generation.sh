#!/bin/bash

# =============================================================================
# Script Name: test_sbom_generation.sh
# Description: Generates dummy project files (Node, Python, Java) and a Docker image,
#              then runs generate_sbom.sh to verify SBOM generation.
# =============================================================================

TEST_DIR="$(pwd)/test_workspace"
SBOM_SCRIPT="$(pwd)/generate_sbom.sh"
OUTPUT_DIR=""

echo "=========================================="
echo "Starting SBOM Generation Test Suite"
echo "=========================================="

# 1. Setup Test Workspace
echo "[Setup] Creating test workspace at $TEST_DIR..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 2. Key Dummy Files
echo "[Setup] Generating dummy files..."

# Node.js (package-lock.json)
mkdir -p "$TEST_DIR/node_project"
cat <<EOF > "$TEST_DIR/node_project/package.json"
{
  "name": "test-app",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.17.1"
  }
}
EOF
# Simple package-lock.json with one dependency
cat <<EOF > "$TEST_DIR/node_project/package-lock.json"
{
  "name": "test-app",
  "version": "1.0.0",
  "lockfileVersion": 2,
  "requires": true,
  "packages": {
    "": {
      "name": "test-app",
      "version": "1.0.0",
      "dependencies": {
        "express": "^4.17.1"
      }
    },
    "node_modules/express": {
      "version": "4.17.1",
      "resolved": "https://registry.npmjs.org/express/-/express-4.17.1.tgz",
      "integrity": "sha512-mHJ9m793QlTxNHpzhIueDKx+4eGJLq1MGkAXK8gxbMkwgP1nFM9M4NptWbWz1KzYmsT6A9p2jDke82K8tS2rA==",
      "engines": {
        "node": ">= 0.10.0"
      }
    }
  },
  "dependencies": {
    "express": {
      "version": "4.17.1"
    }
  }
}
EOF

# Python (requirements.txt)
mkdir -p "$TEST_DIR/python_project"
echo "requests==2.26.0" > "$TEST_DIR/python_project/requirements.txt"
echo "flask==2.0.1" >> "$TEST_DIR/python_project/requirements.txt"

# Java (pom.xml)
mkdir -p "$TEST_DIR/java_project"
cat <<EOF > "$TEST_DIR/java_project/pom.xml"
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>test-app</artifactId>
  <version>1.0.0</version>
  <dependencies>
    <dependency>
      <groupId>org.springframework</groupId>
      <artifactId>spring-core</artifactId>
      <version>5.3.9</version>
    </dependency>
  </dependencies>
</project>
EOF

# Docker Image (.tar)
# We pull a tiny image (alpine) and save it.
echo "[Setup] Pulling and saving dummy docker image (alpine)..."
docker pull alpine:latest > /dev/null 2>&1
docker save -o "$TEST_DIR/alpine_image.tar" alpine:latest

# 2.5 Docker Image (.tar.gz)
echo "[Setup] Saving docker image as .tar.gz (alpine)..."
# We re-use the image, but gzip it to test detection
gzip -c "$TEST_DIR/alpine_image.tar" > "$TEST_DIR/alpine_image.tar.gz"

# 3. Run Scanning
echo "=========================================="
echo "Running generate_sbom.sh (Project Scan)..."
echo "=========================================="

# Make sure script is executable
chmod +x "$SBOM_SCRIPT"

# Run scan on the test directory (Project Mode)
"$SBOM_SCRIPT" "$TEST_DIR"

# Run scan on specific files (File Mode Test)
echo "------------------------------------------"
echo "Running generate_sbom.sh (Single Image Scan - .tar.gz)..."
"$SBOM_SCRIPT" "$TEST_DIR/alpine_image.tar.gz"

# 4. Verify Results
DATE_STR=$(date +"%Y%m%d")
PROJECT_ROOT="$(pwd)"
# Check if standard local output exists, otherwise check /app/trivy-sbom
if [ -d "$PROJECT_ROOT/output/$DATE_STR" ]; then
    TODAY_OUTPUT_DIR="$PROJECT_ROOT/output/$DATE_STR"
else
    TODAY_OUTPUT_DIR="$PROJECT_ROOT/trivy-sbom/output/$DATE_STR"
fi

echo "=========================================="
echo "Verifying Output Files in $TODAY_OUTPUT_DIR"
echo "=========================================="

check_sbom() {
    local FILE_PATTERN="$1"
    local EXPECTED_NAME="$2"
    
    FOUND_FILE=$(find "$TODAY_OUTPUT_DIR" -name "$FILE_PATTERN" | head -n 1)
    
    if [ -n "$FOUND_FILE" ]; then
        if grep -q "CycloneDX" "$FOUND_FILE"; then
            echo "[PASS] $EXPECTED_NAME: Found and valid."
        else
            echo "[FAIL] $EXPECTED_NAME: Found but invalid content."
        fi
    else
        echo "[FAIL] $EXPECTED_NAME: NOT Found."
    fi
}

# 1. Check Project SBOM (Directory Scan)
# Expect: YYYYMMDD_test_workspace_Project_SBOM.json
check_sbom "*test_workspace_Project_SBOM.json" "Project SBOM (Directory Scan)"

# 2. Check Single File Scan (.tar.gz)
check_sbom "*alpine_image.tar.gz_SBOM.json" "Docker Image (.tar.gz)"

echo "=========================================="
echo "Test Completed."
echo "=========================================="
