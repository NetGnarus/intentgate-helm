# IntentGate Helm chart

[![CI](https://github.com/NetGnarus/intentgate-helm/actions/workflows/ci.yml/badge.svg)](https://github.com/NetGnarus/intentgate-helm/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Helm chart](https://img.shields.io/badge/ghcr.io-charts%2Fintentgate-2188ff.svg)](https://github.com/NetGnarus/intentgate-helm/pkgs/container/charts%2Fintentgate)

Deploys the [IntentGate gateway](https://github.com/NetGnarus/intentgate-gateway)
and (optionally) the [intent extractor](https://github.com/NetGnarus/intentgate-extractor)
into a Kubernetes cluster.

## Companion repositories

| Repo | Purpose |
| ---- | ------- |
| [intentgate-gateway](https://github.com/NetGnarus/intentgate-gateway) | Go gateway with the four-check pipeline. Deployed by this chart. |
| [intentgate-extractor](https://github.com/NetGnarus/intentgate-extractor) | Optional FastAPI service for intent extraction. Deployed by this chart when `extractor.enabled: true`. |
| [intentgate-sdk-python](https://github.com/NetGnarus/intentgate-sdk-python) | Python SDK that talks to the deployed gateway. |
| [intentgate-helm](https://github.com/NetGnarus/intentgate-helm) | This chart. |

## What it deploys

| Component  | Required | Description                                                     |
| ---------- | :------: | --------------------------------------------------------------- |
| Gateway    |    ✓     | Go binary, full four-check pipeline + audit. Service on 8080.   |
| Extractor  |    ◯     | Python intent service. Service on 8090. Toggle with `extractor.enabled`. |
| Redis      |    ◯     | NOT bundled. Provide `redisUrl` to point at your own Redis if you need multi-replica budget counters. |

The chart is a single-tenant install. For multi-tenant control-plane
deployments, see the (separate, commercial) `intentgate-private/control-plane`
chart.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.x
- A Kubernetes namespace you can deploy to
- (Optional) Redis if you want multi-replica budget enforcement
- (Optional) An Anthropic API key if you want production-quality intent extraction

## Install from the OCI registry

The chart is published to GHCR as an OCI artifact on every `vX.Y.Z` git
tag. Helm 3.7+ pulls from OCI directly:

```sh
helm install intentgate oci://ghcr.io/netgnarus/charts/intentgate \
  --version 0.1.0 \
  --namespace intentgate --create-namespace
```

To pin to the latest published minor:

```sh
helm install intentgate oci://ghcr.io/netgnarus/charts/intentgate \
  --version "~0.1" \
  --namespace intentgate --create-namespace
```

Available versions: https://github.com/NetGnarus/intentgate-helm/pkgs/container/charts%2Fintentgate

## Quick start from source (single-replica dev)

```sh
git clone https://github.com/NetGnarus/intentgate-helm.git
helm install intentgate ./intentgate-helm \
  --namespace intentgate --create-namespace
```

That's it. The chart will:

- Create a `ServiceAccount`.
- Deploy the gateway and (in stub mode by default) the extractor.
- Wire the gateway's `INTENTGATE_EXTRACTOR_URL` to the extractor's in-cluster Service.
- Run the gateway with all-permissive defaults so a smoke test works immediately.

The gateway will generate an ephemeral master key at startup (logged
once, lost on restart). Read `kubectl logs` to see it.

After install, follow the post-install `NOTES.txt` that Helm prints —
it has the exact `kubectl port-forward` and `curl` commands to verify.

## Production install

```sh
helm install intentgate ./helm \
  --namespace intentgate --create-namespace \
  -f values-prod.yaml
```

with a `values-prod.yaml` like:

```yaml
gateway:
  replicaCount: 3
  requireCapability: true
  requireIntent: true
  requireBudget: true
  # Either inline (chart writes a Secret):
  masterKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
  # Or point at one you manage out-of-band:
  # existingMasterKeySecret: "intentgate-master-key"
  policy: |
    package intentgate.policy
    import rego.v1
    default decision := {"allow": false, "reason": "default deny"}
    decision := {"allow": true, "reason": "read-only"} if startswith(input.tool, "read_")

extractor:
  replicaCount: 2
  stubMode: false
  anthropicApiKey: "sk-ant-api03-..."
  # Or:
  # existingApiKeySecret: "anthropic-api-key"

redisUrl: "redis://intentgate-redis-master:6379/0"
```

## Values reference

See [`values.yaml`](values.yaml) for the canonical reference. Highlights:

| Path                                | Default                  | Notes                                                                  |
| ----------------------------------- | ------------------------ | ---------------------------------------------------------------------- |
| `gateway.replicaCount`              | `1`                      | >1 only with `redisUrl` set.                                           |
| `gateway.image.repository`          | `ghcr.io/netgnarus/intentgate-gateway` |                                                          |
| `gateway.image.tag`                 | `""` → chart appVersion  |                                                                        |
| `gateway.requireCapability`         | `false`                  | Set `true` in production.                                              |
| `gateway.requireIntent`             | `false`                  | Requires `extractor.enabled` or an external extractor.                 |
| `gateway.requireBudget`             | `false`                  | Strict mode for the fourth check.                                      |
| `gateway.auditTarget`               | `stdout`                 | Or `none`.                                                             |
| `gateway.masterKey`                 | `""`                     | base64url HMAC key. Empty → ephemeral (dev only).                      |
| `gateway.existingMasterKeySecret`   | `""`                     | Reference a Secret you manage instead of inline.                       |
| `gateway.policy`                    | `""`                     | Inline Rego (chart writes ConfigMap). Empty → embedded default.        |
| `gateway.existingPolicyConfigMap`   | `""`                     | Reference a ConfigMap you manage instead of inline.                    |
| `extractor.enabled`                 | `true`                   | Set `false` to skip the extractor entirely.                            |
| `extractor.stubMode`                | `true`                   | Offline heuristic. Set `false` + supply `anthropicApiKey` for production. |
| `extractor.anthropicApiKey`         | `""`                     | Inline API key (chart writes a Secret). Ignored in stub mode.          |
| `extractor.existingApiKeySecret`    | `""`                     | Reference an existing Secret instead.                                  |
| `redisUrl`                          | `""`                     | Empty → in-memory budget store (single-replica only).                  |
| `serviceAccount.create`             | `true`                   |                                                                        |

## Uninstall

```sh
helm uninstall intentgate -n intentgate
```

## Templates

```
templates/
├── _helpers.tpl                 # naming + label helpers
├── NOTES.txt                    # post-install instructions
├── serviceaccount.yaml
├── gateway-deployment.yaml      # the Go binary, four-check pipeline
├── gateway-service.yaml         # ClusterIP :8080
├── gateway-configmap.yaml       # rendered only when policy is inline
├── gateway-secret.yaml          # rendered only when masterKey is inline
├── extractor-deployment.yaml    # Python service
├── extractor-service.yaml       # ClusterIP :8090
└── extractor-secret.yaml        # rendered only when an API key is inline
```

## What this chart does NOT include

By design, the chart stays minimal:

- **No bundled Redis.** Bring your own. Most clusters have a managed
  one or a Bitnami subchart already.
- **No Ingress / Gateway API resources.** Customers terminate TLS at
  whichever Ingress they already operate.
- **No NetworkPolicies.** Add them in a separate chart if required.
- **No HPA / PDB.** Production wraps these around the Deployment via
  GitOps overlays. The basic Deployment shape is HPA-friendly.
- **No control plane.** The commercial `intentgate-private/control-plane`
  chart is a separate install.

## Develop locally

```sh
helm lint .
helm template intentgate . | kubeconform -strict -summary -
helm template intentgate . -f tests/values-prod.yaml | kubeconform -strict -summary -
```

`tests/values-prod.yaml` exercises the production-style toggles
(strict mode on, inline policy, inline keys) so CI can validate the
"production" code path renders valid Kubernetes manifests.

CI runs both renderings on every PR — see `.github/workflows/ci.yml`.

## Contributing

Apache 2.0 and welcomes community contributions. A formal `CONTRIBUTING.md`
is coming with the v0.1 → v1.0 polish pass. For now, please open an
issue to discuss any non-trivial change before sending a PR.

## Security

If you find a security vulnerability, please **do not** open a public
issue. Email security@netgnarus.com (or open a GitHub Security Advisory
on this repo) and we'll respond within two business days.

## Production hardening checklist

Before exposing the gateway to real agent traffic, walk through:

- [ ] `gateway.requireCapability: true`
- [ ] Stable `masterKey` (not ephemeral) — either inline or via existing Secret
- [ ] Customer-authored Rego policy — not the embedded default
- [ ] `redisUrl` pointing at a Redis with persistence + auth
- [ ] `extractor.stubMode: false` + a real Anthropic key (or an external extractor URL)
- [ ] An Ingress / Gateway API in front of the gateway with TLS
- [ ] A log shipper (vector, fluent-bit, promtail) tailing pod stdout into your SIEM
- [ ] Resource limits adjusted for your real traffic
- [ ] PodDisruptionBudget for the gateway Deployment (`replicaCount >= 2`)
