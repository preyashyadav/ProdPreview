#!/bin/bash
set -e

ARGO_NAMESPACE="argocd"
TOKEN="${1:-}"
REPO_URL_INPUT="${2:-}"
GITHUB_TOKEN_SECRET="github-token"
ARGO_REPO_SECRET="prod-preview-repo"

if [[ -t 1 ]]; then
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  BLUE="\033[0;34m"
  RESET="\033[0m"
else
  RED=""
  GREEN=""
  BLUE=""
  RESET=""
fi

info() {
  printf "%b\n" "${BLUE}[INFO]${RESET} $1"
}

success() {
  printf "%b\n" "${GREEN}[OK]${RESET} $1"
}

error() {
  printf "%b\n" "${RED}[ERROR]${RESET} $1" >&2
}

on_error() {
  error "GitHub secret setup failed. Review the messages above and try again."
}

trap on_error ERR

usage() {
  echo "Usage: $0 <github-personal-access-token> [github-repo-url]" >&2
  echo "Example: $0 ghp_xxx https://github.com/<OWNER>/<REPO>.git" >&2
}

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Missing required command: ${cmd}"
    exit 1
  fi
}

normalize_repo_url() {
  local raw_url="$1"

  if [[ -z "${raw_url}" ]]; then
    echo ""
    return
  fi

  if [[ "${raw_url}" == git@github.com:* ]]; then
    raw_url="https://github.com/${raw_url#git@github.com:}"
  fi

  raw_url="${raw_url%.git}"
  echo "${raw_url}.git"
}

detect_repo_url() {
  if [[ -n "${REPO_URL_INPUT}" ]]; then
    normalize_repo_url "${REPO_URL_INPUT}"
    return
  fi

  if command -v git >/dev/null 2>&1; then
    local detected
    detected="$(git config --get remote.origin.url 2>/dev/null || true)"
    normalize_repo_url "${detected}"
    return
  fi

  echo ""
}

require_command kubectl

if [[ -z "${TOKEN}" ]]; then
  usage
  exit 1
fi

REPO_URL="$(detect_repo_url)"
if [[ -z "${REPO_URL}" ]]; then
  error "GitHub repo URL is required."
  echo "Pass it as the second argument, for example:" >&2
  echo "  $0 <token> https://github.com/<OWNER>/<REPO>.git" >&2
  exit 1
fi

info "Checking kubectl connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
  error "kubectl is not connected to a reachable cluster."
  echo "Make sure your kind cluster is running and your context is set correctly." >&2
  exit 1
fi
success "kubectl is connected to a cluster."

info "Checking namespace ${ARGO_NAMESPACE}..."
if ! kubectl get namespace "${ARGO_NAMESPACE}" >/dev/null 2>&1; then
  error "Namespace ${ARGO_NAMESPACE} does not exist."
  echo "Run ./infra/local/setup-argocd.sh first." >&2
  exit 1
fi
success "Namespace ${ARGO_NAMESPACE} exists."

info "Creating or updating secret ${GITHUB_TOKEN_SECRET}..."
kubectl create secret generic "${GITHUB_TOKEN_SECRET}" \
  --from-literal=token="${TOKEN}" \
  -n "${ARGO_NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
success "Secret ${GITHUB_TOKEN_SECRET} is ready."

info "Creating or updating Argo CD repo secret ${ARGO_REPO_SECRET}..."
kubectl create secret generic "${ARGO_REPO_SECRET}" \
  --from-literal=type=git \
  --from-literal=url="${REPO_URL}" \
  --from-literal=password="${TOKEN}" \
  --from-literal=username=not-used \
  -n "${ARGO_NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl label secret "${ARGO_REPO_SECRET}" -n "${ARGO_NAMESPACE}" \
  argocd.argoproj.io/secret-type=repository --overwrite >/dev/null
success "Secret ${ARGO_REPO_SECRET} is ready and labeled for Argo CD."

info "Verifying secrets..."
kubectl get secret "${GITHUB_TOKEN_SECRET}" -n "${ARGO_NAMESPACE}" >/dev/null
kubectl get secret "${ARGO_REPO_SECRET}" -n "${ARGO_NAMESPACE}" >/dev/null
success "Both secrets exist."

echo
echo "Created/updated in namespace ${ARGO_NAMESPACE}:"
echo "- ${GITHUB_TOKEN_SECRET}"
echo "- ${ARGO_REPO_SECRET}"
echo "GitHub repo URL: ${REPO_URL}"
echo
echo "If you want to target a different repo later, rerun:"
echo "  $0 <token> https://github.com/<OWNER>/<REPO>.git"
