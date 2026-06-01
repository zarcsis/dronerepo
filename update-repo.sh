#!/bin/bash
set -e

EMAIL="development@special-delivery.org"
SUITES=(bookworm trixie)
COMPONENT="main"
ARCHES=(arm64 armhf)
ORIGIN="dronerepo"
LABEL="dronerepo"
REPO_URL="https://zarcsis.github.io/dronerepo/"

for SUITE in "${SUITES[@]}"; do
    echo "=== $SUITE ==="

    POOL_DIR="pool/$SUITE/$COMPONENT"
    DIST_DIR="dists/$SUITE"

    mkdir -p "$POOL_DIR"

    for ARCH in "${ARCHES[@]}"; do
        BIN_DIR="$DIST_DIR/$COMPONENT/binary-$ARCH"
        mkdir -p "$BIN_DIR"

        echo "Scanning $POOL_DIR for $ARCH..."
        # -a <arch> matches *_<arch>.deb and *_all.deb, so arch-independent
        # packages land in every per-arch index, as a multi-arch repo expects.
        dpkg-scanpackages --multiversion -a "$ARCH" "$POOL_DIR" > "$BIN_DIR/Packages"
        gzip -k -f "$BIN_DIR/Packages"
    done

    echo "Generating Release..."
    apt-ftparchive \
        -o "APT::FTPArchive::Release::Origin=$ORIGIN" \
        -o "APT::FTPArchive::Release::Label=$LABEL" \
        -o "APT::FTPArchive::Release::Suite=$SUITE" \
        -o "APT::FTPArchive::Release::Codename=$SUITE" \
        -o "APT::FTPArchive::Release::Architectures=${ARCHES[*]}" \
        -o "APT::FTPArchive::Release::Components=$COMPONENT" \
        release "$DIST_DIR" > "$DIST_DIR/Release"

    echo "Signing Release..."
    rm -f "$DIST_DIR/Release.gpg" "$DIST_DIR/InRelease"
    gpg --default-key "$EMAIL" -abs -o "$DIST_DIR/Release.gpg" "$DIST_DIR/Release"
    gpg --default-key "$EMAIL" --clearsign -o "$DIST_DIR/InRelease" "$DIST_DIR/Release"
done

echo "Generating index.html..."
{
    cat <<HEADER
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>dronerepo</title>
<style>
  :root {
    --bg: #ffffff;
    --fg: #222222;
    --muted: #888888;
    --border: #eeeeee;
    --rule: #dddddd;
    --code-bg: #f4f4f4;
    --th-bg: #fafafa;
    --link: #0366d6;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0d1117;
      --fg: #e6edf3;
      --muted: #8b949e;
      --border: #21262d;
      --rule: #30363d;
      --code-bg: #161b22;
      --th-bg: #161b22;
      --link: #58a6ff;
    }
  }
  html, body { background: var(--bg); color: var(--fg); }
  body { font-family: system-ui, -apple-system, sans-serif; max-width: 960px; margin: 2em auto; padding: 0 1em; line-height: 1.45; }
  h1 { margin-bottom: 0.1em; }
  h2 { margin-top: 2em; border-bottom: 1px solid var(--rule); padding-bottom: 0.2em; }
  code { background: var(--code-bg); padding: 0.1em 0.35em; border-radius: 3px; font-size: 0.92em; }
  pre { background: var(--code-bg); padding: 0.8em 1em; border-radius: 4px; overflow-x: auto; font-size: 0.9em; }
  table { border-collapse: collapse; width: 100%; margin-top: 0.5em; font-size: 0.93em; }
  th, td { text-align: left; padding: 0.45em 0.7em; border-bottom: 1px solid var(--border); }
  th { background: var(--th-bg); font-weight: 600; }
  td.size { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
  a { color: var(--link); text-decoration: none; }
  a:hover { text-decoration: underline; }
  .empty { color: var(--muted); font-style: italic; }
  .meta { margin-top: 3em; color: var(--muted); font-size: 0.85em; }
</style>
<meta name="color-scheme" content="light dark">
</head>
<body>
<h1>dronerepo</h1>
<p>Debian package repository for <code>bookworm</code> and <code>trixie</code>.</p>

<h2>Setup</h2>
<pre>curl -fsSL ${REPO_URL}repo.key | sudo tee /etc/apt/trusted.gpg.d/dronerepo.asc &gt; /dev/null
echo "deb ${REPO_URL} \$(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/dronerepo.list
sudo apt update</pre>
<p>Signing key: <a href="repo.key">repo.key</a></p>
HEADER

    for SUITE in "${SUITES[@]}"; do
        printf '\n<h2>%s</h2>\n' "$SUITE"
        POOL_DIR="pool/$SUITE/$COMPONENT"
        shopt -s nullglob
        DEBS=("$POOL_DIR"/*.deb)
        shopt -u nullglob
        if [ ${#DEBS[@]} -eq 0 ]; then
            echo '<p class="empty">No packages yet.</p>'
            continue
        fi
        echo '<table>'
        echo '<thead><tr><th>Package</th><th>Version</th><th>Arch</th><th class="size">Size</th><th>Download</th></tr></thead>'
        echo '<tbody>'
        for DEB in "${DEBS[@]}"; do
            BASE=$(basename "$DEB" .deb)
            DEB_ARCH="${BASE##*_}"
            REST="${BASE%_*}"
            VERSION="${REST##*_}"
            NAME="${REST%_*}"
            SIZE_BYTES=$(stat -c %s "$DEB")
            SIZE_HUMAN=$(numfmt --to=iec --suffix=B --format="%.1f" "$SIZE_BYTES")
            printf '<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td class="size">%s</td><td><a href="%s">%s</a></td></tr>\n' \
                "$NAME" "$VERSION" "$DEB_ARCH" "$SIZE_HUMAN" "$DEB" "$(basename "$DEB")"
        done
        echo '</tbody></table>'
    done

    printf '\n<p class="meta">Generated %s</p>\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
    echo '</body></html>'
} > index.html

echo "Ready!"
