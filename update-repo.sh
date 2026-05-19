#!/bin/bash
set -e

EMAIL="development@special-delivery.org"
SUITES=(bookworm trixie)
COMPONENT="main"
ARCH="arm64"
ORIGIN="dronerepo"
LABEL="dronerepo"

for SUITE in "${SUITES[@]}"; do
    echo "=== $SUITE ==="

    POOL_DIR="pool/$SUITE/$COMPONENT"
    DIST_DIR="dists/$SUITE"
    BIN_DIR="$DIST_DIR/$COMPONENT/binary-$ARCH"

    mkdir -p "$POOL_DIR" "$BIN_DIR"

    echo "Scanning $POOL_DIR..."
    dpkg-scanpackages --multiversion "$POOL_DIR" > "$BIN_DIR/Packages"
    gzip -k -f "$BIN_DIR/Packages"

    echo "Generating Release..."
    apt-ftparchive \
        -o "APT::FTPArchive::Release::Origin=$ORIGIN" \
        -o "APT::FTPArchive::Release::Label=$LABEL" \
        -o "APT::FTPArchive::Release::Suite=$SUITE" \
        -o "APT::FTPArchive::Release::Codename=$SUITE" \
        -o "APT::FTPArchive::Release::Architectures=$ARCH" \
        -o "APT::FTPArchive::Release::Components=$COMPONENT" \
        release "$DIST_DIR" > "$DIST_DIR/Release"

    echo "Signing Release..."
    rm -f "$DIST_DIR/Release.gpg" "$DIST_DIR/InRelease"
    gpg --default-key "$EMAIL" -abs -o "$DIST_DIR/Release.gpg" "$DIST_DIR/Release"
    gpg --default-key "$EMAIL" --clearsign -o "$DIST_DIR/InRelease" "$DIST_DIR/Release"
done

echo "Ready!"
