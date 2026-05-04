#!/bin/bash
set -e

EMAIL="development@special-delivery.org"

echo "Creating Packages..."
dpkg-scanpackages --multiversion . > Packages
gzip -k -f Packages

echo "Creating Release..."
apt-ftparchive release . > Release

echo "Signing Release file..."
rm -f Release.gpg InRelease

gpg --default-key "$EMAIL" -abs -o Release.gpg Release
gpg --default-key "$EMAIL" --clearsign -o InRelease Release

echo "Ready!"
