# slipway-cli

Public releases of the Slipway CLI, and the `setup-slipway` GitHub Action that installs it.

The CLI is built and released from the Slipway source repository. This repository only hosts the release files, so you can download them without a GitHub token. Each Slipway release publishes a matching release here.

## Install

### GitHub Actions

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - name: Setup Slipway CLI
    uses: dpc-sdp/slipway-cli/actions/setup-slipway@main
    with:
      api-base-url: https://slipway.cicd.sdp.platform.vic.gov.au
```

The action:

1. Downloads the CLI for the runner's OS and architecture, and checks it against `checksums.txt`.
2. Adds `slipway` and the `follow-run` plugin to `PATH`.
3. Sets `SLIPWAY_BASE_URL` and `RSH_PROFILE=gha`, so the CLI exchanges the GitHub Actions OIDC token for a Slipway token. The job needs `id-token: write`.

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `api-base-url` | Yes | | Slipway API base URL. |
| `version` | No | `latest` | Release to install: `latest`, `vX.Y.Z` or `X.Y.Z`. |
| `repo` | No | `dpc-sdp/slipway-cli` | Repository to download releases from. |
| `github-token` | No | | Deprecated and ignored. |

| Output | Description |
| --- | --- |
| `version` | The installed release tag, for example `v1.2.3`. |

Runners must be Linux or macOS, on x64 or arm64.

### Homebrew

```sh
brew install dpc-sdp/slipway-cli/slipway-cli
```

### Manual download

Download the archive for your platform from [Releases](https://github.com/dpc-sdp/slipway-cli/releases), check it against `checksums.txt`, and extract it:

```sh
version=0.35.0
curl -fsSLO "https://github.com/dpc-sdp/slipway-cli/releases/download/v${version}/slipway-cli_${version}_linux_amd64.tar.gz"
curl -fsSLO "https://github.com/dpc-sdp/slipway-cli/releases/download/v${version}/checksums.txt"
sha256sum --check --ignore-missing checksums.txt
tar -xzf "slipway-cli_${version}_linux_amd64.tar.gz"
./slipway support plugin install ./slipway-plugin-follow-run --yes
```

## Licence

[MIT](LICENSE)
