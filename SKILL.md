---
name: hetzner-cloud-vps
description: Manage Hetzner Cloud VPS infrastructure through the official Cloud API. Use when an agent must inventory, inspect, provision, operate, troubleshoot, or safely modify Hetzner Cloud servers, networks, firewalls, volumes, IPs, load balancers, and asynchronous actions from any AI platform.
---

# Hetzner Cloud VPS Operations

Manage Hetzner **Cloud** resources through `https://api.hetzner.cloud/v1`. This skill does not cover Hetzner dedicated servers, Robot, Storage Box, DNS Console, or in-guest SSH administration.

## Configure authentication

1. Ask the user or platform secret manager for a **project-scoped Hetzner Cloud API token**. Never request, print, embed, commit, or package a real token.
2. Store it in a platform secret store, then expose it only at runtime as `HCLOUD_TOKEN` (preferred) or `HETZNER_CLOUD_API_TOKEN`.
3. Verify the credential with a read-only request before making changes:

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/servers
```

A token is bound to a single Hetzner Cloud project. Create a separate token for every project and revoke a token immediately if it may have been exposed. Create tokens in Hetzner Console: **Project → Security → API Tokens**.

## Default workflow

1. **Discover first.** List and inspect resources; identify the project, resource ID, labels, location, protection state, attached volumes/networks, public IPs, and current server status.
2. **State the planned change.** Name the exact resource, intended outcome, dependencies, expected downtime, and whether an action is reversible.
3. **Use the least disruptive operation.** Prefer labels and graceful shutdowns; use snapshots/backups before rebuilds, type changes, or data-risking changes.
4. **Invoke the official API.** Use `scripts/hcloud-api.sh` for consistent authenticated calls or an SDK/HTTP client with equivalent safeguards.
5. **Monitor async work.** Creation and most mutations return an `action`; poll `GET /actions/{id}` until `status` is `success` or `error`.
6. **Verify final state.** Re-fetch the resource and report its immutable ID, status, network reachability if relevant, and action result.

See `references/cloud-api.md` before relying on an endpoint or request field not already verified for the task.

## Read-only discovery

Use these safe starting points:

```bash
scripts/hcloud-api.sh GET /servers
scripts/hcloud-api.sh GET /networks
scripts/hcloud-api.sh GET /firewalls
scripts/hcloud-api.sh GET /volumes
scripts/hcloud-api.sh GET /load_balancers
scripts/hcloud-api.sh GET /actions
```

Target a known ID whenever possible:

```bash
scripts/hcloud-api.sh GET /servers/12345
scripts/hcloud-api.sh GET /servers/12345/actions
```

Use API pagination and filters where the reference documents them. Do not choose a resource based only on a partial name match; use its numeric ID and verify labels/location before modifying it.

## Server lifecycle

The documented action paths include:

```bash
# Brief disruption; verify workload health after completion.
scripts/hcloud-api.sh POST /servers/12345/actions/reboot '{}'

# Stop/start only when the expected downtime is accepted.
scripts/hcloud-api.sh POST /servers/12345/actions/shutdown '{}'
scripts/hcloud-api.sh POST /servers/12345/actions/poweron '{}'
```

`shutdown` requests a graceful guest shutdown; `poweroff` is a forced operation. Prefer `shutdown`, allow time for completion, and use `poweroff` only when explicitly warranted. Do not reboot, power off, reset, rebuild, resize, delete, detach storage, reassign IPs, or alter firewall/network reachability without the user's explicit approval of the exact target and effect.

## Provisioning and configuration changes

Before `POST /servers`, confirm the server type, image, location, network/firewall attachments, SSH key IDs, labels, cloud-init `user_data`, backup policy, and estimated operational impact. Treat `user_data` as executable infrastructure configuration: inspect it for secrets and destructive shell commands before sending it.

Before firewall or network changes, identify the operator's current source IP and retain a recovery path (console/rescue access or a tested rule) to avoid lockout. Before volume detach, type changes, rebuilds, or deletion, confirm backups/snapshots, mount/service dependencies, and the recovery plan.

## Async actions

Use the polling helper after a mutation response supplies an action ID:

```bash
scripts/hcloud-api.sh wait-action 987654
```

Stop and surface the returned error object if an action enters `error`. Do not assume success just because a mutation request returned HTTP 201 or 202.

## Safety rules

- Treat API tokens, SSH private keys, cloud-init secrets, IP addresses, and console output as sensitive.
- Never put secrets in source code, prompts, shell history, artifacts, logs, or command-line literals.
- Use server IDs rather than name guesses and re-fetch immediately before an impactful mutation.
- Require explicit user confirmation for irreversible/high-impact actions: deleting a server, volume, snapshot/image, network, firewall, load balancer, IP, or DNS resource; rebuilding; resetting a password; disabling protection; or any change likely to cause data loss or loss of access.
- The bundled helper blocks `DELETE` unless `HCLOUD_ALLOW_DESTRUCTIVE=1` is set for that one command. This is a guardrail, not authorization.
- Do not claim SSH access from a Cloud API token. Obtain a hostname/IP and separately supplied SSH credentials only when guest-level administration is requested.

## Portability notes

This is intentionally vendor-API and shell based. On another AI platform, install `curl` and optionally `jq`, copy the skill directory, configure `HCLOUD_TOKEN` in that platform's secret manager, and follow the same workflow. Replace the helper with the platform's approved HTTP tool only if it can send the `Authorization: Bearer` header without exposing the token.
***