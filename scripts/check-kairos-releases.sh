#!/bin/bash
#
# Check Kairos releases from Quay.io - categorized by distribution/variant/arch
# Usage: ./check-kairos-releases.sh
#

# Get asset names from latest GitHub release and extract unique distributions
distributions=$(curl -sS 'https://api.github.com/repos/kairos-io/kairos/releases' | \
  jq -r '.[0].assets[] | select(.name | endswith(".iso")) | .name' | \
  sed 's/kairos-//; s/\.iso$//' | \
  sed 's/-.*$//' | \
  sort -u)

echo "Kairos Releases from Quay.io"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to map distribution names (GitHub asset) to Quay repository names
get_quay_repo() {
  case "$1" in
    rocky) echo "rockylinux" ;;
    *) echo "$1" ;;
  esac
}

# For each distribution, fetch tags from Quay.io
for distro in $distributions; do
  # Map distribution name to Quay repository name
  quay_repo=$(get_quay_repo "$distro")

  response=$(curl -sS "https://quay.io/api/v1/repository/kairos/$quay_repo/tag/?onlyActiveTags=true")

  # Check if repository exists (has 'tags' key) before processing
  if echo "$response" | jq -e '.tags' > /dev/null 2>&1; then
    tags=$(echo "$response" | jq -r '.tags[] | select(.name | endswith(".sig") | not) | .name' | sort)
  else
    tags=""
  fi

  if [ -z "$tags" ]; then
    echo "Distribution:  $distro [no tags found]"
    continue
  fi

  # Display each tag
  first=true
  while IFS= read -r tag; do
    if $first; then
      echo "Distribution:  $distro"
      first=false
    fi

    # Parse tag format examples:
    # 24.04-standard-amd64-generic-v3.7.2-k3s-v1.33.7-k3s3
    # 24.04-core-amd64-generic-v3.7.2
    # 22.04-standard-arm64-rpi4-v3.7.2-k3s-v1.35.0-k3s3
    # 22.04-core-arm64-nvidia-jetson-agx-orin-v3.7.2

    # Extract version: first digits.digits
    version=$(echo "$tag" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')

    # Extract variant: between version and arch or device (core/standard)
    variant=$(echo "$tag" | sed -E 's/^[^-]*-([^-]*).*/\1/')

    # Extract arch: amd64, arm64, etc - find first occurrence after variant
    arch=$(echo "$tag" | sed -E 's/^[^-]*-[^-]*-([^-]*).*/\1/')

    # Extract Kairos version (only for standard/with k8s - look for vX.Y.Z before -k[03]s)
    kairos_ver=$(echo "$tag" | sed -n 's/.*-\(v[0-9.]*\)-k[03]s-.*/\1/p')

    # Extract K8s version (k3s-vX.Y.Z-k3sN or k0s-vX.Y.Z-k0sN)
    k8s_ver=$(echo "$tag" | sed -n 's/.*-\(k[03]s-v[0-9.]*-k[03]s[0-9.]*\).*/\1/p')

    # Display
    echo "  $version ($variant, $arch)"
    if [ -n "$kairos_ver" ]; then
      echo "    Kairos:      $kairos_ver"
      echo "    Kubernetes:  $k8s_ver"
    fi
    echo "    Quay URL:    quay.io/kairos/$quay_repo:$tag"
    echo ""
  done <<< "$tags"
done
