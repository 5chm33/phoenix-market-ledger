# Phoenix Market Ledger — approval and safety model

PhoenixXI’s owner approved this project to proceed on 22 October 2026. This document preserves the boundary of the approved pilot release so contributors, reviewers, and future maintainers can inspect it.

## The release does

- Observe an incoming `0x04C` AH response only when a player has enabled `/pml on`.
- Record a local row only for the documented successful-bid subtype and result.
- Reject any delivered quantity other than one or the item’s exact full stack size.
- Write a small local outbox record with a random event ID and schema/release version.
- Offer a separate, player-run PowerShell queue worker that uploads only after explicit authentication and HTTPS acknowledgement.

## The release does not do

- Make any network request from the Ashita game process.
- Register outgoing packet events or send, block, alter, inject, replay, search, bid, buy, sell, list, cancel, or automate an Auction House action.
- Upload raw packets, player/character names, seller names, chat, account data, searches, listings, Bazaar information, or failed bids.
- Use PSXI or any third-party market provider.

## Server rules

The server receives schema-validated JSON through a 256 KB route-specific limit and an upload rate limit. It accepts only the current collector schema and release, exact valid quantities, UTC timestamps from the prior seven days, unique event IDs, and a bounded contribution bucket per item/side. A player’s key is revocable, hashed at rest, scoped only to upload, and shown once.

Every submitted collector observation begins pending review. A public price side needs at least three approved completed sales from at least three contributors, within the last seven days, with a latest observation under six hours old. Manual web attestations stay outside public and Craftbook pricing. The rollout switch can pause all enrollment and ingestion immediately.

## Pilot rollout

The `pilot` mode is intentionally not a public market feed. It exists to verify the Phoenix packet layout against real user-authorized successful purchases, monitor the local outbox/uploader, and review the resulting pending rows. Only after that evidence is satisfactory should an administrator enable `public` mode; even then, prices remain withheld unless the independent-contributor and freshness rules are met.
