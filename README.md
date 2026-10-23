# Phoenix Market Ledger

A PhoenixXI-approved, opt-in Ashita v4 collector for community Auction House sale evidence.

## What it does

When you explicitly enable it with `/pml on`, the addon records only your own **successful normal AH purchases** to a local outbox. It observes incoming data only.

It does **not** search, bid, buy, sell, list, cancel, automate AH activity, modify packets, or make network requests from the game client. It records no names, chat, raw packets, account data, listings, or Bazaar data.

A separate optional PowerShell uploader can submit the local queue over HTTPS when you run it. Its revocable upload key is prompted at runtime and is never saved in the addon or queue.

## Install

1. Copy `phoenix_market_ledger` to your Ashita `addons` directory.
2. Load it in game and run `/pml status`.
3. Run `/pml on` to opt in, or `/pml off` to stop local capture immediately.
4. Create a revocable upload key in the Phoenix Market Ledger website.
5. Outside the game, run `phoenix_market_ledger\tools\upload-observations.ps1` when you choose to submit queued rows. Add `-Watch` only if you deliberately want the separate uploader process to watch the local queue; stop it with `Ctrl+C`.

## Commands

| Command | Action |
| --- | --- |
| `/pml status` | Displays capture state and local queue path. |
| `/pml on` | Starts local successful-purchase capture. |
| `/pml off` | Stops capture immediately. |
| `/pml file` | Displays the local queue path. |

## Data quality and privacy

Each row has a random event ID, release metadata, UTC time, item ID, exact delivered quantity, gil paid, and a completed-sale marker. The collector and server reject quantities other than one item or a full stack.

Submitted rows are reviewed. Public market prices and Craftbook fallback prices require at least **three reviewed sales from three different contributors**, for the same single/stack side, within seven days, with recent evidence. Bazaar asks, listings, manual entries, thin samples, and external market providers are excluded. Your manual Craftbook prices always take priority.

## License

[GPL-3.0](LICENSE)
