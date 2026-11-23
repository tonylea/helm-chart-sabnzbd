# SABnzbd Helm Chart

![Downloads](https://img.shields.io/github/downloads/tonylea/helm-chart-sabnzbd/total)

Deploys [SABnzbd](https://sabnzbd.org/) from LinuxServer's image, [`lscr.io/linuxserver/sabnzbd`](https://github.com/linuxserver/docker-sabnzbd), the only image SABnzbd's install page lists.

The chart is opinionated: the keys, the login, the Usenet servers, the categories and the folders are all set from values, and applied to `sabnzbd.ini` at every start.
It runs one replica, and stops the old pod before starting the new one, since SABnzbd keeps its queue and history in SQLite and a second pod would fail to attach the volume or corrupt the database.
SABnzbd keeps its data in `/config`, its unfinished jobs in the incomplete folder, and its finished ones on the media volumes.
It runs non-root in LinuxServer's non-root mode, with an `emptyDir` on `/run`.
Because s6 refuses to start unless `/run` is owned by the running UID, a first init container runs as root with only the `CHOWN` capability, chowns `/run`, `/config` and the incomplete folder (not recursively) to `uid` and `gid`, and exits.
Every other container is non-root with all capabilities dropped.

## Values

| Value | Default |
| --- | --- |
| `image.tag` | the chart's `appVersion` |
| `init.image.repository` | `lscr.io/linuxserver/sabnzbd` |
| `init.image.tag` | `image.tag` |
| `init.resources` | none |
| `uid` | `1000` |
| `gid` | `1000` |
| `timezone` | `UTC` |
| `cacheLimit` | `500M` |
| `apiKey.secretKeyRef.name` | none; required |
| `apiKey.secretKeyRef.key` | `api-key` |
| `nzbKey.secretKeyRef.name` | none; required |
| `nzbKey.secretKeyRef.key` | `nzb-key` |
| `login.username.secretKeyRef.name` | none; required |
| `login.username.secretKeyRef.key` | `username` |
| `login.password.secretKeyRef.name` | none; required |
| `login.password.secretKeyRef.key` | `password` |
| `servers` | none |
| `servers[].name` | required; the server's section name |
| `servers[].host` | required |
| `servers[].port` | `563` |
| `servers[].ssl` | `true` |
| `servers[].connections` | `8` |
| `servers[].enable` | `true` |
| `servers[].username.secretKeyRef.name` and `.key` | none; both required |
| `servers[].password.secretKeyRef.name` and `.key` | none; both required |
| `categories` | `tv`, `movies`, `music`, `books` and `comics` |
| `categories[].name` | required |
| `categories[].dir` | the category's name, a folder under `completeDir` |
| `categories[].pp` | none, SABnzbd's default |
| `categories[].script` | `Default` |
| `categories[].priority` | `-100`, SABnzbd's default |
| `completeDir` | none; required, on one of the `persistence.media` mounts |
| `persistence.config.existingClaim` | none; required |
| `persistence.incomplete.existingClaim` | none; required |
| `persistence.incomplete.mountPath` | `/incomplete-downloads` |
| `persistence.incomplete.chown` | `true`; set `false` where the storage refuses a chown, such as an NFS export that maps every user to one |
| `persistence.media` | none; at least one mount required |
| `persistence.media[].name` | required |
| `persistence.media[].existingClaim` | none; required |
| `persistence.media[].mountPath` | none; required |
| `resources` | none |
| `httpRoute.enabled` | `false` |
| `httpRoute.parentRefs` | none; required when enabled |
| `httpRoute.hostnames` | none |

## Fixed settings

An init container sets these keys in `sabnzbd.ini` at every start, creating the file if it's missing and leaving every other key as it is.
SABnzbd rewrites that file whenever a setting changes, so it can't be a ConfigMap mount.
Writing it only once would drift from the values, and SABnzbd's `config_lock` would lock the UI out entirely.

- `[misc]`: `api_key`, `nzb_key`, `username`, `password`, `download_dir`, `complete_dir` and `cache_limit`.
  The cache is set explicitly, because a new install sizes it from system memory, which in a pod may be the node's.
- `[servers]`: one `[[<name>]]` per entry in `servers`, with `host`, `port`, `ssl`, `username`, `password`, `connections` and `enable`.
- `[categories]`: one `[[<name>]]` per entry in `categories`, with `dir`, `pp`, `script` and `priority`.

Passwords are written plain, and SABnzbd reads a plain value as it is.
The init container runs a short Python script with `configobj`, the library SABnzbd reads and writes the file with, so the file keeps SABnzbd's own format.
It uses the SABnzbd image, which already ships both, so no second image is pulled and the tag follows the app.
It also creates each category's folder.
A category's `dir` is written as given: a relative one is under `completeDir`, and an absolute one can be on another media mount.

With a login set, SABnzbd skips its hostname check, so `host_whitelist` is left alone.

## Requirements

- Secrets holding the API key, the NZB key, the UI login and each server's login, with the keys named in the values.
- Existing claims for `/config`, for the incomplete folder and for each media mount.
  The media claims must be writable by `uid` and `gid`, because in non-root mode the image doesn't fix ownership.
  The chart chowns only the tops of `/config` and the incomplete folder.
- `completeDir` on a media mount, and each mount at the same path in every pod that reads the files, so the apps that ask SABnzbd where a download is can find it.
  The [Servarr wiki](https://wiki.servarr.com/docker-guide) covers when an import can be a hardlink rather than a copy.
- The Gateway API's `HTTPRoute` CRD, when `httpRoute.enabled` is set.

## Usage

```sh
helm repo add sabnzbd https://tonylea.github.io/helm-chart-sabnzbd
helm install sabnzbd sabnzbd/sabnzbd --values my-values.yaml
```

```yaml
timezone: Europe/London
apiKey:
  secretKeyRef:
    name: sabnzbd
nzbKey:
  secretKeyRef:
    name: sabnzbd
login:
  username:
    secretKeyRef:
      name: sabnzbd
  password:
    secretKeyRef:
      name: sabnzbd
servers:
  - name: provider
    host: news.example.com
    username:
      secretKeyRef:
        name: sabnzbd-provider
        key: username
    password:
      secretKeyRef:
        name: sabnzbd-provider
        key: password
completeDir: /media/downloads
persistence:
  config:
    existingClaim: sabnzbd-config
  incomplete:
    existingClaim: sabnzbd-incomplete
  media:
    - name: media
      existingClaim: media
      mountPath: /media
```

## Development

Pull requests run:

- `helm lint --strict`, and the rendered chart checked by kubeconform against Kubernetes 1.37.
- helm-unittest's tests in `tests/`.
- An install with chart-testing in a kind cluster, against Secrets and claims from `ci/kind`.

Commits follow Conventional Commits.
Releases are versioned and tagged automatically from `main`, and published to the Helm repository on this repo's GitHub Pages.
