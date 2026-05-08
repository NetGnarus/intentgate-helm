# IntentGate Helm chart

Deploys the [IntentGate gateway](https://github.com/NetGnarus/intentgate-gateway)
and (optionally) the [intent extractor](https://github.com/NetGnarus/intentgate-extractor)
into a Kubernetes cluster.

License: **Apache 2.0**.

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

## Quick start (single-replica dev)

```sh
helm install intentgate ./helm \
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
