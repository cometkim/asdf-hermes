#!/usr/bin/env bash

set -eo pipefail

current_script_path=${BASH_SOURCE[0]}
plugin_dir=$(dirname "$(dirname "$current_script_path")")

# shellcheck source=lib/semver.bash
source "${plugin_dir}/lib/semver.bash"

GITHUB_REPO="facebook/hermes"
REPO_URL="https://github.com/$GITHUB_REPO"

curl_opts=(-fsSL)
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

function sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

function list_git_tags() {
  git ls-remote --tags --refs "$REPO_URL" |
    grep -o 'refs/tags/v.*' | cut -d/ -f3- |
    sed 's/^v//'
}

function get_platform() {
  case "$OSTYPE" in
    darwin*) echo -n "darwin" ;;
    linux*) echo -n "linux" ;;
    *) fail "Unsupported platform" ;;
  esac
}

function get_arch() {
  case "$(uname -m)" in
    x86_64) echo -n "amd64" ;;
    arm64) echo -n "arm64" ;;
    *) fail "Unsupported architecture" ;;
  esac
}

function get_archive_name() {
  local platform
  platform=$(get_platform)

  local arch
  arch=$(get_arch)

  if [[ "$platform" = "linux" && "$arch" != "amd64" ]]; then
    fail "Unsupported architecture; Only x86_64 is supported for Linux"
  fi

  if [[ "$platform" = "darwin" && "$arch" != "arm64" ]]; then
    fail "Unsupported architecture; Only ARM is supported for MacOS"
  fi

  echo -n "hermes-cli-$platform"
}

function get_archive_url() {
  local version=$1

  local archive_name
  archive_name=$(get_archive_name)

  if [[ "$version" == "latest" || $(semver_compare "0.13.0" "$version") -ge 0 ]]; then
    echo -n "$REPO_URL/releases/download/v$version/$archive_name.tar.gz"
  else
    echo -n "$REPO_URL/releases/download/v$version/$archive_name-v$version.tar.gz"
  fi
}

function get_source_url() {
  local version=$1

  echo -n "$REPO_URL/archive/v$version.zip"
}

function get_temp_dir() {
  local base
  base="${TMPDIR:-/tmp}"
  base="${base%/}"

  local tmpdir
  tmpdir=$(mktemp -d "$base/asdf-hermes.XXXX")

  echo -n "$tmpdir"
}

function fail() {
  echo -e "\e[31mFail:\e[m $*" 1>&2
  exit 1
}
