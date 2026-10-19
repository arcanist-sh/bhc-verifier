# bhc-verifier

Builds packages published to the [arcanist.sh registry](https://registry.arcanist.sh)
with [BHC](https://bhc.arcanist.sh) and posts signed results back, so the
registry can show which versions are **BHC-verified**.

Every 30 minutes (or on a `registry-publish` dispatch) the workflow asks the
registry for versions without an attestation, checks each tarball against its
published SHA-256, builds it with `hx build --backend bhc`, and submits an
Ed25519-signed attestation (`pass` or `fail`, BHC version, profile, and a link
to the run log) as the verifier `ci-bhc`.

- Workflow: [`.github/workflows/bhc-verify.yml`](.github/workflows/bhc-verify.yml)
- Signing: [`scripts/attest.mjs`](https://github.com/arcanist-sh/registry/blob/main/scripts/attest.mjs) in the registry repository
- Secret: `BHC_VERIFIER_KEY` (the verifier's private key; its public key is registered with the registry)
