# Phoenix Market Ledger — staff review request

**Status:** Review-only. Do not use on Phoenix until Phoenix staff approves this exact source and release.

`phoenix_market_ledger` is an Ashita v4 addon that can create an opt-in **local TSV record** after a player personally completes a normal Auction House purchase. It does not make a network request from the game process. A separate player-run PowerShell uploader can submit the selected local TSV to the independent Phoenix Market Ledger service.

## Exact behavior

When enabled after staff approval, the addon registers one **incoming-only** packet handler. It watches the normal Auction House response packet `0x04C` and logs a row only when the response is a successful bid. Each row contains:

```
observedAt, itemId, side (single or stack), priceGil, evidence=ah_sale_observed
```

It does not persist player name, buyer name, seller name, chat text, listing data, raw packet bytes, inventory content, IP address, game credential, or Phoenix account credential.

## Explicit non-behavior

The addon does **not**:

- Register an outgoing packet callback.
- Send, inject, block, delay, modify, replay, or construct any game packet.
- Open the AH, search the AH, list, bid, purchase, cancel, collect, or automate any AH action.
- Inspect Bazaar data.
- Call HTTP/S, load a browser, or transmit from the game process.
- Enable collection by default. Both `staff_review_approved` and `collect_successful_purchases` must be manually set/confirmed after staff approval.

## Upload and public aggregation

The optional PowerShell uploader reads the local TSV only when a player runs it. It sends only the five fields above through HTTPS using a revocable collector key. The service stores the key only as a hash. The server deduplicates submissions, accepts data only from the past seven days, and keeps every observation pending until review. Public prices and Craftbook exports require at least three **approved** observations for the same item and side, with a latest observation under six hours old.

The server is also disabled by default: it rejects collector-key creation and all observation uploads until its operator explicitly enables the reviewed release after written Phoenix staff approval. This prevents the review package from becoming a live collector merely by being installed.

Pending observations, one-off prices, Bazaar asks, active listings, and packet bytes never appear in public prices or Craftbook profit calculations.

## Source and verification

The package includes all Lua and PowerShell source. The protocol layout is based on LandSandBoat’s published `0x04C` server packet implementation and is deliberately marked for Phoenix staff confirmation before enabling. The project will change its parser or remove the observer if Phoenix’s live protocol/policy requires it.

Please evaluate this exact package rather than treating Craftbook approval as approval for this separate addon.
