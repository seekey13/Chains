--[[
* Vanacore look by Vekien. Palette, type, and plate for the Chains panel.
--]]

local vana = { };

-- One palette. Colours stay '#RRGGBB' until a draw asks for them.
vana.P = {
    bg = '#161822', border = '#2A2E3E', hover = '#1F2334',
    well = '#0E1017', well_edge = '#272B3C', popup = '#0F1118',
    white = '#FFFFFF', text = '#E8EAF1', text2 = '#BDC1D0',
    dim = '#7B8095', faint = '#4E536A',
    accent2 = '#A9C1FF', accent_lo = '#3E5CB3', accent_bg = '#1B2340',
    teal = '#5FD3B3', amber = '#E8B45C', rose = '#EE6F78',
};

-- Body and small text, in unscaled pixels. S() is what a draw passes.
vana.BODY  = 16;
vana.SMALL = 13.5;

local DYNAMIC = (tonumber(IMGUI_VERSION_NUM) or 0) >= 19200;

local function gui()
    return require('imgui');
end

--[[
* '#RRGGBB' and an alpha, as the ABGR word a draw list takes.
--]]
function vana.u32(hex, alpha)
    local r = tonumber(hex:sub(2, 3), 16);
    local g = tonumber(hex:sub(4, 5), 16);
    local b = tonumber(hex:sub(6, 7), 16);
    local a = math.floor(math.max(0, math.min(1, alpha or 1)) * 255 + 0.5);
    return ((a * 256 + b) * 256 + g) * 256 + r;
end

--[[
* The same colour as the { r, g, b, a } floats PushStyleColor takes.
--]]
function vana.rgba(hex, alpha)
    return {
        tonumber(hex:sub(2, 3), 16) / 255,
        tonumber(hex:sub(4, 5), 16) / 255,
        tonumber(hex:sub(6, 7), 16) / 255,
        alpha or 1,
    };
end

--[[
* The colour t of the way from a to b. t is 0..1.
--]]
function vana.mix(a, b, t)
    t = math.max(0, math.min(1, t or 0));
    local out = '#';
    for i = 2, 6, 2 do
        local x = tonumber(a:sub(i, i + 1), 16);
        local y = tonumber(b:sub(i, i + 1), 16);
        out = out .. string.format('%02X', math.floor(x + (y - x) * t + 0.5));
    end
    return out;
end

-- 1440px tall is 1.1. Shorter screens stop at 0.75 of that ratio, taller at 1.6.
local scale = 1;

function vana.scale_to(screen_h)
    local h = tonumber(screen_h) or 1080;
    scale = math.max(0.75, math.min(1.6, h / 1440)) * 1.1;
end

function vana.S(n)
    return math.floor(n * scale + 0.5);
end

-- Segoe UI, one face per weight. Nil until bake finds the file.
local fonts = { ready = false };
local fonts_tried = false;

-- The size each face is baked at. A build that cannot draw a font at any
-- size scales this one by the window instead.
local BAKE_PX = 18;

local measured, measured_scale, measured_n = { }, nil, 0;

--[[
* Segoe UI from Windows, baked once. Called from the load event, outside any
* frame: the atlas is shared, and adding to it mid-frame crashes. A missing
* file leaves that face out and text falls back to ImGui's own.
--]]
function vana.bake()
    if (fonts_tried) then
        return;
    end
    fonts_tried = true;
    local im = gui();
    local dir = ((os.getenv and os.getenv('WINDIR')) or 'C:\\Windows') .. '\\Fonts\\';
    local function add(file)
        local path = dir .. file;
        local handle = io.open(path, 'rb');
        if (not handle) then
            return nil;
        end
        handle:close();
        local ok, face = pcall(im.AddFontFromFileTTF, path, BAKE_PX);
        if (ok and face) then
            return face;
        end
        return nil;
    end
    local text = add('segoeui.ttf');
    if (not text) then
        return;
    end
    local semi = add('seguisb.ttf') or text;
    fonts.text = text;
    fonts.semi = semi;
    fonts.semi_italic = add('seguisbi.ttf') or semi;
    fonts.ready = true;
end

--[[
* Once a frame, before anything draws. The screen sets the scale, and a scale
* change throws out cached measurements.
--]]
function vana.frame()
    local h = 1080;
    local ok, io = pcall(function ()
        return gui().GetIO();
    end);
    if (ok and io and io.DisplaySize) then
        h = tonumber(io.DisplaySize.y) or h;
    end
    vana.scale_to(h);
    if (measured_scale ~= scale) then
        measured, measured_scale, measured_n = { }, scale, 0;
    end
end

-- The window font scale each push replaced, for its pop to put back, and the
-- scale now set. Only used where PushFont cannot take a size.
local scales, window_scale = { }, 1;

--[[
* Puts face `which` on the font stack at px, when Segoe loaded. False when the
* caller should leave ImGui's own font where it is. On a build that cannot
* draw a font at an arbitrary size (ImGui before 1.92), the face goes on at
* the size it was baked at and the window's font scale makes up the rest, as
* /chains scale did before the plate. Text past BAKE_PX is drawn from the
* smaller bake, so it is a little soft.
--]]
function vana.push(which, px)
    local face = fonts[which];
    if (not (fonts.ready and face)) then
        return false;
    end
    local im = gui();
    if (DYNAMIC) then
        im.PushFont(face, px);
    else
        im.PushFont(face);
        scales[#scales + 1] = window_scale;
        window_scale = math.max(0.1, (px or BAKE_PX) / BAKE_PX);
        im.SetWindowFontScale(window_scale);
    end
    return true;
end

function vana.pop()
    local im = gui();
    if (not DYNAMIC) then
        window_scale = table.remove(scales) or 1;
        im.SetWindowFontScale(window_scale);
    end
    im.PopFont();
end

local function text_wh(w, h)
    if (type(w) == 'table') then
        return w.x or w[1] or 0, w.y or w[2] or 0;
    end
    return w or 0, h or 0;
end

--[[
* Width and height of str in face `which` at px. Cached: the same labels are
* measured every frame.
--]]
function vana.measure(str, which, px)
    str = tostring(str or '');
    px = px or vana.S(vana.BODY);
    if (measured_scale ~= scale or measured_n > 4000) then
        measured, measured_scale, measured_n = { }, scale, 0;
    end
    local face = fonts[which];
    local key = tostring(face) .. '|' .. tostring(px) .. '|' .. str;
    local found = measured[key];
    if (found) then
        return found[1], found[2];
    end
    local w, h;
    -- Measured the way text_mid draws it, through the same push, so a label
    -- keeps inside its row on either kind of build.
    if (vana.push(which, px)) then
        w, h = text_wh(gui().CalcTextSize(str));
        vana.pop();
    else
        w, h = text_wh(gui().CalcTextSize(str));
    end
    measured[key] = { w, h };
    measured_n = measured_n + 1;
    return w, h;
end

--[[
* Segoe's line holds a tall ascent and a descent, so text centred by its box
* sits low. This is how far to raise it.
--]]
local function lift(h)
    if (DYNAMIC and fonts.ready) then
        return math.floor(h * 0.06 + 0.5);
    end
    return 0;
end

--[[
* str with its middle on cy. which is a face name ('text', 'semi', ...).
--]]
function vana.text_mid(dl, x, cy, str, hex, which, px, alpha)
    local _, h = vana.measure(str, which, px);
    local y = cy - h / 2 - lift(h);
    local pushed = vana.push(which, px);
    dl:AddText({ x, y }, vana.u32(hex, alpha), str);
    if (pushed) then
        vana.pop();
    end
end

--[[
* Capitals one glyph at a time, spacing pixels apart. Returns the width.
--]]
function vana.text_spaced(dl, x, cy, str, hex, which, px, spacing, alpha)
    str = tostring(str or '');
    spacing = spacing or 0;
    local start, i, n = x, 1, #str;
    while (i <= n) do
        local b = str:byte(i);
        local len = 1;
        if (b >= 0xF0) then
            len = 4;
        elseif (b >= 0xE0) then
            len = 3;
        elseif (b >= 0xC0) then
            len = 2;
        end
        local letter = str:sub(i, i + len - 1);
        vana.text_mid(dl, x, cy, letter, hex, which, px, alpha);
        x = x + vana.measure(letter, which, px) + spacing;
        i = i + len;
    end
    if (x == start) then
        return 0;
    end
    return x - start - spacing;
end

function vana.fill(dl, x, y, w, h, hex, radius, alpha, corners)
    if (w <= 0 or h <= 0) then
        return;
    end
    local col = vana.u32(hex, alpha);
    if (corners == nil) then
        dl:AddRectFilled({ x, y }, { x + w, y + h }, col, radius or 0);
    else
        dl:AddRectFilled({ x, y }, { x + w, y + h }, col, radius or 0, corners);
    end
end

function vana.outline(dl, x, y, w, h, hex, radius, alpha)
    if (w <= 0 or h <= 0) then
        return;
    end
    dl:AddRect({ x, y }, { x + w, y + h }, vana.u32(hex, alpha), radius or 0);
end

-- One pixel past either side and two below.
function vana.shadow(x, y, w, h, dl)
    vana.fill(dl, x - 1, y, w + 2, h + 2, '#000000', vana.S(6), 0.35);
end

-- The panel: shadow, ground, hairline.
function vana.plate(dl, x, y, w, h)
    local r = vana.S(5);
    vana.shadow(x, y, w, h, dl);
    vana.fill(dl, x, y, w, h, vana.P.bg, r, 1);
    vana.outline(dl, x, y, w, h, vana.P.border, r, 1);
end

-- A window's name on its title bar: semibold, white, at the body size.
function vana.title(dl, x, cy, str, px)
    vana.text_mid(dl, x, cy, str, vana.P.white, 'semi', px or vana.S(vana.BODY));
end

--[[
* A group's heading: spaced small capitals in teal, then a faint teal rule.
* span is the width the rule may run to. px defaults to the small size.
--]]
function vana.heading(dl, x, cy, str, span, px)
    local title = string.upper(str);
    px = px or vana.S(vana.SMALL);
    local spacing = math.max(1, vana.S(1.2));
    local tw = vana.text_spaced(dl, x, cy, title, vana.P.teal, 'semi_italic', px, spacing);
    local line_x = x + tw + vana.S(10);
    local line_end = x + (span or 0);
    if (line_end > line_x) then
        dl:AddLine({ line_x, cy }, { line_end, cy }, vana.u32(vana.P.teal, 0.35), 1);
    end
end

function vana.label(dl, x, cy, str, px)
    vana.text_mid(dl, x, cy, str, vana.P.text, 'text', px or vana.S(vana.BODY));
end

--[[
* A chevron or a close mark, px pixels across, centred on cx, cy.
--]]
function vana.glyph(dl, kind, cx, cy, hex, px, alpha)
    local k = (px or 11) / 24;
    local col = vana.u32(hex, alpha);
    local thickness = math.max(1, 2 * k);
    local function p(px_, py)
        return { cx + (px_ - 12) * k, cy + (py - 12) * k };
    end
    if (kind == 'right') then
        dl:AddLine(p(9, 5), p(16, 12), col, thickness);
        dl:AddLine(p(16, 12), p(9, 19), col, thickness);
    elseif (kind == 'left') then
        dl:AddLine(p(15, 5), p(8, 12), col, thickness);
        dl:AddLine(p(8, 12), p(15, 19), col, thickness);
    elseif (kind == 'close') then
        dl:AddLine(p(6, 6), p(18, 18), col, thickness);
        dl:AddLine(p(18, 6), p(6, 18), col, thickness);
    end
end

--[[
* A window's close mark: an X 72% of its box, dim until the pointer is on it
* and then rose, with no disc behind it. box is the square that takes the
* click, centred on cx, cy. veto stands it down while something drawn over it
* owns the cursor. Returns clicked, hovered.
--]]
function vana.close(id, cx, cy, box, veto)
    local im = gui();
    im.SetCursorScreenPos({ cx - box / 2, cy - box / 2 });
    local clicked = im.InvisibleButton(id, { box, box });
    local hovered = im.IsItemHovered() and not veto;
    vana.glyph(im.GetWindowDrawList(), 'close', cx, cy,
               hovered and vana.P.rose or vana.P.dim, box * 0.72);
    return (clicked and not veto) and true or false, hovered;
end

local CLEAR = { 0, 0, 0, 0 };

-- Lines past n characters broken at a space, so a tooltip stays narrow.
local function wrap_chars(s, n)
    local out = { };
    for line in (s .. '\n'):gmatch('(.-)\n') do
        while (#line > n) do
            local cut = line:sub(1, n + 1):match('^.*() ');
            if (not cut or cut < n / 2) then
                break;
            end
            out[#out + 1], line = line:sub(1, cut - 1), line:sub(cut + 1);
        end
        out[#out + 1] = line;
    end
    return table.concat(out, '\n');
end

local TIP_COLORS = {
    { 'PopupBg', 'popup', 0.97 },
    { 'Border', 'border', 1 },
    { 'Text', 'text', 1 },
};

--[[
* A tooltip by the mouse, in the palette and Segoe, wrapped. SetTooltip takes
* a printf format on Ashita 4.16's interface, so its '%' are doubled.
--]]
function vana.tooltip(s)
    if (s == nil or s == '') then
        return;
    end
    local im = gui();
    for _, entry in ipairs(TIP_COLORS) do
        im.PushStyleColor(_G['ImGuiCol_' .. entry[1]], vana.rgba(vana.P[entry[2]], entry[3]));
    end
    im.PushStyleVar(ImGuiStyleVar_WindowPadding, { vana.S(9), vana.S(6) });
    im.PushStyleVar(ImGuiStyleVar_WindowRounding, vana.S(4));
    im.PushStyleVar(ImGuiStyleVar_PopupRounding, vana.S(4));
    im.PushStyleVar(ImGuiStyleVar_PopupBorderSize, 1);
    local pushed = vana.push('text', vana.S(vana.SMALL + 0.5));
    im.SetTooltip((wrap_chars(tostring(s), 72):gsub('%%', '%%%%')));
    if (pushed) then
        vana.pop();
    end
    im.PopStyleVar(4);
    im.PopStyleColor(#TIP_COLORS);
end

local step_buf, step_meta = { }, { };

--[[
* A sunken stepper: chevrons on the ends, the number typed in the middle.
* A click steps by `step`, ctrl-click by `fast`, and holding repeats.
* Returns value, changed, typing.
--]]
function vana.stepper(id, x, cy, w, value, minv, maxv, step, fast)
    local im = gui();
    local h = vana.S(24);
    local y = cy - h / 2;
    local dl = im.GetWindowDrawList();
    local r = vana.S(4);
    vana.fill(dl, x, y, w, h, vana.P.well, r, 1);
    vana.outline(dl, x, y, w, h, vana.P.well_edge, r, 1);
    local cap = math.min(vana.S(24), math.floor(w / 3));
    local buf = step_buf[id];
    if (buf == nil) then
        buf = { tostring(value) };
        step_buf[id] = buf;
    end
    local meta = step_meta[id];
    if (meta == nil) then
        meta = { };
        step_meta[id] = meta;
    end
    if (not meta.editing) then
        buf[1] = tostring(value);
    end

    local changed = false;
    local function apply(v)
        v = math.max(minv, math.min(maxv, math.floor(v + 0.5)));
        if (v ~= value) then
            value = v;
            changed = true;
            buf[1] = tostring(v);
        end
    end

    -- The number is submitted first. The end caps come after it, or the field
    -- covers them and a click on a chevron only puts the caret in the number.
    local field_w = math.max(1, w - cap * 2);
    local px = vana.S(vana.SMALL + 0.5);
    local tw = vana.measure(buf[1] or '', 'text', px);
    local left_pad = math.floor((field_w - tw) / 2);
    if (left_pad < vana.S(2)) then
        left_pad = vana.S(2);
    end
    local pushed = vana.push('text', px);
    local text_h = px;
    local ok_sz, sz = pcall(im.GetFontSize);
    if (ok_sz and sz and sz > 0) then
        text_h = sz;
    end
    im.PushStyleColor(ImGuiCol_FrameBg, CLEAR);
    im.PushStyleColor(ImGuiCol_FrameBgHovered, CLEAR);
    im.PushStyleColor(ImGuiCol_FrameBgActive, CLEAR);
    im.PushStyleColor(ImGuiCol_Text, vana.rgba(vana.P.text2));
    im.PushStyleVar(ImGuiStyleVar_FramePadding, { left_pad, math.max(0, (h - text_h) / 2) });
    im.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
    im.SetCursorScreenPos({ x + cap, y });
    im.SetNextItemWidth(field_w);
    local flags = ImGuiInputTextFlags_CharsDecimal or 0;
    -- The id changes after a step, below. An active field keeps the digits it
    -- was opened with, so a chevron press would land and then be drawn back.
    local edited = im.InputText(id .. '.n' .. tostring(meta.gen or 0), buf, 8, flags);
    local typing = im.IsItemActive();
    im.PopStyleVar(2);
    im.PopStyleColor(4);
    if (pushed) then
        vana.pop();
    end
    if (edited) then
        local n = tonumber(buf[1]);
        if (n ~= nil) then
            apply(n);
        end
    end

    local ax, ay = im.GetMousePos();
    local mx, my = ax, ay;
    if (type(ax) ~= 'number') then
        local ok, px_, py_ = pcall(function ()
            return ax.x or ax[1], ax.y or ax[2];
        end);
        mx, my = (ok and type(px_) == 'number') and px_ or nil,
                 (ok and type(py_) == 'number') and py_ or nil;
    end
    -- A popup over the row is another window. A click there is not a step.
    local win_hot = false;
    pcall(function ()
        win_hot = im.IsWindowHovered() and true or false;
    end);
    local function on(v)
        return v == true or v == 1;
    end
    local stepped = false;
    local function endcap(side, dx, dir)
        local bx = x + dx;
        im.SetCursorScreenPos({ bx, y });
        im.InvisibleButton(id .. side, { math.max(1, cap), h });
        -- IsItemClicked, not the button's return: that return stays false on
        -- this build. The rect covers a field that still overlaps the cap and
        -- would otherwise take the click for itself.
        local item_hot = im.IsItemHovered();
        local item_click = on(im.IsItemClicked(0));
        local over = mx ~= nil and my ~= nil
                     and mx >= bx and mx < bx + cap and my >= y and my < y + h;
        local clicked = item_click or (over and win_hot and on(im.IsMouseClicked(0)));
        local arm = meta[side] or { };
        meta[side] = arm;
        local held = on(im.IsItemActive())
                     or clicked
                     or (over and win_hot and on(im.IsMouseDown(0)) and arm.at ~= nil);
        local hot = item_hot or (over and win_hot);
        if (hot) then
            local corners = (dir < 0)
                and (rawget(_G, 'ImDrawFlags_RoundCornersLeft')
                     or rawget(_G, 'ImDrawCornerFlags_Left'))
                or (rawget(_G, 'ImDrawFlags_RoundCornersRight')
                    or rawget(_G, 'ImDrawCornerFlags_Right'));
            vana.fill(dl, bx + ((dir < 0) and 1 or 0), y + 1, cap - 1, h - 2,
                      '#FFFFFF', math.max(0, r - 1), 0.07, corners);
        end
        vana.glyph(dl, (dir < 0) and 'left' or 'right',
                   bx + cap / 2, cy, hot and vana.P.text or vana.P.dim, vana.S(8));
        local now = os.clock();
        if (not held) then
            arm.at = nil;
        else
            local due = clicked and true or false;
            if (not due and arm.at ~= nil) then
                local gap = (now - arm.at > 0.4) and 0.06 or 999;
                due = now - (arm.step or 0) >= gap;
            end
            if (due) then
                local io_ok, io = pcall(im.GetIO);
                local ctrl = io_ok and io and (io.KeyCtrl == true or io.KeyCtrl == 1);
                local d = ctrl and fast or step;
                apply(value + dir * d);
                stepped = true;
                arm.step = now;
                if (arm.at == nil) then
                    arm.at = now;
                end
            end
        end
    end
    endcap('.dec', 0, -1);
    endcap('.inc', math.max(0, w - cap), 1);

    -- A step has to win over the caret. The next frame draws a new field, so
    -- the one that took the click cannot write the old digits back.
    if (stepped) then
        meta.gen = (meta.gen or 0) + 1;
        meta.editing = false;
    else
        meta.editing = typing;
    end
    return value, changed, meta.editing;
end

return vana;
