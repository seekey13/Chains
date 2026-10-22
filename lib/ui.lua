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
local imgui = require('imgui');

-- Unscaled pixels. lo, hi, default. The screen scale is applied later by S().
local LIMITS = {
    pad   = { 8,  48, 18 },
    title = { 11, 32, 16 },
    timer = { 11, 32, 16 },
    body  = { 11, 28, 16 },
    small = { 10, 24, 13 },
};

--[[
* Fill any missing size and clamp the rest. scale multiplies the defaults
* the first time a key is absent, which is how an old /chains scale carries
* over. Later edits from the panel are left alone.
--]]
function ui.normalize(look, scale)
    if (type(look) ~= 'table') then
        look = { };
    end
    scale = tonumber(scale) or 1;
    if (scale ~= scale) then
        scale = 1;
    end
    for key, lim in pairs(LIMITS) do
        local v = tonumber(look[key]);
        if (v == nil or v ~= v) then
            v = lim[3] * scale;
        end
        look[key] = math.max(lim[1], math.min(lim[2], math.floor(v + 0.5)));
    end
    return look;
end

local SAMPLE = {
    mode = 'live',
    status = 'go',
    seconds = 8,
    step = 2,
    name = 'Savage Blade',
    props = { 'Fusion' },
    burst = { 'Fire', 'Light' },
    next = {
        { name = 'Full Break', level = 3, prop = 'Light' },
        { name = 'Circle Blade', level = 2, prop = 'Distortion' },
    },
};

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
* look is the size table from settings: pad, title, timer, body, small,
* in unscaled pixels. Nil uses the defaults.
*
* Returns { w, h, paint(dl, x, y) -> closed }. w and h include the shadow
* the plate throws, so the window is that size and the plate sits inside it.
--]]
function ui.layout(model, look)
    local st = vana;
    local P = st.P;
    look = ui.normalize(look);
    -- One padding inset, and a text size for each role on the plate.
    -- The warp list's pitch still floors the rows, and the title bar
    -- stays at least the settings panel's 44.
    local pad = st.S(look.pad);
    local margin_l = pad;
    local margin_r = pad;
    local title_px = st.S(look.title);
    local body = st.S(look.body);
    local small = st.S(look.small);
    local num_px = st.S(look.timer);
    local tag_px = st.S(math.max(10, look.timer - 3));
    local pitch = math.max(st.S(24), body + st.S(8), small + st.S(10));
    local head_gap = math.max(st.S(6), math.floor(pad * 0.4));
    local head_h = math.max(st.S(26), small + st.S(10));
    local after_title = math.max(st.S(6), math.floor(pad * 0.55));
    local bottom = math.max(st.S(8), math.floor(pad * 0.7));
    local gap = math.max(st.S(6), math.floor(pad * 0.4));
    local chip_h = math.max(st.S(20), small + st.S(6));
    local chip_pad = math.max(st.S(6), math.floor(pad * 0.3));
    local title_h = math.max(st.S(44), title_px + st.S(18), num_px + st.S(16));
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
            local ph = math.max(st.S(24), num_px + st.S(8), tag_px + st.S(8));
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

        local function section(x, cy, str)
            local title = string.upper(str);
            local spacing = math.max(1, st.S(1.2));
            local tw = st.text_spaced(dl, x, cy, title, P.teal, 'semi_italic', small, spacing);
            local line_x = x + tw + st.S(10);
            local line_end = x + inner;
            if (line_end > line_x) then
                dl:AddLine({ line_x, cy }, { line_end, cy }, st.u32(P.teal, 0.35), 1);
            end
        end

        local yb = py + title_h + 1 + after_title;
        for _, block in ipairs(blocks) do
            if (block.kind == 'head') then
                yb = yb + head_gap;
                section(lx, yb + head_h / 2, block.text);
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

local EDITOR_ROWS = {
    { 'Padding', 'pad',   4 },
    { 'Title',   'title', 2 },
    { 'Timer',   'timer', 2 },
    { 'Body',    'body',  2 },
    { 'Small',   'small', 2 },
};

local function mouse_xy()
    local ax, ay = imgui.GetMousePos();
    if (type(ax) == 'number') then
        return ax, ay;
    end
    if (type(ax) == 'table') then
        return ax.x or ax[1], ax.y or ax[2];
    end
    return nil, nil;
end

--[[
* The /chains panel: a sample chain, then a stepper for the plate's padding
* and one for each text role. look is mutated in place. color is the
* property-hue toggle, so the sample matches the live plate.
*
* paint returns closed, changed, typing.
--]]
function ui.editor(look, color)
    local st = vana;
    local P = st.P;
    look = ui.normalize(look);
    local sample = ui.layout({
        mode = 'live',
        status = SAMPLE.status,
        seconds = SAMPLE.seconds,
        step = SAMPLE.step,
        name = SAMPLE.name,
        props = SAMPLE.props,
        burst = SAMPLE.burst,
        next = SAMPLE.next,
        color = color ~= false,
    }, look);

    local margin_l = st.S(24);
    local margin_r = st.S(18);
    local title_h = st.S(44);
    local title_px = st.S(st.BODY);
    local label_px = title_px;
    local line_h = st.S(30);
    local head_gap = st.S(8);
    local head_h = st.S(26);
    local bottom = st.S(14);
    local close_box = st.S(21);
    local ctrl_w = st.S(110);
    local label_w = 0;
    for _, row in ipairs(EDITOR_ROWS) do
        label_w = math.max(label_w, st.measure(row[1], 'text', label_px));
    end
    local inner = math.max(label_w + st.S(18) + ctrl_w, sample.w);
    local title_w = st.measure('Chains', 'semi', title_px);
    local panel_w = math.max(
        margin_l + inner + margin_r,
        margin_l + title_w + st.S(10) + close_box + margin_r);
    -- Title, Sample heading, the preview, Look heading, one row per stepper.
    local panel_h = title_h + 1
        + head_gap + head_h + sample.h + st.S(8)
        + head_gap + head_h + line_h * #EDITOR_ROWS
        + bottom;

    local function paint(dl, x, y)
        local px, py = x + 1, y;
        st.plate(dl, px, py, panel_w, panel_h);
        local lx = px + margin_l;
        local rx = px + panel_w - margin_r;
        local title_cy = py + title_h / 2;
        st.title(dl, lx, title_cy, 'Chains', title_px);
        local hit, hot = st.close('##chains_edit_x', rx - close_box / 2, title_cy, close_box, false);
        if (hot) then
            st.tooltip('Close');
        end
        dl:AddLine({ px, py + title_h }, { px + panel_w, py + title_h }, st.u32(P.border), 1);

        local yb = py + title_h + 1;
        local function heading(name)
            yb = yb + head_gap;
            st.heading(dl, lx, yb + st.S(12), name, rx - lx);
            yb = yb + head_h;
        end

        heading('Sample');
        sample.paint(dl, lx, yb);
        yb = yb + sample.h + st.S(8);

        heading('Look');
        local mx, my = mouse_xy();
        local win = false;
        pcall(function ()
            win = imgui.IsWindowHovered() and true or false;
        end);
        local changed, typing = false, false;
        for _, row in ipairs(EDITOR_ROWS) do
            local top = yb;
            local cy = top + line_h / 2;
            yb = yb + line_h;
            local band = win and mx ~= nil and my ~= nil
                and mx >= px + st.S(4) and mx < px + panel_w - st.S(4)
                and my >= top and my < top + line_h;
            if (band) then
                st.fill(dl, px + st.S(4), top, panel_w - st.S(8), line_h, P.hover, st.S(3), 0.8);
            end
            st.label(dl, lx, cy, row[1], label_px);
            local lim = LIMITS[row[2]];
            local value, edited, typing_row, hot_row = st.stepper(
                '##chains_' .. row[2], rx - ctrl_w, cy, ctrl_w,
                look[row[2]], lim[1], lim[2], 1, row[3]);
            if (edited) then
                look[row[2]] = value;
                changed = true;
            end
            typing = typing or typing_row;
        end
        return hit and true or false, changed, typing;
    end

    return { w = panel_w + 2, h = panel_h + 2, paint = paint };
end

return ui;
