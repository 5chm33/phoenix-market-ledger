addon.name    = 'phoenix_market_ledger';
addon.author  = 'Phoenix Market Ledger contributors';
addon.version = '0.2.0';
addon.desc    = 'Opt-in local capture of successful Phoenix Auction House purchases.';
addon.link    = 'https://github.com/5chm33/phoenix-market-ledger';

require('common');
local settings = require('settings');

-- SAFETY CONTRACT
-- This addon never registers packet_out, never sends, blocks, rewrites, or injects
-- a packet, never opens/searches the AH, and never performs an AH action. It reads
-- only a normal incoming successful-purchase response initiated by the player.
-- It has no HTTP client. It appends a local outbox row only when the player opts in.

local AH_RESPONSE_PACKET = 0x04C;
local BID_RESPONSE       = 0x0E;
local BID_SUCCESS        = 0x01;
local SCHEMA_VERSION     = 'pml-1';
local RELEASE_VERSION    = addon.version;
local DEDUPE_WINDOW      = 5 * 60;
local MAX_SEEN           = 512;

local default_settings = T{
    -- Opt-in is per player and can be turned off immediately with /pml off.
    collect_successful_purchases = false,
    -- This is a local outbox only. The optional external uploader is separate.
    observations_file = 'data\\observations.tsv',
};

local config = settings.load(default_settings);
local seen = {};
local event_sequence = 0;

local function chat(message)
    print(('[Phoenix Market Ledger] %s'):fmt(message));
end

local function u16(data, offset)
    return data:byte(offset + 1) + data:byte(offset + 2) * 256;
end

local function u32(data, offset)
    return data:byte(offset + 1)
        + data:byte(offset + 2) * 256
        + data:byte(offset + 3) * 65536
        + data:byte(offset + 4) * 16777216;
end

local function observations_path()
    return ('%s\\config\\addons\\%s\\%s'):fmt(AshitaCore:GetInstallPath(), addon.name, config.observations_file);
end

local function ensure_header(path)
    local file = io.open(path, 'r');
    if (file ~= nil) then
        file:close();
        return true;
    end
    file = io.open(path, 'w');
    if (file == nil) then
        chat('Could not create the local observation file. Collection remains local-only and will retry next purchase.');
        return false;
    end
    file:write('eventId\tschemaVersion\treleaseVersion\tobservedAt\titemId\tquantity\tpriceGil\tevidence\n');
    file:close();
    return true;
end

local function item_stack_size(item_id)
    local item = AshitaCore:GetResourceManager():GetItemById(item_id);
    if (item == nil) then
        return nil;
    end
    return item.StackSize or 1;
end

local function prune_seen(now)
    local count = 0;
    for key, observed_at in pairs(seen) do
        if (now - observed_at > DEDUPE_WINDOW) then
            seen[key] = nil;
        else
            count = count + 1;
        end
    end
    -- A bounded cache is only replay suppression. It must never grow for a long session.
    if (count > MAX_SEEN) then
        seen = {};
    end
end

local function next_event_id(now, item_id, price_gil, quantity)
    event_sequence = event_sequence + 1;
    return ('pml_%d_%d_%d_%d_%d'):fmt(now, item_id, price_gil, quantity, event_sequence);
end

local function append_success(item_id, price_gil, quantity)
    if (item_id == nil or item_id <= 0 or price_gil == nil or price_gil <= 0 or quantity == nil) then
        return;
    end
    local stack_size = item_stack_size(item_id);
    if (stack_size == nil) then
        chat(('Skipped unknown item id %d.'):fmt(item_id));
        return;
    end
    -- Fail closed: a partial or unknown delivered quantity never becomes a
    -- single/stack price. The server repeats this validation independently.
    if (quantity ~= 1 and quantity ~= stack_size) then
        chat(('Skipped unqualified quantity %d for item %d (expected 1 or %d).'):fmt(quantity, item_id, stack_size));
        return;
    end
    local now = os.time();
    prune_seen(now);
    local local_key = ('%d:%d:%d:%d'):fmt(item_id, quantity, price_gil, math.floor(now / DEDUPE_WINDOW));
    if (seen[local_key]) then
        return;
    end
    seen[local_key] = now;
    local path = observations_path();
    if (not ensure_header(path)) then
        return;
    end
    local file = io.open(path, 'a');
    if (file == nil) then
        chat('Could not append the local observation file.');
        return;
    end
    local event_id = next_event_id(now, item_id, price_gil, quantity);
    file:write(('%s\t%s\t%s\t%s\t%d\t%d\t%d\tah_sale_observed\n'):fmt(
        event_id,
        SCHEMA_VERSION,
        RELEASE_VERSION,
        os.date('!%Y-%m-%dT%H:%M:%SZ', now),
        item_id,
        quantity,
        price_gil
    ));
    file:close();
    local side = quantity == 1 and 'single' or 'full stack';
    chat(('Recorded local %s purchase: item %d at %d gil. The separate optional uploader can contribute it.'):fmt(side, item_id, price_gil));
end

local function enabled()
    return config.collect_successful_purchases;
end

ashita.events.register('load', 'pml_load_cb', function ()
    ensure_header(observations_path());
    chat('Read-only collector loaded. Uploading is separate and never occurs from the game client. Use /pml status, /pml on, or /pml off.');
end);

ashita.events.register('command', 'pml_command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or args[1]:lower() ~= '/pml') then
        return;
    end
    e.blocked = true;
    local action = (args[2] or 'status'):lower();
    if (action == 'status') then
        chat(('collector=%s; release=%s; local file=%s'):fmt(config.collect_successful_purchases and 'on' or 'off', RELEASE_VERSION, observations_path()));
        return;
    end
    if (action == 'on') then
        config.collect_successful_purchases = true;
        settings.save();
        chat('Local successful-purchase logging enabled. No data is uploaded from the game client.');
        return;
    end
    if (action == 'off') then
        config.collect_successful_purchases = false;
        settings.save();
        chat('Local successful-purchase logging disabled.');
        return;
    end
    if (action == 'file') then
        chat(('Local observation file: %s'):fmt(observations_path()));
        return;
    end
    chat('Commands: /pml status | on | off | file');
end);

ashita.events.register('packet_in', 'pml_packet_in_cb', function (e)
    if (not enabled() or e.id ~= AH_RESPONSE_PACKET or e.data == nil or #e.data < 16) then
        return;
    end
    -- These offsets are deliberately fail-closed and must be fixture-verified for
    -- every Phoenix client protocol update before a new collector version ships.
    local response_type = e.data:byte(5); -- packet offset 4
    local result = e.data:byte(7);        -- packet offset 6
    if (response_type ~= BID_RESPONSE or result ~= BID_SUCCESS) then
        return;
    end
    -- GP_AUC_PARAM_BID begins at packet offset 8: u32 bid price, u16 item ID,
    -- then delivered quantity. This observes a normal successful bid only.
    local price_gil = u32(e.data, 8);
    local item_id = u16(e.data, 12);
    local quantity = e.data:byte(15); -- packet offset 14
    append_success(item_id, price_gil, quantity);
end);
