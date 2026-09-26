# Hetzner Cloud API Reference

Use the live [Hetzner Cloud API reference](https://docs.hetzner.cloud/reference/cloud) as the authority for paths, request schemas, available server types/images, and response fields. The API base URL is `https://api.hetzner.cloud/v1`; authenticate every request with `Authorization: Bearer <token>`.

## First calls

| Objective | Method and path | Expected top-level response |
|---|---|---|
| Verify access / inventory servers | `GET /servers` | `servers`, optionally `meta.pagination` |
| Inspect a server | `GET /servers/{id}` | `server` |
| List async work | `GET /actions` | `actions`, optionally `meta.pagination` |
| Inspect an action | `GET /actions/{id}` | `action` |

## Core resource collections

| Resource | Collection path | Important caution |
|---|---|---|
| Servers | `/servers` | Guest lifecycle and connectivity impact |
| Server actions | `/servers/{id}/actions` | Poll returned action IDs to completion |
| Networks | `/networks` | Validate routes and attachment dependencies |
| Firewalls | `/firewalls` | Preserve an access/recovery path before changes |
| Volumes | `/volumes` | Confirm filesystem, mount, and service dependencies |
| Load balancers | `/load_balancers` | Validate targets and traffic behavior |
| Primary IPs | `/primary_ips` | Some assignment changes require powered-off servers |
| Floating IPs | `/floating_ips` | Guest OS configuration is required after assignment |
| Images / snapshots | `/images` | Confirm data retention and deletion effects |
| SSH keys | `/ssh_keys` | Use registered public keys; never handle private keys |

## Common server actions

The API reference documents action endpoints under `POST /servers/{id}/actions/`, including `poweron`, `poweroff`, `shutdown`, `reboot`, `reset`, `rebuild`, `change_type`, `create_image`, `enable_rescue`, and `request_console`. Inspect the live schema before each use. Actions commonly return an `action` object with `id`, `status`, `progress`, and possibly `error`.

## Error handling

- Treat any HTTP failure as a failed request; capture the returned JSON error without exposing secrets.
- Treat an async action as pending until `action.status` is `success`.
- If `action.status` is `error`, retain the action ID and returned error code/message for troubleshooting; do not blindly retry an impactful mutation.
- `401` commonly indicates an invalid/missing token; `403` can indicate insufficient project permission; `404` can mean the resource is absent from the token's project.

## Official sources

- [Cloud API reference](https://docs.hetzner.cloud/reference/cloud)
- [Hetzner Cloud documentation](https://docs.hetzner.com/cloud/)
- [Hetzner Cloud CLI (`hcloud`)](https://github.com/hetznercloud/cli)
- [Hetzner Python client](https://github.com/hetznercloud/hcloud-python)