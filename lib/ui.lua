--[[
* Chains panel, in the Vanacore look UberMap uses for its settings panel
* and warp list. lib/vana.lua is that look. This file only places the
* skillchain rows on the plate.
*
* The title bar, margins, row pitch and teal headings are the settings
* panel's. The list itself is as tight as the warp list. Gameplay hues stay
* the old property colors, lightened where a dark hue would sink into the
* navy ground. With color off, every property is body text.
--]]

local ui = { };
local vana = require('lib.vana');

-- The skillchain palette (Sammeh), as '#RRGGBB'.
local RAW = {
    Light = '#FFFFFF',
    Dark = '#0000CC',
    Ice = '#00FFFF',
    Water = '#00FFFF',
    Earth = '#998000',
    Wind = '#66FF66',
    Fire = '#FF0000',
    Lightning = '#FF00FF',
    Gravitation = '#663300',
    Fragmentation = '#FF99FF',
    Fusion = '#FF6666',
    Distortion = '#3399FF',
    Darkness = '#0000CC',
    Umbra = '#0000CC',
    Compression = '#0000CC',
    Radiance = '#FFFFFF',
    Transfixion = '#FFFFFF',
    Induration = '#00FFFF',
    Reverberation = '#00FFFF',
    Scission = '#998000',
    Detonation = '#66FF66',
    Liquefaction = '#FF0000',
    Impaction = '#FF00FF',
};

local DARK_FAMILY = {
    Dark = true,
    Darkness = true,
    Umbra = true,
    Compression = true,
};

local PROP = { };

local function prepare(name, hex)
    local r = tonumber(hex:sub(2, 3), 16);
    local g = tonumber(hex:sub(4, 5), 16);
    local b = tonumber(hex:sub(6, 7), 16);
    if (DARK_FAMILY[name] or math.max(r, g, b) < 170) then
        local t = DARK_FAMILY[name] and 0.62 or 0.5;
        return vana.mix(hex, '#FFFFFF', t);
    end
    return hex;
end

for name, hex in pairs(RAW) do
    PROP[name] = prepare(name, hex);
end

local function prop_hex(name, enabled)
    if (not enabled) then
        return vana.P.text;
    end
    return PROP[name] or vana.P.text2;
end

function ui.bake()
    vana.bake();
end

function ui.frame(user)
    vana.user = user;
    vana.frame();
end

--[[
* model:
*   mode     'live' or 'move'
*   status   'wait', 'go', or 'burst' (live)
*   seconds  remaining count
*   step     chain step
*   name     action that opened the window
*   bound    chainbound level, or nil
*   props    resonating properties
*   burst    burst elements when step > 1, or nil
*   next     { name, level, prop } highest level first, or nil when closed
*   color    property hues on
*
* Returns { w, h, paint(dl, x, y) -> closed }. w and h include the shadow
* the plate throws, so the window is that size and the plate sits inside it.
--]]
function ui.layout(model)
    local st = vana;
    local P = st.P;
    -- Settings panel: 24 in from the left, 18 from the right, a 44px title
    -- bar, 14 under the last row. Rows are the warp list's pitch.
    local margin_l = st.S(24);
    local margin_r = st.S(18);
    local title_h = st.S(44);
    local title_px = st.S(st.BODY);
    local body = title_px;
    local small = st.S(st.SMALL);
    local pitch = math.max(st.S(24), body + st.S(8));
    local head_gap = st.S(8);
    local head_h = st.S(26);
    local after_title = st.S(10);
    local bottom = st.S(14);
    local gap = st.S(8);
    local num_px = st.S(st.BODY);
    local tag_px = st.S(st.SMALL);
    local chip_h = st.S(20);
    local chip_pad = st.S(7);
    local radius = st.S(4);
    local close_box = st.S(21);

    local function chip_width(label)
        return st.measure(label, 'text', small) + chip_pad * 2;
    end

    local function chips_width(list)
        local w = 0;
        for i, name in ipairs(list) do
            if (i > 1) then
                w = w + gap;
            end
            w = w + chip_width(name);
        end
        return w;
    end

    local word, secs, pill_w, num_slot = nil, 0, 0, 0;
    if (model.mode == 'live' and model.status ~= nil) then
        word = (model.status == 'wait' and 'WAIT')
            or (model.status == 'go' and 'GO')
            or 'BURST';
        secs = math.max(0, math.floor((tonumber(model.seconds) or 0) + 0.5));
        num_slot = math.max(
            st.measure(tostring(secs), 'semi', num_px),
            st.measure('88', 'semi', num_px));
        pill_w = st.S(8) * 2 + st.measure(word, 'semi', tag_px) + st.S(6) + num_slot;
    end

    local title_w = st.measure('Chains', 'semi', title_px);
    local corner = (model.mode == 'live') and pill_w or close_box;
    local inner = title_w + st.S(10) + corner;
    local blocks = { };

    if (model.mode ~= 'live') then
        local hint = 'Drag to move';
        inner = math.max(inner, st.measure(hint, 'text', small));
        blocks[1] = { kind = 'hint', text = hint };
    else
        local step = ('Step %d'):format(tonumber(model.step) or 0);
        local step_w = st.measure(step, 'text', small);
        local name = tostring(model.name or '');
        inner = math.max(inner, step_w + gap + st.measure(name, 'text', body));
        blocks[#blocks + 1] = {
            kind = 'step', step = step, step_w = step_w, name = name,
        };

        if (model.bound) then
            local label = ('Chainbound Lv.%d'):format(model.bound);
            inner = math.max(inner, chip_width(label));
            blocks[#blocks + 1] = { kind = 'bound', text = label };
        elseif (model.props ~= nil and #model.props > 0) then
            inner = math.max(inner, chips_width(model.props));
            blocks[#blocks + 1] = { kind = 'chips', list = model.props };
        end

        if (model.burst ~= nil and #model.burst > 0) then
            blocks[#blocks + 1] = { kind = 'head', text = 'Burst' };
            inner = math.max(inner, chips_width(model.burst));
            blocks[#blocks + 1] = { kind = 'chips', list = model.burst };
        end

        local rows = model.next;
        if (rows ~= nil) then
            blocks[#blocks + 1] = { kind = 'head', text = 'Next' };
            if (#rows == 0) then
                local hint = 'None ready';
                inner = math.max(inner, st.measure(hint, 'text', small));
                blocks[#blocks + 1] = { kind = 'hint', text = hint };
            else
                -- Columns share one width, so a long name and a long property
                -- on different rows still clear each other.
                local prop_w, lv_w, name_w = 0, 0, 0;
                for _, row in ipairs(rows) do
                    local lv = 'Lv.' .. tostring(row.level or 0);
                    lv_w = math.max(lv_w, st.measure(lv, 'text', small));
                    prop_w = math.max(prop_w, st.measure(tostring(row.prop or ''), 'text', body));
                    name_w = math.max(name_w, st.measure(tostring(row.name or ''), 'text', body));
                end
                inner = math.max(inner, name_w + gap + lv_w + gap + prop_w);
                for _, row in ipairs(rows) do
                    blocks[#blocks + 1] = {
                        kind = 'next', row = row, prop_w = prop_w, lv_w = lv_w,
                    };
                end
            end
        end
    end

    inner = math.max(inner, st.S(220));
    local w = margin_l + inner + margin_r;
    local h = title_h + 1 + after_title + bottom;
    for _, block in ipairs(blocks) do
        if (block.kind == 'head') then
            h = h + head_gap + head_h;
        else
            h = h + pitch;
        end
    end

    local function draw_chips(dl, x, cy, list, bound)
        local cursor = x;
        for _, name in ipairs(list) do
            local label = tostring(name);
            local cw = chip_width(label);
            local top = cy - chip_h / 2;
            if (bound) then
                st.fill(dl, cursor, top, cw, chip_h, P.accent_bg, radius, 1);
                st.outline(dl, cursor, top, cw, chip_h, P.accent_lo, radius, 1);
                st.text_mid(dl, cursor + chip_pad, cy, label, P.accent2, 'text', small);
            else
                st.fill(dl, cursor, top, cw, chip_h, P.well, radius, 1);
                st.outline(dl, cursor, top, cw, chip_h, P.well_edge, radius, 1);
                st.text_mid(dl, cursor + chip_pad, cy, label,
                    prop_hex(label, model.color), 'text', small);
            end
            cursor = cursor + cw + gap;
        end
    end

    -- true when the move-mode close mark was clicked.
    local function paint(dl, x, y)
        -- The shadow sits 1px left and right of the plate and 2px under it.
        -- The window is that much larger, or the shadow is clipped away.
        local px, py = x + 1, y;
        st.plate(dl, px, py, w, h);

        local lx = px + margin_l;
        local rx = px + w - margin_r;
        local title_cy = py + title_h / 2;
        st.title(dl, lx, title_cy, 'Chains', title_px);

        local closed = false;
        if (word ~= nil) then
            local hex = (model.status == 'wait' and P.rose)
                or (model.status == 'go' and P.teal)
                or P.amber;
            local ph = st.S(24);
            local pill_y = title_cy - ph / 2;
            local pill_x = rx - pill_w;
            st.fill(dl, pill_x, pill_y, pill_w, ph, st.mix(P.well, hex, 0.22), ph / 2, 1);
            st.outline(dl, pill_x, pill_y, pill_w, ph, st.mix(P.well_edge, hex, 0.7), ph / 2, 1);
            local tx = pill_x + st.S(8);
            st.text_mid(dl, tx, title_cy, word, hex, 'semi', tag_px);
            tx = tx + st.measure(word, 'semi', tag_px) + st.S(6);
            local shown = tostring(secs);
            local nw = st.measure(shown, 'semi', num_px);
            st.text_mid(dl, tx + num_slot - nw, title_cy, shown, P.white, 'semi', num_px);
        else
            local hit, hot = st.close('##chains_x', rx - close_box / 2, title_cy, close_box, false);
            closed = hit and true or false;
            if (hot) then
                st.tooltip('Close');
            end
        end

        dl:AddLine({ px, py + title_h }, { px + w, py + title_h }, st.u32(P.border), 1);

        local yb = py + title_h + 1 + after_title;
        for _, block in ipairs(blocks) do
            if (block.kind == 'head') then
                yb = yb + head_gap;
                st.heading(dl, lx, yb + st.S(12), block.text, inner);
                yb = yb + head_h;
            else
                local cy = yb + pitch / 2;
                if (block.kind == 'hint') then
                    st.text_mid(dl, lx, cy, block.text, P.faint, 'text', small);
                elseif (block.kind == 'step') then
                    st.text_mid(dl, lx, cy, block.step, P.dim, 'text', small);
                    st.text_mid(dl, lx + block.step_w + gap, cy, block.name, P.text, 'text', body);
                elseif (block.kind == 'bound') then
                    draw_chips(dl, lx, cy, { block.text }, true);
                elseif (block.kind == 'chips') then
                    draw_chips(dl, lx, cy, block.list, false);
                elseif (block.kind == 'next') then
                    local row = block.row;
                    local prop = tostring(row.prop or '');
                    local lv = 'Lv.' .. tostring(row.level or 0);
                    st.text_mid(dl, lx, cy, tostring(row.name or ''), P.text, 'text', body);
                    local prop_x = lx + inner - block.prop_w;
                    st.text_mid(dl, prop_x - gap - block.lv_w, cy, lv, P.dim, 'text', small);
                    st.text_mid(dl, prop_x, cy, prop, prop_hex(prop, model.color), 'text', body);
                end
                yb = yb + pitch;
            end
        end
        return closed;
    end

    -- +2 is the shadow: 1px to either side, 2px under, none above.
    return { w = w + 2, h = h + 2, paint = paint };
end

return ui;
