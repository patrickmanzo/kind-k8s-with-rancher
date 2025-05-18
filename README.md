# kind-k8s-with-rancher

> **Ambiente Kubernetes local** com Kind + Rancher: tudo rodando local, sem custo de cloud!

---

## 🔧 Pré-requisitos

| Ferramenta | Versão recomendada |
|------------|-------------------|
| Docker     | ≥ 20.10           |
| Kind       | **v0.27.0**       |
| kubectl    | v1.30 |
| Helm       | ≥ 3.13            |
| sudo       | para mapear portas 80/443 |

---

## 📁 Estrutura do repositório

```text
.
├── cluster/
│   └── kind-config.yaml        # configuração do Kind
├── manifests/
│   └── issuer-selfsigned.yaml  # Issuer + Certificate
├── rancher/
│   └── values.yaml             # valores de Helm para o Rancher
├── Makefile                    # cria / deleta tudo com um comando
└── README.md
```

---

## 🚀 Uso rápido

### 1 · Clonar o projeto

```bash
git clone https://github.com/patrickmanzo/kind-k8s-with-rancher.git
cd k8s-rancher-project
```

### 2 · Provisionar

```bash
make all
```

O `make all` executa, em ordem:
- **check-deps** – garante docker, kind, kubectl, helm
- **cluster** – cria o Kind rancher
- **cert-manager** – instala o chart do cert-manager
- **tls** – gera Issuer + Certificate self-signed
- **ingres** – instala o chart do ingress-nginx-controller
- **rancher** – instala o chart do rancher

---

### 3 · 🔑 Primeiro acesso ao Rancher

Senha bootstrap (mostrada uma única vez nos logs ou no secret):

```bash
kubectl -n cattle-system logs deploy/rancher | grep 'Bootstrap Password'
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

Com o /etc/hosts configurado com: 127.0.0.1 rancher.local
É possível acessar pelo navegador:
[https://rancher.local](https://rancher.local)

**Ou** via port-forward:

```bash
kubectl -n cattle-system port-forward deploy/rancher 9443:443
```

Acesse: [https://localhost:9443](https://localhost:9443)
(Aceite o aviso de certificado auto-assinado.)

---

### 4 · 🧹 Limpeza

```bash
make clean
```
Deleta o cluster Kind.

---

### 5 · 🛠️ Personalizações

--------------------------------------------------------------------------------------------------------------------------------------
| O que mudar                           | Como fazer                                                                                 |
|---------------------------------------|--------------------------------------------------------------------------------------------|
| Nome do cluster                       | `make CLUSTER_NAME=meu-cluster`                                                            |
| Hostname do Rancher                   | `make RANCHER_HOST=rancher.127.0.0.1.nip.io`                                               |
| Versões (Kind / cert-manager / chart) | Editar `CERTM_VER`, `RANCHER_CHART_VER` e `INGRESS_VER` no Makefile                        |
| TLS oficial                           | Substituir `manifests/issuer-selfsigned.yaml` por um Issuer do Let's Encrypt ou CA interna |
--------------------------------------------------------------------------------------------------------------------------------------