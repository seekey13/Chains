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
    timer = { 11, 32, 16 },
    body  = { 11, 28, 16 },
    small = { 10, 24, 13 },
};

-- The text roles /chains scale sets together. Padding is left alone.
local TEXT_ROLES = { 'timer', 'body', 'small' };

--[[
* Fill any missing size with its default and clamp the rest to whole pixels
* inside its limits.
--]]
function ui.normalize(look)
    if (type(look) ~= 'table') then
        look = { };
    end
    for key, lim in pairs(LIMITS) do
        local v = tonumber(look[key]);
        if (v == nil or v ~= v) then
            v = lim[3];
        end
        look[key] = math.max(lim[1], math.min(lim[2], math.floor(v + 0.5)));
    end
    return look;
end

--[[
* Every text role at its default times n, so n = 1 is the defaults again.
* This is /chains scale, and how an old font_scale carries over once.
--]]
function ui.scale_look(look, n)
    for _, key in ipairs(TEXT_ROLES) do
        look[key] = LIMITS[key][3] * n;
    end
    return ui.normalize(look);
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

function ui.frame()
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
* look is the size table from settings: pad, timer, body, small, in
* unscaled pixels. Nil uses the defaults.
*
* Returns { w, h, paint(dl, x, y) -> closed }. w and h include the shadow
* the plate throws, so the window is that size and the plate sits inside it.
--]]
function ui.layout(model, look)
    local st = vana;
    local P = st.P;
    look = ui.normalize(look);
    -- One padding inset, and a text size for each role on the plate.
    -- The timer's top inset matches its right inset. The weapon skill
    -- starts on the bottom of the step text.
    local pad = st.S(look.pad);
    local margin_l = pad;
    local margin_r = pad;
    local body = st.S(look.body);
    local small = st.S(look.small);
    local num_px = st.S(look.timer);
    local tag_px = st.S(math.max(10, look.timer - 3));
    local head_gap = math.max(st.S(6), math.floor(pad * 0.4));
    local bottom = math.max(st.S(8), math.floor(pad * 0.7));
    local gap = math.max(st.S(6), math.floor(pad * 0.4));
    local chip_pad = math.max(st.S(6), math.floor(pad * 0.3));
    local radius = st.S(4);
    local close_box = st.S(21);

    -- Names are the action, the follow-ups, a property such as Fusion, and
    -- the elements listed under Burst. Section headings stay on Headers.
    local function head_h(px)
        return math.max(st.S(26), px + st.S(10));
    end

    local function chip_h(px)
        return math.max(st.S(20), px + st.S(6));
    end

    local function chip_width(label, px)
        return st.measure(label, 'text', px) + chip_pad * 2;
    end

    local function chips_width(list, px)
        local w = 0;
        for i, name in ipairs(list) do
            if (i > 1) then
                w = w + gap;
            end
            w = w + chip_width(name, px);
        end
        return w;
    end

    local word, secs, pill_w, pill_h, num_slot = nil, 0, 0, 0, 0;
    if (model.mode == 'live' and model.status ~= nil) then
        word = (model.status == 'wait' and 'WAIT')
            or (model.status == 'go' and 'GO')
            or 'BURST';
        -- A countdown: 2.1s left reads 3, and 0 only once it has run out.
        secs = math.max(0, math.ceil(tonumber(model.seconds) or 0));
        num_slot = math.max(
            st.measure(tostring(secs), 'semi', num_px),
            st.measure('88', 'semi', num_px));
        pill_w = st.S(8) * 2 + st.measure(word, 'semi', tag_px) + st.S(6) + num_slot;
        pill_h = math.max(st.S(24), num_px + st.S(8), tag_px + st.S(8));
    end
    -- Move mode's single line. The live step line is only as tall as its text.
    local title_h = math.max(st.S(32), small + st.S(14));
    local pitch = math.max(st.S(24), body + st.S(8), small + st.S(10));

    local step_label = nil;
    local step_h = 0;
    local inner = 0;
    local blocks = { };

    if (model.mode ~= 'live') then
        local hint = 'Drag to move';
        inner = st.measure(hint, 'text', small) + gap + close_box;
    else
        step_label = ('Step %d'):format(tonumber(model.step) or 0);
        local name = tostring(model.name or '');
        local step_w, measured_h = st.measure(step_label, 'text', small);
        local name_w, name_h = st.measure(name, 'text', body);
        step_h = measured_h;
        -- The pill hangs past the step when it is taller, so the skill
        -- keeps clear of it on the right.
        local name_span = name_w;
        if (pill_h > step_h) then
            name_span = name_w + gap + pill_w;
        end
        inner = math.max(step_w + gap + pill_w, name_span);
        blocks[#blocks + 1] = { kind = 'skill', name = name, h = name_h };

        if (model.bound) then
            local label = ('Chainbound Lv.%d'):format(model.bound);
            inner = math.max(inner, chip_width(label, small));
            blocks[#blocks + 1] = { kind = 'bound', text = label };
        elseif (model.props ~= nil and #model.props > 0) then
            inner = math.max(inner, chips_width(model.props, body));
            blocks[#blocks + 1] = { kind = 'chips', list = model.props, px = body };
        end

        if (model.burst ~= nil and #model.burst > 0) then
            blocks[#blocks + 1] = { kind = 'head', text = 'Burst' };
            inner = math.max(inner, chips_width(model.burst, body));
            blocks[#blocks + 1] = { kind = 'chips', list = model.burst, px = body };
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
    -- Live: the right inset, repeated above the step and the timer.
    -- The weapon skill then begins with nothing between it and the step.
    -- Rows after it start under the pill: a large timer over small text is
    -- taller than the step and the skill together, and would sit on the
    -- property chips.
    local pill_floor = (pill_h > 0) and (margin_r + pill_h) or 0;
    local h = (step_label ~= nil) and (margin_r + step_h) or title_h;
    if (#blocks > 0) then
        h = h + bottom;
        for _, block in ipairs(blocks) do
            if (block.kind == 'head') then
                h = h + head_gap + head_h(block.px or small);
            elseif (block.kind == 'skill') then
                local below = math.max(0, math.floor((pitch - block.h) / 2));
                h = math.max(h + block.h + below, pill_floor + bottom);
            else
                h = h + pitch;
            end
        end
    end
    if (pill_h > 0) then
        h = math.max(h, margin_r + pill_h + bottom);
    end

    local function draw_chips(dl, x, cy, list, bound, px)
        local cursor = x;
        local ch = chip_h(px);
        for _, name in ipairs(list) do
            local label = tostring(name);
            local cw = chip_width(label, px);
            local top = cy - ch / 2;
            if (bound) then
                st.fill(dl, cursor, top, cw, ch, P.accent_bg, radius, 1);
                st.outline(dl, cursor, top, cw, ch, P.accent_lo, radius, 1);
                st.text_mid(dl, cursor + chip_pad, cy, label, P.accent2, 'text', px);
            else
                st.fill(dl, cursor, top, cw, ch, P.well, radius, 1);
                st.outline(dl, cursor, top, cw, ch, P.well_edge, radius, 1);
                st.text_mid(dl, cursor + chip_pad, cy, label,
                    prop_hex(label, model.color), 'text', px);
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
        local step_top = py + margin_r;
        if (step_label ~= nil) then
            st.text_mid(dl, lx, step_top + step_h / 2, step_label, P.text, 'text', small);
        elseif (model.mode ~= 'live') then
            st.text_mid(dl, lx, title_cy, 'Drag to move', P.faint, 'text', small);
        end

        local closed = false;
        if (word == nil) then
            local hit, hot = st.close('##chains_x', rx - close_box / 2, title_cy, close_box, false);
            closed = hit and true or false;
            if (hot) then
                st.tooltip('Close');
            end
        end

        local function draw_timer(dl, cy)
            local hex = (model.status == 'wait' and P.rose)
                or (model.status == 'go' and P.teal)
                or P.amber;
            local pill_y = cy - pill_h / 2;
            local pill_x = rx - pill_w;
            st.fill(dl, pill_x, pill_y, pill_w, pill_h, st.mix(P.well, hex, 0.22), pill_h / 2, 1);
            st.outline(dl, pill_x, pill_y, pill_w, pill_h, st.mix(P.well_edge, hex, 0.7), pill_h / 2, 1);
            local tx = pill_x + st.S(8);
            st.text_mid(dl, tx, cy, word, hex, 'semi', tag_px);
            tx = tx + st.measure(word, 'semi', tag_px) + st.S(6);
            local shown = tostring(secs);
            local nw = st.measure(shown, 'semi', num_px);
            st.text_mid(dl, tx + num_slot - nw, cy, shown, P.white, 'semi', num_px);
        end

        if (word ~= nil) then
            -- Same inset above the pill as between the pill and the plate edge.
            draw_timer(dl, step_top + pill_h / 2);
        end

        local function section(x, cy, str, px)
            local title = string.upper(str);
            local spacing = math.max(1, st.S(1.2));
            local tw = st.text_spaced(dl, x, cy, title, P.teal, 'semi_italic', px, spacing);
            local line_x = x + tw + st.S(10);
            local line_end = x + inner;
            if (line_end > line_x) then
                dl:AddLine({ line_x, cy }, { line_end, cy }, st.u32(P.teal, 0.35), 1);
            end
        end

        local yb = (step_label ~= nil) and (step_top + step_h) or (py + title_h);
        for _, block in ipairs(blocks) do
            if (block.kind == 'head') then
                local hh = head_h(block.px or small);
                yb = yb + head_gap;
                section(lx, yb + hh / 2, block.text, block.px or small);
                yb = yb + hh;
            else
                local cy = yb + pitch / 2;
                local advance = pitch;
                if (block.kind == 'hint') then
                    st.text_mid(dl, lx, cy, block.text, P.faint, 'text', small);
                elseif (block.kind == 'skill') then
                    local nh = block.h;
                    cy = yb + nh / 2;
                    advance = nh + math.max(0, math.floor((pitch - nh) / 2));
                    st.text_mid(dl, lx, cy, block.name, P.text, 'text', body);
                elseif (block.kind == 'bound') then
                    draw_chips(dl, lx, cy, { block.text }, true, small);
                elseif (block.kind == 'chips') then
                    draw_chips(dl, lx, cy, block.list, false, block.px or small);
                elseif (block.kind == 'next') then
                    local row = block.row;
                    local prop = tostring(row.prop or '');
                    local lv = 'Lv.' .. tostring(row.level or 0);
                    st.text_mid(dl, lx, cy, tostring(row.name or ''), P.text, 'text', body);
                    local prop_x = lx + inner - block.prop_w;
                    st.text_mid(dl, prop_x - gap - block.lv_w, cy, lv, P.dim, 'text', small);
                    st.text_mid(dl, prop_x, cy, prop, prop_hex(prop, model.color), 'text', body);
                end
                yb = yb + advance;
                if (block.kind == 'skill') then
                    yb = math.max(yb, py + pill_floor);
                end
            end
        end
        return closed;
    end

    -- +2 is the shadow: 1px to either side, 2px under, none above.
    return { w = w + 2, h = h + 2, paint = paint };
end

local EDITOR_ROWS = {
    { 'Padding', 'pad',   4 },
    { 'Timer',   'timer', 2 },
    { 'Name',    'body',  2 },
    { 'Headers', 'small', 2 },
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
