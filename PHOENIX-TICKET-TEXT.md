# Phoenix Market Ledger — addon review request

Please review **Phoenix Market Ledger 0.1.0-review** for Ashita v4.

Public, complete source: https://github.com/5chm33/phoenix-market-ledger

This is an opt-in community market-data collector intended to support a Phoenix-specific Craftbook profit overlay. It is disabled by default and will not be distributed for use until Phoenix approves this exact release.

The addon observes only an incoming AH success response after a player personally completes a normal Auction House purchase. It writes a local TSV containing only UTC time, item ID, single/stack side, and successful price. A separate, player-run uploader may later submit that local file to the community ledger. The addon itself has no HTTP client.

It does not register an outgoing packet handler; send, inject, block, modify, replay, or construct packets; open or search the AH; bid, purchase, list, cancel, collect, or automate any AH action; inspect Bazaar data; retain character/buyer/seller names, chat, raw packet bytes, inventory, or account credentials.

The parser offsets are documented as an implementation assumption based on LandSandBoat’s public AH packet source. We will update or remove the collector if Phoenix staff confirms a different protocol or policy. `STAFF-REVIEW.md` contains the complete behavior, non-behavior, data fields, and server-side aggregation controls.

Could Phoenix please confirm whether observing this incoming, player-initiated success response is permitted and whether the documented packet layout matches Phoenix? If approved, we will tag and distribute the reviewed version unchanged.
