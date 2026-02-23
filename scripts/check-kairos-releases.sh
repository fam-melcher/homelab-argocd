#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/check-kairos-releases.sh -d <distribution> -a <arch> -k <k8s_dist> [-t <image_type>] [-p <platform>] [-H]

Required:
  -d  Distribution / Quay repo (e.g., ubuntu, alpine, rockylinux)
  -a  Arch (e.g., amd64, arm64)
  -k  Kubernetes distribution (k3s or k0s)

Optional:
  -t  Image type (standard or core)
  -p  Platform/device flavor (e.g., generic, rpi4, nvidia-jetson-agx-orin)
  -H  Human-readable output (default is machine-readable)

Notes:
  - Latest Kairos version is discovered via GitHub redirect:
      https://github.com/kairos-io/kairos/releases/latest
  - Tags ending with .sig or starting with sha256 are ignored.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd curl
need_cmd jq
need_cmd sed

distribution=""
arch=""
k8s_dist=""
image_type=""
platform=""
human=false

while getopts ":d:a:k:t:p:Hh" opt; do
  case "$opt" in
    d) distribution="$OPTARG" ;;
    a) arch="$OPTARG" ;;
    k) k8s_dist="$OPTARG" ;;
    t) image_type="$OPTARG" ;;
    p) platform="$OPTARG" ;;
    H) human=true ;;
    h)
      usage
      exit 0
      ;;
    :) die "option -$OPTARG requires an argument" ;;
    \?) die "unknown option: -$OPTARG" ;;
  esac
done

if [[ -z "$distribution" || -z "$arch" || -z "$k8s_dist" ]]; then
  usage >&2
  exit 2
fi

case "$k8s_dist" in
  k3s|k0s) ;;
  *) die "-k must be one of: k3s, k0s" ;;
esac

if [[ -n "$image_type" ]]; then
  case "$image_type" in
    standard|core) ;;
    *) die "-t must be one of: standard, core" ;;
  esac
fi

# Function to map distribution names (GitHub asset) to Quay repository names
get_quay_repo() {
  case "$1" in
    rocky) printf '%s\n' "rockylinux" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

fetch_latest_kairos_release_tag() {
  local tag
  tag=$(
    curl -fsSLI -o /dev/null -w '%{url_effective}\n' \
      'https://github.com/kairos-io/kairos/releases/latest' \
      | sed 's#.*/##'
  )

  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "unexpected latest release tag from GitHub: $tag"
  fi
  printf '%s\n' "$tag"
}

pick_latest_matching_tag() {
  local quay_repo="$1"
  local kairos_tag="$2"
  local page limit max_pages response picked
  page=1
  limit=100
  max_pages=8

  local ubuntu_lts_only
  ubuntu_lts_only=false
  if [[ "$distribution" == "ubuntu" ]]; then
    ubuntu_lts_only=true
  fi

  while (( page <= max_pages )); do
    response=$(curl -fsSL "https://quay.io/api/v1/repository/kairos/${quay_repo}/tag/?onlyActiveTags=true&page=${page}&limit=${limit}")
    picked=$(jq -r \
      --arg arch "$arch" \
      --arg image_type "$image_type" \
      --arg platform "$platform" \
      --arg k8s_dist "$k8s_dist" \
      --arg kairos_tag "$kairos_tag" \
      --argjson ubuntu_lts_only "$( [[ "$ubuntu_lts_only" == "true" ]] && printf 'true' || printf 'false' )" \
      '
      def os_score($n):
        if ($n | test("^[0-9]+\\.[0-9]+"))
        then ($n
          | capture("^(?<maj>[0-9]+)\\.(?<min>[0-9]+)")
          | ((.maj | tonumber) * 100 + (.min | tonumber)))
        else 0
        end;

      def ubuntu_lts_ok($n):
        if ($n | test("^[0-9]+\\.[0-9]+"))
        then ($n
          | capture("^(?<yy>[0-9]+)\\.(?<mm>[0-9]+)")
          | ((.yy | tonumber) % 2 == 0) and ((.mm | tonumber) == 4))
        else false
        end;

      def ok_name($n):
        ($n | endswith(".sig") | not)
        and ($n | test("^sha256") | not)
        and (if $ubuntu_lts_only then ubuntu_lts_ok($n) else true end)
        and ($n | contains("-" + $arch + "-"))
        and (if $image_type != "" then ($n | contains("-" + $image_type + "-")) else true end)
        and (if $platform != "" then ($n | contains("-" + $arch + "-" + $platform + "-")) else true end)
        and ($n | test("-" + $kairos_tag + "($|-)"))
        and ($n | test("-" + $k8s_dist + "-v[0-9]"));

      [
        .tags[]?
        | select(.name != null)
        | select(ok_name(.name))
        | {name: .name, os: os_score(.name), ts: (.start_ts // 0)}
      ]
      | sort_by([.os, .ts])
      | reverse
      | .[0].name // ""
      ' <<<"$response")

    if [[ -n "$picked" ]]; then
      printf '%s\n' "$picked"
      return 0
    fi

    page=$((page + 1))
  done

  return 1
}

quay_repo=$(get_quay_repo "$distribution")
latest_kairos_tag=$(fetch_latest_kairos_release_tag)

tag=$(pick_latest_matching_tag "$quay_repo" "$latest_kairos_tag" || true)
if [[ -z "$tag" ]]; then
  die "no matching Quay tag found for distro=${distribution} arch=${arch} k8s=${k8s_dist} kairos=${latest_kairos_tag} image_type=${image_type:-any} platform=${platform:-any}"
fi

image="quay.io/kairos/${quay_repo}:${tag}"

if [[ "$human" == "true" ]]; then
  printf 'Kairos (latest): %s\n' "$latest_kairos_tag"
  printf 'Distribution:    %s (repo: %s)\n' "$distribution" "$quay_repo"
  printf 'Arch:            %s\n' "$arch"
  printf 'Kubernetes dist: %s\n' "$k8s_dist"
  if [[ -n "$image_type" ]]; then
    printf 'Image type:      %s\n' "$image_type"
  fi
  if [[ -n "$platform" ]]; then
    printf 'Platform:        %s\n' "$platform"
  fi
  printf 'Image:           %s\n' "$image"
else
  printf 'kairos_version=%s\n' "$latest_kairos_tag"
  printf 'distribution=%s\n' "$distribution"
  printf 'quay_repo=%s\n' "$quay_repo"
  printf 'arch=%s\n' "$arch"
  printf 'k8s_dist=%s\n' "$k8s_dist"
  if [[ -n "$image_type" ]]; then
    printf 'image_type=%s\n' "$image_type"
  fi
  if [[ -n "$platform" ]]; then
    printf 'platform=%s\n' "$platform"
  fi
  printf 'tag=%s\n' "$tag"
  printf 'image=%s\n' "$image"
fi
