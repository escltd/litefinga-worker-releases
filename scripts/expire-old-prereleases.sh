#!/usr/bin/env bash
# Delete aged GitHub pre-releases (and their tags), and optionally prune all
# releases down to the newest KEEP_LAST_N.
#
# Requires: gh, jq, GH_TOKEN or GITHUB_TOKEN, GITHUB_REPOSITORY (owner/repo).
#
# Env:
#   RETENTION_DAYS  Delete pre-releases older than this many days (default: 3).
#   KEEP_LAST_N     If >0, also delete releases beyond the newest N (default: 0 = skip).
#                   Skips drafts, the release marked Latest, and tags referenced by
#                   manifest.json / manifest-prerelease.json when those files exist.
set -euo pipefail

RETENTION_DAYS="${RETENTION_DAYS:-3}"
KEEP_LAST_N="${KEEP_LAST_N:-0}"
REPO="${GITHUB_REPOSITORY:-}"

if [[ -z "${REPO}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "${GH_TOKEN}" ]]; then
  echo "GH_TOKEN or GITHUB_TOKEN is required" >&2
  exit 1
fi

if ! [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
  echo "RETENTION_DAYS must be a non-negative integer (got: ${RETENTION_DAYS})" >&2
  exit 1
fi
if ! [[ "${KEEP_LAST_N}" =~ ^[0-9]+$ ]]; then
  echo "KEEP_LAST_N must be a non-negative integer (got: ${KEEP_LAST_N})" >&2
  exit 1
fi

declare -A PROTECTED=()

protect_tag() {
  local tag="${1:-}"
  if [[ -n "${tag}" && "${tag}" != "null" ]]; then
    PROTECTED["${tag}"]=1
  fi
}

if [[ -f manifest.json ]]; then
  protect_tag "$(jq -r '.version // empty' manifest.json)"
fi
if [[ -f manifest-prerelease.json ]]; then
  protect_tag "$(jq -r '.version // empty' manifest-prerelease.json)"
fi

is_protected() {
  local tag="$1"
  [[ -n "${PROTECTED[${tag}]:-}" ]]
}

delete_release() {
  local tag="$1"
  local reason="$2"
  if is_protected "${tag}"; then
    echo "Skipping protected tag ${tag} (${reason})"
    return 0
  fi
  echo "Deleting ${tag} (${reason})"
  gh release delete "${tag}" -R "${REPO}" --yes --cleanup-tag
}

# createdAt, tagName, isPrerelease, isLatest, isDraft — newest first
list_releases_tsv() {
  gh release list -R "${REPO}" --limit 1000 \
    --json tagName,isPrerelease,isLatest,createdAt,isDraft \
    --jq 'sort_by(.createdAt) | reverse | .[] | [.createdAt, .tagName, (.isPrerelease|tostring), (.isLatest|tostring), (.isDraft|tostring)] | @tsv'
}

deleted_pre=0
deleted_keep=0

if (( RETENTION_DAYS > 0 )); then
  cutoff_epoch="$(date -u -d "${RETENTION_DAYS} days ago" +%s)"
  echo "Expiring pre-releases older than ${RETENTION_DAYS} day(s) (before $(date -u -d "@${cutoff_epoch}" -Iseconds))"

  while IFS=$'\t' read -r created tag is_pre is_latest is_draft; do
    [[ -z "${tag:-}" ]] && continue
    [[ "${is_draft}" == "true" ]] && continue
    [[ "${is_pre}" != "true" ]] && continue
    [[ "${is_latest}" == "true" ]] && continue

    created_epoch="$(date -u -d "${created}" +%s)"
    if (( created_epoch < cutoff_epoch )); then
      delete_release "${tag}" "pre-release older than ${RETENTION_DAYS}d, created ${created}"
      deleted_pre=$((deleted_pre + 1))
    fi
  done < <(list_releases_tsv)

  echo "Deleted ${deleted_pre} expired pre-release(s)"
else
  echo "Skipping age-based pre-release expiry (RETENTION_DAYS=0)"
fi

if (( KEEP_LAST_N > 0 )); then
  echo "Pruning all releases to newest ${KEEP_LAST_N} (keeping Latest + manifest tags)"
  idx=0
  while IFS=$'\t' read -r created tag is_pre is_latest is_draft; do
    [[ -z "${tag:-}" ]] && continue
    [[ "${is_draft}" == "true" ]] && continue

    idx=$((idx + 1))
    if (( idx <= KEEP_LAST_N )); then
      echo "Keeping ${tag} (#${idx}, created ${created})"
      continue
    fi
    if [[ "${is_latest}" == "true" ]]; then
      echo "Skipping Latest release ${tag} (outside keep window)"
      continue
    fi
    delete_release "${tag}" "beyond keep_last_n=${KEEP_LAST_N}, created ${created}"
    deleted_keep=$((deleted_keep + 1))
  done < <(list_releases_tsv)

  echo "Deleted ${deleted_keep} release(s) beyond keep_last_n=${KEEP_LAST_N}"
else
  echo "Skipping keep-last prune (KEEP_LAST_N=0)"
fi

echo "Done. pre-release deletions=${deleted_pre} keep-last deletions=${deleted_keep}"
