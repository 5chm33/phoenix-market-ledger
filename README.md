# Phoenix Market Ledger collector — approved pilot

PhoenixXI’s owner has approved this project to proceed. This source-complete Ashita v4 addon is the **read-only local capture** component of the Phoenix Market Ledger pilot. It records only a player’s successful normal Auction House purchase after the player opts in. It cannot search, bid, buy, list, cancel, inject, block, rewrite, or otherwise alter AH behavior.

The addon never sends a network request. Its only side effect is an append to a local outbox. A separate, optional Windows PowerShell uploader can submit that outbox over HTTPS while the player has explicitly started it. The uploader is an external process and cannot influence the game client.

## Install and use

1. Install the `phoenix_market_ledger` folder in Ashita’s addon folder.
2. Load it in game, then run `/pml status`.
3. If you agree to local capture, run `/pml on`. `/pml off` stops capture immediately.
4. Sign in to the Phoenix Market Ledger website and create a revocable upload key for this device. The key is shown once and is not stored in the addon, TSV, Craftbook, or game process.
5. Outside the game, run one upload when you choose:

   ```powershell
   .\tools\upload-observations.ps1
   ```

   Or, while you deliberately want background contribution, run the optional external watcher. It prompts for the key and holds it only in memory for that process:

   ```powershell
   .\tools\upload-observations.ps1 -Watch
   ```

   Stop it with `Ctrl+C`. The watcher responds to local outbox changes and makes a periodic recovery sweep; it does not query or automate the Auction House.

## What is recorded

A row contains only `eventId`, collector schema/release version, UTC observation time, item ID, exact delivered quantity, gil paid, and `ah_sale_observed`. The addon rejects every quantity except **one** or the item’s exact full stack size. It does not retain character names, seller names, account data, chat, raw packet bytes, AH searches, listings, Bazaar data, or failed bids.

The service independently validates the schema, item, quantity, timestamp, release version, event ID, and per-contributor rate bucket. Uploaded rows begin **pending review**. Public price and Craftbook eligibility require at least three reviewed completed sales from at least three contributors for the same side, within seven days, with an observation under six hours old. Single and full-stack price evidence never mix.

## Privacy and controls

- Opt-in starts **off**. `/pml off` stops local capture immediately.
- The local `data/observations.tsv` queue remains under the player’s control.
- The external uploader sends only queue rows after an HTTPS acknowledgement; it preserves failed rows, and records acknowledged rows locally in `sent-observations.tsv`.
- The player can revoke an upload key from the Ledger website. The server also has a rollout/kill switch and can suspend a key.
- Manual price entries in Craftbook always override every community market value.

This release is intentionally conservative: no public evidence is fabricated before independent completed-sale observations exist.
