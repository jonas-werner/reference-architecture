#!/bin/bash

cd /milvus-backup

# Define the GitHub repository
REPO="zilliztech/milvus-backup"

# Define the desired architecture (e.g., Linux_x86_64, Darwin_arm64, etc.)
# Adjust this variable according to your operating system and architecture.
ARCH="Linux_x86_64"

# Get the latest release tag
LATEST_RELEASE_TAG=$(wget -q -O - "https://api.github.com/repos/$REPO/releases/latest" | grep -o '"tag_name": ".*"' | cut -d" " -f 2 | tr -d "\"")
LATEST_RELEASE_VERSION=$(echo $LATEST_RELEASE_TAG | sed 's/v//')

if [ -z "$LATEST_RELEASE_TAG" ]; then
    echo "Error: Could not retrieve the latest release tag."
    exit 1
fi

echo "Latest release tag: $LATEST_RELEASE_TAG"

# Construct the download URL for the tar.gz archive
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$LATEST_RELEASE_TAG/milvus-backup_${LATEST_RELEASE_VERSION}_${ARCH}.tar.gz"

echo "Downloading from: $DOWNLOAD_URL"

# Download the archive
wget -q "$DOWNLOAD_URL" -O "milvus-backup_${ARCH}.tar.gz"

if [ $? -ne 0 ]; then
    echo "Error: Download failed."
    exit 1
fi

echo "Download complete. Extracting..."

# Extract the archive
tar -xzf "milvus-backup_${ARCH}.tar.gz"

if [ $? -ne 0 ]; then
    echo "Error: Extraction failed."
    exit 1
fi

echo "Extraction complete. milvus-backup is now in the current directory."

# Clean up the downloaded archive
rm "milvus-backup_${LATEST_RELEASE_VERSION}_${ARCH}.tar.gz"

echo "Cleaned up downloaded archive."

# Create backup
BKP_TIMESTAMP=$(date "+%Y%m%d%H%M%S")
./milvus-backup create -n "bkp${BKP_TIMESTAMP}"
