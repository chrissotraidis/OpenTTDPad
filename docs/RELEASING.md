# Releasing OpenTTDPad

A `v*` tag never publishes on its own. The **Tagged release** workflow builds and
verifies the artifacts, creates a *draft* release if none exists, and leaves an
existing release untouched. Publishing is always a manual step.

## Before publishing

1. `./scripts/check-local.sh` passes on `main`. While the repository is
   private, the macOS workflows run only when started by hand (GitHub Free's
   private Actions allowance covers about 190 macOS minutes a month); once it is
   public they run on every push and pull request at no cost.
2. Build the release candidate from a clean `main` checkout:

   ```sh
   ./scripts/bootstrap-reference.sh
   ./scripts/build-device.sh
   ./scripts/package-ipa.sh
   ./scripts/package-source-release.sh
   ./scripts/verify-release.sh
   ```

3. Every public file passes PadMint's audit (and the private release gate):

   ```sh
   cd /path/to/padmint
   python3 -m padmint audit /path/to/OpenTTDPad/build/artifacts/<file>
   ```

4. PadMint player check from PadMint's current `main` (plus the OpenTTDPad catalog
   entry), with the clean checkout:

   ```sh
   scripts/player-check.sh openttdpad ios - /path/to/OpenTTDPad
   ```

5. Install the exact IPA in place on a physical iPad and launch it.
6. Write `docs/releases/vX.Y.Z.md`, bump `MACOSX_BUNDLE_SHORT_VERSION_STRING` and
   `MACOSX_BUNDLE_BUNDLE_VERSION` in `engine/CMakeLists.txt`, and update the README.
7. Create a draft GitHub release for `vX.Y.Z` targeting `main`, with the notes and
   the audited files from `build/artifacts/`, plus `padmint.json` attached as
   `OpenTTDPad-vX.Y.Z-padmint.json` and listed in `SHA256SUMS`. PadMint only
   builds a release that publishes its recipe this way.

## Publishing (owner only)

1. Make the repository public if it is not already.
2. Review and publish the draft release. Publishing creates the tag; the workflow
   then rebuilds and verifies, and leaves the published files alone.
3. Merge the PadMint catalog entry and release PadMint.
4. Run the player check again without a checkout, the way players build it:

   ```sh
   scripts/player-check.sh openttdpad ios -
   ```

   A failure blocks the announcement.
5. Announce.
