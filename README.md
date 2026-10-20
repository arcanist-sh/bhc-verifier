# bhc-verifier

Builds packages published to the [arcanist.sh registry](https://registry.arcanist.sh) with
[bhc](https://arcanist.sh/bhc/), the Basel Haskell Compiler, and posts signed results back, so the
registry can show which versions are **bhc-verified**. It is the first piece of verification that
accumulates: a build that ran once is recorded beside the package instead of repeated by everyone
who uses it.

Every 30 minutes, or right away on a `registry-publish` dispatch, the workflow:

1. asks the registry for versions without an attestation,
2. checks each tarball against its published SHA-256,
3. builds it with `hx build --backend bhc` (today under the `default` profile),
4. submits an Ed25519-signed attestation, `pass` or `fail`, with the bhc version, the profile and a
   link to the run log, as the verifier `ci-bhc`.

The registry shows the result on each package page; see
[registry.arcanist.sh](https://registry.arcanist.sh) and the
[registry documentation](https://arcanist.sh/registry/).

- Workflow: [`.github/workflows/bhc-verify.yml`](.github/workflows/bhc-verify.yml)
- Signing: [`scripts/attest.mjs`](https://github.com/arcanist-sh/registry/blob/main/scripts/attest.mjs)
  in the registry repository
- Secret: `BHC_VERIFIER_KEY`, the verifier's private key; its public key is registered with the
  registry
- Template: the workflow is maintained as
  [`verifier/bhc-verify.yml`](https://github.com/arcanist-sh/registry/blob/main/verifier/bhc-verify.yml)
  in the registry repository
