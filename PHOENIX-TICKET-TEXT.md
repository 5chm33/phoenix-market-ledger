# Phoenix Market Ledger — approval request archive

**Resolved 22 October 2026.** PhoenixXI owner and lead developer Kipling gave blanket approval for the Auctioneer-style Phoenix Market Ledger initiative to proceed. The approved pilot release is now **0.2.0**; its source, safety contract, and opt-in behavior are in the repository root.

The original 0.1.0 review request proposed an opt-in community market-data collector to support a Phoenix-specific Craftbook profit overlay. Its core guarantees remain in the release:

- It observes only an incoming successful AH response after a player completes a normal purchase.
- It never registers outgoing packet handlers or sends, injects, blocks, alters, replays, constructs, searches, bids, purchases, lists, cancels, collects, or automates AH behavior.
- It has no game-process HTTP client; it writes only a local outbox. A separate player-run external uploader may submit approved fields over HTTPS.
- It does not retain character/buyer/seller names, chat, raw packet bytes, inventory, account credentials, listings, or Bazaar data.

The pilot is server-controlled and begins with public pricing disabled. Public ledger/Craftbook pricing remains withheld until independent reviewed completed-sale evidence passes the declared quorum and freshness checks.
