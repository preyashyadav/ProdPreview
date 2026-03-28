#!/bin/bash
set -e

CLUSTER_NAME="prod-preview"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/kind-config.yaml"
KUBECONTEXT="kind-${CLUSTER_NAME}"

if [[ -t 1 ]]; then
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  BOLD="\033[1m"
  RESET="\033[0m"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  RESET=""
fi

print_banner() {
  echo
  printf "%b\n" "${BLUE}${BOLD}========================================${RESET}"
  printf "%b\n" "${BLUE}${BOLD}  ProdPreview kind Cluster Bootstrap${RESET}"
  printf "%b\n" "${BLUE}${BOLD}========================================${RESET}"
  echo
}

info() {
  printf "%b\n" "${BLUE}[INFO]${RESET} $1"
}

success() {
  printf "%b\n" "${GREEN}[OK]${RESET} $1"
}

warn() {
  printf "%b\n" "${YELLOW}[WARN]${RESET} $1"
}

error() {
  printf "%b\n" "${RED}[ERROR]${RESET} $1" >&2
}

on_error() {
  error "Cluster setup failed. Review the messages above and try again."
}

trap on_error ERR

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Missing required command: ${cmd}"
    case "${cmd}" in
      docker)
        echo "Install Docker Desktop from https://docs.docker.com/get-docker/" >&2
        ;;
      kind)
        echo "Install kind with: brew install kind" >&2
        ;;
      kubectl)
        echo "Install kubectl with: brew install kubectl" >&2
        ;;
    esac
    exit 1
  fi
}

docker_running() {
  docker info >/dev/null 2>&1
}

cluster_exists() {
  kind get clusters | grep -Fxq "${CLUSTER_NAME}"
}

confirm_recreate() {
  local reply

  if [[ ! -t 0 ]]; then
    error "A cluster named ${CLUSTER_NAME} already exists, but this script cannot prompt in non-interactive mode."
    echo "Delete it manually with: kind delete cluster --name ${CLUSTER_NAME}" >&2
    exit 1
  fi

  read -r -p "A kind cluster named ${CLUSTER_NAME} already exists. Delete and recreate it? [y/N]: " reply
  case "${reply}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

print_banner

info "Checking prerequisites..."
require_command docker
require_command kind
require_command kubectl
success "docker, kind, and kubectl are installed."

if [[ ! -f "${CONFIG_FILE}" ]]; then
  error "Missing kind config file: ${CONFIG_FILE}"
  exit 1
fi

info "Checking Docker daemon..."
if ! docker_running; then
  error "Docker is not running."
  echo "Start Docker Desktop and rerun this script." >&2
  exit 1
fi
success "Docker is running."

SHOULD_CREATE_CLUSTER=true

if cluster_exists; then
  warn "A kind cluster named ${CLUSTER_NAME} already exists."
  if confirm_recreate; then
    info "Deleting existing cluster ${CLUSTER_NAME}..."
    kind delete cluster --name "${CLUSTER_NAME}"
    success "Deleted existing cluster."
  else
    warn "Keeping the existing cluster and reusing it."
    SHOULD_CREATE_CLUSTER=false
  fi
fi

if [[ "${SHOULD_CREATE_CLUSTER}" == "true" ]]; then
  info "Creating kind cluster ${CLUSTER_NAME} using ${CONFIG_FILE}..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"
  success "Cluster created."
fi

info "Setting kubectl context to ${KUBECONTEXT}..."
kubectl config use-context "${KUBECONTEXT}" >/dev/null
success "kubectl context set."

info "Waiting for all nodes to become Ready (timeout: 120s)..."
kubectl wait --for=condition=Ready node --all --timeout=120s >/dev/null
success "All nodes are Ready."

echo
success "kind cluster setup complete."
echo "Cluster name: ${CLUSTER_NAME}"
echo "Node status:"
kubectl get nodes -o wide
echo
echo "Next step: run setup-argocd.sh"
