###############################################################################
# Makefile – Kind + Rancher													 #
###############################################################################

.ONESHELL:
SHELL := /bin/bash
SHELLFLAGS := -eu -o pipefail -c

CLUSTER_NAME        ?= rancher
RANCHER_HOST        ?= rancher.local

CERTM_VER           ?= v1.17.1
RANCHER_CHART_VER   ?= 2.11.1
INGRESS_VER ?= 4.10.1

.PHONY: all check-deps cluster cert-manager tls ingress rancher clean

all: check-deps cluster cert-manager tls ingress rancher
	@echo -e "\n✅ Ambiente pronto! Acesse → https://$(RANCHER_HOST)"

check-deps:
	@echo "🔎 Verificando dependências…"
	@missing=0; for bin in docker kind kubectl helm; do \
	    if ! command -v $$bin >/dev/null; then \
	      echo "❌ $$bin não encontrado"; missing=1; \
	    else printf "✔️  %-7s %s\n" $$bin "$$($$bin version 2>/dev/null | head -1)"; fi; \
	  done; \
	  if [ $$missing -eq 1 ]; then \
	    echo "Instale as dependências acima e rode make novamente."; exit 1; \
	  fi

cluster:
	echo "➜ Criando cluster $(CLUSTER_NAME)…"
	kind create cluster --name $(CLUSTER_NAME) --config cluster/kind-config.yaml
	kubectl wait --for=condition=Ready nodes --all --timeout=180s
	echo "✅ Cluster OK"

cert-manager:
	echo "➜ Instalando cert-manager $(CERTM_VER)…"
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm upgrade --install cert-manager jetstack/cert-manager \
	  --namespace cert-manager --create-namespace \
	  --version $(CERTM_VER) --set installCRDs=true
	for d in cert-manager cert-manager-webhook cert-manager-cainjector; do
	  kubectl -n cert-manager rollout status deploy/$$d --timeout=180s; done
	echo "✅ cert-manager pronto"

tls:
	echo "➜ Criando Issuer e Certificate…"
	kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
	sed "s/__RANCHER_HOST__/$(RANCHER_HOST)/" manifests/issuer-selfsigned.yaml | kubectl apply -f -
	kubectl -n cattle-system wait --for=condition=Ready secret/tls-rancher-ingress --timeout=120s
	echo "✅ TLS secret criado"

ingress:
	@echo "➜ Instalando ingress-nginx $(INGRESS_VER)…"
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	  --namespace ingress-nginx --create-namespace \
	  --version $(INGRESS_VER) \
	  --set controller.publishService.enabled=false \
	  --set controller.service.type="ClusterIP" \
	  --set controller.ingressClassResource.enabled=true \
	  --set controller.ingressClassResource.name=nginx \
      --set controller.ingressClassResource.default=true \
	  --set controller.hostNetwork=true
	kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s
	@echo "✅ ingress-nginx pronto"

rancher:
	echo "➜ Atualizando /etc/hosts no WSL…"
	if ! grep -q "$(RANCHER_HOST)" /etc/hosts; then \
	  sudo sh -c 'echo "127.0.0.1 $(RANCHER_HOST)" >> /etc/hosts'; \
	fi
	
	echo "➜ Instalando Rancher chart $(RANCHER_CHART_VER)…"
	helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
	helm repo update
	helm upgrade --install rancher rancher-stable/rancher \
	  --namespace cattle-system \
	  --values rancher/values.yaml \
	  --version $(RANCHER_CHART_VER)
	kubectl -n cattle-system rollout status deploy/rancher --timeout=300s
	echo "✅ Rancher disponível em https://$(RANCHER_HOST)"

clean:
	-kind delete cluster --name $(CLUSTER_NAME) || true