#!/bin/bash
set -e

ARGO_NAMESPACE="argocd"
ARGO_CONTEXT="kind-prod-preview"
ARGO_INSTALL_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
ROLL_OUT_TIMEOUT="300s"
NAMESPACE_DELETE_TIMEOUT="180s"

CRDS=(
  "applications.argoproj.io"
  "applicationsets.argoproj.io"
  "appprojects.argoproj.io"
)

DEPLOYMENTS=(
  "argocd-server"
  "argocd-repo-server"
  "argocd-applicationset-controller"
  "argocd-redis"
  "argocd-notifications-controller"
  "argocd-dex-server"
)

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
  error "Argo CD setup failed. Review the messages above and try again."
}

trap on_error ERR

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Missing required command: ${cmd}"
    if [[ "${cmd}" == "kubectl" ]]; then
      echo "Install kubectl with: brew install kubectl" >&2
    fi
    exit 1
  fi
}

decode_base64() {
  local encoded="$1"

  if printf "%s" "${encoded}" | base64 --decode >/dev/null 2>&1; then
    printf "%s" "${encoded}" | base64 --decode
  elif printf "%s" "${encoded}" | base64 -d >/dev/null 2>&1; then
    printf "%s" "${encoded}" | base64 -d
  else
    printf "%s" "${encoded}" | base64 -D
  fi
}

namespace_exists() {
  kubectl get namespace "${ARGO_NAMESPACE}" >/dev/null 2>&1
}

delete_existing_installation() {
  warn "Removing any existing Argo CD installation before reinstalling..."

  if namespace_exists; then
    info "Deleting namespace ${ARGO_NAMESPACE}..."
    kubectl delete namespace "${ARGO_NAMESPACE}" --ignore-not-found >/dev/null

    info "Waiting for namespace ${ARGO_NAMESPACE} to be fully deleted..."
    kubectl wait --for=delete "namespace/${ARGO_NAMESPACE}" --timeout="${NAMESPACE_DELETE_TIMEOUT}" >/dev/null
    success "Namespace ${ARGO_NAMESPACE} has been deleted."
  else
    info "Namespace ${ARGO_NAMESPACE} does not exist. Skipping namespace cleanup."
  fi

  info "Deleting Argo CD CRDs if they exist..."
  kubectl delete crd "${CRDS[@]}" --ignore-not-found >/dev/null
  success "Argo CD CRDs cleaned up."
}

require_command kubectl

info "Checking kubectl context..."
CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
if [[ -z "${CURRENT_CONTEXT}" ]]; then
  error "kubectl does not have a current context configured."
  echo "Run ./infra/local/setup-cluster.sh first." >&2
  exit 1
fi

if [[ "${CURRENT_CONTEXT}" != "${ARGO_CONTEXT}" ]]; then
  error "Current kubectl context is ${CURRENT_CONTEXT}, expected ${ARGO_CONTEXT}."
  echo "Run ./infra/local/setup-cluster.sh first or switch contexts manually." >&2
  exit 1
fi

info "Checking that the kind cluster is reachable..."
if ! kubectl cluster-info >/dev/null 2>&1; then
  error "The kind cluster is not reachable through kubectl."
  echo "Make sure the cluster is running, then rerun this script." >&2
  exit 1
fi
success "kubectl can reach ${ARGO_CONTEXT}."

delete_existing_installation

info "Ensuring namespace ${ARGO_NAMESPACE} exists..."
kubectl create namespace "${ARGO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
success "Namespace ${ARGO_NAMESPACE} is ready."

info "Installing Argo CD from the official manifest..."
kubectl apply --server-side -n "${ARGO_NAMESPACE}" -f "${ARGO_INSTALL_URL}" >/dev/null
success "Argo CD manifests applied."

info "Waiting for Argo CD deployments to become available..."
for deployment in "${DEPLOYMENTS[@]}"; do
  info "Waiting for deployment/${deployment}..."
  kubectl rollout status "deployment/${deployment}" -n "${ARGO_NAMESPACE}" --timeout="${ROLL_OUT_TIMEOUT}" >/dev/null
done
success "All Argo CD deployments are available."

info "Patching argocd-server service to NodePort 30080..."
kubectl patch svc argocd-server -n "${ARGO_NAMESPACE}" -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30080}]}}' >/dev/null
success "argocd-server service patched."

info "Waiting 10 seconds for the service patch to apply..."
sleep 10

info "Retrieving initial admin password..."
ENCODED_PASSWORD="$(kubectl -n "${ARGO_NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}')"
if [[ -z "${ENCODED_PASSWORD}" ]]; then
  error "Could not read the initial admin password from argocd-initial-admin-secret."
  exit 1
fi
PASSWORD="$(decode_base64 "${ENCODED_PASSWORD}")"

echo
printf "%b\n" "${GREEN}============================================${RESET}"
printf "%b\n" "${GREEN}Argo CD installed successfully!${RESET}"
printf "%b\n" "${GREEN}============================================${RESET}"
echo "URL:      https://localhost:30080"
echo "Username: admin"
echo "Password: ${PASSWORD}"
echo
echo "To login via CLI:"
echo "argocd login localhost:30080 --username admin --password ${PASSWORD} --insecure"
echo
echo "Next step: run create-github-secret.sh <your-github-token>"
printf "%b\n" "${GREEN}============================================${RESET}"
