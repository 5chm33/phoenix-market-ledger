addon.name    = 'phoenix_market_ledger';
addon.author  = 'Phoenix Market Ledger contributors';
addon.version = '0.1.0-review';
addon.desc    = 'Opt-in local log of successful Auction House purchases for Phoenix staff review.';
addon.link    = 'https://github.com/HorizonXI/PhoenixMarketLedger';

require('common');
local settings = require('settings');

-- REVIEW SAFETY CONTRACT
-- This addon never registers packet_out, never sends, blocks, rewrites, or injects a
-- packet, never opens/searches the AH, and never performs an AH action. It observes
-- only an incoming successful-purchase response that the player initiated normally.
-- It has no HTTP client. It writes a local TSV only when staff_review_approved and
-- collect_successful_purchases are explicitly enabled by the player after approval.

local AH_RESPONSE_PACKET = 0x04C;
local BID_RESPONSE       = 0x0E;
local BID_SUCCESS        = 0x01;
local REVIEW_NOTICE      = 'DO NOT ENABLE UNTIL PHOENIX STAFF APPROVES THIS EXACT RELEASE.';

local default_settings = T{
    -- This must remain false in the staff-review package and until staff approval.
    staff_review_approved = false,
    collect_successful_purchases = false,
    -- This addon writes only a local TSV. A separate player-run uploader sends it.
    -- There is no network request from the game process.
    observations_file = 'data\\observations.tsv',
};

local config = settings.load(default_settings);
local seen = {};

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
        chat('Could not create the local observation file.');
        return false;
    end
    file:write('observedAt\titemId\tside\tpriceGil\tevidence\n');
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

local function append_success(item_id, price_gil, quantity)
    if (item_id == nil or item_id <= 0 or price_gil == nil or price_gil <= 0) then
        return;
    end
    local stack_size = item_stack_size(item_id);
    if (stack_size == nil) then
        chat(('Skipped an unknown item id %d.'):fmt(item_id));
        return;
    end
    local side = quantity > 1 and 'stack' or 'single';
    if (side == 'stack' and stack_size <= 1) then
        chat(('Skipped impossible stack result for item id %d.'):fmt(item_id));
        return;
    end
    local now = os.time();
    -- Local replay protection. The server applies its own contributor-safe dedupe.
    local fingerprint = ('%d:%s:%d:%d'):fmt(item_id, side, price_gil, math.floor(now / 300));
    if (seen[fingerprint]) then
        return;
    end
    seen[fingerprint] = true;
    local path = observations_path();
    if (not ensure_header(path)) then
        return;
    end
    local file = io.open(path, 'a');
    if (file == nil) then
        chat('Could not append the local observation file.');
        return;
    end
    file:write(('%s\t%d\t%s\t%d\tah_sale_observed\n'):fmt(os.date('!%Y-%m-%dT%H:%M:%SZ', now), item_id, side, price_gil));
    file:close();
    chat(('Recorded local %s purchase: item %d at %d gil. Run the separate uploader when you choose to contribute it.'):fmt(side, item_id, price_gil));
end

local function enabled()
    return config.staff_review_approved and config.collect_successful_purchases;
end

ashita.events.register('load', 'pml_load_cb', function ()
    ensure_header(observations_path());
    if (not config.staff_review_approved) then
        chat(REVIEW_NOTICE);
    end
end);

ashita.events.register('command', 'pml_command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or args[1]:lower() ~= '/pml') then
        return;
    end
    e.blocked = true;
    local action = (args[2] or 'status'):lower();
    if (action == 'status') then
        chat(('collector=%s; staff approval=%s; local file=%s'):fmt(config.collect_successful_purchases and 'on' or 'off', config.staff_review_approved and 'confirmed' or 'required', observations_path()));
        return;
    end
    if (action == 'on') then
        if (not config.staff_review_approved) then
            chat(REVIEW_NOTICE);
            return;
        end
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
    -- Packet offsets are based on the published LandSandBoat 0x04C layout and
    -- must be reconfirmed by Phoenix staff before enabling the reviewed addon.
    local response_type = e.data:byte(5); -- packet offset 4
    local result = e.data:byte(7);        -- packet offset 6
    if (response_type ~= BID_RESPONSE or result ~= BID_SUCCESS) then
        return;
    end
    -- GP_AUC_PARAM_BID begins at packet offset 8: u32 bid price, u16 item id,
    -- then the delivered quantity. This observes a normal successful bid only.
    local price_gil = u32(e.data, 8);
    local item_id = u16(e.data, 12);
    local quantity = e.data:byte(15); -- packet offset 14
    append_success(item_id, price_gil, quantity);
end);
