#!/usr/bin/env bash
# Installs the slipway CLI and follow-run plugin from public GitHub releases.
# Called by action.yml; reads its inputs from INPUT_* environment variables.
set -euo pipefail

trap 'echo "::endgroup::"' ERR

repo="${INPUT_REPO:-dpc-sdp/slipway-cli}"
requested_version="${INPUT_VERSION:-latest}"
api_base_url="${INPUT_API_BASE_URL:-}"

if [[ -z "$api_base_url" ]]; then
  echo "::error::api-base-url input is required."
  exit 1
fi

if [[ -n "${INPUT_GITHUB_TOKEN:-}" ]]; then
  echo "::warning::The github-token input is deprecated and ignored. Slipway CLI releases are public."
fi

fetch() {
  curl --fail --silent --show-error --location \
    --retry 3 --connect-timeout 10 "$@"
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

echo "::group::Detect runner platform"
os_raw="${RUNNER_OS:-}"
arch_raw="${RUNNER_ARCH:-}"
case "$os_raw" in
  Linux) os_name="linux" ;;
  macOS) os_name="darwin" ;;
  *)
    echo "::error::Unsupported runner OS: $os_raw (slipway-cli ships Linux and Darwin only)"
    exit 1
    ;;
esac
case "$arch_raw" in
  X64) arch_name="amd64" ;;
  ARM64) arch_name="arm64" ;;
  *)
    echo "::error::Unsupported runner arch: $arch_raw"
    exit 1
    ;;
esac
echo "Runner: ${os_name}/${arch_name}"
echo "::endgroup::"

echo "::group::Resolve release tag (${requested_version})"
if [[ "$requested_version" == "latest" ]]; then
  # /releases/latest redirects to /releases/tag/<tag>. This avoids the GitHub
  # API, so there is no token or API rate limit involved.
  latest_url="$(fetch --output /dev/null --write-out '%{url_effective}' "https://github.com/${repo}/releases/latest")"
  tag="${latest_url##*/}"
else
  tag="v${requested_version#v}"
fi
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "::error::Could not resolve a release for version '${requested_version}' on ${repo}."
  exit 1
fi
echo "Resolved tag: ${tag}"
echo "::endgroup::"

slipway_asset="slipway-cli_${tag#v}_${os_name}_${arch_name}.tar.gz"
download_base="https://github.com/${repo}/releases/download/${tag}"
workdir="${RUNNER_TEMP:-/tmp}/setup-slipway-${tag}-${os_name}-${arch_name}"
bindir="${workdir}/bin"
mkdir -p "$workdir" "$bindir"

echo "::group::Download ${slipway_asset}"
if ! fetch --output "${workdir}/${slipway_asset}" "${download_base}/${slipway_asset}"; then
  echo "::error::Could not download ${slipway_asset} from release ${tag} on ${repo}."
  exit 1
fi
fetch --output "${workdir}/checksums.txt" "${download_base}/checksums.txt"
expected_sha="$(awk -v name="$slipway_asset" '$2 == name { print $1 }' "${workdir}/checksums.txt")"
if [[ -z "$expected_sha" ]]; then
  echo "::error::checksums.txt in release ${tag} has no entry for ${slipway_asset}."
  exit 1
fi
actual_sha="$(sha256 "${workdir}/${slipway_asset}")"
if [[ "$actual_sha" != "$expected_sha" ]]; then
  echo "::error::Checksum mismatch for ${slipway_asset}: expected ${expected_sha}, got ${actual_sha}."
  exit 1
fi
echo "Checksum OK: ${actual_sha}"
echo "::endgroup::"

echo "::group::Extract slipway binaries"
rm -rf "${workdir}/extract"
mkdir -p "${workdir}/extract"
tar -xzf "${workdir}/${slipway_asset}" -C "${workdir}/extract"
slipway_found="$(find "${workdir}/extract" -type f -name slipway -print -quit)"
plugin_found="$(find "${workdir}/extract" -type f -name slipway-plugin-follow-run -print -quit)"
if [[ -z "$slipway_found" ]]; then
  echo "::error::Could not find extracted slipway binary"
  exit 1
fi
if [[ -z "$plugin_found" ]]; then
  echo "::error::Could not find extracted slipway-plugin-follow-run plugin"
  exit 1
fi
cp "$slipway_found" "${bindir}/slipway"
cp "$plugin_found" "${bindir}/slipway-plugin-follow-run"
chmod +x "${bindir}/slipway" "${bindir}/slipway-plugin-follow-run"
"${bindir}/slipway" --version || true
echo "::endgroup::"

echo "::group::Install follow-run plugin"
"${bindir}/slipway" support plugin install "${bindir}/slipway-plugin-follow-run" --yes
"${bindir}/slipway" support plugin list
echo "::endgroup::"

echo "::group::Configure environment"
echo "$bindir" >>"$GITHUB_PATH"
{
  echo "SLIPWAY_BASE_URL=${api_base_url}"
  echo "RSH_PROFILE=gha"
} >>"$GITHUB_ENV"
echo "version=${tag}" >>"$GITHUB_OUTPUT"
echo "PATH      += ${bindir}"
echo "SLIPWAY_BASE_URL = ${api_base_url}"
echo "RSH_PROFILE      = gha"
echo "::endgroup::"

echo "::notice title=slipway installed::${tag} (${os_name}/${arch_name}) — follow-run plugin installed, profile=gha, base=${api_base_url}"
