# Phoenix Market Ledger collector

> **Phoenix staff-review package. Do not use this addon on Phoenix until staff has approved this exact source/release.**

This is a source-complete Ashita v4 companion for a community-owned Phoenix Auction House price ledger. It is intentionally a narrow, read-only observer: after explicit approval and opt-in, it records only a player's successful normal AH purchase locally. It has no game-client network calls and cannot search, bid, buy, list, cancel, or edit AH behavior.

## What the user sees

After staff approval, a player can load the addon and use:

| Command | Effect |
|---|---|
| `/pml status` | Shows whether collection is enabled and where the local TSV lives. |
| `/pml on` | Enables local successful-purchase logging only after the approved release is configured. |
| `/pml off` | Stops local logging immediately. |
| `/pml file` | Prints the local TSV location. |

The game addon writes `data/observations.tsv`. The player can voluntarily run `tools/upload-observations.ps1` outside the game to submit that file over HTTPS with a revocable collector key. The key is never stored in the addon, TSV, or game client.

The receiving service itself rejects collector keys and uploads until the reviewed release has written Phoenix staff approval, so installing this package cannot silently create a live feed.

## Privacy and accuracy

The local row is `observedAt`, `itemId`, `side`, `priceGil`, and `evidence`. The server drops future/old data, deduplicates replays, holds all observations for review, and uses a price only after three approved same-side sales in seven days with fresh evidence under six hours old. Stack prices remain separate from individual prices; Craftbook receives a stack price only after normalizing it per item.

Read [STAFF-REVIEW.md](../STAFF-REVIEW.md) before distributing or enabling this package.
