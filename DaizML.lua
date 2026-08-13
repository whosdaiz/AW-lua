local DAIZML_VERSION = "1.0"
local DAIZML_SIGNATURE = "DAIZML_SOURCE_V1"
_G.DAIZML_VERSION = DAIZML_VERSION

local staleEvents = { "Draw", "CreateMove", "PreMove", "DrawESP", "FireGameEvent", "Unload" }
local function clearCallbacks(ids)
    for _, id in ipairs(ids) do
        for _, event in ipairs(staleEvents) do
            pcall(callbacks.Unregister, event, id)
        end
    end
end

clearCallbacks({
    "WHOS_UIDraw", "WHOS_UIInput", "WHOS_UIUnload",
    "WHOS_MISCLogic", "WHOS_MISCUnload", "WHOS_DebugProbe",
    "WHOS_HostUI", "WHOS_HostInput", "WHOS_HostUnload",
    "DaizML_UIDraw", "DaizML_UIInput", "DaizML_UIUnload",
    "DaizML_MISCLogic", "DaizML_MISCUnload", "DaizML_DebugProbe",
    "DaizML_HostUI", "DaizML_HostInput", "DaizML_HostUnload",
    "daizml_keys_input",
})

local __DAIZML_GUILIB = [===[
local M = {}
M.VERSION = "1.0"

local T = {
    x = 340, y = 160, w = 720, h = 520,

    accent    = { 232, 144, 74 },
    accent2   = { 255, 186, 120, 255 },
    accent_bg = { 58, 36, 22, 255 },
    bg        = { 12, 13, 16, 252 },
    bg2       = { 18, 19, 24, 252 },
    section   = { 24, 26, 32, 252 },
    border    = { 42, 46, 56, 255 },
    divider   = { 34, 38, 48, 255 },
    text      = { 198, 204, 214, 255 },
    textdim   = { 118, 126, 140, 255 },
    texthi    = { 248, 248, 250, 255 },
    widget    = { 28, 31, 38, 255 },
    widgethi  = { 36, 40, 50, 255 },
    shadow    = { 0, 0, 0, 130 },
    rail      = { 16, 17, 22, 255 },

    title     = "DaizML",
    title_tld = "studio",
    titlebar  = 52,
    pad       = 20,
    sec_gap   = 14,

    font      = { "Segoe UI", "Bahnschrift", "Tahoma" },
    font_logo = { "Bahnschrift", "Segoe UI Semibold", "Segoe UI" },
    font_size = 14,

    notif_pos    = "bottom-right",
    notif_w      = 290,
    notif_margin = 18,
    notif_life   = 3.5,
    notif_info    = { 230, 230, 235 },
    notif_success = { 170, 220, 185 },
    notif_error   = { 235, 90, 90 },
}

local WH = { check = 28, button = 36, slider = 36, combo = 52, multicombo = 52, input = 52, color = 28, keybox = 52, check_slider = 36, check_keybox = 36, check_combo = 52, key_combo = 52, dual_check = 28, dual_slider = 36 }
local function wheight(wd)
    if wd.hidden then return 0 end
    if wd.kind == "listbox" then
        return ((wd.label and wd.label ~= "") and 18 or 0) + wd.h + 6
    end
    if wd.kind == "custom" then return wd._measured or wd.h end
    return WH[wd.kind] or 28
end

local ANIM = { open = 13, tab = 17 }

local floor, sqrt, mmin, mmax, mabs = math.floor, math.sqrt, math.min, math.max, math.abs
local function rnd(n) return floor(n + 0.5) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function smooth(t) t = clamp(t, 0, 1); return t * t * (3 - 2 * t) end

local function decimalsOf(step)
    if not step or step >= 1 then return 0 end
    local d, s = 0, step
    while s < 1 and d < 6 do
        s = s * 10; d = d + 1
        if mabs(s - floor(s + 0.5)) < 1e-7 then break end
    end
    return d
end

local ALPHA = 1
local DT = 0
local clipTop, clipBottom

local function approach(cur, target, speed)
    return cur + (target - cur) * clamp(DT * speed, 0, 1)
end

local function lerpc(a, b, t)
    t = clamp(t, 0, 1)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 255) + ((b[4] or 255) - (a[4] or 255)) * t,
    }
end

local ffi = ffi

local FONT, FONT_B, FONT_LOGO, FONT_SMALL
local WM_FONT, WM_FONT_LOGO
local function initFonts()
    local mk = function(list, size, weight)
        for _, name in ipairs(list) do
            local f
            pcall(function() f = draw.CreateFont(name, size, weight) end)
            if not f then pcall(function() f = draw.AddFont(name, size, weight) end) end
            if f then return f, name end
        end
    end
    FONT              = mk(T.font, T.font_size, 400)
    FONT_B            = mk(T.font, T.font_size, 600)
    FONT_LOGO         = mk(T.font_logo, T.font_size + 2, 700) or FONT_B
    FONT_SMALL        = mk(T.font, math.max(11, T.font_size - 2), 400) or FONT
end

local function initWatermarkFonts()
    local mk = function(list, size, weight)
        for _, name in ipairs(list) do
            local f
            pcall(function() f = draw.CreateFont(name, size, weight) end)
            if not f then pcall(function() f = draw.AddFont(name, size, weight) end) end
            if f then return f end
        end
    end
    local faces = { "Segoe UI", "Bahnschrift", "Tahoma" }
    WM_FONT = mk(faces, 14, 600)
    WM_FONT_LOGO = mk(faces, 16, 700) or WM_FONT
end

local function setcol(c) draw.Color(c[1], c[2], c[3], rnd((c[4] or 255) * ALPHA)) end

local function rect(x, y, w, h, c)
    setcol(c); draw.FilledRect(rnd(x), rnd(y), rnd(x + w), rnd(y + h))
end

local function drawLogo(x, y, w, h)
    local ok = pcall(function()
        if FONT_LOGO then draw.SetFont(FONT_LOGO) end
        local label = "WhosDaiz Multi Lua"
        local tw, th = draw.GetTextSize(label)
        draw.Color(T.texthi[1], T.texthi[2], T.texthi[3], rnd(255 * ALPHA))
        draw.Text(rnd(x), rnd(y + (h - th) * 0.5 - 1), label)
        draw.Color(T.accent[1], T.accent[2], T.accent[3], rnd(235 * ALPHA))
        draw.FilledRect(rnd(x), rnd(y + h - 2), rnd(x + mmax(w, tw)), rnd(y + h))
    end)
    return ok
end

local function rfill(x, y, w, h, r, c, tl, tr, br, bl)
    x, y, w, h = rnd(x), rnd(y), rnd(w), rnd(h)
    r = mmin(r, floor(w / 2), floor(h / 2))
    if r <= 0 then rect(x, y, w, h, c); return end
    if tl == nil then tl, tr, br, bl = true, true, true, true end
    rect(x, y + r, w, h - 2 * r, c)
    for dy = 0, r - 1 do
        local dx = r - floor(sqrt(r * r - (r - dy - 0.5) ^ 2) + 0.5)
        local lt, rt = tl and dx or 0, tr and dx or 0
        local lb, rb = bl and dx or 0, br and dx or 0
        rect(x + lt, y + dy, w - lt - rt, 1, c)
        rect(x + lb, y + h - 1 - dy, w - lb - rb, 1, c)
    end
end

local function rbox(x, y, w, h, r, fill, brd)
    rfill(x, y, w, h, r, brd)
    rfill(x + 1, y + 1, w - 2, h - 2, r - 1, fill)
end

local function frame(x, y, w, h, c)
    rect(x, y, w, 1, c); rect(x, y + h - 1, w, 1, c)
    rect(x, y, 1, h, c); rect(x + w - 1, y, 1, h, c)
end

local function rgb2hsv(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local mx, mn = mmax(r, g, b), mmin(r, g, b)
    local v, d = mx, mx - mn
    local s = mx == 0 and 0 or d / mx
    local h = 0
    if d ~= 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6; if h < 0 then h = h + 1 end
    end
    return h, s, v
end

local function hsv2rgb(h, s, v)
    local i = floor(h * 6) % 6
    local f = h * 6 - floor(h * 6)
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local r, g, b
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return rnd(r * 255), rnd(g * 255), rnd(b * 255)
end

local function textw(s) local w = draw.GetTextSize(s); return w or 0 end

local function fitText(s, maxWidth, font)
    s = tostring(s or "")
    if font then pcall(function() draw.SetFont(font) end) end
    if textw(s) <= maxWidth then return s end
    local suffix = "..."
    local available = mmax(0, maxWidth - textw(suffix))
    local lo, hi, best = 0, #s, 0
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        if textw(s:sub(1, mid)) <= available then best = mid; lo = mid + 1
        else hi = mid - 1 end
    end
    return s:sub(1, best) .. suffix
end

local function text(x, y, c, s, font, align)
    if font then draw.SetFont(font) end
    if align == "center" then x = x - textw(s) / 2
    elseif align == "right" then x = x - textw(s) end
    setcol(c); draw.Text(rnd(x), rnd(y), s)
end

local _getMouse
local function resolveMouse()
    local cands = {
        function() local p = input.GetMousePos();    return p.x or p[1], p.y or p[2] end,
        function() local p = input.GetCursorPos();    return p.x or p[1], p.y or p[2] end,
        function() local x, y = input.GetMousePos();  return x, y end,
        function() local x, y = input.GetCursorPos(); return x, y end,
    }
    for _, f in ipairs(cands) do
        local ok, x, y = pcall(f)
        if ok and type(x) == "number" and type(y) == "number" then return f end
    end
end

local _clock
local function resolveClock()
    local cands = {
        function() return globals.RealTime() end,
        function() return globals.CurTime() end,
        function() return os.clock() end,
    }
    for _, f in ipairs(cands) do
        local ok, v = pcall(f)
        if ok and type(v) == "number" then return f end
    end
end
local function now() if _clock then local ok, v = pcall(_clock); if ok then return v end end return 0 end

local _getWheel
local function resolveWheel()
    local cands = {
        function() return input.GetMouseWheel() end,
        function() return input.GetMouseWheelDelta() end,
        function() return input.GetScrollDelta() end,
        function() return input.GetScroll() end,
    }
    for _, f in ipairs(cands) do
        local ok, v = pcall(f)
        if ok and type(v) == "number" then return f end
    end
end
local function readWheel() if _getWheel then local ok, v = pcall(_getWheel); if ok and type(v) == "number" then return v end end return 0 end

local SHIFT_DIGITS = { [0x30] = ")", [0x31] = "!", [0x32] = "@", [0x33] = "#", [0x34] = "$",
                       [0x35] = "%", [0x36] = "^", [0x37] = "&", [0x38] = "*", [0x39] = "(" }
local OEM = {
    [0xBA] = { ";", ":" }, [0xBB] = { "=", "+" }, [0xBC] = { ",", "<" }, [0xBD] = { "-", "_" },
    [0xBE] = { ".", ">" }, [0xBF] = { "/", "?" }, [0xC0] = { "`", "~" }, [0xDB] = { "[", "{" },
    [0xDC] = { "\\", "|" }, [0xDD] = { "]", "}" }, [0xDE] = { "'", '"' },
}
local function keyPressed(k) local v = false; pcall(function() v = input.IsButtonPressed(k) end); return v end
local function keyDown(k)    local v = false; pcall(function() v = input.IsButtonDown(k)  end); return v end

pcall(function() ffi.cdef[[
    int    OpenClipboard(void*);
    int    CloseClipboard(void);
    int    EmptyClipboard(void);
    void*  GetClipboardData(unsigned int);
    void*  SetClipboardData(unsigned int, void*);
    void*  GlobalAlloc(unsigned int, size_t);
    void*  GlobalLock(void*);
    int    GlobalUnlock(void*);
]] end)

local function clipGet()
    local out
    pcall(function()
        if ffi.C.OpenClipboard(nil) == 0 then return end
        local h = ffi.C.GetClipboardData(1)
        if h ~= nil then
            local p = ffi.C.GlobalLock(h)
            if p ~= nil then out = ffi.string(ffi.cast("char*", p)); ffi.C.GlobalUnlock(h) end
        end
        ffi.C.CloseClipboard()
    end)
    if out then out = out:gsub("[\r\n\t]", "") end
    return out
end

local function clipSet(s)
    s = tostring(s or "")
    pcall(function()
        if ffi.C.OpenClipboard(nil) == 0 then return end
        ffi.C.EmptyClipboard()
        local n = #s + 1
        local h = ffi.C.GlobalAlloc(2, n)
        if h ~= nil then
            local p = ffi.C.GlobalLock(h)
            if p ~= nil then
                local dst = ffi.cast("char*", p)
                for i = 0, n - 1 do dst[i] = (i < #s) and s:byte(i + 1) or 0 end
                ffi.C.GlobalUnlock(h)
                ffi.C.SetClipboardData(1, h)
            end
        end
        ffi.C.CloseClipboard()
    end)
end

local _kr = {}
local REPEAT_DELAY, REPEAT_RATE = 0.40, 0.035
local function keyRepeat(k, t)
    if not keyDown(k) then _kr[k] = nil; return false end
    local s = _kr[k]
    if not s then _kr[k] = { first = t, last = t }; return true end
    if (t - s.first) >= REPEAT_DELAY and (t - s.last) >= REPEAT_RATE then s.last = t; return true end
    return false
end

local function selBounds(wd)
    local c = wd._caret or #wd.value
    local a = wd._anchor or c
    if a > c then a, c = c, a end
    return a, c
end
local function hasSel(wd) return (wd._anchor or wd._caret or 0) ~= (wd._caret or 0) end
local function delSel(wd)
    local a, b = selBounds(wd)
    if a == b then return false end
    wd.value = wd.value:sub(1, a) .. wd.value:sub(b + 1)
    wd._caret = a; wd._anchor = a
    return true
end

local function inputView(wd, avail)
    local v, n = wd.value, #wd.value
    local caret = clamp(wd._caret or n, 0, n); wd._caret = caret
    if wd._anchor then wd._anchor = clamp(wd._anchor, 0, n) end
    local off = clamp(wd._off or 0, 0, n)
    if caret < off then off = caret end
    while off < caret and textw(v:sub(off + 1, caret)) > avail do off = off + 1 end
    local e = n
    while e > off and textw(v:sub(off + 1, e)) > avail do e = e - 1 end
    if e < caret then e = caret end
    wd._off = off
    return v:sub(off + 1, e), off, e
end

local function caretFromX(wd, relx, off)
    local v, n = wd.value, #wd.value
    if relx <= 0 then return off end
    for i = off + 1, n do
        local w = textw(v:sub(off + 1, i))
        if w >= relx then
            local wp = textw(v:sub(off + 1, i - 1))
            return ((relx - wp) < (w - relx)) and (i - 1) or i
        end
    end
    return n
end

local function pollText(wd, t)
    local ctrl  = keyDown(0x11)
    local shift = keyDown(0x10)
    local n = #wd.value
    wd._caret  = clamp(wd._caret or n, 0, n)
    wd._anchor = wd._anchor and clamp(wd._anchor, 0, n) or wd._caret

    if ctrl then
        if keyPressed(0x41) then wd._anchor = 0; wd._caret = n end
        if keyPressed(0x43) then local a, b = selBounds(wd); clipSet(a ~= b and wd.value:sub(a + 1, b) or wd.value) end
        if keyPressed(0x58) then
            local a, b = selBounds(wd)
            if a ~= b then clipSet(wd.value:sub(a + 1, b)); delSel(wd)
            else clipSet(wd.value); wd.value = ""; wd._caret = 0; wd._anchor = 0 end
        end
        if keyPressed(0x56) then
            local s = clipGet()
            if s then
                delSel(wd)
                local c = wd._caret
                wd.value = wd.value:sub(1, c) .. s .. wd.value:sub(c + 1)
                wd._caret = c + #s; wd._anchor = wd._caret
            end
        end
        return
    end

    local function move(to)
        wd._caret = clamp(to, 0, #wd.value)
        if not shift then wd._anchor = wd._caret end
    end
    local function ins(ch)
        delSel(wd)
        local c = wd._caret
        wd.value = wd.value:sub(1, c) .. ch .. wd.value:sub(c + 1)
        wd._caret = c + 1; wd._anchor = wd._caret
    end

    if keyRepeat(0x25, t) then
        local a, b = selBounds(wd)
        if not shift and a ~= b then wd._caret = a; wd._anchor = a else move(wd._caret - 1) end
    end
    if keyRepeat(0x27, t) then
        local a, b = selBounds(wd)
        if not shift and a ~= b then wd._caret = b; wd._anchor = b else move(wd._caret + 1) end
    end
    if keyPressed(0x24) then move(0) end
    if keyPressed(0x23) then move(#wd.value) end

    if keyRepeat(0x08, t) then
        if not delSel(wd) then
            local c = wd._caret
            if c > 0 then wd.value = wd.value:sub(1, c - 1) .. wd.value:sub(c + 1); wd._caret = c - 1; wd._anchor = c - 1 end
        end
    end
    if keyRepeat(0x2E, t) then
        if not delSel(wd) then
            local c = wd._caret
            if c < #wd.value then wd.value = wd.value:sub(1, c) .. wd.value:sub(c + 2) end
        end
    end

    if keyRepeat(0x20, t) then ins(" ") end
    for k = 0x41, 0x5A do
        if keyRepeat(k, t) then local ch = string.char(k); ins(shift and ch or ch:lower()) end
    end
    for k = 0x30, 0x39 do
        if keyRepeat(k, t) then ins(shift and SHIFT_DIGITS[k] or string.char(k)) end
    end
    for k, pair in pairs(OEM) do
        if keyRepeat(k, t) then ins(shift and pair[2] or pair[1]) end
    end
    if keyPressed(0x0D) or keyPressed(0x1B) then M._focus = nil end
end

local ms = { x = 0, y = 0, down = false, pressed = false, released = false, consumed = false }
local function updateMouse()
    if _getMouse then
        local ok, x, y = pcall(_getMouse)
        if ok then ms.x, ms.y = x or ms.x, y or ms.y end
    end
    local down = false
    pcall(function() down = input.IsButtonDown(0x01) and true or false end)
    ms.pressed  = down and not ms.down
    ms.released = (not down) and ms.down
    ms.down     = down
    ms.consumed = false
    ms.wheel    = readWheel()
end

local function hovering(x, y, w, h)
    return ms.x >= x and ms.x <= x + w and ms.y >= y and ms.y <= y + h
end

local function clicked(x, y, w, h)
    if ms.consumed or not ms.pressed then return false end
    if hovering(x, y, w, h) then ms.consumed = true; return true end
    return false
end

local function handle(w)
    return {
        Get = function() return w.value end,
        Set = function(_, v) w.value = v end,
        SetHidden = function(_, h) w.hidden = h and true or false end,
        IsHidden = function() return w.hidden and true or false end,
    }
end

local UI = {
    T = T, now = now, clamp = clamp, lerp = lerpc,
    rect  = function(x, y, w, h, c) rect(x, y, w, h, c) end,
    rfill = function(x, y, w, h, r, c) rfill(x, y, w, h, r, c) end,
    rbox  = function(x, y, w, h, r, f, b) rbox(x, y, w, h, r, f, b or T.border) end,
    text  = function(x, y, s, col, align) text(x, y, col or T.text, tostring(s), FONT, align) end,
    title = function(x, y, s, col, align) text(x, y, col or T.texthi, tostring(s), FONT_B, align) end,
    textw = function(s) return textw(tostring(s)) end,
    hover = function(x, y, w, h) return hovering(x, y, w, h) end,
    click = function(x, y, w, h) return clicked(x, y, w, h) end,
    mouse = function() return ms.x, ms.y, ms.down end,
    screen = function() local w, h = 0, 0; pcall(function() w, h = draw.GetScreenSize() end); return w, h end,
}

local IM = {}
UI._x, UI._cy, UI._w = 0, 0, 200
UI.layout = function(x, y, w) UI._x = x; UI._cy = y; if w then UI._w = w end end

local Section = {}
Section.__index = Section

function Section.new(title) return setmetatable({ title = title, ws = {} }, Section) end

function Section:_add(w) self.ws[#self.ws + 1] = w; return handle(w) end

function Section:Checkbox(label, def)
    return self:_add({ kind = "check", label = label, value = def and true or false })
end

function Section:DualCheck(leftLabel, rightLabel, leftDef, rightDef)
    local w = {
        kind = "dual_check",
        leftLabel = leftLabel or "",
        rightLabel = rightLabel or "",
        left = leftDef and true or false,
        right = rightDef and true or false,
    }
    self.ws[#self.ws + 1] = w
    return {
        left = {
            Get = function() return w.left end,
            Set = function(_, v) w.left = v and true or false end,
        },
        right = {
            Get = function() return w.right end,
            Set = function(_, v) w.right = v and true or false end,
        },
    }
end

function Section:Button(label, cb)
    return self:_add({ kind = "button", label = label, cb = cb })
end

function Section:Slider(label, def, mn, mx, step, fmt)
    step = step or 1
    return self:_add({ kind = "slider", label = label, value = def, min = mn, max = mx,
                       step = step, dec = decimalsOf(step), fmt = fmt })
end

function Section:DualSlider(leftLabel, leftDef, leftMin, leftMax, leftStep, leftFmt,
                            rightLabel, rightDef, rightMin, rightMax, rightStep, rightFmt)
    leftStep = leftStep or 1
    rightStep = rightStep or 1
    local w = {
        kind = "dual_slider",
        leftLabel = leftLabel or "",
        rightLabel = rightLabel or "",
        leftValue = leftDef,
        rightValue = rightDef,
        leftMin = leftMin, leftMax = leftMax, leftStep = leftStep,
        rightMin = rightMin, rightMax = rightMax, rightStep = rightStep,
        leftDec = decimalsOf(leftStep), rightDec = decimalsOf(rightStep),
        leftFmt = leftFmt, rightFmt = rightFmt,
    }
    self.ws[#self.ws + 1] = w
    return {
        left = {
            Get = function() return w.leftValue end,
            Set = function(_, v) w.leftValue = v end,
        },
        right = {
            Get = function() return w.rightValue end,
            Set = function(_, v) w.rightValue = v end,
        },
    }
end

function Section:SliderFloat(label, def, mn, mx, fmt, step)
    return self:Slider(label, def, mn, mx, step or 0.01, fmt)
end

function Section:CheckSlider(checkLabel, sliderLabel, checkDef, sliderDef, mn, mx, step, fmt)
    step = step or 1
    local w = {
        kind = "check_slider",
        checkLabel = checkLabel or "",
        sliderLabel = sliderLabel or "",
        check = checkDef and true or false,
        value = sliderDef or mn or 0,
        min = mn or 0,
        max = mx or 100,
        step = step,
        dec = decimalsOf(step),
        fmt = fmt,
    }
    self.ws[#self.ws + 1] = w
    return {
        check = {
            Get = function() return w.check end,
            Set = function(_, v) w.check = v and true or false end,
        },
        slider = {
            Get = function() return w.value end,
            Set = function(_, v) w.value = v end,
        },
    }
end

function Section:CheckKeybox(checkLabel, keyLabel, checkDef, keyDef)
    local w = {
        kind = "check_keybox",
        checkLabel = checkLabel or "",
        keyLabel = keyLabel or "Key",
        check = checkDef and true or false,
        value = tonumber(keyDef) or 0,
    }
    self.ws[#self.ws + 1] = w
    return {
        check = {
            Get = function() return w.check end,
            Set = function(_, v) w.check = v and true or false end,
        },
        key = {
            Get = function() return w.value end,
            Set = function(_, v) w.value = tonumber(v) or 0 end,
        },
    }
end

function Section:CheckCombo(checkLabel, comboLabel, checkDef, options, comboDef)
    local w = {
        kind = "check_combo",
        checkLabel = checkLabel or "",
        comboLabel = comboLabel or "",
        check = checkDef and true or false,
        options = options or {},
        value = tonumber(comboDef) or 1,
    }
    self.ws[#self.ws + 1] = w
    return {
        check = {
            Get = function() return w.check end,
            Set = function(_, v) w.check = v and true or false end,
        },
        combo = {
            Get = function() return w.value end,
            Set = function(_, v)
                v = tonumber(v) or 1
                if v < 1 then v = 1 end
                if v > #w.options then v = mmax(1, #w.options) end
                w.value = v
            end,
        },
    }
end

function Section:KeyCombo(keyLabel, comboLabel, keyDef, options, comboDef)
    local w = {
        kind = "key_combo",
        keyLabel = keyLabel or "Key",
        comboLabel = comboLabel or "",
        keyValue = tonumber(keyDef) or 0,
        options = options or {},
        value = tonumber(comboDef) or 1,
    }
    self.ws[#self.ws + 1] = w
    return {
        key = {
            Get = function() return w.keyValue end,
            Set = function(_, v) w.keyValue = tonumber(v) or 0 end,
        },
        combo = {
            Get = function() return w.value end,
            Set = function(_, v)
                v = tonumber(v) or 1
                if v < 1 then v = 1 end
                if v > #w.options then v = mmax(1, #w.options) end
                w.value = v
            end,
        },
    }
end

function Section:Combo(label, options, def)
    return self:_add({ kind = "combo", label = label, options = options, value = def or 1 })
end

function Section:MultiCombo(label, options, defaults)
    local sel = {}
    if defaults then for _, i in ipairs(defaults) do sel[i] = true end end
    return self:_add({ kind = "multicombo", label = label, options = options, value = sel })
end

function Section:Input(label, def, placeholder)
    return self:_add({ kind = "input", label = label, value = def or "", placeholder = placeholder })
end

function Section:ColorPicker(label, col)
    col = col or { 255, 255, 255, 255 }
    return self:_add({ kind = "color", label = label, value = { col[1], col[2], col[3], col[4] or 255 } })
end

function Section:Keybox(label, def)
    return self:_add({ kind = "keybox", label = label, value = tonumber(def) or 0 })
end

function Section:Listbox(label, items, height, def)
    local fill = (height == "fill")
    if fill then self._hasFill = true end
    local w = { kind = "listbox", label = label, items = items or {}, value = def or 1,
                h = fill and 120 or (height or 200), fill = fill, scroll = 0 }
    self.ws[#self.ws + 1] = w
    return {
        Get = function() return w.value end,
        Set = function(_, v) w.value = v end,
        SetItems = function(_, newItems, value)
            w.items = newItems or {}
            w.value = tonumber(value) or 1
            if w.value < 1 then w.value = 1 end
            if w.value > #w.items then w.value = mmax(1, #w.items) end
            w.scroll = 0
        end,
        Count = function() return #w.items end,
    }
end

function Section:Custom(height, fn)
    return self:_add({ kind = "custom", h = height or 60, fn = fn })
end

function Section:height()
    local h = 42 + 10
    for _, wd in ipairs(self.ws) do h = h + wheight(wd) end
    return h
end

function Section:render(x, y, w)
    local natural = self:height()
    local h = natural
    if self._layoutH then
        h = mmax(natural, self._layoutH)
    elseif self._hasFill and clipBottom then
        local fh = (clipBottom - 12) - y
        if fh > h then h = fh end
    end

    if clipBottom and y >= clipBottom then return h end
    if clipTop and (y + h) <= clipTop then return h end

    local boxH = h
    if clipBottom and (y + boxH) > clipBottom then
        boxH = mmax(0, clipBottom - y)
    end
    if boxH > 0 and (not clipTop or y + boxH > clipTop) then
        local drawY = y
        local drawH = boxH
        if clipTop and drawY < clipTop then
            drawH = drawH - (clipTop - drawY)
            drawY = clipTop
        end
        if drawH > 0 then
            rbox(x, drawY, w, drawH, 12, T.section, T.border)
            rfill(x + 1, drawY + 1, w - 2, 1, 9, { T.accent[1], T.accent[2], T.accent[3], 50 })
        end
        if (not clipTop or y + 26 > clipTop) and (not clipBottom or y + 12 < clipBottom) then
            rfill(x + 14, y + 12, 3, 14, 1, T.accent)
            text(x + 23, y + 12, T.texthi, self.title, FONT_B)
            if (not clipBottom or y + 33 < clipBottom) and (not clipTop or y + 34 > clipTop) then
                rect(x + 14, y + 33, w - 28, 1, T.divider)
            end
        end
    end

    local iy = y + 44
    local ix = x + 14
    local iw = w - 28
    for _, wd in ipairs(self.ws) do
        if wd.hidden then
            -- skip
        else
        local wh
        if wd.kind == "listbox" and wd.fill then
            local labelH = (wd.label and wd.label ~= "") and 18 or 0
            local remain = (y + h - 12) - (iy + labelH)
            wd._fillH = mmax(wd.h or 120, remain)
            wh = labelH + wd._fillH + 6
        else
            wh = wheight(wd)
        end
        local visible = true
        if clipBottom and iy >= clipBottom then visible = false end
        if clipTop and (iy + wh) <= clipTop then visible = false end
        if clipBottom and (iy + 6) >= clipBottom then visible = false end
        if visible then
            self:_widget(wd, ix, iy, iw)
        end
        iy = iy + wh
        if clipBottom and iy >= clipBottom then break end
        end
    end
    return h
end

local KEYBOX_NAMES = {
    [0x00] = "None", [0x01] = "Mouse1", [0x02] = "Mouse2", [0x04] = "Mouse3",
    [0x05] = "Mouse4", [0x06] = "Mouse5", [0x08] = "Backspace", [0x09] = "Tab",
    [0x0D] = "Enter", [0x10] = "Shift", [0x11] = "Ctrl", [0x12] = "Alt",
    [0x1B] = "Escape", [0x20] = "Space", [0x21] = "Page Up", [0x22] = "Page Down",
    [0x23] = "End", [0x24] = "Home", [0x25] = "Left", [0x26] = "Up",
    [0x27] = "Right", [0x28] = "Down", [0x2D] = "Insert", [0x2E] = "Delete",
    [0x700] = "MWheel Up", [0x701] = "MWheel Down",
}
local function keyboxName(code)
    code = tonumber(code) or 0
    if KEYBOX_NAMES[code] then return KEYBOX_NAMES[code] end
    if code >= 0x30 and code <= 0x39 then return string.char(code) end
    if code >= 0x41 and code <= 0x5A then return string.char(code) end
    if code >= 0x70 and code <= 0x7B then return "F" .. tostring(code - 0x6F) end
    return code > 0 and string.format("VK 0x%02X", code) or "None"
end
function Section:_widget(wd, x, y, w)
    if wd.kind == "check" then
        local box = 15
        local by  = y + 1
        local hov = hovering(x, by, w, box)
        wd._h  = approach(wd._h or 0, hov and 1 or 0, 16)
        wd._on = approach(wd._on or 0, wd.value and 1 or 0, 16)
        local fill = lerpc(lerpc(T.widget, T.widgethi, wd._h), T.accent, wd._on)
        rbox(x, by, box, box, 4, fill, lerpc(T.border, T.accent, wd._on))
        text(x + box + 9, y + 2, lerpc(T.text, T.texthi, mmax(wd._h, wd._on)), wd.label, FONT)
        if clicked(x, by, w, box) then wd.value = not wd.value end

    elseif wd.kind == "dual_check" then
        local gap = 14
        local half = floor((w - gap) * 0.5)
        local box = 15
        local by = y + 1

        local hovL = hovering(x, by, half, box + 4)
        wd._hl = approach(wd._hl or 0, hovL and 1 or 0, 16)
        wd._onL = approach(wd._onL or 0, wd.left and 1 or 0, 16)
        local fillL = lerpc(lerpc(T.widget, T.widgethi, wd._hl), T.accent, wd._onL)
        rbox(x, by, box, box, 4, fillL, lerpc(T.border, T.accent, wd._onL))
        text(x + box + 9, y + 2, lerpc(T.text, T.texthi, mmax(wd._hl, wd._onL)), fitText(wd.leftLabel, half - box - 14, FONT), FONT)
        if clicked(x, by, half, box + 4) then wd.left = not wd.left end

        local rx = x + half + gap
        local hovR = hovering(rx, by, half, box + 4)
        wd._hr = approach(wd._hr or 0, hovR and 1 or 0, 16)
        wd._onR = approach(wd._onR or 0, wd.right and 1 or 0, 16)
        local fillR = lerpc(lerpc(T.widget, T.widgethi, wd._hr), T.accent, wd._onR)
        rbox(rx, by, box, box, 4, fillR, lerpc(T.border, T.accent, wd._onR))
        text(rx + box + 9, y + 2, lerpc(T.text, T.texthi, mmax(wd._hr, wd._onR)), fitText(wd.rightLabel, half - box - 14, FONT), FONT)
        if clicked(rx, by, half, box + 4) then wd.right = not wd.right end

    elseif wd.kind == "dual_slider" then
        local gap = 14
        local half = floor((w - gap) * 0.5)
        local function drawHalf(side, sx, sw, label, value, mn, mx, step, dec, fmt)
            local active = (M._slider == wd and wd._side == side)
            local hov = hovering(sx, y + 18 - 6, sw, 18)
            local hk = "_h" .. side
            wd[hk] = approach(wd[hk] or 0, (active or hov) and 1 or 0, 16)
            text(sx, y, lerpc(T.text, T.texthi, wd[hk]), fitText(label, sw - 36, FONT), FONT)
            local valstr
            if fmt then valstr = string.format(fmt, value)
            elseif dec > 0 then valstr = string.format("%." .. dec .. "f", value)
            else valstr = tostring(rnd(value)) end
            text(sx + sw, y, T.texthi, valstr, FONT, "right")
            local ty, th = y + 18, 6
            local frac = clamp((value - mn) / math.max(0.0001, mx - mn), 0, 1)
            rbox(sx, ty, sw, th, 3, lerpc(T.widget, T.widgethi, wd[hk]), T.border)
            if frac > 0 then rfill(sx, ty, mmax(th, sw * frac), th, 3, T.accent, true, false, false, true) end
            if ms.pressed and not ms.consumed and hovering(sx, ty - 6, sw, th + 12) then
                ms.consumed = true
                M._slider = wd
                wd._side = side
            end
            if active then
                if ms.down and sw > 0 then
                    local raw = mn + clamp((ms.x - sx) / sw, 0, 1) * (mx - mn)
                    if raw ~= raw then raw = mn end
                    local v = mn + floor((raw - mn) / step + 0.5) * step
                    v = clamp(v, mn, mx)
                    if dec > 0 then v = tonumber(string.format("%." .. dec .. "f", v)) or v end
                    if side == "L" then wd.leftValue = v else wd.rightValue = v end
                elseif not ms.down then
                    M._slider = nil
                    wd._side = nil
                end
            end
        end
        drawHalf("L", x, half, wd.leftLabel, wd.leftValue, wd.leftMin, wd.leftMax, wd.leftStep, wd.leftDec, wd.leftFmt)
        drawHalf("R", x + half + gap, half, wd.rightLabel, wd.rightValue, wd.rightMin, wd.rightMax, wd.rightStep, wd.rightDec, wd.rightFmt)

    elseif wd.kind == "check_slider" then
        local gap = 14
        local leftW = floor(w * 0.48)
        local rightX = x + leftW + gap
        local rightW = w - leftW - gap

        local box = 15
        local by = y + 10
        local hovC = hovering(x, by, leftW, box)
        wd._h = approach(wd._h or 0, hovC and 1 or 0, 16)
        wd._on = approach(wd._on or 0, wd.check and 1 or 0, 16)
        local fill = lerpc(lerpc(T.widget, T.widgethi, wd._h), T.accent, wd._on)
        rbox(x, by, box, box, 4, fill, lerpc(T.border, T.accent, wd._on))
        text(x + box + 9, by + 1, lerpc(T.text, T.texthi, mmax(wd._h, wd._on)), wd.checkLabel, FONT)
        if clicked(x, by, leftW, box + 4) then wd.check = not wd.check end

        local active = (M._slider == wd)
        local hovS = hovering(rightX, y, rightW, 34)
        wd._hs = approach(wd._hs or 0, (active or hovS) and 1 or 0, 16)
        text(rightX, y, lerpc(T.text, T.texthi, wd._hs), wd.sliderLabel, FONT)
        local valstr
        if wd.fmt then valstr = string.format(wd.fmt, wd.value)
        elseif wd.dec > 0 then valstr = string.format("%." .. wd.dec .. "f", wd.value)
        else valstr = tostring(rnd(wd.value)) end
        text(rightX + rightW, y, T.texthi, valstr, FONT, "right")
        local ty, th = y + 18, 6
        local frac = clamp((wd.value - wd.min) / math.max(0.0001, wd.max - wd.min), 0, 1)
        rbox(rightX, ty, rightW, th, 3, lerpc(T.widget, T.widgethi, wd._hs), T.border)
        if frac > 0 then rfill(rightX, ty, mmax(th, rightW * frac), th, 3, T.accent, true, false, false, true) end
        if ms.pressed and not ms.consumed and hovering(rightX, ty - 6, rightW, th + 12) then
            ms.consumed = true; M._slider = wd
        end
        if active then
            if ms.down and rightW > 0 then
                local raw = wd.min + clamp((ms.x - rightX) / rightW, 0, 1) * (wd.max - wd.min)
                if raw ~= raw then raw = wd.min end
                local v = wd.min + floor((raw - wd.min) / wd.step + 0.5) * wd.step
                v = clamp(v, wd.min, wd.max)
                if wd.dec > 0 then v = tonumber(string.format("%." .. wd.dec .. "f", v)) or v end
                wd.value = v
            elseif not ms.down then
                M._slider = nil
            end
        end

    elseif wd.kind == "check_keybox" then
        local gap = 14
        local leftW = floor(w * 0.55)
        local rightX = x + leftW + gap
        local rightW = w - leftW - gap

        local box = 15
        local by = y + 10
        local hovC = hovering(x, by, leftW, box)
        wd._h = approach(wd._h or 0, hovC and 1 or 0, 16)
        wd._on = approach(wd._on or 0, wd.check and 1 or 0, 16)
        local fill = lerpc(lerpc(T.widget, T.widgethi, wd._h), T.accent, wd._on)
        rbox(x, by, box, box, 4, fill, lerpc(T.border, T.accent, wd._on))
        text(x + box + 9, by + 1, lerpc(T.text, T.texthi, mmax(wd._h, wd._on)), wd.checkLabel, FONT)
        if clicked(x, by, leftW, box + 4) then wd.check = not wd.check end

        local active = (M._keybox == wd)
        local hovK = hovering(rightX, y + 4, rightW, 28)
        wd._hk = approach(wd._hk or 0, (hovK or active) and 1 or 0, 16)
        text(rightX, y, lerpc(T.text, T.texthi, wd._hk), wd.keyLabel, FONT)
        local kbY, kbH = y + 14, 20
        rbox(rightX, kbY, rightW, kbH, 5, lerpc(T.widget, T.widgethi, wd._hk), active and T.accent or T.border)
        local shown = active and "Press key / scroll" or keyboxName(wd.value)
        text(rightX + rightW / 2, kbY + 4, active and T.accent or T.text, fitText(shown, rightW - 12, FONT), FONT, "center")
        if clicked(rightX, kbY, rightW, kbH) then
            if active then M._keybox = nil
            else M._keybox = wd; wd._captureAt = now() + 0.12 end
        end
        if M._keybox == wd and now() >= (wd._captureAt or 0) then
            local wheel = ms.wheel or 0
            if wheel > 0 then
                wd.value = 0x700
                M._keybox = nil
            elseif wheel < 0 then
                wd.value = 0x701
                M._keybox = nil
            else
                for code = 1, 255 do
                    if keyPressed(code) then
                        wd.value = (code == 0x1B or code == 0x08 or code == 0x2E) and 0 or code
                        M._keybox = nil
                        break
                    end
                end
            end
        end

    elseif wd.kind == "check_combo" then
        local gap = 14
        local leftW = floor(w * 0.48)
        local rightX = x + leftW + gap
        local rightW = w - leftW - gap

        local box = 15
        local by = y + 18
        local hovC = hovering(x, by, leftW, box)
        wd._h = approach(wd._h or 0, hovC and 1 or 0, 16)
        wd._on = approach(wd._on or 0, wd.check and 1 or 0, 16)
        local fill = lerpc(lerpc(T.widget, T.widgethi, wd._h), T.accent, wd._on)
        rbox(x, by, box, box, 4, fill, lerpc(T.border, T.accent, wd._on))
        text(x + box + 9, by + 1, lerpc(T.text, T.texthi, mmax(wd._h, wd._on)), wd.checkLabel, FONT)
        if clicked(x, by, leftW, box + 4) then wd.check = not wd.check end

        local open = (M._combo == wd)
        local comboY, comboH = y + 18, 22
        local hovK = hovering(rightX, comboY, rightW, comboH)
        wd._hc = approach(wd._hc or 0, (hovK or open) and 1 or 0, 16)
        text(rightX, y, lerpc(T.text, T.texthi, wd._hc), wd.comboLabel, FONT)
        rbox(rightX, comboY, rightW, comboH, 5, lerpc(T.widget, T.widgethi, wd._hc), open and T.accent or T.border)
        local shown = wd.options[wd.value] or "?"
        text(rightX + 9, comboY + 5, open and T.texthi or lerpc(T.text, T.texthi, wd._hc), fitText(shown, mmax(20, rightW - 28), FONT), FONT)
        text(rightX + rightW - 16, comboY + 5, open and T.accent or T.textdim, open and "-" or "v", FONT)
        if clicked(rightX, comboY, rightW, comboH) then M._combo = open and nil or wd end
        if M._combo == wd then M._dd = { wd = wd, x = rightX, y = comboY + comboH, w = rightW, bh = comboH } end

    elseif wd.kind == "key_combo" then
        local gap = 14
        local leftW = floor(w * 0.48)
        local rightX = x + leftW + gap
        local rightW = w - leftW - gap

        local active = (M._keybox == wd)
        local hovK = hovering(x, y + 4, leftW, 40)
        wd._hk = approach(wd._hk or 0, (hovK or active) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._hk), wd.keyLabel, FONT)
        local kbY, kbH = y + 18, 22
        rbox(x, kbY, leftW, kbH, 5, lerpc(T.widget, T.widgethi, wd._hk), active and T.accent or T.border)
        local shownKey = active and "Press key / scroll" or keyboxName(wd.keyValue)
        text(x + leftW / 2, kbY + 5, active and T.accent or T.text, fitText(shownKey, leftW - 12, FONT), FONT, "center")
        if clicked(x, kbY, leftW, kbH) then
            if active then
                M._keybox = nil
            else
                M._combo = nil
                M._keybox = wd
                wd._captureAt = now() + 0.12
            end
        end
        if M._keybox == wd and now() >= (wd._captureAt or 0) then
            local wheel = ms.wheel or 0
            if wheel > 0 then
                wd.keyValue = 0x700
                M._keybox = nil
            elseif wheel < 0 then
                wd.keyValue = 0x701
                M._keybox = nil
            else
                for code = 1, 255 do
                    if keyPressed(code) then
                        wd.keyValue = (code == 0x1B or code == 0x08 or code == 0x2E) and 0 or code
                        M._keybox = nil
                        break
                    end
                end
            end
        end

        local open = (M._combo == wd)
        local comboY, comboH = y + 18, 22
        local hovC = hovering(rightX, comboY, rightW, comboH)
        wd._hc = approach(wd._hc or 0, (hovC or open) and 1 or 0, 16)
        text(rightX, y, lerpc(T.text, T.texthi, wd._hc), wd.comboLabel, FONT)
        rbox(rightX, comboY, rightW, comboH, 5, lerpc(T.widget, T.widgethi, wd._hc), open and T.accent or T.border)
        local shown = wd.options[wd.value] or "?"
        text(rightX + 9, comboY + 5, open and T.texthi or lerpc(T.text, T.texthi, wd._hc), fitText(shown, mmax(20, rightW - 28), FONT), FONT)
        text(rightX + rightW - 16, comboY + 5, open and T.accent or T.textdim, open and "-" or "v", FONT)
        if clicked(rightX, comboY, rightW, comboH) then
            M._keybox = nil
            M._combo = open and nil or wd
        end
        if M._combo == wd then M._dd = { wd = wd, x = rightX, y = comboY + comboH, w = rightW, bh = comboH } end

    elseif wd.kind == "button" then
        local bh  = 22
        local hov = hovering(x, y + 1, w, bh)
        wd._h = approach(wd._h or 0, hov and 1 or 0, 16)
        rbox(x, y + 1, w, bh, 6, lerpc(T.widget, T.widgethi, wd._h), lerpc(T.border, T.accent, wd._h * 0.55))
        local buttonText = fitText(wd.label, mmax(20, w - 18), FONT)
        text(x + w / 2, y + 6, lerpc(T.text, T.texthi, wd._h), buttonText, FONT, "center")
        if clicked(x, y + 1, w, bh) then
            local ok, err = pcall(wd.cb); if not ok then print("[DaizML] button error: " .. tostring(err)) end
        end

    elseif wd.kind == "slider" then
        local active = (M._slider == wd)
        wd._h = approach(wd._h or 0, (active or hovering(x, y + 18 - 6, w, 18)) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        local valstr
        if wd.fmt then valstr = string.format(wd.fmt, wd.value)
        elseif wd.dec > 0 then valstr = string.format("%." .. wd.dec .. "f", wd.value)
        else valstr = tostring(rnd(wd.value)) end
        text(x + w, y, T.texthi, valstr, FONT, "right")
        local ty, th = y + 18, 6
        local frac = clamp((wd.value - wd.min) / (wd.max - wd.min), 0, 1)
        rbox(x, ty, w, th, 3, lerpc(T.widget, T.widgethi, wd._h), T.border)
        if frac > 0 then rfill(x, ty, mmax(th, w * frac), th, 3, T.accent, true, false, false, true) end
        if ms.pressed and not ms.consumed and hovering(x, ty - 6, w, th + 12) then
            ms.consumed = true; M._slider = wd
        end
        if active then
            if ms.down and w > 0 then
                local raw = wd.min + clamp((ms.x - x) / w, 0, 1) * (wd.max - wd.min)
                if raw ~= raw then raw = wd.min end
                local v = wd.min + floor((raw - wd.min) / wd.step + 0.5) * wd.step
                v = clamp(v, wd.min, wd.max)
                if wd.dec > 0 then v = tonumber(string.format("%." .. wd.dec .. "f", v)) or v end
                wd.value = v
            elseif not ms.down then
                M._slider = nil
            end
        end

    elseif wd.kind == "combo" then
        local by, bh = y + 18, 22
        local open = (M._combo == wd)
        local hov  = hovering(x, by, w, bh)
        wd._h = approach(wd._h or 0, (hov or open) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        rbox(x, by, w, bh, 5, lerpc(T.widget, T.widgethi, wd._h), open and T.accent or T.border)
        local shown = wd.options[wd.value] or "?"
        local selectedColor = wd.optionColors and wd.optionColors[wd.value]
        local suffix = wd.optionSuffixes and wd.optionSuffixes[wd.value]
        local normalColor = open and T.texthi or lerpc(T.text, T.texthi, wd._h)
        local available = mmax(20, w - 28)
        if suffix and selectedColor and shown:sub(-#suffix) == suffix then
            local prefix = fitText(shown:sub(1, #shown - #suffix), mmax(0, available - textw(suffix)), FONT)
            text(x + 9, by + 5, normalColor, prefix, FONT)
            text(x + 9 + textw(prefix), by + 5, selectedColor, suffix, FONT)
        else
            text(x + 9, by + 5, normalColor, fitText(shown, available, FONT), FONT)
        end
        text(x + w - 16, by + 5, open and T.accent or T.textdim, open and "-" or "v", FONT)
        if clicked(x, by, w, bh) then M._combo = open and nil or wd end
        if M._combo == wd then M._dd = { wd = wd, x = x, y = by + bh, w = w, bh = bh } end

    elseif wd.kind == "multicombo" then
        local by, bh = y + 18, 22
        local open = (M._combo == wd)
        local hov  = hovering(x, by, w, bh)
        wd._h = approach(wd._h or 0, (hov or open) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        rbox(x, by, w, bh, 5, lerpc(T.widget, T.widgethi, wd._h), open and T.accent or T.border)
        local parts, count = {}, 0
        for i, o in ipairs(wd.options) do if wd.value[i] then count = count + 1; parts[#parts + 1] = o end end
        local shown = count == 0 and "None" or (count > 2 and (count .. " selected") or table.concat(parts, ", "))
        shown = fitText(shown, mmax(20, w - 28), FONT)
        text(x + 9, by + 5, open and T.texthi or lerpc(T.text, T.texthi, wd._h), shown, FONT)
        text(x + w - 16, by + 5, open and T.accent or T.textdim, open and "-" or "v", FONT)
        if clicked(x, by, w, bh) then M._combo = open and nil or wd end
        if M._combo == wd then M._dd = { wd = wd, x = x, y = by + bh, w = w, bh = bh } end

    elseif wd.kind == "input" then
        local by, bh = y + 18, 22
        local focused = (M._focus == wd)
        local hov = hovering(x, by, w, bh)
        wd._h = approach(wd._h or 0, (hov or focused) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        rbox(x, by, w, bh, 5, lerpc(T.widget, T.widgethi, wd._h), focused and T.accent or T.border)
        local pad, avail = 9, w - 16
        local tx, ty = x + pad, by + 5
        if wd.value ~= "" or focused then
            local vis, off = inputView(wd, avail)
            if focused then
                local a, b = selBounds(wd)
                if a ~= b then
                    local va, vb = clamp(a, off, off + #vis), clamp(b, off, off + #vis)
                    local sx = textw(wd.value:sub(off + 1, va))
                    local sw = textw(wd.value:sub(off + 1, vb)) - sx
                    if sw > 0 then rfill(tx + sx - 1, by + 4, mmin(sw + 2, avail), bh - 8, 3, { T.accent[1], T.accent[2], T.accent[3], 110 }) end
                end
            end
            text(tx, ty, focused and T.texthi or T.text, vis, FONT)
            if focused and not hasSel(wd) and (floor(now() * 1.6) % 2 == 0) then
                rfill(tx + textw(wd.value:sub(off + 1, wd._caret)), by + 4, 1, bh - 8, 0, T.accent)
            end
        else
            text(tx, ty, T.textdim, wd.placeholder or "", FONT)
        end
        if ms.pressed and not ms.consumed and hovering(x, by, w, bh) then
            ms.consumed = true; M._focus = wd
            local c = caretFromX(wd, ms.x - tx, wd._off or 0)
            wd._caret, wd._anchor, M._inputDrag = c, c, wd
        end
        if M._inputDrag == wd then
            if ms.down and M._focus == wd then wd._caret = caretFromX(wd, ms.x - tx, wd._off or 0)
            else M._inputDrag = nil end
        end
        if focused then pollText(wd, now()) end

    elseif wd.kind == "keybox" then
        local by, bh = y + 18, 22
        local active = (M._keybox == wd)
        local hov = hovering(x, by, w, bh)
        wd._h = approach(wd._h or 0, (hov or active) and 1 or 0, 16)
        text(x, y, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        rbox(x, by, w, bh, 5, lerpc(T.widget, T.widgethi, wd._h), active and T.accent or T.border)
        local shown = active and "Press a key (Esc clears)" or keyboxName(wd.value)
        text(x + w / 2, by + 5, active and T.accent or T.text, fitText(shown, w - 16, FONT), FONT, "center")
        if clicked(x, by, w, bh) then
            if active then M._keybox = nil
            else M._keybox = wd; wd._captureAt = now() + 0.12 end
        end
        if M._keybox == wd and now() >= (wd._captureAt or 0) then
            for code = 1, 255 do
                if keyPressed(code) then
                    wd.value = (code == 0x1B or code == 0x08 or code == 0x2E) and 0 or code
                    M._keybox = nil
                    break
                end
            end
        end
    elseif wd.kind == "color" then
        local hov = hovering(x, y, w, 20)
        wd._h = approach(wd._h or 0, hov and 1 or 0, 16)
        text(x, y + 4, lerpc(T.text, T.texthi, wd._h), wd.label, FONT)
        local sw, shh = 32, 14
        local bx, by = x + w - sw, y + 3
        rbox(bx, by, sw, shh, 3, { wd.value[1], wd.value[2], wd.value[3], 255 }, (M._cp == wd) and T.accent or T.border)
        if clicked(bx, by, sw, shh) then
            if M._cp == wd then M._cp = nil
            else M._cp = wd; wd._hsv = { rgb2hsv(wd.value[1], wd.value[2], wd.value[3]) } end
        end
        if M._cp == wd then
            M._cpRect = { x = x, y = y + 24, sx = bx, sy = by, sw = sw, sh = shh }
        end

    elseif wd.kind == "listbox" then
        local ly = y
        if wd.label and wd.label ~= "" then text(x, y, T.text, wd.label, FONT); ly = y + 18 end
        local lh, itemH = (wd._fillH or wd.h), 20
        if clipBottom then lh = mmax(40, mmin(lh, clipBottom - ly - 8)) end
        rbox(x, ly, w, lh, 5, T.bg2, T.border)
        local n = #wd.items
        local visible = mmax(1, floor(lh / itemH))
        local maxScroll = mmax(0, n - visible)
        if (ms.wheel or 0) ~= 0 and hovering(x, ly, w, lh) then
            wd.scroll = wd.scroll - (ms.wheel > 0 and 1 or -1)
            ms.wheel = 0
        end
        wd.scroll = clamp(wd.scroll, 0, maxScroll)
        local hasBar = n > visible
        local listW = hasBar and (w - 9) or w
        for vi = 0, visible - 1 do
            local idx = vi + 1 + floor(wd.scroll)
            if idx <= n then
                local iy = ly + vi * itemH
                local sel = (idx == wd.value)
                local hov = hovering(x + 2, iy, listW - 4, itemH)
                if sel then
                    rfill(x + 3, iy + 1, listW - 6, itemH - 2, 3, T.accent_bg)
                    rfill(x + 3, iy + 1, 2, itemH - 2, 1, T.accent)
                elseif hov then
                    rfill(x + 3, iy + 1, listW - 6, itemH - 2, 3, T.widget)
                end
                text(x + 11, iy + 3, (sel or hov) and T.texthi or T.text, tostring(wd.items[idx]), FONT)
                if clicked(x + 2, iy, listW - 4, itemH) then wd.value = idx end
            end
        end
        if hasBar then
            local trackX = x + w - 6
            local thumbH = mmax(20, lh * visible / n)
            local thumbY = ly + (lh - thumbH) * (maxScroll > 0 and wd.scroll / maxScroll or 0)
            rfill(trackX, ly + 2, 4, lh - 4, 2, T.widget)
            rfill(trackX, thumbY, 4, thumbH, 2, T.widgethi)
            if ms.pressed and not ms.consumed and hovering(trackX - 2, ly, 8, lh) then
                ms.consumed = true; M._scrollbar = wd
            end
            if M._scrollbar == wd then
                if ms.down then wd.scroll = rnd(clamp((ms.y - ly) / lh, 0, 1) * maxScroll)
                else M._scrollbar = nil end
            end
        end

    elseif wd.kind == "custom" then
        if wd.fn then
            UI._x, UI._cy, UI._w = x, y, w
            local ok, err = pcall(wd.fn, UI, x, y, w)
            if not ok then print("[DaizML] custom widget error: " .. tostring(err)) end
            local used = UI._cy - y
            wd._measured = used > 0 and used or wd.h
        end
    end
end

local function imWidget(id, factory)
    local wd = IM[id]
    if not wd then wd = factory(); IM[id] = wd end
    return wd
end
local function imEmit(wd)
    Section._widget(Section, wd, UI._x, UI._cy, UI._w)
    UI._cy = UI._cy + wheight(wd)
end

function UI.checkbox(id, def)
    local wd = imWidget(id, function() return { kind = "check", label = id, value = def and true or false } end)
    imEmit(wd); return wd.value
end
function UI.slider(id, def, mn, mx, step, fmt)
    local wd = imWidget(id, function() local s = step or 1
        return { kind = "slider", label = id, value = def, min = mn, max = mx, step = s, dec = decimalsOf(s), fmt = fmt } end)
    wd.min, wd.max = mn, mx
    imEmit(wd); return wd.value
end
function UI.combo(id, options, def)
    local wd = imWidget(id, function() return { kind = "combo", label = id, options = options, value = def or 1 } end)
    wd.options = options
    imEmit(wd); return wd.value
end
function UI.button(id)
    local wd = imWidget(id, function() return { kind = "button", label = id } end)
    wd._clicked = false
    wd.cb = function() wd._clicked = true end
    imEmit(wd); return wd._clicked
end
function UI.colorpicker(id, def)
    local wd = imWidget(id, function() local c = def or { 255, 255, 255, 255 }
        return { kind = "color", label = id, value = { c[1], c[2], c[3], c[4] or 255 } } end)
    imEmit(wd); return wd.value
end
function UI.label(s, col)
    local shown = fitText(tostring(s), mmax(20, (UI._w or 200) - 2), FONT)
    text(UI._x, UI._cy, col or T.text, shown, FONT); UI._cy = UI._cy + 18
end

local function renderSectionAt(s, x, y, w)
    local h = 40
    pcall(function() h = s:height() end)
    if s._layoutH then h = mmax(h, s._layoutH) end
    if clipBottom and y >= clipBottom then return h end
    if clipTop and (y + h) <= clipTop then return h end
    local rh = h
    local ok, err = pcall(function() rh = s:render(x, y, w) or h end)
    if not ok then print("[DaizML] section '" .. tostring(s.title) .. "' error: " .. tostring(err)); return h end
    return rh
end

local function renderAutoPack(secs, x, y, w, cols)
    cols = cols or 1
    local colW = (w - (cols - 1) * T.pad) / cols
    local colY, colX = {}, {}
    for c = 1, cols do colY[c] = y; colX[c] = x + (c - 1) * (colW + T.pad) end
    for _, s in ipairs(secs) do
        local best = 1
        for c = 2, cols do if colY[c] < colY[best] then best = c end end
        colY[best] = colY[best] + renderSectionAt(s, colX[best], colY[best], colW) + T.sec_gap
    end
end

local function renderRows(rows, x, y, w)
    local cy = y
    for _, row in ipairs(rows) do
        local n = #row
        if n > 0 then
            local gap = 8
            local colW = (w - (n - 1) * gap) / n
            local colH = {}
            local rowH = 0
            for ci, col in ipairs(row) do
                local h = 0
                for _, s in ipairs(col) do
                    s._layoutH = nil
                    local sh = 40
                    pcall(function() sh = s:height() end)
                    h = h + sh + T.sec_gap
                end
                colH[ci] = h
                if h > rowH then rowH = h end
            end
            for ci, col in ipairs(row) do
                local cxx = x + (ci - 1) * (colW + gap)
                local yy = cy
                local stretch = rowH - colH[ci]
                if stretch > 0 then
                    for _, s in ipairs(col) do
                        if s._hasFill then
                            local sh = 40
                            pcall(function() sh = s:height() end)
                            s._layoutH = sh + stretch
                            break
                        end
                    end
                end
                for _, s in ipairs(col) do
                    yy = yy + renderSectionAt(s, cxx, yy, colW) + T.sec_gap
                    s._layoutH = nil
                end
            end
            cy = cy + rowH
        end
    end
end

local SUBBAR_H = 28

local function renderSubBar(cont, x, y, w)
    local n = #cont.subs
    if n < 1 then return nil, 1 end
    w = mmax(1, tonumber(w) or 1)
    pcall(function() if FONT then draw.SetFont(FONT) end end)

    local minPad = 16
    local natural = {}
    local totalNat = 0
    for i, sub in ipairs(cont.subs) do
        local tw = textw(sub.name) + minPad
        if tw < 36 then tw = 36 end
        natural[i] = tw
        totalNat = totalNat + tw
    end

    local pos, tgtX, tgtW = {}, x, 0
    local sx = x
    if totalNat <= w then
        local extra = (w - totalNat) / n
        for i = 1, n do
            local tw = natural[i] + extra
            pos[i] = { x = sx, w = tw }
            if i == cont._activeSub then tgtX, tgtW = sx, tw end
            sx = sx + tw
        end
    else
        local scale = w / totalNat
        local used = 0
        for i = 1, n - 1 do
            local tw = mmax(28, natural[i] * scale)
            pos[i] = { x = sx, w = tw }
            if i == cont._activeSub then tgtX, tgtW = sx, tw end
            sx = sx + tw
            used = used + tw
        end
        local lastW = mmax(28, w - used)
        pos[n] = { x = sx, w = lastW }
        if n == cont._activeSub then tgtX, tgtW = sx, lastW end
    end

    local relX = tgtX - x
    cont._subX = approach(cont._subX or relX, relX, 16)
    cont._subW = approach(cont._subW or tgtW, tgtW, 16)
    rfill(x + cont._subX + 4, y + SUBBAR_H - 6, mmax(8, cont._subW - 8), 2, 1, T.accent)

    for i, sub in ipairs(cont.subs) do
        local p = pos[i]
        local active = (i == cont._activeSub)
        local hov = hovering(p.x, y, p.w, SUBBAR_H)
        sub._h = approach(sub._h or 0, (active or hov) and 1 or 0, 16)
        local label = fitText(sub.name, mmax(12, p.w - 6), FONT)
        text(p.x + p.w / 2, y + 6, lerpc(T.textdim, T.texthi, sub._h), label, FONT, "center")
        if clicked(p.x, y, p.w, SUBBAR_H) and cont._activeSub ~= i then cont._activeSub = i; cont._subT = 0 end
    end
    rect(x, y + SUBBAR_H, w, 1, T.divider)

    cont._subT = (cont._subT or 1) + (1 - (cont._subT or 1)) * clamp(DT * ANIM.tab, 0, 1)
    return cont.subs[cont._activeSub], smooth(cont._subT)
end

local renderContainer
renderContainer = function(cont, x, y, w)
    if cont.subs and #cont.subs > 0 then
        local child, e = renderSubBar(cont, x, y, w)
        if child then renderContainer(child, x + (1 - e) * 16, y + SUBBAR_H + T.sec_gap, w) end
        return
    end
    if cont._rows and #cont._rows > 0 then renderRows(cont._rows, x, y, w)
    else renderAutoPack(cont.secs, x, y, w, cont._cols) end
end

local function measureSecs(secs)
    local total = 0
    for _, s in ipairs(secs) do local h = 40; pcall(function() h = s:height() end); total = total + h + T.sec_gap end
    return total
end

local containerHeight
containerHeight = function(cont)
    if cont.subs and #cont.subs > 0 then
        local sub = cont.subs[cont._activeSub]
        return SUBBAR_H + T.sec_gap + (sub and containerHeight(sub) or 0)
    end
    if cont._rows and #cont._rows > 0 then
        local total = 0
        for _, row in ipairs(cont._rows) do
            local rowH = 0
            for _, col in ipairs(row) do local h = measureSecs(col); if h > rowH then rowH = h end end
            total = total + rowH
        end
        return total
    end
    local cols = cont._cols or 1
    local colY = {}
    for c = 1, cols do colY[c] = 0 end
    for _, s in ipairs(cont.secs) do
        local best = 1
        for c = 2, cols do if colY[c] < colY[best] then best = c end end
        local h = 40; pcall(function() h = s:height() end)
        colY[best] = colY[best] + h + T.sec_gap
    end
    local mx = 0
    for c = 1, cols do if colY[c] > mx then mx = colY[c] end end
    return mx
end

local function tabContentHeight(tab)
    return containerHeight(tab)
end

local function addSection(cont, title)
    local s = Section.new(title)
    if cont._rows and #cont._rows > 0 then
        local row = cont._rows[#cont._rows]
        local col = row[#row]
        col[#col + 1] = s
    else
        cont.secs[#cont.secs + 1] = s
    end
    return s
end
local function contRow(cont) cont._rows[#cont._rows + 1] = { {} }; return cont end
local function contCol(cont)
    if #cont._rows == 0 then cont._rows[#cont._rows + 1] = { {} } end
    local row = cont._rows[#cont._rows]
    row[#row + 1] = {}
    return cont
end

local Sub = {}
Sub.__index = Sub
function Sub.new(name)
    return setmetatable({ name = name, secs = {}, subs = {}, _rows = {}, _activeSub = 1, _subT = 1 }, Sub)
end
function Sub:Section(title) return addSection(self, title) end
function Sub:Row() return contRow(self) end
function Sub:Col() return contCol(self) end
function Sub:Columns(n) self._cols = n; return self end
function Sub:Sub(name)
    local s = Sub.new(name)
    self.subs[#self.subs + 1] = s
    return s
end

local Tab = {}
Tab.__index = Tab

function Tab.new(name)
    return setmetatable({ name = name, secs = {}, subs = {}, _rows = {}, _cols = 1, _activeSub = 1, _subT = 1 }, Tab)
end

function Tab:Section(title) return addSection(self, title) end
function Tab:Row() return contRow(self) end
function Tab:Col() return contCol(self) end
function Tab:Columns(n) self._cols = n; return self end

function Tab:Sub(name)
    local s = Sub.new(name)
    self.subs[#self.subs + 1] = s
    return s
end

function Tab:render(x, y, w)
    renderContainer(self, x, y, w)
end

M._tabs   = {}
M._active = 1
M._win    = { x = T.x, y = T.y, w = T.w, h = T.h }
M._minimized = false
M._sidebarCollapsed = false
M._sidebarAnim = 1
M._t      = 0
M._tabT   = 1
M._last   = nil
M._toasts = {}
M._notifPos = T.notif_pos
M._onframe = {}

M._watermark = {
    enabled    = false,
    parts      = { custom = true, name = true, uuid = true, map = true, fps = true, ping = true },
    order      = { "custom", "name", "uuid", "map", "fps", "ping" },
    labels     = false,
    labels_invert = false,
    custom_text = "Aimware",
    user       = nil,
    nick       = nil,
    pos        = "top-right",
    x          = nil,
    y          = nil,
    bg         = { 15, 19, 26, 252 },
    accent     = { 74, 166, 255, 255 },
    text       = { 247, 249, 255, 255 },
    text_dim   = { 205, 213, 225, 255 },
    border     = { 40, 48, 61, 255 },
    scale      = 1.0,
    font       = "Segoe UI",
    _fps       = 0,
    _fpsShow   = 0,
    _fpsFrames = 0,
    _fpsWindowStart = nil,
    _ping      = 0,
    _killTry   = -1,
    _drag      = nil,
}

local WM_MISC_KEYS = { "misc.watermark", "misc.watermark.enable", "misc.indicators.watermark" }

function M:Watermark(on) self._watermark.enabled = on and true or false; return self end

function M:WatermarkSet(opts)
    local wm = self._watermark
    if opts.enabled     ~= nil then wm.enabled = opts.enabled and true or false end
    if opts.custom_text ~= nil then wm.custom_text = tostring(opts.custom_text) end
    if opts.user        ~= nil then wm.user = opts.user end
    if opts.nick        ~= nil then wm.nick = opts.nick end
    if opts.pos         ~= nil then wm.pos = opts.pos end
    if opts.x           ~= nil then wm.x = opts.x end
    if opts.y           ~= nil then wm.y = opts.y end
    if opts.bg          ~= nil then wm.bg = { opts.bg[1], opts.bg[2], opts.bg[3], opts.bg[4] or 255 } end
    if opts.accent      ~= nil then wm.accent = { opts.accent[1], opts.accent[2], opts.accent[3], opts.accent[4] or 255 } end
    if opts.text        ~= nil then wm.text = { opts.text[1], opts.text[2], opts.text[3], opts.text[4] or 255 } end
    if opts.text_dim    ~= nil then wm.text_dim = { opts.text_dim[1], opts.text_dim[2], opts.text_dim[3], opts.text_dim[4] or 255 } end
    if opts.border      ~= nil then wm.border = { opts.border[1], opts.border[2], opts.border[3], opts.border[4] or 255 } end
    if opts.scale       ~= nil then wm.scale = clamp(tonumber(opts.scale) or 1, 0.7, 2.0) end
    if opts.font        ~= nil and tostring(opts.font) ~= "" then wm.font = tostring(opts.font) end
    if opts.parts then
        for k, v in pairs(opts.parts) do wm.parts[k] = v and true or false end
    end
    if opts.order ~= nil then
        if type(opts.order) == "table" then
            wm.order = opts.order
        end
    end
    if opts.labels ~= nil then wm.labels = opts.labels and true or false end
    if opts.labels_invert ~= nil then wm.labels_invert = opts.labels_invert and true or false end
    return self
end

function M:RefreshWatermarkFonts()
    local wm = self._watermark
    local scale = clamp(tonumber(wm.scale) or 1, 0.7, 2.0)
    local faces = { "Segoe UI", "Bahnschrift", "Tahoma" }
    local mk = function(list, size, weight)
        for _, name in ipairs(list) do
            local f
            pcall(function() f = draw.CreateFont(name, size, weight) end)
            if not f then pcall(function() f = draw.AddFont(name, size, weight) end) end
            if f then return f end
        end
    end
    WM_FONT = mk(faces, mmax(10, rnd(14 * scale)), 600)
    WM_FONT_LOGO = mk(faces, mmax(11, rnd(16 * scale)), 700) or WM_FONT
    wm.font = "Segoe UI"
    return self
end

function M:KeyName(code)
    return keyboxName(code)
end

function M:WatermarkResetPos()
    local wm = self._watermark
    wm.x, wm.y, wm._drag = nil, nil, nil
    return self
end

function M:WatermarkResetColors()
    local wm = self._watermark
    wm.bg = { 12, 13, 16, 214 }
    wm.accent = { 232, 144, 74, 255 }
    wm.text = { 248, 248, 250, 255 }
    wm.text_dim = { 198, 204, 214, 255 }
    wm.border = { 42, 46, 56, 255 }
    wm.scale = 1.0
    wm.font = "Segoe UI"
    self:RefreshWatermarkFonts()
    return self
end

function M:OnFrame(fn) self._onframe[#self._onframe + 1] = fn; return self end

function M:Tab(name)
    local t = Tab.new(name)
    self._tabs[#self._tabs + 1] = t
    return t
end

local function smoother(x) x = clamp(x, 0, 1); return x * x * x * (x * (x * 6 - 15) + 10) end

function M:Notify(text, kind)
    self._toasts[#self._toasts + 1] = { text = tostring(text), kind = kind or "info", born = now(), life = T.notif_life }
    while #self._toasts > 6 do table.remove(self._toasts, 1) end
end
function M:Info(t)    self:Notify(t, "info")    end
function M:Success(t) self:Notify(t, "success") end
function M:Error(t)   self:Notify(t, "error")   end

function M:SetNotifPos(p) self._notifPos = p end
function M:GetNotifPos() return self._notifPos end

function M:_drawToasts()
    local toasts = self._toasts
    if #toasts == 0 then return end

    local SLIDE_IN, SLIDE_OUT, SLIDE_DIST, GAP = 0.32, 0.45, 24, 8
    local MIN_W, M_OFF = T.notif_w, T.notif_margin
    local sw, sh = 0, 0
    pcall(function() sw, sh = draw.GetScreenSize() end)
    if sw == 0 then return end

    local pos   = self._notifPos
    local right = pos:find("right") ~= nil
    local top   = pos:find("top") ~= nil

    local i = 1
    while i <= #toasts do
        if (now() - toasts[i].born) >= toasts[i].life + SLIDE_OUT + 0.05 then table.remove(toasts, i)
        else i = i + 1 end
    end

    local y = top and M_OFF or (sh - M_OFF)

    local order = {}
    if top then for k = 1, #toasts do order[#order + 1] = k end
    else for k = #toasts, 1, -1 do order[#order + 1] = k end end

    for _, k in ipairs(order) do
        local tw = toasts[k]
        local age = now() - tw.born
        local inE  = smoother(clamp(age / SLIDE_IN, 0, 1))
        local outE = smoother(clamp((age - tw.life) / SLIDE_OUT, 0, 1))
        local dx   = (1 - inE) * SLIDE_DIST + outE * SLIDE_DIST
        local a    = inE * (1 - outE)
        local h    = 46
        pcall(function() draw.SetFont(FONT) end)
        local W = clamp(textw(tw.text) + 30, MIN_W, mmax(MIN_W, mmin(520, sw - M_OFF * 2)))

        local bx = right and (sw - M_OFF - W + dx) or (M_OFF - dx)
        local by = top and y or (y - h)

        ALPHA = a
        local kc = (tw.kind == "success" and T.notif_success) or (tw.kind == "error" and T.notif_error) or T.notif_info
        rbox(bx, by, W, h, 8, T.section, T.border)
        rfill(bx, by, 3, h, 3, kc, true, false, false, true)
        text(bx + 14, by + 9, T.texthi, fitText(tw.text, W - 28, FONT), FONT)

        local prog = 1 - clamp(age / tw.life, 0, 1)
        rect(bx + 12, by + h - 9, W - 24, 3, T.widget)
        if prog > 0 then rfill(bx + 12, by + h - 9, (W - 24) * prog, 3, 1, kc, true, false, false, true) end

        y = top and (y + (h + GAP) * a) or (y - (h + GAP) * a)
    end
end

function M:_drawWatermark()
    local wm = self._watermark
    if not wm.enabled then return end

    do
        wm._fpsFrames = (wm._fpsFrames or 0) + 1
        local rt
        pcall(function() rt = globals.RealTime() end)
        if type(rt) ~= "number" then pcall(function() rt = os.clock() end) end
        if type(rt) == "number" then
            if type(wm._fpsWindowStart) ~= "number" then
                wm._fpsWindowStart = rt
                wm._fpsFrames = 0
            else
                local elapsed = rt - wm._fpsWindowStart
                if elapsed < 0 then
                    wm._fpsWindowStart = rt
                    wm._fpsFrames = 0
                elseif elapsed >= 0.4 then
                    local fps = wm._fpsFrames / elapsed
                    if fps >= 1 and fps <= 1000 then
                        wm._fps = fps
                        wm._fpsShow = floor(fps + 0.5)
                    end
                    wm._fpsWindowStart = rt
                    wm._fpsFrames = 0
                end
            end
        end
    end

    do
        local rt
        pcall(function() rt = globals.RealTime() end)
        if type(rt) ~= "number" then pcall(function() rt = os.clock() end) end
        local last = tonumber(wm._pingAt)
        local elapsed = (type(rt) == "number" and type(last) == "number") and (rt - last) or nil
        local need = (elapsed == nil) or (elapsed >= 0.5) or (elapsed < 0)
        if need then
            wm._pingAt = (type(rt) == "number") and rt or 0
            local ping = 0
            pcall(function()
                local lp = entities.GetLocalPlayer()
                if not lp then return end

                local function readEnt(e, key)
                    if not e then return nil end
                    local v
                    pcall(function() v = e:GetFieldEntity(key) end)
                    if v ~= nil then return v end
                    pcall(function() v = e:GetPropEntity(key) end)
                    if v ~= nil then return v end
                    pcall(function() v = e:GetField(key) end)
                    if type(v) == "userdata" then return v end
                    pcall(function() v = e:GetProp(key) end)
                    if type(v) == "userdata" then return v end
                    return nil
                end

                local function readPing(e)
                    if not e then return nil end
                    local v
                    pcall(function() v = e:GetFieldInt("m_iPing") end)
                    if type(v) == "number" then return v end
                    pcall(function() v = e:GetPropInt("m_iPing") end)
                    if type(v) == "number" then return v end
                    pcall(function() v = e:GetField("m_iPing") end)
                    if type(v) == "number" then return v end
                    pcall(function() v = e:GetProp("m_iPing") end)
                    if type(v) == "number" then return v end
                    return nil
                end

                local ctrl
                pcall(function()
                    if entities.GetLocalPlayerController then
                        ctrl = entities.GetLocalPlayerController()
                    end
                end)
                local v = readPing(ctrl)
                if type(v) ~= "number" then
                    ctrl = readEnt(lp, "m_hController")
                        or readEnt(lp, "m_hOriginalControllerOfCurrentPawn")
                    v = readPing(ctrl)
                end
                if type(v) ~= "number" then
                    local pawnIdx, pawnName
                    pcall(function() pawnIdx = lp:GetIndex() end)
                    pcall(function() pawnName = lp:GetName() end)
                    local classes = { "CCSPlayerController", "C_CSPlayerController" }
                    for c = 1, #classes do
                        local list
                        pcall(function() list = entities.FindByClass(classes[c]) end)
                        if type(list) == "table" then
                            for i = 1, #list do
                                local cand = list[i]
                                if cand then
                                    local matched = false
                                    local linked = readEnt(cand, "m_hPlayerPawn")
                                    if linked and pawnIdx then
                                        local li
                                        pcall(function() li = linked:GetIndex() end)
                                        if li == pawnIdx then matched = true end
                                    end
                                    if not matched and pawnName then
                                        local cn
                                        pcall(function() cn = cand:GetName() end)
                                        if cn == pawnName then matched = true end
                                    end
                                    if matched then
                                        v = readPing(cand)
                                        if type(v) == "number" then break end
                                    end
                                end
                            end
                        end
                        if type(v) == "number" then break end
                    end
                end
                if type(v) ~= "number" then
                    v = readPing(lp)
                end
                if type(v) == "number" and v >= 0 then
                    ping = floor(v + 0.5)
                end
            end)
            wm._ping = clamp(ping, 0, 999)
        end
    end

    local colBg = wm.bg or { 9, 11, 16, 214 }
    local colAccent = wm.accent or { 74, 166, 255, 255 }
    local colText = wm.text or { 205, 213, 225, 255 }
    pcall(function()
        local c = uiAccent:Get()
        if type(c) == "table" and c[1] then
            colAccent = { c[1], c[2], c[3], c[4] or 255 }
        end
    end)
    pcall(function()
        local c = uiText:Get()
        if type(c) == "table" and c[1] then
            colText = { c[1], c[2], c[3], c[4] or 255 }
        end
    end)
    colBg = { 9, 11, 16, 214 }
    local colDim = {
        math.max(90, math.floor((colText[1] or 205) * 0.72)),
        math.max(95, math.floor((colText[2] or 213) * 0.72)),
        math.max(105, math.floor((colText[3] or 225) * 0.72)),
        255,
    }
    local colBorder = wm.border or { 40, 48, 61, 255 }
    local scale = clamp(tonumber(wm.scale) or 1, 0.7, 2.0)
    local font = WM_FONT or FONT
    local fontLogo = WM_FONT_LOGO or FONT_LOGO or font

    local function aimwareName()
        if type(wm.user) == "string" and wm.user ~= "" and wm.user ~= "user" then
            return wm.user
        end
        local name
        pcall(function() name = cheat.GetUserName() end)
        name = tostring(name or ""):gsub("[%c%z]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then
            wm.user = name
            return name
        end
        return wm.user or "user"
    end

    local function aimwareUserId()
        local id
        pcall(function() id = cheat.GetUserID() end)
        id = tonumber(id)
        if type(id) == "number" then
            wm._userId = id
            return id
        end
        return tonumber(wm._userId)
    end

    local function mapName()
        local map
        pcall(function() map = engine.GetMapName() end)
        map = tostring(map or ""):gsub("[%c%z]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if map == "" then return "unknown" end
        map = map:gsub("\\", "/"):match("([^/]+)$") or map
        map = map:gsub("%.bsp$", ""):gsub("%.vpk$", "")
        return map
    end

    local function nameSeg(s)
        s = tostring(s or "")
        local dot
        for i = #s, 2, -1 do if s:sub(i, i) == "." then dot = i; break end end
        if dot and dot >= 2 and dot < #s then
            return { { s:sub(1, dot - 1), colText, fontLogo }, { s:sub(dot), colAccent, fontLogo } }
        end
        return { { s, colText, fontLogo } }
    end

    local function fixedSeg(label, probe)
        local seg = { { label, colDim, font } }
        if probe and probe ~= label then
            pcall(function()
                draw.SetFont(font)
                seg.minW = mmax(textw(label), textw(probe))
            end)
        end
        return seg
    end

    local useLabels = wm.labels and true or false
    local invertLabels = wm.labels_invert and true or false
    local colLabel = invertLabels and colText or colAccent
    local colValue = invertLabels and colAccent or colText

    local function labeledSeg(prefix, value, probe)
        local valueText = tostring(value or "")
        local seg = {
            { tostring(prefix or ""), colLabel, font },
            { valueText, colValue, font },
        }
        if probe and probe ~= valueText then
            pcall(function()
                draw.SetFont(font)
                local prefixW = textw(tostring(prefix or ""))
                seg.minW = prefixW + mmax(textw(valueText), textw(probe))
            end)
        end
        return seg
    end

    local segs = {}
    local order = wm.order
    if type(order) ~= "table" or #order == 0 then
        order = { "custom", "name", "uuid", "map", "fps", "ping" }
    end
    for oi = 1, #order do
        local key = order[oi]
        if key == "custom" and wm.parts.custom then
            local ct = tostring(wm.custom_text or "")
            if ct ~= "" then segs[#segs + 1] = nameSeg(ct) end
        elseif key == "name" and wm.parts.name then
            if useLabels then
                segs[#segs + 1] = labeledSeg("AW User: ", aimwareName())
            else
                segs[#segs + 1] = nameSeg(aimwareName())
            end
        elseif key == "uuid" and wm.parts.uuid then
            local id = aimwareUserId()
            local label = (type(id) == "number") and tostring(floor(id)) or "uuid"
            if useLabels then
                segs[#segs + 1] = labeledSeg("UUID: ", label)
            else
                segs[#segs + 1] = fixedSeg(label, label)
            end
        elseif key == "map" and wm.parts.map then
            local map = mapName()
            if useLabels then
                segs[#segs + 1] = labeledSeg("Map: ", map)
            else
                segs[#segs + 1] = fixedSeg(map, map)
            end
        elseif key == "fps" and wm.parts.fps then
            local shown = clamp(tonumber(wm._fpsShow) or floor((wm._fps or 0) + 0.5), 0, 999)
            if useLabels then
                segs[#segs + 1] = labeledSeg("FPS: ", tostring(shown), "000")
            else
                segs[#segs + 1] = fixedSeg(string.format("%d fps", shown), "000 fps")
            end
        elseif key == "ping" and wm.parts.ping then
            local shown = clamp(tonumber(wm._ping) or 0, 0, 999)
            if useLabels then
                segs[#segs + 1] = labeledSeg("Ping: ", tostring(shown), "000")
            else
                local label = string.format("%d ms", shown)
                segs[#segs + 1] = fixedSeg(label, label)
            end
        end
    end
    if #segs == 0 then return end

    local sw, sh = 0, 0
    pcall(function() sw, sh = draw.GetScreenSize() end)
    if sw == 0 then return end

    local PADX, PADY, DIVPAD = mmax(6, rnd(11 * scale)), mmax(3, rnd(6 * scale)), mmax(5, rnd(9 * scale))
    local radius = mmax(3, rnd(6 * scale))
    local function runW(run)
        if run[3] then pcall(function() draw.SetFont(run[3]) end) end
        return textw(run[1])
    end
    local function segW(seg)
        local w = 0
        for _, run in ipairs(seg) do w = w + runW(run) end
        if seg.minW then w = mmax(w, seg.minW) end
        return w
    end

    local totalW = PADX * 2
    for si, seg in ipairs(segs) do
        if si > 1 then totalW = totalW + DIVPAD * 2 + 1 end
        totalW = totalW + segW(seg)
    end

    local txtH = mmax(10, rnd(14 * scale))
    pcall(function() draw.SetFont(font) end)
    pcall(function() local _, h = draw.GetTextSize("Ayg"); if h and h > 4 then txtH = floor(h + 0.5) end end)
    local barH = txtH + PADY * 2

    local margin = mmax(8, rnd(14 * scale))
    local pos    = wm.pos or "top-right"
    local right  = pos:find("right") ~= nil
    local bottom = pos:find("bottom") ~= nil
    local bx = right  and (sw - margin - totalW) or margin
    local by = bottom and (sh - margin - barH)   or margin
    if wm.x ~= nil and wm.y ~= nil then
        bx, by = wm.x, wm.y
    end
    bx = clamp(bx, 0, mmax(0, sw - totalW))
    by = clamp(by, 0, mmax(0, sh - barH))

    if self._open then
        local hov = hovering(bx, by, totalW, barH)
        if ms.pressed and not ms.consumed and hov then
            ms.consumed = true
            wm._drag = { dx = ms.x - bx, dy = ms.y - by }
        end
        if wm._drag then
            if ms.down then
                bx = clamp(ms.x - wm._drag.dx, 0, mmax(0, sw - totalW))
                by = clamp(ms.y - wm._drag.dy, 0, mmax(0, sh - barH))
                wm.x, wm.y = bx, by
                ms.consumed = true
            else
                wm._drag = nil
            end
        end
    else
        wm._drag = nil
    end

    local canDrag = self._open and true or false
    local active = wm._drag and true or false
    local hov = canDrag and hovering(bx, by, totalW, barH)
    local border = (active and colAccent) or (hov and { colBorder[1] + 20, colBorder[2] + 20, colBorder[3] + 20, 255 }) or colBorder

    ALPHA = 1
    rbox(bx, by, totalW, barH, radius, colBg, border)
    rfill(bx, by, totalW, mmax(1, rnd(2 * scale)), radius, colAccent, true, true, false, false)

    local cx = bx + PADX
    local ty = by + PADY
    for si, seg in ipairs(segs) do
        if si > 1 then
            rect(cx + DIVPAD, by + mmax(3, rnd(6 * scale)), 1, barH - mmax(6, rnd(12 * scale)), colBorder)
            cx = cx + DIVPAD * 2 + 1
        end
        local slot = segW(seg)
        local tx = cx
        for _, run in ipairs(seg) do
            text(tx, ty, run[2], run[1], run[3])
            tx = tx + textw(run[1])
        end
        cx = cx + slot
    end
end

local SIDEBAR_W_FULL = 220
local SIDEBAR_W_MINI = 68
local SIDEBAR_BRAND_H = 72
local SIDEBAR_PROFILE_H = 86

local function sidebarAnim()
    local a = tonumber(M._sidebarAnim)
    if a == nil then a = M._sidebarCollapsed and 0 or 1 end
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    return a
end

local function sidebarW()
    local a = sidebarAnim()
    return math.floor(SIDEBAR_W_MINI + (SIDEBAR_W_FULL - SIDEBAR_W_MINI) * a + 0.5)
end

local function sidebarCompact()
    return sidebarAnim() < 0.55
end

local NAV_LABELS = {
    ["MISC"] = "Misc",
    ["VISUALS"] = "Visuals",
    ["SKINS"] = "Skins",
    ["SETTINGS"] = "Settings",
    ["PARTICLES"] = "Particles",
    ["GRENADE"] = "Grenades",
}

local TAB_ICON_SIZE = 16
local TabIcons = { tex = {}, tried = {} }
local TabFonts = {}
local TAB_ICON_SVG = {
    SKINS = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#ffffff" d="M2.5 10.2c0-.6.4-1.1 1-1.3l8.2-2.5c.3-.1.6 0 .8.2l1.1 1.1 2.2-.7c.5-.2 1.1 0 1.4.4l1.4 2.1c.2.3.2.7 0 1l-1.1 1.4c-.2.3-.6.4-.9.3l-1.5-.4-1.2 1.5c-.2.3-.6.4-.9.3L3.8 12.2c-.7-.2-1.3-.9-1.3-1.6v-.4zm14.2 1.1 1.1.3 1-1.2-1.2-1.8-1.8.6.9 2.1zM4.2 14.5h9.2c.4 0 .7.3.7.7v.8c0 .4-.3.7-.7.7H4.2c-.4 0-.7-.3-.7-.7v-.8c0-.4.3-.7.7-.7zm1.2 3.2h6.8c.3 0 .6.3.6.6v.6c0 .3-.3.6-.6.6H5.4c-.3 0-.6-.3-.6-.6v-.6c0-.3.3-.6.6-.6z"/></svg>]],
    VISUALS = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="none" stroke="#ffffff" stroke-width="1.7" stroke-linecap="round" d="M2.8 12s3.4-5.4 9.2-5.4S21.2 12 21.2 12s-3.4 5.4-9.2 5.4S2.8 12 2.8 12z"/><circle cx="12" cy="12" r="3.1" fill="none" stroke="#ffffff" stroke-width="1.7"/><circle cx="12" cy="12" r="1.2" fill="#ffffff"/></svg>]],
    MISC = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="none" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" d="M4 7h16M4 12h16M4 17h16"/><circle cx="8" cy="7" r="1.7" fill="#ffffff"/><circle cx="15" cy="12" r="1.7" fill="#ffffff"/><circle cx="10" cy="17" r="1.7" fill="#ffffff"/></svg>]],
    GRENADE = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#ffffff" d="M10.2 3.2h3.6c.4 0 .7.3.7.7v1.1h.9c.5 0 .9.4.9.9v1.1l.8.5c1.5.9 2.5 2.6 2.5 4.5v3.6c0 2.9-2.4 5.3-5.3 5.3h-3.6c-2.9 0-5.3-2.4-5.3-5.3v-3.6c0-1.9 1-3.6 2.5-4.5l.8-.5V5.9c0-.5.4-.9.9-.9h.9V3.9c0-.4.3-.7.7-.7zm1.8 4.2c-2.6 0-4.7 2.1-4.7 4.7v3.2c0 2.1 1.7 3.8 3.8 3.8h1.8c2.1 0 3.8-1.7 3.8-3.8v-3.2c0-2.6-2.1-4.7-4.7-4.7z"/><path fill="#ffffff" d="M11.2 2.2h1.6v1.4h-1.6z"/></svg>]],
    PARTICLES = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#ffffff" d="M12 3.2l1.1 3.3 3.4.1-2.7 2.1.9 3.4L12 10.6 9.3 12.1l.9-3.4-2.7-2.1 3.4-.1z"/><circle cx="5.2" cy="16.2" r="1.3" fill="#ffffff"/><circle cx="18.8" cy="15.5" r="1.1" fill="#ffffff"/><circle cx="9.2" cy="19.2" r="0.9" fill="#ffffff"/><circle cx="15.5" cy="19.5" r="1.0" fill="#ffffff"/><circle cx="19.5" cy="8.2" r="0.8" fill="#ffffff"/></svg>]],
    SETTINGS = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#ffffff" d="M19.1 12.6c0-.2 0-.4-.1-.6l1.7-1.3c.2-.1.2-.4.1-.6l-1.6-2.8c-.1-.2-.3-.3-.5-.2l-2 .8c-.3-.3-.7-.5-1.1-.6l-.3-2.1c0-.2-.2-.4-.4-.4h-3.2c-.2 0-.4.2-.4.4l-.3 2.1c-.4.1-.8.3-1.1.6l-2-.8c-.2-.1-.4 0-.5.2L3.2 10.1c-.1.2-.1.5.1.6l1.7 1.3c0 .2-.1.4-.1.6s0 .4.1.6L3.3 14.5c-.2.1-.2.4-.1.6l1.6 2.8c.1.2.3.3.5.2l2-.8c.3.3.7.5 1.1.6l.3 2.1c0 .2.2.4.4.4h3.2c.2 0 .4-.2.4-.4l.3-2.1c.4-.1.8-.3 1.1-.6l2 .8c.2.1.4 0 .5-.2l1.6-2.8c.1-.2.1-.5-.1-.6l-1.7-1.3c.1-.2.1-.4.1-.6zM12 15.2c-1.8 0-3.2-1.4-3.2-3.2S10.2 8.8 12 8.8s3.2 1.4 3.2 3.2-1.4 3.2-3.2 3.2z"/></svg>]],
    SAVE = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#ffffff" d="M17.2 3.2H5.2C4 3.2 3.2 4 3.2 5.2v13.6c0 1.2.8 2 2 2h13.6c1.2 0 2-.8 2-2V7.2l-3.6-4zM12 18.2c-1.7 0-3-1.3-3-3s1.3-3 3-3 3 1.3 3 3-1.3 3-3 3zm3.2-9.6H5.2V5.2h10v3.4z"/></svg>]],
    WARNING = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#ffffff" d="M12.9 3.6l9.2 15.9c.4.7-.1 1.6-.9 1.6H2.8c-.8 0-1.3-.9-.9-1.6L11.1 3.6c.4-.7 1.4-.7 1.8 0z"/><path fill="#1a1a1a" d="M12 8.4c.5 0 .9.4.9.9v4.6c0 .5-.4.9-.9.9s-.9-.4-.9-.9V9.3c0-.5.4-.9.9-.9zm0 7.8c.6 0 1.1.5 1.1 1.1S12.6 18.4 12 18.4s-1.1-.5-1.1-1.1.5-1.1 1.1-1.1z"/></svg>]],
}

local function tabIconIsSvg(data)
    return type(data) == "string" and #data > 40
        and (data:find("<svg", 1, true) or data:find("<SVG", 1, true))
end

local function ensureTabIcon(key, pixelSize)
    pixelSize = math.floor(clamp(tonumber(pixelSize) or TAB_ICON_SIZE, 12, 72))
    local bucket = math.floor((pixelSize + 1) / 2) * 2
    local cacheKey = key .. "@" .. bucket
    if TabIcons.tex[cacheKey] ~= nil then return TabIcons.tex[cacheKey] end
    if TabIcons.tried[cacheKey] then return false end
    TabIcons.tried[cacheKey] = true
    local data = TAB_ICON_SVG[key]
    if not tabIconIsSvg(data) then
        TabIcons.tex[cacheKey] = false
        return false
    end
    local svgScale = bucket / 24
    local rgba, w, h
    local ok = pcall(function()
        rgba, w, h = common.RasterizeSVG(data, svgScale)
    end)
    if not (ok and rgba and w and h and w > 0 and h > 0) then
        TabIcons.tex[cacheKey] = false
        return false
    end
    local tex
    ok = pcall(function() tex = draw.CreateTexture(rgba, w, h) end)
    if not (ok and tex) then
        TabIcons.tex[cacheKey] = false
        return false
    end
    TabIcons.tex[cacheKey] = { tex = tex, w = w, h = h }
    return TabIcons.tex[cacheKey]
end

local function drawTabIcon(key, x, y, size, col, a)
    size = tonumber(size) or TAB_ICON_SIZE
    a = tonumber(a) or 255
    local info = ensureTabIcon(key, size)
    if not (info and info.tex) then return false end
    local tw, th = size, size
    if info.w and info.h and info.h > 0 then
        tw = size * (info.w / info.h)
    end
    pcall(function()
        draw.Color(
            math.floor(col[1] or 220),
            math.floor(col[2] or 220),
            math.floor(col[3] or 220),
            math.floor((a or 255) * ALPHA)
        )
        draw.SetTexture(info.tex)
        draw.FilledRect(math.floor(x), math.floor(y), math.floor(x + tw), math.floor(y + th))
        draw.SetTexture(nil)
    end)
    return true
end

local HEADER_USER
local HEADER_UUID
local HeaderNameFont, HeaderIdFont 
HeaderNameFont, HeaderIdFont = nil, nil
local function aimwareHeaderUser()
    if HEADER_USER and HEADER_USER ~= "" then return HEADER_USER end
    local value
    pcall(function() value = cheat.GetUserName() end)
    value = tostring(value or ""):gsub("[%c%z]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value ~= "" then HEADER_USER = value; return value end
    return "Aimware user"
end

local function aimwareHeaderUuid()
    if HEADER_UUID ~= nil then return HEADER_UUID end
    local id
    pcall(function() id = cheat.GetUserID() end)
    id = tonumber(id)
    if type(id) == "number" then
        HEADER_UUID = math.floor(id)
        return HEADER_UUID
    end
    return nil
end

local function aimwareHeaderLabel()
    local name = aimwareHeaderUser()
    local id = aimwareHeaderUuid()
    if id then return string.format("%s (%d)", name, id) end
    return name
end

local function tabFont(size, weight)
    size = math.floor(clamp(tonumber(size) or 14, 11, 20))
    weight = tonumber(weight) or 400
    local key = size .. ":" .. weight
    if TabFonts[key] then return TabFonts[key] end
    local f
    local faces = T.font or { "Segoe UI", "Tahoma" }
    for _, name in ipairs(faces) do
        pcall(function() f = draw.CreateFont(name, size, weight) end)
        if not f then pcall(function() f = draw.AddFont(name, size, weight) end) end
        if f then break end
    end
    TabFonts[key] = f or FONT
    return TabFonts[key]
end

local TAB_ICON_MAX = 18
local TAB_FONT_MAX = 14
local TAB_ROW_CONTENT_H = 40

local function tabLayout(tabs, win)
    local pos = {}
    local n = mmax(1, #tabs)
    local sw = sidebarW()
    local compact = sidebarCompact()
    local padX = compact and 8 or 12
    local x = win.x + padX
    local top = win.y + SIDEBAR_BRAND_H + 8
    local bottom = win.y + win.h - SIDEBAR_PROFILE_H - 12
    local avail = mmax(1, bottom - top)
    local step = avail / n
    local h = clamp(step * 0.82, 28, mmax(TAB_ROW_CONTENT_H, step * 0.9))
    local y0 = top + (step - h) * 0.35
    local w = mmax(28, sw - padX * 2)
    for i = 1, n do
        pos[i] = { x = x, y = y0 + (i - 1) * step, w = w, h = h, step = step }
    end
    return pos
end

function M:_sidebarToggleRect(win)
    local sw = sidebarW()
    local bw, bh = 22, 22
    local a = sidebarAnim()
    local bx, by
    if a < 0.55 then
        bx = win.x + math.floor((sw - bw) * 0.5)
        by = win.y + 46
    else
        bx = win.x + sw - bw - 10
        by = win.y + 22
    end
    return bx, by, bw, bh
end

function M:_tabInput(win)
    if win.h < 120 then return end
    local tx, ty, tw, th = self:_sidebarToggleRect(win)
    if clicked(tx, ty, tw, th) then
        self._sidebarCollapsed = not self._sidebarCollapsed
        return
    end
    local pos = tabLayout(self._tabs, win)
    for i, p in ipairs(pos) do
        if p.y + 4 < win.y + win.h and p.y + p.h > win.y then
            if clicked(p.x, p.y, p.w, p.h) and self._active ~= i then
                self._active = i
                self._scroll = 0
                M._combo = nil
                self._tabT = 0
            end
        end
    end
end

function M:_saveBtnRect(win)
    return win.x + win.w - 108, win.y + 12, 88, 28
end

function M:_drawTabBar(win)
    local clipOk = false
    pcall(function()
        draw.SetScissorRect(rnd(win.x), rnd(win.y), rnd(win.w), rnd(win.h))
        clipOk = true
    end)

    if type(M._ensureSteamAvatar) == "function" then
        pcall(M._ensureSteamAvatar)
    end

    local sw = sidebarW()
    local a = sidebarAnim()
    local compact = a < 0.55
    local labelA = clamp((a - 0.35) / 0.45, 0, 1)

    local rail = T.rail or T.bg
    rfill(win.x + 1, win.y + 1, sw - 1, win.h - 2, 14, rail, true, false, true, false)
    rect(win.x + sw, win.y + 10, 1, mmax(0, win.h - 20), T.divider)

    do
        if type(M._ensureBrandLogo) == "function" then
            pcall(M._ensureBrandLogo)
        end
        local mark = 28
        local bx, by
        if compact then
            bx = win.x + math.floor((sw - mark) * 0.5)
            by = win.y + 14
        else
            bx = win.x + 18
            by = win.y + 18
        end
        rfill(bx, by, mark, mark, 8, T.accent_bg)
        rfill(bx + 2, by + 2, mark - 4, mark - 4, 6, { 14, 18, 30, 255 })
        local logoPad = 3
        local logoSz = mark - logoPad * 2
        local drewLogo = false
        if M._brandLogoTex then
            local okDraw = pcall(function()
                draw.Color(255, 255, 255, rnd(255 * ALPHA))
                draw.SetTexture(M._brandLogoTex)
                draw.FilledRect(rnd(bx + logoPad), rnd(by + logoPad), rnd(bx + logoPad + logoSz), rnd(by + logoPad + logoSz))
                draw.SetTexture(nil)
            end)
            drewLogo = okDraw and true or false
        end
        if not drewLogo then
            text(bx + mark * 0.5, by + 5, T.texthi, "D", FONT_B or FONT_LOGO or FONT, "center")
        end
        if labelA > 0.02 then
            local titleCol = { T.texthi[1], T.texthi[2], T.texthi[3], math.floor((T.texthi[4] or 255) * labelA) }
            local dimCol = { T.textdim[1], T.textdim[2], T.textdim[3], math.floor((T.textdim[4] or 255) * labelA) }
            text(bx + mark + 10, by + 2, titleCol, tostring(T.title or "DaizML"), FONT_LOGO or FONT_B or FONT)
            text(bx + mark + 10, by + 20, dimCol, tostring(T.title_tld or "studio"):upper(), FONT_SMALL)
        end
    end

    do
        local tx, ty, tw, th = self:_sidebarToggleRect(win)
        local hov = hovering(tx, ty, tw, th)
        rbox(tx, ty, tw, th, 6, hov and T.widgethi or T.widget, hov and T.accent or T.border)
        local glyph = self._sidebarCollapsed and ">" or "<"
        text(tx + tw * 0.5, ty + 3, hov and T.texthi or T.textdim, glyph, FONT_B or FONT, "center")
    end

    if win.h >= 160 then
        local pos = tabLayout(self._tabs, win)
        for i, t in ipairs(self._tabs) do
            local p = pos[i]
            if p and p.y + 4 < win.y + win.h - SIDEBAR_PROFILE_H and p.y + p.h > win.y + SIDEBAR_BRAND_H then
                local active = (i == self._active)
                local hovTab = hovering(p.x, p.y, p.w, p.h)
                t._h = approach(t._h or 0, (active or hovTab) and 1 or 0, 14)
                local iconSz = math.floor(clamp(mmin(p.h * 0.42, TAB_ICON_MAX), 14, TAB_ICON_MAX))
                local fontSz = math.floor(clamp(mmin(p.h * 0.34, TAB_FONT_MAX), 12, TAB_FONT_MAX))
                local contentH = mmin(p.h, TAB_ROW_CONTENT_H)
                local cy = p.y + (p.h - contentH) * 0.5
                if active then
                    rfill(p.x, cy, p.w, contentH, 10, T.accent_bg)
                    if not compact then
                        local barH = mmax(12, contentH - 16)
                        rfill(p.x + 3, cy + (contentH - barH) * 0.5, 3, barH, 2, T.accent)
                    end
                elseif (t._h or 0) > 0.02 then
                    local ha = math.floor(110 * (t._h or 0))
                    rfill(p.x, cy, p.w, contentH, 10, { T.widgethi[1], T.widgethi[2], T.widgethi[3], ha })
                end
                local fLabel = tabFont(fontSz, active and 600 or 400)
                local iconCol = lerpc(T.textdim, active and T.accent or T.texthi, t._h)
                local iconA = active and 255 or math.floor(150 + 90 * (t._h or 0))
                local iconX = compact and (p.x + (p.w - iconSz) * 0.5) or (p.x + 14)
                local iconY = cy + (contentH - iconSz) * 0.5
                local hasIcon = drawTabIcon(t.name, iconX, iconY, iconSz, iconCol, iconA)
                if labelA > 0.02 then
                    local label = NAV_LABELS[t.name] or t.name
                    local textX = hasIcon and (p.x + 14 + iconSz + 10) or (p.x + 16)
                    local textMax = p.w - (textX - p.x) - 12
                    label = fitText(label, textMax, fLabel)
                    local ty = cy + mmax(4, (contentH - fontSz) * 0.5 - 1)
                    local col = lerpc(T.textdim, T.texthi, t._h)
                    text(textX, ty, { col[1], col[2], col[3], math.floor((col[4] or 255) * labelA) }, label, fLabel)
                end
            end
        end
    end

    do
        local ph = SIDEBAR_PROFILE_H - 16
        local px = win.x + (compact and 8 or 12)
        local py = win.y + win.h - SIDEBAR_PROFILE_H + 4
        local pw = mmax(36, sw - (compact and 16 or 24))
        rfill(px, py, pw, ph, 12, T.section)
        rect(px, py, pw, 1, T.divider)

        local size = compact and 32 or 36
        local ax = compact and (px + math.floor((pw - size) * 0.5)) or (px + 12)
        local ay = py + math.floor((ph - size) * 0.5)
        local cx = ax + size * 0.5
        local cy = ay + size * 0.5
        local rad = math.floor(size * 0.5)
        rfill(cx - rad - 1, cy - rad - 1, size + 2, size + 2, rad + 1, { T.accent[1], T.accent[2], T.accent[3], 200 })
        rfill(cx - rad, cy - rad, size, size, rad, { 22, 24, 30, 255 })
        if M._avatarTex then
            local s = size - 2
            local tx0 = math.floor(cx - s * 0.5)
            local ty0 = math.floor(cy - s * 0.5)
            pcall(function()
                draw.Color(255, 255, 255, rnd(255 * ALPHA))
                draw.SetTexture(M._avatarTex)
                draw.FilledRect(tx0, ty0, tx0 + s, ty0 + s)
                draw.SetTexture(nil)
            end)
        else
            local init = tostring(aimwareHeaderUser() or "?"):sub(1, 1):upper()
            text(cx, cy - 8, T.texthi, init, FONT_B or FONT_LOGO or FONT, "center")
        end

        if labelA > 0.02 then
            local nameStr = aimwareHeaderUser()
            local id = aimwareHeaderUuid()
            local nameFont = HeaderNameFont
            if not nameFont then
                pcall(function() nameFont = draw.CreateFont("Segoe UI", 14, 650) end)
                if not nameFont then pcall(function() nameFont = draw.AddFont("Segoe UI", 14, 650) end) end
                HeaderNameFont = nameFont or FONT_B or FONT
                nameFont = HeaderNameFont
            end
            local idFont = HeaderIdFont
            if not idFont then
                pcall(function() idFont = draw.CreateFont("Segoe UI", 11, 400) end)
                if not idFont then pcall(function() idFont = draw.AddFont("Segoe UI", 11, 400) end) end
                HeaderIdFont = idFont or FONT_SMALL or FONT
                idFont = HeaderIdFont
            end
            local tx = ax + size + 10
            local maxW = math.max(40, (px + pw - 10) - tx)
            nameStr = fitText(nameStr, maxW, nameFont)
            local nameCol = { T.texthi[1], T.texthi[2], T.texthi[3], math.floor((T.texthi[4] or 255) * labelA) }
            local dimCol = { T.textdim[1], T.textdim[2], T.textdim[3], math.floor((T.textdim[4] or 255) * labelA) }
            text(tx, ay + 4, nameCol, nameStr, nameFont)
            if id then
                text(tx, ay + 22, dimCol, string.format("ID %d", id), idFont)
            else
                text(tx, ay + 22, dimCol, "signed in", idFont)
            end
        end
    end

    do
        local tab = self._tabs[self._active]
        local page = tab and (NAV_LABELS[tab.name] or tab.name) or "Menu"
        local hx = win.x + sw + 22
        local hy = win.y + 14
        text(hx, hy, T.texthi, page, FONT_LOGO or FONT_B or FONT)
        text(hx, hy + 20, T.textdim, "Module", FONT_SMALL)

        local sx, sy, swB, sh = self:_saveBtnRect(win)
        local flash = approach(self._saveFlash or 0, 0, 3)
        self._saveFlash = flash < 0.01 and 0 or flash
        local hov = hovering(sx, sy, swB, sh)
        local base = hov and T.widgethi or T.widget
        local fill = lerpc(base, { 64, 200, 120, 255 }, flash)
        local edge = lerpc(T.accent, { 96, 230, 150, 255 }, flash)
        rbox(sx, sy, swB, sh, 8, fill, { edge[1], edge[2], edge[3], 200 })
        local saveCol = flash > 0.35 and T.texthi or (hov and T.texthi or T.textdim)
        local saveA = flash > 0.35 and 255 or (hov and 255 or 200)
        local saveIcon = 16
        drawTabIcon("SAVE", sx + 12, sy + (sh - saveIcon) * 0.5, saveIcon, saveCol, saveA)
        text(sx + 34, sy + 6, saveCol, "Save", FONT_SMALL)
    end

    if clipOk then
        pcall(function()
            local ssw, ssh = draw.GetScreenSize()
            draw.SetScissorRect(0, 0, ssw, ssh)
        end)
    end
end

local DD_ITEMH, DD_MAXVIS = 22, 9

function M:_dropdownInput()
    if not M._combo or not M._dd or M._dd.wd ~= M._combo then return end
    local d, wd = M._dd, M._dd.wd
    local n = #wd.options
    local visible = mmin(n, DD_MAXVIS)
    local listH = visible * DD_ITEMH
    local maxScroll = mmax(0, n - visible)
    wd._ddScroll = clamp(wd._ddScroll or 0, 0, maxScroll)

    if (ms.wheel or 0) ~= 0 and hovering(d.x, d.y, d.w, listH) then
        wd._ddScroll = clamp(wd._ddScroll - (ms.wheel > 0 and 1 or -1), 0, maxScroll)
        ms.wheel = 0
    end

    if maxScroll > 0 then
        local trackX = d.x + d.w - 7
        if ms.pressed and not ms.consumed and hovering(trackX - 2, d.y, 10, listH) then
            ms.consumed = true; M._ddScrollbar = wd
        end
        if M._ddScrollbar == wd then
            if ms.down then wd._ddScroll = rnd(clamp((ms.y - d.y) / listH, 0, 1) * maxScroll)
            else M._ddScrollbar = nil end
            return
        end
    end

    if not ms.pressed or ms.consumed then return end
    if hovering(d.x, d.y, d.w, listH) then
        for vi = 0, visible - 1 do
            if hovering(d.x, d.y + vi * DD_ITEMH, d.w, DD_ITEMH) then
                local i = vi + 1 + floor(wd._ddScroll)
                if i <= n then
                    if wd.kind == "multicombo" then wd.value[i] = not wd.value[i] or nil
                    else wd.value = i; M._combo = nil end
                end
                break
            end
        end
        ms.consumed = true
    elseif not hovering(d.x, d.y - d.bh, d.w, d.bh) then
        M._combo = nil
    end
end

local function drawOptionText(x, y, maxWidth, normalColor, value, suffix, suffixColor)
    value = tostring(value or "")
    maxWidth = mmax(8, maxWidth or 8)
    if suffix and suffixColor and value:sub(-#suffix) == suffix then
        local prefix = fitText(value:sub(1, #value - #suffix), mmax(0, maxWidth - textw(suffix)), FONT)
        text(x, y, normalColor, prefix, FONT)
        text(x + textw(prefix), y, suffixColor, suffix, FONT)
    else
        text(x, y, normalColor, fitText(value, maxWidth, FONT), FONT)
    end
end

function M:_drawDropdown()
    if not M._combo or not M._dd or M._dd.wd ~= M._combo then return end
    local d, wd = M._dd, M._dd.wd
    local multi = (wd.kind == "multicombo")
    local n = #wd.options
    local visible = mmin(n, DD_MAXVIS)
    local listH = visible * DD_ITEMH
    local maxScroll = mmax(0, n - visible)
    local scroll = clamp(wd._ddScroll or 0, 0, maxScroll)
    local hasBar = maxScroll > 0
    local iw = hasBar and (d.w - 9) or d.w
    rbox(d.x, d.y, d.w, listH, 5, T.widget, T.accent)
    for vi = 0, visible - 1 do
        local i = vi + 1 + floor(scroll)
        if i <= n then
            local opt = wd.options[i]
            local iy = d.y + vi * DD_ITEMH
            local sel = multi and wd.value[i] or (not multi and wd.value == i)
            local hov = hovering(d.x, iy, iw, DD_ITEMH)
            if hov then rect(d.x + 1, iy, iw - 2, DD_ITEMH, T.widgethi) end
            local optionColor = wd.optionColors and wd.optionColors[i]
            local suffix = wd.optionSuffixes and wd.optionSuffixes[i]
            if multi then
                rbox(d.x + 8, iy + 5, 12, 12, 3, sel and T.accent or T.widget, sel and T.accent or T.border)
                drawOptionText(d.x + 26, iy + 5, iw - 34, (sel or hov) and T.texthi or T.text, opt, suffix, optionColor)
            else
                if sel then rect(d.x + 1, iy, 3, DD_ITEMH, T.accent) end
                local normalColor = (sel or hov) and T.texthi or T.text
                drawOptionText(d.x + 9, iy + 5, iw - 18, normalColor, opt, suffix, optionColor)
            end
        end
    end
    if hasBar then
        local trackX = d.x + d.w - 6
        local thumbH = mmax(20, listH * visible / n)
        local thumbY = d.y + (listH - thumbH) * (scroll / maxScroll)
        rfill(trackX, d.y + 2, 4, listH - 4, 2, T.widget)
        rfill(trackX, thumbY, 4, thumbH, 2, T.accent)
    end
end

local CP = { pad = 12, svW = 138, svH = 128, barW = 14, gap = 10, sw = 22, sgap = 6, slots = 5 }
local function cpWidth()  return CP.pad * 2 + CP.svW + CP.gap * 2 + CP.barW * 2 end
local function cpHeight() return CP.pad * 2 + CP.svH + 52 end

function M:_cpInput()
    if not M._cp or not M._cpRect then return end
    if not ms.pressed or ms.consumed then return end
    local r = M._cpRect
    if hovering(r.x, r.y, cpWidth(), cpHeight()) then ms.consumed = true
    elseif not hovering(r.sx, r.sy, r.sw, r.sh) then M._cp = nil end
end

function M:_cpDraw()
    if not M._cp or not M._cpRect then return end
    local wd, r = M._cp, M._cpRect
    if not wd._hsv then wd._hsv = { rgb2hsv(wd.value[1], wd.value[2], wd.value[3]) } end
    local hsv = wd._hsv
    local w = cpWidth()

    if self._win then r.x = mmin(r.x, self._win.x + self._win.w - w - 6) end

    rbox(r.x, r.y, w, cpHeight(), 6, T.section, T.accent)
    local svX, svY, svW, svH = r.x + CP.pad, r.y + CP.pad, CP.svW, CP.svH
    local hueX   = svX + svW + CP.gap
    local alphaX = hueX + CP.barW + CP.gap

    if ms.pressed and not M._cpDrag then
        if hovering(svX, svY, svW, svH) then M._cpDrag = "sv"
        elseif hovering(hueX, svY, CP.barW, svH) then M._cpDrag = "hue"
        elseif hovering(alphaX, svY, CP.barW, svH) then M._cpDrag = "alpha" end
    end
    if M._cpDrag then
        if ms.down then
            if M._cpDrag == "sv" then
                hsv[2] = clamp((ms.x - svX) / svW, 0, 1)
                hsv[3] = clamp(1 - (ms.y - svY) / svH, 0, 1)
            elseif M._cpDrag == "hue" then
                hsv[1] = clamp((ms.y - svY) / svH, 0, 1)
            elseif M._cpDrag == "alpha" then
                wd.value[4] = rnd(clamp(1 - (ms.y - svY) / svH, 0, 1) * 255)
            end
        else M._cpDrag = nil end
    end

    M._swatches = M._swatches or {}
    local sy   = svY + svH + 28
    local addX = svX
    local addHov = hovering(addX, sy, CP.sw, CP.sw)
    local pre = { hsv2rgb(hsv[1], hsv[2], hsv[3]) }
    if ms.pressed and addHov then
        table.insert(M._swatches, 1, { pre[1], pre[2], pre[3], wd.value[4] or 255 })
        while #M._swatches > CP.slots do table.remove(M._swatches) end
    end
    for i = 1, CP.slots do
        local c = M._swatches[i]
        local cxs = addX + i * (CP.sw + CP.sgap)
        if c and ms.pressed and hovering(cxs, sy, CP.sw, CP.sw) then
            hsv[1], hsv[2], hsv[3] = rgb2hsv(c[1], c[2], c[3])
            wd.value[4] = c[4] or 255
        end
    end

    local h, s, v = hsv[1], hsv[2], hsv[3]
    local cr, cg, cb = hsv2rgb(h, s, v)
    local av = wd.value[4] or 255

    local hr, hg, hb = hsv2rgb(h, 1, 1)
    rect(svX, svY, svW, svH, { hr, hg, hb })
    for dx = 0, svW - 1, 2 do
        rect(svX + dx, svY, 2, svH, { 255, 255, 255, 255 * (1 - dx / svW) })
    end
    for dy = 0, svH - 1, 2 do
        rect(svX, svY + dy, svW, 2, { 0, 0, 0, 255 * (dy / svH) })
    end
    frame(svX, svY, svW, svH, T.border)
    local cxp = svX + clamp(s, 0, 1) * svW
    local cyp = svY + (1 - clamp(v, 0, 1)) * svH
    rbox(cxp - 5, cyp - 5, 10, 10, 5, { cr, cg, cb }, { 255, 255, 255 })

    for dy = 0, svH - 1, 2 do
        rect(hueX, svY + dy, CP.barW, 2, { hsv2rgb(dy / svH, 1, 1) })
    end
    frame(hueX, svY, CP.barW, svH, T.border)
    rfill(hueX - 2, svY + clamp(h, 0, 1) * svH - 2, CP.barW + 4, 4, 1, { 255, 255, 255 })

    rect(alphaX, svY, CP.barW, svH, T.widget)
    for dy = 0, svH - 1, 2 do
        rect(alphaX, svY + dy, CP.barW, 2, { cr, cg, cb, 255 * (1 - dy / svH) })
    end
    frame(alphaX, svY, CP.barW, svH, T.border)
    rfill(alphaX - 2, svY + (1 - av / 255) * svH - 2, CP.barW + 4, 4, 1, { 255, 255, 255 })

    wd.value[1], wd.value[2], wd.value[3] = cr, cg, cb
    local ty = svY + svH + 6
    text(svX, ty, T.textdim, string.format("R %d  G %d  B %d  A %d", cr, cg, cb, av), FONT)

    rbox(addX, sy, CP.sw, CP.sw, 4, addHov and T.widgethi or T.widget, T.border)
    text(addX + CP.sw / 2, sy + 3, addHov and T.texthi or T.textdim, "+", FONT, "center")
    for i = 1, CP.slots do
        local c = M._swatches[i]
        local cxs = addX + i * (CP.sw + CP.sgap)
        rbox(cxs, sy, CP.sw, CP.sw, 4, c and { c[1], c[2], c[3], 255 } or T.bg2, T.border)
    end
end

function M:_titlebarInput(win)
    local sx, sy, sw, sh = self:_saveBtnRect(win)
    if clicked(sx, sy, sw, sh) then
        self._saveFlash = 1
        if type(self.OnSaveClick) == "function" then
            pcall(self.OnSaveClick)
        end
    end
end

function M:_drag(win)
    local sw = sidebarW()
    local inRail = hovering(win.x, win.y, sw, win.h)
    local inHead = hovering(win.x + sw, win.y, win.w - sw, T.titlebar)
    if ms.pressed and not ms.consumed and (inRail or inHead) then
        local sx, sy, swB, sh = self:_saveBtnRect(win)
        if hovering(sx, sy, swB, sh) then return end
        local tx, ty, tw, th = self:_sidebarToggleRect(win)
        if hovering(tx, ty, tw, th) then return end
        local pos = tabLayout(self._tabs, win)
        for _, p in ipairs(pos) do
            if hovering(p.x, p.y, p.w, p.h) then return end
        end
        ms.consumed = true
        self._dragWin = { dx = ms.x - win.x, dy = ms.y - win.y }
    end
    if self._dragWin then
        if ms.down then win.x = ms.x - self._dragWin.dx; win.y = ms.y - self._dragWin.dy
        else self._dragWin = nil end
    end
end

function M:_frame()
    local real = self._win
    self._minimized = false

    local targetA = self._sidebarCollapsed and 0 or 1
    self._sidebarAnim = approach(self._sidebarAnim == nil and targetA or self._sidebarAnim, targetA, 14)
    local sw = sidebarW()

    local tab = self._tabs[self._active]

    local contentH = 0
    if tab then pcall(function() contentH = tabContentHeight(tab) end) end
    local chrome = T.titlebar + T.pad * 2

    local screenW, screenH = 1920, 1080
    pcall(function() screenW, screenH = draw.GetScreenSize() end)
    screenW = screenW or 1920
    screenH = screenH or 1080

    local grip = 14
    if self._resizeEnabled ~= false then
        local gx, gy = real.x + real.w - grip, real.y + real.h - grip
        if ms.pressed and not ms.consumed and hovering(gx, gy, grip, grip) then
            ms.consumed = true
            self._resize = { ox = ms.x, oy = ms.y, ow = real.w, oh = real.h }
            self._autoH = false
        end
        if self._resize then
            if ms.down then
                real.w = clamp(self._resize.ow + (ms.x - self._resize.ox), 560, screenW - 40)
                real.h = clamp(self._resize.oh + (ms.y - self._resize.oy), 360, screenH - 40)
            else
                self._resize = nil
            end
        end
    end

    if self._autoH then
        local targetH = clamp(contentH + chrome + 8, 360, screenH - 60)
        real.h = real.h + (targetH - real.h) * clamp(DT * 14, 0, 1)
    end

    local ease = smooth(self._t)
    ALPHA = ease
    local oy = (1 - ease) * 18
    local win = { x = real.x, y = real.y - oy, w = real.w, h = real.h }

    rbox(win.x + 10, win.y + 14, win.w, win.h, 16, { 0, 0, 0, math.floor(90 * ease) }, { 0, 0, 0, 0 })
    rbox(win.x, win.y, win.w, win.h, 16, T.bg2, T.border)
    rfill(win.x + sw + 1, win.y + 1, win.w - sw - 2, win.h - 2, 14, T.bg2, false, true, true, false)
    rect(win.x + sw + 18, win.y + T.titlebar, win.w - sw - 36, 1, T.divider)
    rfill(win.x + sw + 18, win.y + T.titlebar, 48, 2, 1, { T.accent[1], T.accent[2], T.accent[3], 220 })

    self:_tabInput(win)
    self:_titlebarInput(win)
    self:_drag(win)
    self:_dropdownInput()
    self:_cpInput()

    local availH = win.h - chrome
    local maxScroll = mmax(0, contentH - availH)
    self._scroll = clamp(self._scroll or 0, 0, maxScroll)

    if maxScroll > 0 then
        local barX, barW = win.x + win.w - 7, 4
        local th = mmax(20, (availH / contentH) * availH)
        local ty = win.y + T.titlebar + (availH - th) * (self._scroll / maxScroll)
        if ms.pressed and not ms.consumed and hovering(barX - 2, win.y + T.titlebar, barW + 6, availH) then
            ms.consumed = true
            self._scrollDrag = true
        end
        if self._scrollDrag then
            if ms.down then
                local frac = clamp((ms.y - (win.y + T.titlebar) - th * 0.5) / mmax(1, availH - th), 0, 1)
                self._scroll = frac * maxScroll
            else
                self._scrollDrag = nil
            end
        end
    end

    local tabEase = smooth(self._tabT)
    local cx = win.x + sw + T.pad + (1 - tabEase) * 22
    local cy = win.y + T.titlebar + T.pad - self._scroll
    local cw = win.w - sw - T.pad * 2 - 10
    clipTop, clipBottom = win.y + T.titlebar, win.y + win.h - 2
    local scissorOn = false
    pcall(function()
        draw.SetScissorRect(
            rnd(win.x + sw + 1),
            rnd(win.y + T.titlebar),
            rnd(win.w - sw - 2),
            rnd(mmax(1, win.h - T.titlebar - 2))
        )
        scissorOn = true
    end)
    if tab then
        local ok, err = pcall(function() tab:render(cx, cy, cw) end)
        if not ok then print("[DaizML] tab '" .. tostring(tab.name) .. "' error: " .. tostring(err)) end
    end
    if scissorOn then
        pcall(function()
            local ssw, ssh = draw.GetScreenSize()
            draw.SetScissorRect(0, 0, ssw, ssh)
        end)
    end
    clipTop, clipBottom = nil, nil

    if maxScroll > 0 and (ms.wheel or 0) ~= 0 and hovering(win.x + sw, win.y + T.titlebar, win.w - sw, win.h - T.titlebar) then
        self._scroll = clamp(self._scroll - (ms.wheel > 0 and 36 or -36), 0, maxScroll)
        ms.wheel = 0
    end

    self:_drawTabBar(win)

    if maxScroll > 0 then
        local th = mmax(20, (availH / contentH) * availH)
        local ty = win.y + T.titlebar + (availH - th) * (self._scroll / maxScroll)
        rfill(win.x + win.w - 6, win.y + T.titlebar + 2, 3, availH - 4, 2, T.widget)
        rfill(win.x + win.w - 6, ty, 3, th, 2, T.accent)
    end

    if self._resizeEnabled ~= false then
        local gx, gy = win.x + win.w - 12, win.y + win.h - 12
        local dim = T.textdim
        rect(gx, gy + 7, 8, 1, dim)
        rect(gx + 3, gy + 4, 5, 1, dim)
        rect(gx + 6, gy + 1, 2, 1, dim)
    end

    self:_drawDropdown()
    self:_cpDraw()

    if M._focus and ms.pressed and not ms.consumed then M._focus = nil end

    real.x = win.x
    real.y = win.y + oy
end

function M:OpenFolder()
    pcall(function()
        ffi.cdef[[ int ShellExecuteA(void*, const char*, const char*, const char*, const char*, int); ]]
    end)
    pcall(function()
        local shell = ffi.load("shell32")
        shell.ShellExecuteA(nil, "open", M._dir or ".", nil, nil, 1)
    end)
end

function M:_initScreen()
    local win = self._win
    ALPHA = smooth(self._t)
    rbox(win.x, win.y, win.w, win.h, 16, T.bg2, T.border)
    rfill(win.x, win.y, 4, win.h, 2, T.accent, true, false, true, false)
    local dots = string.rep(".", floor(now() * 2) % 4)
    text(win.x + win.w / 2, win.y + win.h / 2 - 12, T.texthi, "Warming up" .. dots, FONT_B, "center")
    text(win.x + win.w / 2, win.y + win.h / 2 + 12, T.textdim, "loading fonts & chrome", FONT, "center")
end

function M:Build(opts)
    opts = opts or {}
    if opts.w then self._win.w = opts.w end
    if opts.h then self._win.h = opts.h end
    if opts.x then self._win.x = opts.x end
    if opts.y then self._win.y = opts.y end
    if opts.autoH ~= nil then
        self._autoH = opts.autoH and true or false
    else
        self._autoH = (opts.h == nil)
    end
    if opts.resize ~= nil then
        self._resizeEnabled = opts.resize and true or false
    else
        self._resizeEnabled = true
    end

    _getMouse = resolveMouse()
    _getWheel = resolveWheel()
    _clock    = resolveClock()
    initFonts()
    initWatermarkFonts()
    if not _getMouse then print("[DaizML] WARNING: mouse position API not found -- cursor won't track") end

    local menuRef
    local menuRefOk, menuRefErr = pcall(function() menuRef = gui.Reference("MENU") end)
    self._menuRef = menuRef
    self._debug = (opts.debug == true) or (self._debug == true)
    self._forceOpen = (opts.forceOpen == true) or (self._forceOpen == true)
    self._drawFrames = 0
    self._debugLastPrint = 0

    local function drawRuntimeOverlays(t)
        if type(self._inspectDrawPopup) == "function" and self._inspectPopupOpen then
            local ok, err = pcall(self._inspectDrawPopup)
            if not ok then
                print("[DaizML] inspect popup draw error: " .. tostring(err))
                self._inspectPopupOpen = false
                self._inspectSavedMenuVisible = nil
                pcall(function() self:Notify("inspect popup failed", "error") end)
            end
        end
        if type(self._warnDrawPopup) == "function" and self._warnPopupOpen then
            local ok, err = pcall(self._warnDrawPopup)
            if not ok then
                print("[DaizML] warn popup draw error: " .. tostring(err))
                self._warnPopupOpen = false
                pcall(function() self:Notify("warn popup failed", "error") end)
            end
        end
        if type(self._skinCacheDrawPopup) == "function" and self._skinCachePopupOpen then
            local ok, err = pcall(self._skinCacheDrawPopup)
            if not ok then
                print("[DaizML] skin cache popup draw error: " .. tostring(err))
                self._skinCachePopupOpen = false
            end
        end
    end

    self._drawRuntimeOverlays = drawRuntimeOverlays

    self._tick = function()
        self._drawFrames = (self._drawFrames or 0) + 1

        local open = false
        if self._forceOpen then
            open = true
        elseif self._followAimwareMenu and menuRef then
            local okActive, active = pcall(function() return menuRef:IsActive() end)
            if okActive then open = active and true or false end
        else
            open = self._menuVisible and true or false
        end
        self._open = open
        if self._inspectPopupOpen or self._warnPopupOpen or self._skinCachePopupOpen then
            open = false
            self._open = false
            self._focus = nil
            self._inputDrag = nil
            self._keybox = nil
        end
        if not open then self._focus = nil; self._inputDrag = nil; self._keybox = nil end

        local t  = now()
        local dt = 1 / 60
        if _clock then
            if self._last then
                local raw = t - self._last
                if raw <= 0 or raw > 0.5 or raw ~= raw then
                    dt = 1 / 60
                else
                    dt = mmin(raw, 0.1)
                end
            else
                dt = 1 / 60
            end
        end
        pcall(function()
            local aft = globals.AbsoluteFrameTime()
            if type(aft) == "number" and aft > 0.0005 and aft < 0.5 then
                dt = aft
            end
        end)
        self._last = t
        DT = dt

        self._t    = self._t    + ((open and 1 or 0) - self._t) * clamp(dt * ANIM.open, 0, 1)
        self._tabT = self._tabT + (1 - self._tabT)              * clamp(dt * ANIM.tab,  0, 1)

        if self._initco then
            pcall(function()
                if coroutine.status(self._initco) ~= "dead" then coroutine.resume(self._initco) end
            end)
            if coroutine.status(self._initco) == "dead" then self._initco = nil end
            pcall(function() self:_initScreen() end)
            return
        end

        if not open and self._t < 0.005 and #self._toasts == 0 and not self._inspectPopupOpen and not self._warnPopupOpen and not self._skinCachePopupOpen then
            pcall(function() self:_drawWatermark() end)
            drawRuntimeOverlays(t)
            self._t = 0
            return
        end

        updateMouse()
        pcall(function() self:_drawWatermark() end)
        pcall(function() self:_drawToasts() end)

        ALPHA = 1
        for _, fn in ipairs(self._onframe) do pcall(fn, UI) end

        if not open and self._t < 0.005 and not self._inspectPopupOpen and not self._warnPopupOpen and not self._skinCachePopupOpen then
            drawRuntimeOverlays(t)
            self._t = 0
            return
        end

        if open then
            local ok, err = pcall(function() self:_frame() end)
            if not ok then print("[DaizML] frame error: " .. tostring(err)) end
        end
        drawRuntimeOverlays(t)
    end

    self._input = function(cmd)
        if not (self._open and self._focus) or not cmd then return end
        pcall(function() cmd.forwardmove = 0 end)
        pcall(function() cmd.sidemove = 0 end)
        pcall(function() cmd.upmove = 0 end)
        pcall(function() cmd.buttons = 0 end)
        pcall(function() cmd:SetForwardMove(0) end)
        pcall(function() cmd:SetSideMove(0) end)
        pcall(function() cmd:SetUpMove(0) end)
        pcall(function() cmd:SetButtons(0) end)
    end

    return self
end

function M:ApplyAppearance(opts)
    opts = opts or {}
    local function copy4(src, fallback)
        src = src or fallback
        return {
            tonumber(src[1]) or fallback[1],
            tonumber(src[2]) or fallback[2],
            tonumber(src[3]) or fallback[3],
            tonumber(src[4]) or fallback[4] or 255,
        }
    end

    if opts.accent then
        T.accent = { opts.accent[1], opts.accent[2], opts.accent[3] }
        T.accent2 = { opts.accent[1], opts.accent[2], opts.accent[3], 255 }
        T.accent_bg = {
            math.floor(opts.accent[1] * 0.18 + 10),
            math.floor(opts.accent[2] * 0.14 + 8),
            math.floor(opts.accent[3] * 0.10 + 6),
            255,
        }
    end
    if opts.bg then T.bg = copy4(opts.bg, T.bg) end
    if opts.bg2 then T.bg2 = copy4(opts.bg2, T.bg2) end
    if opts.section then T.section = copy4(opts.section, T.section) end
    if opts.text then T.text = copy4(opts.text, T.text) end
    if opts.texthi then T.texthi = copy4(opts.texthi, T.texthi) end
    if opts.textdim then T.textdim = copy4(opts.textdim, T.textdim) end
    if opts.border then T.border = copy4(opts.border, T.border) end

    if opts.font_size then
        T.font_size = clamp(tonumber(opts.font_size) or T.font_size, 11, 22)
    end
    if opts.font and tostring(opts.font) ~= "" then
        local primary = tostring(opts.font)
        T.font = { primary, "Segoe UI", "Bahnschrift", "Tahoma" }
        T.font_logo = { primary, "Bahnschrift", "Segoe UI Semibold", "Segoe UI" }
    end

    initFonts()
    return self
end

M.T = T
function M:UIFonts()
    return FONT, FONT_B, FONT_LOGO, FONT_SMALL
end

return M
]===]
local __chunk, __err = loadstring(__DAIZML_GUILIB, "=DaizML_guilib.lua")
if not __chunk then print("[DaizML] UI compile error: " .. tostring(__err)); return end
local __ok, M = pcall(__chunk)
if not __ok or type(M) ~= "table" then print("[DaizML] UI load error: " .. tostring(M)); return end

local DEFAULT_MENU_KEY = 0x2E
local CONFIG_FILE = "DaizML_configs.txt"
local CONFIG_FILE_LEGACY = "WHOS_configs.txt"
local CONFIG_SLOTS = 5

local skinsTab = M:Tab("SKINS")
local visualsTab = M:Tab("VISUALS")
local miscTab = M:Tab("MISC")
local grenadeTab = M:Tab("GRENADE")
local particlesTab = M:Tab("PARTICLES")
local settingsTab = M:Tab("SETTINGS")

local FONT_OPTIONS = {
    "Segoe UI", "Bahnschrift", "Tahoma", "Verdana", "Arial",
    "Consolas", "Georgia", "Trebuchet MS", "Courier New", "Lucida Console",
}
local DEFAULT_ACCENT = { 232, 144, 74, 255 }
local DEFAULT_BG = { 12, 13, 16, 252 }
local DEFAULT_BG2 = { 18, 19, 24, 252 }
local DEFAULT_TEXT = { 198, 204, 214, 255 }
local DEFAULT_FONT = "Segoe UI"
local DEFAULT_FONT_SIZE = 14

local function fontIndex(name)
    name = tostring(name or DEFAULT_FONT)
    for i, n in ipairs(FONT_OPTIONS) do
        if n:lower() == name:lower() then return i end
    end
    return 1
end

local menuSection = settingsTab:Section("Menu")
local menuKey = menuSection:Keybox("Menu keybind", DEFAULT_MENU_KEY)
local followAimware = menuSection:Checkbox("Follow Aimware menu (INSERT)", false)
menuSection:Button("Toggle menu now", function()
    M._menuVisible = not M._menuVisible
    M:Notify(M._menuVisible and "menu shown" or "menu hidden", "info")
end)

local appearanceSection = settingsTab:Section("Appearance")
local uiAccent = appearanceSection:ColorPicker("Accent color", DEFAULT_ACCENT)
local uiBg = appearanceSection:ColorPicker("Background", DEFAULT_BG)
local uiBg2 = appearanceSection:ColorPicker("Panel background", DEFAULT_BG2)
local uiText = appearanceSection:ColorPicker("Text color", DEFAULT_TEXT)
local uiFont = appearanceSection:Combo("Font", FONT_OPTIONS, fontIndex(DEFAULT_FONT))
local uiFontSize = appearanceSection:Slider("Text size", DEFAULT_FONT_SIZE, 11, 22, 1)
appearanceSection:Button("Reset appearance", function()
    uiAccent:Set({ DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3], DEFAULT_ACCENT[4] })
    uiBg:Set({ DEFAULT_BG[1], DEFAULT_BG[2], DEFAULT_BG[3], DEFAULT_BG[4] })
    uiBg2:Set({ DEFAULT_BG2[1], DEFAULT_BG2[2], DEFAULT_BG2[3], DEFAULT_BG2[4] })
    uiText:Set({ DEFAULT_TEXT[1], DEFAULT_TEXT[2], DEFAULT_TEXT[3], DEFAULT_TEXT[4] })
    uiFont:Set(fontIndex(DEFAULT_FONT))
    uiFontSize:Set(DEFAULT_FONT_SIZE)
    M:Notify("appearance reset", "info")
end)

local function applyAppearanceFromWidgets()
    local accent = uiAccent:Get() or DEFAULT_ACCENT
    local bg = uiBg:Get() or DEFAULT_BG
    local bg2 = uiBg2:Get() or DEFAULT_BG2
    local text = uiText:Get() or DEFAULT_TEXT
    local fontName = FONT_OPTIONS[tonumber(uiFont:Get()) or 1] or DEFAULT_FONT
    local size = tonumber(uiFontSize:Get()) or DEFAULT_FONT_SIZE
    local dim = {
        math.max(80, math.floor((text[1] or 205) * 0.58)),
        math.max(90, math.floor((text[2] or 213) * 0.58)),
        math.max(100, math.floor((text[3] or 225) * 0.58)),
        255,
    }
    local hi = {
        math.min(255, math.floor((text[1] or 205) * 1.15)),
        math.min(255, math.floor((text[2] or 213) * 1.15)),
        math.min(255, math.floor((text[3] or 225) * 1.15)),
        255,
    }
    M:ApplyAppearance({
        accent = accent,
        bg = bg,
        bg2 = bg2,
        section = {
            math.min(255, math.floor((bg2[1] or 18) + 8)),
            math.min(255, math.floor((bg2[2] or 19) + 8)),
            math.min(255, math.floor((bg2[3] or 24) + 10)),
            bg2[4] or 252,
        },
        text = text,
        texthi = hi,
        textdim = dim,
        border = {
            math.min(255, math.floor((bg2[1] or 18) + 28)),
            math.min(255, math.floor((bg2[2] or 19) + 30)),
            math.min(255, math.floor((bg2[3] or 24) + 34)),
            255,
        },
        font = fontName,
        font_size = size,
    })
    if M.T then
        M.T.rail = {
            tonumber(bg[1]) or 12,
            tonumber(bg[2]) or 13,
            tonumber(bg[3]) or 16,
            tonumber(bg[4]) or 252,
        }
        M.T.widget = {
            math.min(255, math.floor((bg2[1] or 18) + 12)),
            math.min(255, math.floor((bg2[2] or 19) + 14)),
            math.min(255, math.floor((bg2[3] or 24) + 16)),
            255,
        }
        M.T.widgethi = {
            math.min(255, math.floor((bg2[1] or 18) + 20)),
            math.min(255, math.floor((bg2[2] or 19) + 22)),
            math.min(255, math.floor((bg2[3] or 24) + 26)),
            255,
        }
    end
end

local function appearanceFingerprint()
    local a = uiAccent:Get() or DEFAULT_ACCENT
    local b = uiBg:Get() or DEFAULT_BG
    local b2 = uiBg2:Get() or DEFAULT_BG2
    local t = uiText:Get() or DEFAULT_TEXT
    return string.format(
        "%d,%d,%d|%d,%d,%d|%d,%d,%d|%d,%d,%d|%d|%d",
        a[1], a[2], a[3], b[1], b[2], b[3], b2[1], b2[2], b2[3], t[1], t[2], t[3],
        tonumber(uiFont:Get()) or 1, tonumber(uiFontSize:Get()) or DEFAULT_FONT_SIZE
    )
end

local DEFAULT_WM_BG = { 12, 13, 16, 214 }
local DEFAULT_WM_ACCENT = { 232, 144, 74, 255 }
local DEFAULT_WM_TEXT = { 198, 204, 214, 255 }
local DEFAULT_WM_SCALE = 1.0
local DEFAULT_WM_FONT = DEFAULT_FONT
local DEFAULT_WM_CUSTOM_TEXT = "DaizML"
local WM_PART_OPTIONS = { "CustomText", "Name", "UUID", "Map", "FPS", "Ping" }
local WM_PART_KEYS = { "custom", "name", "uuid", "map", "fps", "ping" }
local WM_PART_KEY_TO_LABEL = {
    custom = "CustomText",
    name = "Name",
    uuid = "UUID",
    map = "Map",
    fps = "FPS",
    ping = "Ping",
}
local DEFAULT_WM_PARTS_SEL = { 1, 2, 3, 4, 5, 6 }
local DEFAULT_WM_ORDER = { "custom", "name", "uuid", "map", "fps", "ping" }

local DEFAULT_STEP_COLOR = { 74, 166, 255, 220 }
local DEFAULT_STEP_DURATION = 0.85
local DEFAULT_STEP_FADE = 0.40
local DEFAULT_STEP_RADIUS = 42
local DEFAULT_STEP_STYLE = 1

local DEFAULT_TRAIL_COLOR = { 255, 255, 255, 255 }
local DEFAULT_TRAIL_LENGTH = 100
local DEFAULT_TRAIL_THICKNESS = 2
local DEFAULT_TRAIL_RATE_MS = 20
local TRAIL_LENGTH_MAX = 200
local TRAIL_MIN_MOVE = 2.0
local TRAIL_CATCHUP_SPEED = 595
local TRAIL_STOP_SPEED = 40
local TRAIL_STOP_DWELL = 0.10
local TRAIL_RESTART_DIST = 40
local TRAIL_STOP_FADE = 0.12
local TRAIL_CATCHUP_MIN_SPAN = 6.0
local TRAIL_MODE_DEFAULT, TRAIL_MODE_PARTICLE = 1, 2
local TRAIL_STYLE_NAMES = { "Default", "Particle" }
local TRAIL_DEF_TYPE_NAMES = { "Line", "Advanced Line", "Rect" }
local TRAIL_DEF_COLOR_NAMES = { "Static", "Chroma", "Gradient Chroma" }
local DEFAULT_TRAIL_DEF_COLOR = { 246, 34, 34, 255 }

local function wmPartsToSel(parts)
    parts = parts or {}
    return {
        [1] = parts.custom and true or nil,
        [2] = parts.name and true or nil,
        [3] = parts.uuid and true or nil,
        [4] = parts.map and true or nil,
        [5] = parts.fps and true or nil,
        [6] = parts.ping and true or nil,
    }
end

local function wmSelToParts(sel)
    sel = sel or {}
    return {
        custom = sel[1] and true or false,
        name = sel[2] and true or false,
        uuid = sel[3] and true or false,
        map = sel[4] and true or false,
        fps = sel[5] and true or false,
        ping = sel[6] and true or false,
    }
end

local function encodeWmParts(parts)
    parts = parts or {}
    return table.concat({
        parts.custom and "1" or "0",
        parts.name and "1" or "0",
        parts.uuid and "1" or "0",
        parts.map and "1" or "0",
        parts.fps and "1" or "0",
        parts.ping and "1" or "0",
    }, ",")
end

local function parseWmParts(text)
    local vals = {}
    for v in tostring(text or ""):gmatch("%d+") do
        vals[#vals + 1] = v
    end
    if #vals <= 0 then
        return { custom = true, name = true, uuid = true, map = true, fps = true, ping = true }
    end
    if #vals == 3 then
        return {
            custom = vals[1] == "1",
            name = vals[2] == "1",
            uuid = true,
            map = true,
            fps = vals[3] == "1",
            ping = true,
        }
    end
    if #vals == 4 then
        return {
            custom = vals[1] == "1",
            name = vals[2] == "1",
            uuid = true,
            map = vals[3] == "1",
            fps = vals[4] == "1",
            ping = true,
        }
    end
    if #vals == 5 then
        return {
            custom = vals[1] == "1",
            name = vals[2] == "1",
            uuid = vals[3] == "1",
            map = vals[4] == "1",
            fps = vals[5] == "1",
            ping = true,
        }
    end
    return {
        custom = vals[1] == "1",
        name = vals[2] == "1",
        uuid = vals[3] == "1",
        map = vals[4] == "1",
        fps = vals[5] == "1",
        ping = vals[6] == "1",
    }
end

local function fingerprintWmParts(sel)
    sel = sel or {}
    return string.format(
        "%d%d%d%d%d%d",
        sel[1] and 1 or 0,
        sel[2] and 1 or 0,
        sel[3] and 1 or 0,
        sel[4] and 1 or 0,
        sel[5] and 1 or 0,
        sel[6] and 1 or 0
    )
end

local function normalizeWmOrder(order)
    local seen = {}
    local out = {}
    if type(order) == "table" then
        for i = 1, #order do
            local key = tostring(order[i] or ""):lower()
            if WM_PART_KEY_TO_LABEL[key] and not seen[key] then
                seen[key] = true
                out[#out + 1] = key
            end
        end
    end
    for i = 1, #WM_PART_KEYS do
        local key = WM_PART_KEYS[i]
        if not seen[key] then out[#out + 1] = key end
    end
    return out
end

local function encodeWmOrder(order)
    return table.concat(normalizeWmOrder(order), ",")
end

local function parseWmOrder(text)
    local order = {}
    for token in tostring(text or ""):gmatch("[^,]+") do
        local key = token:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if key == "customtext" then key = "custom" end
        order[#order + 1] = key
    end
    return normalizeWmOrder(order)
end

local function wmOrderLabel(order)
    order = normalizeWmOrder(order)
    local labels = {}
    for i = 1, #order do
        labels[i] = WM_PART_KEY_TO_LABEL[order[i]] or order[i]
    end
    return table.concat(labels, " > ")
end

local function moveWmOrderKey(order, key, dir)
    order = normalizeWmOrder(order)
    local idx
    for i = 1, #order do
        if order[i] == key then idx = i; break end
    end
    if not idx then return order end
    local j = idx + (dir < 0 and -1 or 1)
    if j < 1 or j > #order then return order end
    order[idx], order[j] = order[j], order[idx]
    return order
end

local function fileRead(path)
    if type(file) == "table" and type(file.Read) == "function" then
        local ok, data = pcall(file.Read, path)
        if ok and type(data) == "string" then return data end
    end
    local data
    pcall(function()
        local f = file.Open(path, "r")
        if f then data = f:Read(); f:Close() end
    end)
    return data
end

local function fileWrite(path, data)
    if type(file) == "table" and type(file.Write) == "function" then
        local ok = pcall(file.Write, path, data)
        if ok then return true end
    end
    local ok = false
    pcall(function()
        local f = file.Open(path, "w")
        if f then f:Write(data); f:Close(); ok = true end
    end)
    return ok
end

local function encodeColor(c, fallback)
    c = c or fallback
    return table.concat({
        tostring(tonumber(c[1]) or fallback[1]),
        tostring(tonumber(c[2]) or fallback[2]),
        tostring(tonumber(c[3]) or fallback[3]),
        tostring(tonumber(c[4]) or fallback[4] or 255),
    }, ",")
end

local function emptySlot(i)
    return {
        name = "Slot " .. tostring(i),
        menu_key = DEFAULT_MENU_KEY,
        follow_aimware = false,
        menu_x = nil,
        menu_y = nil,
        menu_w = nil,
        menu_h = nil,
        sidebar_collapsed = false,
        misc_enable = false,
        misc_mode = 1,
        misc_amount = 50,
        misc_color = { 74, 166, 255, 255 },
        misc_hotkey = 0,
        misc_note = "",
        wm_x = nil,
        wm_y = nil,
        wm_enabled = false,
        wm_bg = { DEFAULT_WM_BG[1], DEFAULT_WM_BG[2], DEFAULT_WM_BG[3], DEFAULT_WM_BG[4] },
        wm_accent = { DEFAULT_WM_ACCENT[1], DEFAULT_WM_ACCENT[2], DEFAULT_WM_ACCENT[3], DEFAULT_WM_ACCENT[4] },
        wm_text = { DEFAULT_WM_TEXT[1], DEFAULT_WM_TEXT[2], DEFAULT_WM_TEXT[3], DEFAULT_WM_TEXT[4] },
        wm_scale = DEFAULT_WM_SCALE,
        wm_font = DEFAULT_WM_FONT,
        wm_custom_text = DEFAULT_WM_CUSTOM_TEXT,
        wm_parts = { custom = true, name = true, uuid = true, map = true, fps = true, ping = true },
        wm_order = { DEFAULT_WM_ORDER[1], DEFAULT_WM_ORDER[2], DEFAULT_WM_ORDER[3], DEFAULT_WM_ORDER[4], DEFAULT_WM_ORDER[5], DEFAULT_WM_ORDER[6] },
        wm_labels = false,
        wm_labels_invert = false,
        ui_accent = { DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3], DEFAULT_ACCENT[4] },
        ui_bg = { DEFAULT_BG[1], DEFAULT_BG[2], DEFAULT_BG[3], DEFAULT_BG[4] },
        ui_bg2 = { DEFAULT_BG2[1], DEFAULT_BG2[2], DEFAULT_BG2[3], DEFAULT_BG2[4] },
        ui_text = { DEFAULT_TEXT[1], DEFAULT_TEXT[2], DEFAULT_TEXT[3], DEFAULT_TEXT[4] },
        ui_font = DEFAULT_FONT,
        ui_font_size = DEFAULT_FONT_SIZE,
        step_enabled = false,
        step_enemies_only = true,
        step_show_local = false,
        step_color = { DEFAULT_STEP_COLOR[1], DEFAULT_STEP_COLOR[2], DEFAULT_STEP_COLOR[3], DEFAULT_STEP_COLOR[4] },
        step_duration = DEFAULT_STEP_DURATION,
        step_fade = DEFAULT_STEP_FADE,
        step_radius = DEFAULT_STEP_RADIUS,
        step_interval = 20,
        step_layers = 2,
        step_style = DEFAULT_STEP_STYLE,
        trail_enabled = false,
        trail_mode = TRAIL_MODE_DEFAULT,
        trail_color = { DEFAULT_TRAIL_COLOR[1], DEFAULT_TRAIL_COLOR[2], DEFAULT_TRAIL_COLOR[3], DEFAULT_TRAIL_COLOR[4] },
        trail_length = DEFAULT_TRAIL_LENGTH,
        trail_thickness = DEFAULT_TRAIL_THICKNESS,
        trail_rate_ms = DEFAULT_TRAIL_RATE_MS,
        trail_rainbow = false,
        trail_def_type = 1,
        trail_def_color_type = 1,
        trail_def_color = { DEFAULT_TRAIL_DEF_COLOR[1], DEFAULT_TRAIL_DEF_COLOR[2], DEFAULT_TRAIL_DEF_COLOR[3], DEFAULT_TRAIL_DEF_COLOR[4] },
        trail_def_chroma = 1,
        trail_def_seg_exp = 10,
        trail_def_line_size = 1,
        trail_def_rect_w = 1,
        trail_def_rect_h = 1,
        trail_def_x_w = 1,
        trail_def_y_w = 1,
        left_hand_knife = false,
        sniper_qs = false,
        sniper_qs_delay = 0,
        deagle_qs = false,
        deagle_qs_delay = 0,
        velocity_graph = false,
        velo_x = nil,
        velo_y = nil,
        live_stats = false,
        live_stats_debug = false,
        live_stats_x = nil,
        live_stats_y = nil,
        radar_hud = false,
        radar_x = nil,
        radar_y = nil,
        radar_size = 200,
        radar_zoom = 100,
        radar_dot_size = 4,
        radar_circle = false,
        radar_hide_panel = true,
        radar_follow = true,
        radar_show_team = true,
        radar_gridlines = true,
        movement_keys = false,
        keys_jump = 0x20,
        keys_bg = true,
        keys_layout = 3,
        keys_x = nil,
        keys_y = nil,
        death_fx_enabled = false,
        death_fx_effect = 1,
        gh_enabled = false,
        gh_hud = true,
        gh_hud_on_spot = false,
        gh_show_all_spots = false,
        gh_aim_line = true,
        gh_aim_style = 4,
        gh_range = 17,
        gh_show_dist = 1200,
        gh_edit_mode = false,
        gh_edit_toggle_key = 0,
        gh_edit_key = 0,
        gh_record_key = 0,
        gh_execute_key = 0,
        gh_x = nil,
        gh_y = nil,
        vm_enabled = false,
        vm_x = 1.0,
        vm_y = 1.0,
        vm_z = -1.0,
        vm_fov_enabled = false,
        vm_fov = 90,
    }
end

local function newConfigState()
    local cfg = { default = 1, slots = {} }
    for i = 1, CONFIG_SLOTS do cfg.slots[i] = emptySlot(i) end
    return cfg
end

local function encodeSlot(slot)
    local c = slot.misc_color or { 74, 166, 255, 255 }
    local name = tostring(slot.name or "Slot"):gsub("[\r\n=]", " ")
    local note = tostring(slot.misc_note or ""):gsub("[\r\n]", " ")
    local font = tostring(slot.ui_font or DEFAULT_FONT):gsub("[\r\n=]", " ")
    return table.concat({
        "name=" .. name,
        "menu_key=" .. tostring(tonumber(slot.menu_key) or DEFAULT_MENU_KEY),
        "follow_aimware=" .. (slot.follow_aimware and "1" or "0"),
        "menu_x=" .. (slot.menu_x ~= nil and tostring(slot.menu_x) or ""),
        "menu_y=" .. (slot.menu_y ~= nil and tostring(slot.menu_y) or ""),
        "menu_w=" .. (slot.menu_w ~= nil and tostring(slot.menu_w) or ""),
        "menu_h=" .. (slot.menu_h ~= nil and tostring(slot.menu_h) or ""),
        "sidebar_collapsed=" .. (slot.sidebar_collapsed and "1" or "0"),
        "misc_enable=" .. (slot.misc_enable and "1" or "0"),
        "misc_mode=" .. tostring(tonumber(slot.misc_mode) or 1),
        "misc_amount=" .. tostring(tonumber(slot.misc_amount) or 50),
        "misc_color=" .. encodeColor(c, { 74, 166, 255, 255 }),
        "misc_hotkey=" .. tostring(tonumber(slot.misc_hotkey) or 0),
        "misc_note=" .. note,
        "wm_x=" .. (slot.wm_x ~= nil and tostring(slot.wm_x) or ""),
        "wm_y=" .. (slot.wm_y ~= nil and tostring(slot.wm_y) or ""),
        "wm_enabled=" .. (slot.wm_enabled and "1" or "0"),
        "wm_bg=" .. encodeColor(slot.wm_bg, DEFAULT_WM_BG),
        "wm_accent=" .. encodeColor(slot.wm_accent, DEFAULT_WM_ACCENT),
        "wm_text=" .. encodeColor(slot.wm_text, DEFAULT_WM_TEXT),
        "wm_scale=" .. tostring(tonumber(slot.wm_scale) or DEFAULT_WM_SCALE),
        "wm_font=" .. tostring(slot.wm_font or DEFAULT_WM_FONT):gsub("[\r\n=]", " "),
        "wm_custom_text=" .. tostring(slot.wm_custom_text or DEFAULT_WM_CUSTOM_TEXT):gsub("[\r\n=]", " "),
        "wm_parts=" .. encodeWmParts(slot.wm_parts),
        "wm_order=" .. encodeWmOrder(slot.wm_order),
        "wm_labels=" .. (slot.wm_labels and "1" or "0"),
        "wm_labels_invert=" .. (slot.wm_labels_invert and "1" or "0"),
        "ui_accent=" .. encodeColor(slot.ui_accent, DEFAULT_ACCENT),
        "ui_bg=" .. encodeColor(slot.ui_bg, DEFAULT_BG),
        "ui_bg2=" .. encodeColor(slot.ui_bg2, DEFAULT_BG2),
        "ui_text=" .. encodeColor(slot.ui_text, DEFAULT_TEXT),
        "ui_font=" .. font,
        "ui_font_size=" .. tostring(tonumber(slot.ui_font_size) or DEFAULT_FONT_SIZE),
        "step_enabled=" .. (slot.step_enabled and "1" or "0"),
        "step_enemies_only=1",
        "step_show_local=" .. (slot.step_show_local and "1" or "0"),
        "step_color=" .. encodeColor(slot.step_color, DEFAULT_STEP_COLOR),
        "step_duration=" .. tostring(tonumber(slot.step_duration) or DEFAULT_STEP_DURATION),
        "step_fade=" .. tostring(tonumber(slot.step_fade) or DEFAULT_STEP_FADE),
        "step_radius=" .. tostring(tonumber(slot.step_radius) or DEFAULT_STEP_RADIUS),
        "step_interval=" .. tostring(tonumber(slot.step_interval) or 20),
        "step_layers=" .. tostring(tonumber(slot.step_layers) or 2),
        "step_style=" .. tostring(tonumber(slot.step_style) or DEFAULT_STEP_STYLE),
        "trail_enabled=" .. (slot.trail_enabled and "1" or "0"),
        "trail_mode=" .. tostring(tonumber(slot.trail_mode) or TRAIL_MODE_DEFAULT),
        "trail_color=" .. encodeColor(slot.trail_color, DEFAULT_TRAIL_COLOR),
        "trail_length=" .. tostring(tonumber(slot.trail_length) or DEFAULT_TRAIL_LENGTH),
        "trail_thickness=" .. tostring(tonumber(slot.trail_thickness) or DEFAULT_TRAIL_THICKNESS),
        "trail_rate_ms=" .. tostring(tonumber(slot.trail_rate_ms) or DEFAULT_TRAIL_RATE_MS),
        "trail_rainbow=" .. (slot.trail_rainbow and "1" or "0"),
        "trail_def_type=" .. tostring(tonumber(slot.trail_def_type) or 1),
        "trail_def_color_type=" .. tostring(tonumber(slot.trail_def_color_type) or 1),
        "trail_def_color=" .. encodeColor(slot.trail_def_color, DEFAULT_TRAIL_DEF_COLOR),
        "trail_def_chroma=" .. tostring(tonumber(slot.trail_def_chroma) or 1),
        "trail_def_seg_exp=" .. tostring(tonumber(slot.trail_def_seg_exp) or 10),
        "trail_def_line_size=" .. tostring(tonumber(slot.trail_def_line_size) or 1),
        "trail_def_rect_w=" .. tostring(tonumber(slot.trail_def_rect_w) or 1),
        "trail_def_rect_h=" .. tostring(tonumber(slot.trail_def_rect_h) or 1),
        "trail_def_x_w=" .. tostring(tonumber(slot.trail_def_x_w) or 1),
        "trail_def_y_w=" .. tostring(tonumber(slot.trail_def_y_w) or 1),
        "left_hand_knife=" .. (slot.left_hand_knife and "1" or "0"),
        "sniper_qs=" .. (slot.sniper_qs and "1" or "0"),
        "sniper_qs_delay=" .. tostring(tonumber(slot.sniper_qs_delay) or 0),
        "deagle_qs=" .. (slot.deagle_qs and "1" or "0"),
        "deagle_qs_delay=" .. tostring(tonumber(slot.deagle_qs_delay) or 0),
        "velocity_graph=" .. (slot.velocity_graph and "1" or "0"),
        "velo_x=" .. (slot.velo_x ~= nil and tostring(slot.velo_x) or ""),
        "velo_y=" .. (slot.velo_y ~= nil and tostring(slot.velo_y) or ""),
        "live_stats=" .. (slot.live_stats and "1" or "0"),
        "live_stats_debug=" .. (slot.live_stats_debug and "1" or "0"),
        "live_stats_x=" .. (slot.live_stats_x ~= nil and tostring(slot.live_stats_x) or ""),
        "live_stats_y=" .. (slot.live_stats_y ~= nil and tostring(slot.live_stats_y) or ""),
        "radar_hud=" .. (slot.radar_hud and "1" or "0"),
        "radar_x=" .. (slot.radar_x ~= nil and tostring(slot.radar_x) or ""),
        "radar_y=" .. (slot.radar_y ~= nil and tostring(slot.radar_y) or ""),
        "radar_size=" .. tostring(tonumber(slot.radar_size) or 200),
        "radar_zoom=" .. tostring(tonumber(slot.radar_zoom) or 100),
        "radar_dot_size=" .. tostring(tonumber(slot.radar_dot_size) or 4),
        "radar_circle=" .. (slot.radar_circle and "1" or "0"),
        "radar_hide_panel=" .. ((slot.radar_hide_panel ~= false) and "1" or "0"),
        "radar_follow=" .. ((slot.radar_follow ~= false) and "1" or "0"),
        "radar_show_team=" .. ((slot.radar_show_team ~= false) and "1" or "0"),
        "radar_gridlines=" .. ((slot.radar_gridlines ~= false) and "1" or "0"),
        "movement_keys=" .. (slot.movement_keys and "1" or "0"),
        "keys_jump=" .. tostring(tonumber(slot.keys_jump) or 0x20),
        "keys_bg=" .. ((slot.keys_bg ~= false) and "1" or "0"),
        "keys_layout=" .. tostring(tonumber(slot.keys_layout) or 3),
        "keys_x=" .. (slot.keys_x ~= nil and tostring(slot.keys_x) or ""),
        "keys_y=" .. (slot.keys_y ~= nil and tostring(slot.keys_y) or ""),
        "death_fx_enabled=" .. (slot.death_fx_enabled and "1" or "0"),
        "death_fx_effect=" .. tostring(tonumber(slot.death_fx_effect) or 1),
        "gh_enabled=" .. (slot.gh_enabled and "1" or "0"),
        "gh_hud=" .. ((slot.gh_hud ~= false) and "1" or "0"),
        "gh_hud_on_spot=" .. (slot.gh_hud_on_spot and "1" or "0"),
        "gh_show_all_spots=" .. (slot.gh_show_all_spots and "1" or "0"),
        "gh_aim_line=" .. ((slot.gh_aim_line ~= false) and "1" or "0"),
        "gh_aim_style=" .. tostring(tonumber(slot.gh_aim_style) or 4),
        "gh_range=" .. tostring(tonumber(slot.gh_range) or 36),
        "gh_show_dist=" .. tostring(tonumber(slot.gh_show_dist) or 1200),
        "gh_edit_mode=" .. (slot.gh_edit_mode and "1" or "0"),
        "gh_edit_toggle_key=" .. tostring(tonumber(slot.gh_edit_toggle_key) or 0),
        "gh_edit_key=" .. tostring(tonumber(slot.gh_edit_key) or 0),
        "gh_record_key=" .. tostring(tonumber(slot.gh_record_key) or 0),
        "gh_execute_key=" .. tostring(tonumber(slot.gh_execute_key) or 0),
        "gh_x=" .. (slot.gh_x ~= nil and tostring(slot.gh_x) or ""),
        "gh_y=" .. (slot.gh_y ~= nil and tostring(slot.gh_y) or ""),
        "vm_enabled=" .. (slot.vm_enabled and "1" or "0"),
        "vm_x=" .. string.format("%.2f", tonumber(slot.vm_x) or 1.0),
        "vm_y=" .. string.format("%.2f", tonumber(slot.vm_y) or 1.0),
        "vm_z=" .. string.format("%.2f", tonumber(slot.vm_z) or -1.0),
        "vm_fov_enabled=" .. (slot.vm_fov_enabled and "1" or "0"),
        "vm_fov=" .. tostring(tonumber(slot.vm_fov) or 90),
    }, "\n")
end

local function parseColor(text, fallback)
    local r, g, b, a = tostring(text or ""):match("^(%d+),(%d+),(%d+),(%d+)$")
    if not r then
        fallback = fallback or { 74, 166, 255, 255 }
        return { fallback[1], fallback[2], fallback[3], fallback[4] or 255 }
    end
    return { tonumber(r), tonumber(g), tonumber(b), tonumber(a) }
end

local function parseNumOrNil(text)
    if text == nil or text == "" then return nil end
    return tonumber(text)
end

local function decodeConfig(text)
    local cfg = newConfigState()
    if type(text) ~= "string" or text == "" then return cfg end

    local current = nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then
            local def = line:match("^default%s*=%s*(%d+)$")
            local slotId = line:match("^slot%s*=%s*(%d+)$")
            if def then
                cfg.default = math.max(1, math.min(CONFIG_SLOTS, tonumber(def) or 1))
            elseif slotId then
                local i = tonumber(slotId)
                if i and i >= 1 and i <= CONFIG_SLOTS then
                    current = cfg.slots[i]
                    current.trail_mode = nil
                else
                    current = nil
                end
            elseif current then
                local key, value = line:match("^([%w_]+)%s*=%s*(.*)$")
                if key then
                    if key == "name" then current.name = value ~= "" and value or current.name
                    elseif key == "menu_key" then current.menu_key = tonumber(value) or DEFAULT_MENU_KEY
                    elseif key == "follow_aimware" then current.follow_aimware = value == "1" or value == "true"
                    elseif key == "menu_x" then current.menu_x = parseNumOrNil(value)
                    elseif key == "menu_y" then current.menu_y = parseNumOrNil(value)
                    elseif key == "menu_w" then current.menu_w = parseNumOrNil(value)
                    elseif key == "menu_h" then current.menu_h = parseNumOrNil(value)
                    elseif key == "sidebar_collapsed" then current.sidebar_collapsed = value == "1" or value == "true"
                    elseif key == "misc_enable" then current.misc_enable = value == "1" or value == "true"
                    elseif key == "misc_mode" then current.misc_mode = tonumber(value) or 1
                    elseif key == "misc_amount" then current.misc_amount = tonumber(value) or 50
                    elseif key == "misc_color" then current.misc_color = parseColor(value, { 74, 166, 255, 255 })
                    elseif key == "misc_hotkey" then current.misc_hotkey = tonumber(value) or 0
                    elseif key == "misc_note" then current.misc_note = value or ""
                    elseif key == "wm_x" then current.wm_x = parseNumOrNil(value)
                    elseif key == "wm_y" then current.wm_y = parseNumOrNil(value)
                    elseif key == "wm_enabled" then current.wm_enabled = value == "1" or value == "true"
                    elseif key == "wm_bg" then current.wm_bg = parseColor(value, DEFAULT_WM_BG)
                    elseif key == "wm_accent" then current.wm_accent = parseColor(value, DEFAULT_WM_ACCENT)
                    elseif key == "wm_text" then current.wm_text = parseColor(value, DEFAULT_WM_TEXT)
                    elseif key == "wm_scale" then
                        local s = tonumber(value) or DEFAULT_WM_SCALE
                        if s < 0.7 then s = 0.7 elseif s > 2.0 then s = 2.0 end
                        current.wm_scale = s
                    elseif key == "wm_font" then current.wm_font = (value ~= "" and value) or DEFAULT_WM_FONT
                    elseif key == "wm_custom_text" then current.wm_custom_text = value or DEFAULT_WM_CUSTOM_TEXT
                    elseif key == "wm_parts" then current.wm_parts = parseWmParts(value)
                    elseif key == "wm_order" then current.wm_order = parseWmOrder(value)
                    elseif key == "wm_labels" then current.wm_labels = value == "1" or value == "true"
                    elseif key == "wm_labels_invert" then current.wm_labels_invert = value == "1" or value == "true"
                    elseif key == "ui_accent" then current.ui_accent = parseColor(value, DEFAULT_ACCENT)
                    elseif key == "ui_bg" then current.ui_bg = parseColor(value, DEFAULT_BG)
                    elseif key == "ui_bg2" then current.ui_bg2 = parseColor(value, DEFAULT_BG2)
                    elseif key == "ui_text" then current.ui_text = parseColor(value, DEFAULT_TEXT)
                    elseif key == "ui_font" then current.ui_font = (value ~= "" and value) or DEFAULT_FONT
                    elseif key == "ui_font_size" then current.ui_font_size = tonumber(value) or DEFAULT_FONT_SIZE
                    elseif key == "step_enabled" then current.step_enabled = value == "1" or value == "true"
                    elseif key == "step_enemies_only" then current.step_enemies_only = true
                    elseif key == "step_show_local" then current.step_show_local = value == "1" or value == "true"
                    elseif key == "step_color" then current.step_color = parseColor(value, DEFAULT_STEP_COLOR)
                    elseif key == "step_duration" then current.step_duration = tonumber(value) or DEFAULT_STEP_DURATION
                    elseif key == "step_fade" then current.step_fade = tonumber(value) or DEFAULT_STEP_FADE
                    elseif key == "step_radius" then current.step_radius = tonumber(value) or DEFAULT_STEP_RADIUS
                    elseif key == "step_interval" then current.step_interval = tonumber(value) or 20
                    elseif key == "step_thickness" then 
                    elseif key == "step_layers" then current.step_layers = tonumber(value) or 2
                    elseif key == "step_style" then current.step_style = tonumber(value) or DEFAULT_STEP_STYLE
                    elseif key == "trail_enabled" then current.trail_enabled = value == "1" or value == "true"
                    elseif key == "trail_mode" then current.trail_mode = tonumber(value) or TRAIL_MODE_PARTICLE
                    elseif key == "trail_color" then current.trail_color = parseColor(value, DEFAULT_TRAIL_COLOR)
                    elseif key == "trail_length" then current.trail_length = tonumber(value) or DEFAULT_TRAIL_LENGTH
                    elseif key == "trail_thickness" then current.trail_thickness = tonumber(value) or DEFAULT_TRAIL_THICKNESS
                    elseif key == "trail_rate_ms" then current.trail_rate_ms = tonumber(value) or DEFAULT_TRAIL_RATE_MS
                    elseif key == "trail_rainbow" then current.trail_rainbow = value == "1" or value == "true"
                    elseif key == "trail_def_type" then current.trail_def_type = tonumber(value) or 1
                    elseif key == "trail_def_color_type" then current.trail_def_color_type = tonumber(value) or 1
                    elseif key == "trail_def_color" then current.trail_def_color = parseColor(value, DEFAULT_TRAIL_DEF_COLOR)
                    elseif key == "trail_def_chroma" then current.trail_def_chroma = tonumber(value) or 1
                    elseif key == "trail_def_seg_exp" then current.trail_def_seg_exp = tonumber(value) or 10
                    elseif key == "trail_def_line_size" then current.trail_def_line_size = tonumber(value) or 1
                    elseif key == "trail_def_rect_w" then current.trail_def_rect_w = tonumber(value) or 1
                    elseif key == "trail_def_rect_h" then current.trail_def_rect_h = tonumber(value) or 1
                    elseif key == "trail_def_x_w" then current.trail_def_x_w = tonumber(value) or 1
                    elseif key == "trail_def_y_w" then current.trail_def_y_w = tonumber(value) or 1
                    elseif key == "trail_persistent" then 
                    elseif key == "left_hand_knife" then current.left_hand_knife = value == "1" or value == "true"
                    elseif key == "sniper_qs" then current.sniper_qs = value == "1" or value == "true"
                    elseif key == "sniper_qs_delay" then current.sniper_qs_delay = tonumber(value) or 0
                    elseif key == "deagle_qs" then current.deagle_qs = value == "1" or value == "true"
                    elseif key == "deagle_qs_delay" then current.deagle_qs_delay = tonumber(value) or 0
                    elseif key == "velocity_graph" then current.velocity_graph = value == "1" or value == "true"
                    elseif key == "velo_x" then current.velo_x = parseNumOrNil(value)
                    elseif key == "velo_y" then current.velo_y = parseNumOrNil(value)
                    elseif key == "live_stats" then current.live_stats = value == "1" or value == "true"
                    elseif key == "live_stats_debug" then current.live_stats_debug = value == "1" or value == "true"
                    elseif key == "live_stats_x" then current.live_stats_x = parseNumOrNil(value)
                    elseif key == "live_stats_y" then current.live_stats_y = parseNumOrNil(value)
                    elseif key == "radar_hud" then current.radar_hud = value == "1" or value == "true"
                    elseif key == "radar_x" then current.radar_x = parseNumOrNil(value)
                    elseif key == "radar_y" then current.radar_y = parseNumOrNil(value)
                    elseif key == "radar_size" then current.radar_size = tonumber(value) or 200
                    elseif key == "radar_zoom" then current.radar_zoom = tonumber(value) or 100
                    elseif key == "radar_dot_size" then current.radar_dot_size = tonumber(value) or 4
                    elseif key == "radar_circle" then current.radar_circle = value == "1" or value == "true"
                    elseif key == "radar_hide_panel" then current.radar_hide_panel = value == "1" or value == "true"
                    elseif key == "radar_follow" then current.radar_follow = value == "1" or value == "true"
                    elseif key == "radar_show_team" then current.radar_show_team = value == "1" or value == "true"
                    elseif key == "radar_gridlines" then current.radar_gridlines = value == "1" or value == "true"
                    elseif key == "movement_keys" then current.movement_keys = value == "1" or value == "true"
                    elseif key == "keys_jump" then current.keys_jump = tonumber(value) or 0x20
                    elseif key == "keys_bg" then current.keys_bg = value == "1" or value == "true"
                    elseif key == "keys_layout" then current.keys_layout = tonumber(value) or 3
                    elseif key == "keys_x" then current.keys_x = parseNumOrNil(value)
                    elseif key == "keys_y" then current.keys_y = parseNumOrNil(value)
                    elseif key == "death_fx_enabled" then current.death_fx_enabled = value == "1" or value == "true"
                    elseif key == "death_fx_effect" then current.death_fx_effect = tonumber(value) or 1
                    elseif key == "gh_enabled" then current.gh_enabled = value == "1" or value == "true"
                    elseif key == "gh_hud" then current.gh_hud = value == "1" or value == "true"
                    elseif key == "gh_hud_on_spot" then current.gh_hud_on_spot = value == "1" or value == "true"
                    elseif key == "gh_show_all_spots" then current.gh_show_all_spots = value == "1" or value == "true"
                    elseif key == "gh_match_nade" then
                        current.gh_show_all_spots = not (value == "1" or value == "true")
                    elseif key == "gh_aim_line" then current.gh_aim_line = value == "1" or value == "true"
                    elseif key == "gh_aim_style" then current.gh_aim_style = tonumber(value) or 4
                    elseif key == "gh_range" then current.gh_range = tonumber(value) or 36
                    elseif key == "gh_show_dist" then current.gh_show_dist = tonumber(value) or 1200
                    elseif key == "gh_edit_mode" then current.gh_edit_mode = value == "1" or value == "true"
                    elseif key == "gh_edit_toggle_key" then current.gh_edit_toggle_key = tonumber(value) or 0
                    elseif key == "gh_edit_key" then current.gh_edit_key = tonumber(value) or 0
                    elseif key == "gh_record_key" then current.gh_record_key = tonumber(value) or 0
                    elseif key == "gh_execute_key" then current.gh_execute_key = tonumber(value) or 0
                    elseif key == "gh_x" then current.gh_x = parseNumOrNil(value)
                    elseif key == "gh_y" then current.gh_y = parseNumOrNil(value)
                    elseif key == "vm_enabled" then current.vm_enabled = value == "1" or value == "true"
                    elseif key == "vm_x" then current.vm_x = tonumber(value) or 1.0
                    elseif key == "vm_y" then current.vm_y = tonumber(value) or 1.0
                    elseif key == "vm_z" then current.vm_z = tonumber(value) or -1.0
                    elseif key == "vm_fov_enabled" then current.vm_fov_enabled = value == "1" or value == "true"
                    elseif key == "vm_fov" then current.vm_fov = tonumber(value) or 90
                    end
                end
            end
        end
    end
    return cfg
end

local function encodeConfig(cfg)
    local parts = { "default=" .. tostring(cfg.default or 1) }
    for i = 1, CONFIG_SLOTS do
        parts[#parts + 1] = "slot=" .. tostring(i)
        parts[#parts + 1] = encodeSlot(cfg.slots[i] or emptySlot(i))
    end
    return table.concat(parts, "\n") .. "\n"
end

local function loadConfigText()
    local text = fileRead(CONFIG_FILE)
    if text and text ~= "" then return text end
    return fileRead(CONFIG_FILE_LEGACY)
end

local Config = decodeConfig(loadConfigText())

local gatherValues, applyValues, applyWatermarkFromWidgets, watermarkFingerprint

local SkinInitError

local SkinSave

local function saveConfigFile()
    if fileWrite(CONFIG_FILE, encodeConfig(Config)) then
        return true
    end
    M:Error("failed to write " .. CONFIG_FILE)
    return false
end

local function slotLabel(i)
    local slot = Config.slots[i]
    local name = slot and slot.name or ("Slot " .. i)
    if Config.default == i then
        return string.format("%d. %s (default)", i, name)
    end
    return string.format("%d. %s", i, name)
end

local function refreshSlotLabels()
    local labels = {}
    for i = 1, CONFIG_SLOTS do labels[i] = slotLabel(i) end
    return labels
end

local configSection = settingsTab:Section("Config slots")
local slotLabels = refreshSlotLabels()
local configSlot = configSection:Combo("Active slot", slotLabels, Config.default or 1)
local configName = configSection:Input("Slot name", Config.slots[Config.default or 1].name, "config name...")

local function findSlotComboWidget()
    for _, w in ipairs(configSection.ws or {}) do
        if w.kind == "combo" and w.label == "Active slot" then return w end
    end
end

local function selectedSlotIndex()
    local i = tonumber(configSlot:Get()) or 1
    if i < 1 then i = 1 end
    if i > CONFIG_SLOTS then i = CONFIG_SLOTS end
    return i
end

local function syncNameFromSlot()
    local i = selectedSlotIndex()
    configName:Set(Config.slots[i].name or ("Slot " .. i))
end

local function updateSlotComboLabels()
    local labels = refreshSlotLabels()
    local wd = findSlotComboWidget()
    if wd then wd.options = labels end
    configSlot:Set(selectedSlotIndex())
end

configSection:Button("Save slot", function()
    local i = selectedSlotIndex()
    local values = gatherValues()
    local name = tostring(configName:Get() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "Slot " .. i end
    values.name = name
    Config.slots[i] = values
    if saveConfigFile() then
        updateSlotComboLabels()
        M:Success("saved config slot " .. i .. " (" .. name .. ")")
    end
end)

M.OnSaveClick = function()
    local i = selectedSlotIndex()
    local values = gatherValues()
    local name = tostring(configName:Get() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "Slot " .. i end
    values.name = name
    Config.slots[i] = values
    if not saveConfigFile() then return end
    updateSlotComboLabels()

    local msg = "saved config slot " .. i .. " (" .. name .. ")"
    if SkinSave then
        local called, ok = pcall(SkinSave)
        if called and ok then
            msg = msg .. " + skins"
        else
            M:Error("skin selection not saved")
        end
    end
    M:Success(msg)
end

configSection:Button("Set as default", function()
    local i = selectedSlotIndex()
    Config.default = i
    if saveConfigFile() then
        updateSlotComboLabels()
        M:Success("default config set to slot " .. i)
    end
end)

configSection:Button("Reload file from disk", function()
    Config = decodeConfig(loadConfigText())
    configSlot:Set(Config.default or 1)
    syncNameFromSlot()
    updateSlotComboLabels()
    applyValues(Config.slots[Config.default or 1])
    M:Info("config file reloaded")
end)

local watermarkSection = miscTab:Section("Watermark")
local wmEnable = watermarkSection:Checkbox("Enable watermark", false)
local wmParts = watermarkSection:MultiCombo("Toggles", WM_PART_OPTIONS, DEFAULT_WM_PARTS_SEL)
local wmOrderPart = watermarkSection:Combo("Reorder part", WM_PART_OPTIONS, 1)
watermarkSection:Button("Move left  <<", function()
    local wm = M._watermark
    local idx = math.max(1, math.min(#WM_PART_KEYS, math.floor(tonumber(wmOrderPart:Get()) or 1)))
    wm.order = moveWmOrderKey(wm.order, WM_PART_KEYS[idx], -1)
    M:Notify("order: " .. wmOrderLabel(wm.order), "info")
end)
watermarkSection:Button("Move right  >>", function()
    local wm = M._watermark
    local idx = math.max(1, math.min(#WM_PART_KEYS, math.floor(tonumber(wmOrderPart:Get()) or 1)))
    wm.order = moveWmOrderKey(wm.order, WM_PART_KEYS[idx], 1)
    M:Notify("order: " .. wmOrderLabel(wm.order), "info")
end)
watermarkSection:Button("Reset order", function()
    M._watermark.order = normalizeWmOrder(DEFAULT_WM_ORDER)
    M:Notify("watermark order reset", "info")
end)
local wmCustomText = watermarkSection:Input("Custom text", DEFAULT_WM_CUSTOM_TEXT, "custom text...")
local wmLabels = watermarkSection:Checkbox("Show labels", false)
local wmLabelsInvert = watermarkSection:Checkbox("Invert label colors", false)
local wmScale = watermarkSection:SliderFloat("Watermark scale", DEFAULT_WM_SCALE, 0.7, 2.0, "%.2fx", 0.05)
watermarkSection:Button("Reset watermark position", function()
    M:WatermarkResetPos()
    M:Notify("watermark position reset", "info")
end)
watermarkSection:Button("Reset watermark style", function()
    wmEnable:Set(false)
    wmParts:Set(wmPartsToSel({ custom = true, name = true, uuid = true, map = true, fps = true, ping = true }))
    M._watermark.order = normalizeWmOrder(DEFAULT_WM_ORDER)
    wmCustomText:Set(DEFAULT_WM_CUSTOM_TEXT)
    wmLabels:Set(false)
    wmLabelsInvert:Set(false)
    wmScale:Set(DEFAULT_WM_SCALE)
    M:WatermarkResetColors()
    M:Notify("watermark style reset", "info")
end)
watermarkSection:Custom(56, function(ui, x, y)
    local order = (M._watermark and M._watermark.order) or DEFAULT_WM_ORDER
    ui.text(x, y, "Order: " .. wmOrderLabel(order))
    ui.text(x, y + 14, "Pick a part above, then Move left/right.")
    ui.text(x, y + 28, "Labels: AW User / UUID / Map / FPS / Ping")
    ui.text(x, y + 42, "Open menu to drag the watermark.")
end)

local togglesSection = miscTab:Section("Toggles")
local leftHandKnife = togglesSection:Checkbox("Knife in left hand", false)
local qsRow = togglesSection:CheckSlider(
    "Sniper quickswitch (AWP/SSG)",
    "Quickswitch Delay",
    false, 0, 0, 600, 10
)
local sniperQuickSwitch = qsRow.check
local sniperQsDelay = qsRow.slider
local deagleQsRow = togglesSection:CheckSlider(
    "Deagle quickswitch",
    "Deagle Delay",
    false, 0, 0, 600, 10
)
local deagleQuickSwitch = deagleQsRow.check
local deagleQsDelay = deagleQsRow.slider

togglesSection:Custom(46, function(ui, x, y, w)
    local th = ui.T or {}
    local divider = th.divider or { 29, 36, 47, 255 }
    local accent = th.accent or { 74, 166, 255 }
    local textdim = th.textdim or { 119, 132, 150, 255 }
    local topPad = 12
    local label = "HUD TOGGLES"
    local tw = ui.textw(label)
    local gap = 12
    local lineY = y + topPad + 12
    local side = math.max(0, math.floor((w - tw) * 0.5) - gap)
    if side > 6 then
        ui.rect(x, lineY, side, 1, divider)
        ui.rect(x, lineY, math.min(28, side), 2, { accent[1], accent[2], accent[3], 180 })
        local rx = x + side + gap + tw + gap
        ui.rect(rx, lineY, side, 1, divider)
        ui.rect(rx + math.max(0, side - 28), lineY, math.min(28, side), 2, { accent[1], accent[2], accent[3], 180 })
    else
        ui.rect(x, lineY + 8, w, 1, divider)
    end
    ui.text(x + (w - tw) * 0.5, y + topPad + 4, label, textdim)
end)

local LiveStatsReset
local LiveStatsPos = { x = nil, y = nil }
local function LiveStatsPosReset()
    LiveStatsPos.x, LiveStatsPos.y = nil, nil
end

LiveStatsPos._hudGroup = function(ui, x, y, w, label)
    local th = ui.T or {}
    local divider = th.divider or { 29, 36, 47, 255 }
    local accent = th.accent or { 74, 166, 255 }
    local textdim = th.textdim or { 119, 132, 150, 255 }
    label = tostring(label or "")
    ui.text(x, y + 8, label, textdim)
    local tw = ui.textw(label)
    local lx = x + tw + 10
    local lw = math.max(0, w - tw - 10)
    if lw > 8 then
        ui.rect(lx, y + 16, lw, 1, divider)
        ui.rect(lx, y + 16, math.min(22, lw), 2, { accent[1], accent[2], accent[3], 150 })
    end
end

togglesSection:Custom(26, function(ui, x, y, w)
    LiveStatsPos._hudGroup(ui, x, y, w, "VELOCITY")
end)
local velocityGraph = togglesSection:Checkbox("Velocity graph", false)
local VeloPos = { x = nil, y = nil }
local function VeloPosReset()
    VeloPos.x, VeloPos.y = nil, nil
end

togglesSection:Custom(26, function(ui, x, y, w)
    LiveStatsPos._hudGroup(ui, x, y, w, "PLAYER HUD")
end)
local liveStats = togglesSection:Checkbox("Player HUD", false)
LiveStatsPos.RadarHud = {
    status = "idle",
    needsAssetSync = false,
    fetching = false,
    lastError = nil,
}
LiveStatsPos._steamAvatarSettled = false
LiveStatsPos._avatarHttpBusy = false
LiveStatsPos._skinHttpBusy = false

togglesSection:Custom(26, function(ui, x, y, w)
    LiveStatsPos._hudGroup(ui, x, y, w, "RADAR")
end)
LiveStatsPos.RadarHud.enabled = togglesSection:Checkbox("Radar HUD", false)
do
    local row = togglesSection:DualSlider(
        "Radar zoom", 100, 100, 250, 5, "%.0f%%",
        "Dot size", 4, 2, 12, 1, "%.0f"
    )
    LiveStatsPos.RadarHud.zoomSlider = row.left
    LiveStatsPos.RadarHud.dotSize = row.right
end
do
    local row = togglesSection:DualCheck("Circle map", "Hide panel", false, true)
    LiveStatsPos.RadarHud.circleMap = row.left
    LiveStatsPos.RadarHud.hidePanel = row.right
end
do
    local row = togglesSection:DualCheck("Follow player", "Show teammates", true, true)
    LiveStatsPos.RadarHud.follow = row.left
    LiveStatsPos.RadarHud.showTeam = row.right
end
LiveStatsPos.RadarHud.gridlines = togglesSection:Checkbox("Gridlines", true)
togglesSection:Custom(22, function(ui, x, y, w)
    local th = ui.T or {}
    local textdim = th.textdim or { 119, 132, 150, 255 }
    local R = LiveStatsPos.RadarHud
    local msg = "Radar: " .. tostring((R and R.status) or "idle")
    ui.text(x, y + 4, msg, textdim)
end)

togglesSection:Custom(26, function(ui, x, y, w)
    LiveStatsPos._hudGroup(ui, x, y, w, "INPUT HUD")
end)
local inputHudRow = togglesSection:DualCheck("Input HUD", "Input HUD background", false, true)
local movementKeys = inputHudRow.left
local keysBackground = inputHudRow.right
local KEY_LAYOUT_NAMES = { "Below", "Right stack", "Right row" }
local KEY_LAYOUT_FROM_COMBO = { 3, 1, 2 }
local KEY_LAYOUT_TO_COMBO = { [3] = 1, [1] = 2, [2] = 3 }
local keysOpts = togglesSection:KeyCombo("Jump key", "Layout", 0x20, KEY_LAYOUT_NAMES, 1)
local jumpKey = keysOpts.key
local keysLayout = keysOpts.combo
local KeysPos = { x = nil, y = nil }
local function KeysPosReset()
    KeysPos.x, KeysPos.y = nil, nil
end

local VM = {
    LIMIT_X = { -2.0, 2.5 },
    LIMIT_Y = { -2.0, 2.0 },
    LIMIT_Z = { -2.0, 2.0 },
    FOV_KEY = "world.fov",
    DEFAULT = { x = 1.0, y = 1.0, z = -1.0, preset = 1, fov = 90 },
    PRESETS = {
        { name = "Default",   x = 1.0,  y = 1.0, z = -1.0 },
        { name = "Centered",  x = 0.0,  y = 0.0, z = -1.0 },
        { name = "Wide",      x = 2.5,  y = 2.0, z = -1.5 },
        { name = "Left side", x = -2.0, y = 1.5, z = -1.0 },
        { name = "Tucked",    x = 1.5,  y = 1.0, z = -2.0 },
    },
    status = "not applied",
    fovStatus = "using the native Aimware setting",
    lastSig = "",
    lastApply = 0,
    wasEnabled = false,
    fovWasEnabled = false,
    fovApplied = false,
    wasScoped = false,
    lastFovValue = nil,
    lastFovApply = 0,
    lastPresetIdx = nil,
}
VM.PRESET_NAMES = {}
for i = 1, #VM.PRESETS do VM.PRESET_NAMES[i] = VM.PRESETS[i].name end

local vmSection = visualsTab:Section("Viewmodel")
VM.enable = vmSection:Checkbox("Enable viewmodel override", false)
VM.preset = vmSection:Combo("Preset", VM.PRESET_NAMES, 1)
VM.x = vmSection:SliderFloat("Horizontal (X)", VM.DEFAULT.x, VM.LIMIT_X[1], VM.LIMIT_X[2], "%.2f", 0.05)
VM.y = vmSection:SliderFloat("Depth (Y)", VM.DEFAULT.y, VM.LIMIT_Y[1], VM.LIMIT_Y[2], "%.2f", 0.05)
VM.z = vmSection:SliderFloat("Vertical (Z)", VM.DEFAULT.z, VM.LIMIT_Z[1], VM.LIMIT_Z[2], "%.2f", 0.05)
VM.fovEnable = vmSection:Checkbox("Override FOV", false)
VM.fov = vmSection:Slider("View FOV", VM.DEFAULT.fov, 60, 120, 1, "%.0f")
VM.lastPresetIdx = math.max(1, math.min(#VM.PRESETS, math.floor(tonumber(VM.preset:Get()) or 1)))

miscTab.secs = { togglesSection, watermarkSection }

local leftKnifeActive = false

local SniperQS = {
    phase = nil,
    knifeAt = 0,
    switchBackAt = 0,
    lastShots = 0,
    lastAttack = false,
}

local DeagleQS = {
    phase = nil,
    knifeAt = 0,
    switchBackAt = 0,
    lastShots = 0,
    lastAttack = false,
}

local function miscNow()
    local t
    pcall(function() t = globals.RealTime() end)
    if type(t) ~= "number" then pcall(function() t = globals.CurTime() end) end
    return type(t) == "number" and t or 0
end

function VM.clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo elseif v > hi then return hi else return v end
end

function VM.readConVar(name, fallback)
    local value
    pcall(function()
        if client and type(client.GetConVar) == "function" then value = client.GetConVar(name) end
    end)
    return tonumber(value) or fallback
end

function VM.setConVar(name, value)
    local text = type(value) == "number" and string.format("%.3f", value) or tostring(value)
    local expected = tonumber(value)

    local function verified()
        if expected == nil then return nil end
        local current
        pcall(function() current = tonumber(client.GetConVar(name)) end)
        if type(current) ~= "number" then return nil end
        return math.abs(current - expected) <= 0.011
    end

    local apiOk = false
    pcall(function()
        if client and type(client.SetConVar) == "function" then
            apiOk = client.SetConVar(name, text, true) ~= false
        end
    end)
    local matches = verified()
    if matches == true or (matches == nil and apiOk) then return true end

    local cmdOk = pcall(function()
        if not (client and type(client.Command) == "function") then error("no client.Command") end
        client.Command(name .. " " .. text, true)
    end)
    matches = verified()
    if matches ~= nil then return matches end
    return apiOk or cmdOk
end

function VM.readGui(key, fallback)
    local value
    pcall(function()
        if gui and type(gui.GetValue) == "function" then value = gui.GetValue(key) end
    end)
    return tonumber(value) or fallback
end

function VM.setGui(key, value)
    if not (gui and type(gui.SetValue) == "function") then return false, nil end
    if not pcall(function() gui.SetValue(key, tonumber(value)) end) then return false, nil end
    local readback = VM.readGui(key, nil)
    return type(readback) == "number" and math.abs(readback - tonumber(value)) <= 0.51, readback
end

VM.original = {
    x = VM.readConVar("viewmodel_offset_x", VM.DEFAULT.x),
    y = VM.readConVar("viewmodel_offset_y", VM.DEFAULT.y),
    z = VM.readConVar("viewmodel_offset_z", VM.DEFAULT.z),
    preset = VM.readConVar("viewmodel_presetpos", VM.DEFAULT.preset),
    fov = VM.clamp(VM.readGui(VM.FOV_KEY, VM.DEFAULT.fov), 60, 120),
}

function VM.values()
    return VM.clamp(VM.x:Get(), VM.LIMIT_X[1], VM.LIMIT_X[2]),
           VM.clamp(VM.y:Get(), VM.LIMIT_Y[1], VM.LIMIT_Y[2]),
           VM.clamp(VM.z:Get(), VM.LIMIT_Z[1], VM.LIMIT_Z[2])
end

function VM.signature()
    local x, y, z = VM.values()
    return string.format("%.2f:%.2f:%.2f", x, y, z)
end

function VM.apply(force)
    if not VM.enable:Get() then return false end
    local now, sig = miscNow(), VM.signature()
    if not force and sig == VM.lastSig and (now - VM.lastApply) < 2.5 then return true end

    local x, y, z = VM.values()
    local ok = VM.setConVar("viewmodel_presetpos", 0)
    ok = VM.setConVar("viewmodel_offset_x", x) and ok
    ok = VM.setConVar("viewmodel_offset_y", y) and ok
    ok = VM.setConVar("viewmodel_offset_z", z) and ok

    VM.lastApply, VM.lastSig = now, sig
    VM.status = ok and string.format("applied  x %.2f  y %.2f  z %.2f", x, y, z)
        or "the game refused the viewmodel cvars"
    return ok
end

function VM.restore()
    local ok = VM.setConVar("viewmodel_offset_x", VM.original.x)
    ok = VM.setConVar("viewmodel_offset_y", VM.original.y) and ok
    ok = VM.setConVar("viewmodel_offset_z", VM.original.z) and ok
    ok = VM.setConVar("viewmodel_presetpos", VM.original.preset) and ok
    VM.lastSig, VM.status = "", ok and "original viewmodel restored" or "restore failed"
    return ok
end

function VM.applyFov(force)
    if not VM.fovEnable:Get() then return false end
    local now = miscNow()
    local value = VM.clamp(VM.fov:Get(), 60, 120)
    if not force and VM.lastFovValue == value then
        if (now - VM.lastFovApply) < 2.5 then return true end
        local current = VM.readGui(VM.FOV_KEY, nil)
        VM.lastFovApply = now
        if type(current) == "number" and math.abs(current - value) <= 0.51 then return true end
    end

    local ok, readback = VM.setGui(VM.FOV_KEY, value)
    VM.lastFovValue, VM.lastFovApply = value, now
    VM.fovApplied = ok and true or false
    VM.fovStatus = ok and string.format("%.0f", readback or value)
        or "the native View FOV is unavailable"
    return ok
end

function VM.restoreFov()
    local value = VM.clamp(VM.original.fov, 60, 120)
    local ok, readback = VM.setGui(VM.FOV_KEY, value)
    VM.fovApplied, VM.lastFovValue = false, nil
    VM.fovStatus = ok and string.format("restored %.0f", readback or value) or "FOV restore failed"
    return ok
end

function VM.isScoped()
    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then return false end

    local v
    pcall(function() v = lp:GetPropBool("m_bIsScoped") end)
    if v == nil then pcall(function() v = lp:GetPropInt("m_bIsScoped") end) end
    if v == nil then pcall(function() v = lp:GetFieldBool("m_bIsScoped") end) end
    if v == nil then pcall(function() v = lp:GetFieldInt("m_bIsScoped") end) end

    if type(v) == "number" then return v ~= 0 end
    return v == true
end

function VM.applyPreset(idx, notify)
    idx = math.max(1, math.min(#VM.PRESETS, math.floor(tonumber(idx) or 1)))
    local p = VM.PRESETS[idx]
    if not p then return false end
    VM.lastPresetIdx = idx
    VM.x:Set(p.x)
    VM.y:Set(p.y)
    VM.z:Set(p.z)
    VM.enable:Set(true)
    pcall(VM.apply, true)
    if notify then M:Notify("viewmodel preset: " .. p.name, "success") end
    return true
end

function VM.update()
    local presetIdx = math.max(1, math.min(#VM.PRESETS, math.floor(tonumber(VM.preset:Get()) or 1)))
    if VM.lastPresetIdx == nil then
        VM.lastPresetIdx = presetIdx
    elseif presetIdx ~= VM.lastPresetIdx then
        pcall(VM.applyPreset, presetIdx, true)
    end

    local on = VM.enable:Get() and true or false
    if on then
        pcall(VM.apply, false)
    elseif VM.wasEnabled then
        pcall(VM.restore)
    end
    VM.wasEnabled = on

    local fovOn = VM.fovEnable:Get() and true or false

    local scoped = VM.isScoped()
    if scoped ~= VM.wasScoped then
        VM.wasScoped = scoped
        if fovOn then pcall(VM.applyFov, true) end
    end

    if fovOn then
        pcall(VM.applyFov, false)
    elseif VM.fovWasEnabled or VM.fovApplied then
        pcall(VM.restoreFov)
    end
    VM.fovWasEnabled = fovOn
end

vmSection:Button("Restore original", function()
    VM.enable:Set(false)
    VM.fovEnable:Set(false)
    pcall(VM.restore)
    pcall(VM.restoreFov)
    M:Notify("viewmodel restored", "info")
end)

vmSection:Custom(32, function(ui, x, y)
    ui.text(x, y, "Viewmodel: " .. tostring(VM.status))
    ui.text(x, y + 14, "FOV: " .. (VM.fovEnable:Get() and tostring(VM.fovStatus)
        or "using the native Aimware setting"))
end)

M:OnFrame(function() pcall(VM.update) end)

local function leftKnifeUpdate()
    local want = leftHandKnife:Get() and true or false
    if not want then
        if leftKnifeActive then
            pcall(function() client.Command("switchhandsright", true) end)
            leftKnifeActive = false
        end
        return
    end

    local ent
    pcall(function() ent = entities.GetLocalPlayer() end)
    if not ent then return end

    local okPlayer, okAlive = false, false
    pcall(function() okPlayer = ent:IsPlayer() and true or false end)
    pcall(function() okAlive = ent:IsAlive() and true or false end)
    if not okPlayer or not okAlive then return end

    local wtype
    pcall(function() wtype = ent:GetWeaponType() end)
    if wtype == nil then return end

    if wtype == 0 and not leftKnifeActive then
        pcall(function() client.Command("switchhandsleft", true) end)
        leftKnifeActive = true
    elseif wtype ~= 0 and leftKnifeActive then
        pcall(function() client.Command("switchhandsright", true) end)
        leftKnifeActive = false
    end
end

local function leftKnifeReset()
    if leftKnifeActive then
        pcall(function() client.Command("switchhandsright", true) end)
        leftKnifeActive = false
    end
end

local function probeWeapon(lp)
    local info = {
        sniper = false,
        deagle = false,
        shots = nil,
    }
    if not lp then return info end

    local id, defIndex
    local className, wepName = "", ""
    pcall(function() id = lp:GetWeaponID() end)
    pcall(function() info.shots = tonumber(lp:GetPropInt("m_iShotsFired")) end)

    local wep
    pcall(function() wep = lp:GetPropEntity("m_hActiveWeapon") end)
    if wep then
        pcall(function()
            if wep.GetClass then className = tostring(wep:GetClass() or "") end
        end)
        pcall(function()
            if wep.GetName then wepName = tostring(wep:GetName() or "") end
        end)
        pcall(function()
            if wep.GetWeaponName then
                local n = tostring(wep:GetWeaponName() or "")
                if n ~= "" then wepName = n end
            end
        end)
        pcall(function() defIndex = tonumber(wep:GetPropInt("m_iItemDefinitionIndex")) end)
        pcall(function()
            if defIndex == nil then
                defIndex = tonumber(wep:GetPropInt("m_AttributeManager.m_Item.m_iItemDefinitionIndex"))
            end
        end)
    end
    if className == "" then
        pcall(function()
            if lp.GetWeaponClass then className = tostring(lp:GetWeaponClass() or "") end
        end)
    end

    local blob = (tostring(className) .. " " .. tostring(wepName)):lower()
    if id == 9 or id == 40 then info.sniper = true end
    if defIndex == 9 or defIndex == 40 then info.sniper = true end
    if blob:find("awp", 1, true) then info.sniper = true end
    if blob:find("ssg08", 1, true) or blob:find("ssg_08", 1, true) then info.sniper = true end

    if id == 1 or defIndex == 1 then info.deagle = true end
    if blob:find("deagle", 1, true) or blob:find("desert eagle", 1, true) then info.deagle = true end
    return info
end

local function cmdAttacking(cmd)
    if not cmd then return false end
    local buttons = nil
    pcall(function() buttons = cmd.buttons end)
    if buttons == nil then pcall(function() buttons = cmd:Buttons() end) end
    if buttons == nil then pcall(function() buttons = cmd:GetButtons() end) end
    buttons = tonumber(buttons)
    if not buttons then return false end
    local masked = nil
    pcall(function()
        if bit and bit.band then masked = bit.band(buttons, 1) end
    end)
    if masked == nil then masked = buttons % 2 end
    return masked ~= 0
end

local function sniperQsUpdate(cmd)
    local enabled = sniperQuickSwitch:Get() and true or false
    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then
        SniperQS.phase = nil
        SniperQS.lastShots = 0
        SniperQS.lastAttack = false
        return
    end

    local alive = false
    pcall(function() alive = lp:IsAlive() and true or false end)
    if not alive then
        SniperQS.phase = nil
        SniperQS.lastShots = 0
        SniperQS.lastAttack = false
        return
    end

    local now = miscNow()
    local info = probeWeapon(lp)
    local shots = tonumber(info.shots) or 0
    local attack = cmdAttacking(cmd)

    if SniperQS.phase == "knife" then
        if now >= SniperQS.knifeAt then
            pcall(function() client.Command("slot3", true) end)
            local extra = (tonumber(sniperQsDelay:Get()) or 0) / 1000
            SniperQS.switchBackAt = now + 0.040 + (math.random() * 0.030) + extra
            SniperQS.phase = "back"
        end
        SniperQS.lastShots = shots
        SniperQS.lastAttack = attack
        return
    end

    if SniperQS.phase == "back" then
        if now >= SniperQS.switchBackAt then
            pcall(function() client.Command("slot1", true) end)
            SniperQS.phase = nil
        end
        SniperQS.lastShots = shots
        SniperQS.lastAttack = attack
        return
    end

    if not enabled then
        SniperQS.lastShots = shots
        SniperQS.lastAttack = attack
        return
    end

    local firedByShots = shots > (SniperQS.lastShots or 0)
    local firedByAttack = attack and not SniperQS.lastAttack
    SniperQS.lastShots = shots
    SniperQS.lastAttack = attack

    if not firedByShots and not firedByAttack then return end
    if not info.sniper then return end

    SniperQS.knifeAt = now + 0.012 + (math.random() * 0.010)
    SniperQS.phase = "knife"
end

local function deagleQsUpdate(cmd)
    local enabled = deagleQuickSwitch:Get() and true or false
    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then
        DeagleQS.phase = nil
        DeagleQS.lastShots = 0
        DeagleQS.lastAttack = false
        return
    end

    local alive = false
    pcall(function() alive = lp:IsAlive() and true or false end)
    if not alive then
        DeagleQS.phase = nil
        DeagleQS.lastShots = 0
        DeagleQS.lastAttack = false
        return
    end

    local now = miscNow()
    local info = probeWeapon(lp)
    local shots = tonumber(info.shots) or 0
    local attack = cmdAttacking(cmd)

    if DeagleQS.phase == "knife" then
        if now >= DeagleQS.knifeAt then
            pcall(function() client.Command("slot3", true) end)
            local extra = (tonumber(deagleQsDelay:Get()) or 0) / 1000
            DeagleQS.switchBackAt = now + 0.040 + (math.random() * 0.030) + extra
            DeagleQS.phase = "back"
        end
        DeagleQS.lastShots = shots
        DeagleQS.lastAttack = attack
        return
    end

    if DeagleQS.phase == "back" then
        if now >= DeagleQS.switchBackAt then
            pcall(function() client.Command("slot2", true) end)
            DeagleQS.phase = nil
        end
        DeagleQS.lastShots = shots
        DeagleQS.lastAttack = attack
        return
    end

    if not enabled then
        DeagleQS.lastShots = shots
        DeagleQS.lastAttack = attack
        return
    end

    local firedByShots = shots > (DeagleQS.lastShots or 0)
    local firedByAttack = attack and not DeagleQS.lastAttack
    DeagleQS.lastShots = shots
    DeagleQS.lastAttack = attack

    if not firedByShots and not firedByAttack then return end
    if not info.deagle then return end

    DeagleQS.knifeAt = now + 0.012 + (math.random() * 0.010)
    DeagleQS.phase = "knife"
end

local stepSection = visualsTab:Section("Step ESP")
local stepEnable = stepSection:Checkbox("Enable Step ESP", false)
local stepColor = stepSection:ColorPicker("Ring color", DEFAULT_STEP_COLOR)
local stepDuration = stepSection:SliderFloat("Duration (s)", DEFAULT_STEP_DURATION, 0.20, 2.50, "%.2fs", 0.05)
local stepRadius = stepSection:Slider("Max radius", DEFAULT_STEP_RADIUS, 10, 150, 1)
local stepInterval = stepSection:Slider("Interval (ticks)", 20, 1, 100, 1)
stepSection:Button("Reset Step ESP", function()
    stepEnable:Set(false)
    stepColor:Set({ DEFAULT_STEP_COLOR[1], DEFAULT_STEP_COLOR[2], DEFAULT_STEP_COLOR[3], DEFAULT_STEP_COLOR[4] })
    stepDuration:Set(DEFAULT_STEP_DURATION)
    stepRadius:Set(DEFAULT_STEP_RADIUS)
    stepInterval:Set(20)
    M:Notify("step esp reset", "info")
end)

local DEATH_EFFECT_NAMES = {
    "Burnt chicken",
    "Blood burst",
    "Material blast",
    "Smoke puff",
    "Flash smoke",
    "Snow blast",
    "Water blast",
    "Train flash",
    "Subtle glow",
    "Mini sparks",
    "Sparks",
    "Fireworks",
    "Golden send-off",
    "Melon gibs",
    "Payday",
    "Souls",
    "Ember",
}
local DEATH_EFFECT_PATHS = {
    {
        exclusive = true,
        { path = "particles/critters/chicken/chicken_roasted.vpcf", z_off = 6 },
        { path = "particles/critters/chicken/chicken_gone_feathers_fire.vpcf", z_off = 54 },
    },
    {
        { path = "particles/burning_fx/impact_gas_rocket_child04a.vpcf", z_off = 6 },
        { path = "particles/burning_fx/impact_gas_rocket_child_bits2.vpcf", z_off = 6 },
    },
    {
        { path = "particles/dev/materials_test.vpcf", z_off = 6 },
    },
    {
        { path = "particles/dev/materials_test_puffs.vpcf", z_off = 6 },
    },
    {
        { path = "particles/explosions_fx/explosion_c4_500_groundbase.vpcf", z_off = 6 },
    },
    {
        { path = "particles/explosions_fx/explosion_hegrenade_snow.vpcf", z_off = 6 },
    },
    {
        { path = "particles/explosions_fx/explosion_basic_water.vpcf", z_off = 6 },
    },
    {
        { path = "particles/explosions_fx/c4_train_ground_low_02.vpcf", z_off = 0 },
        { path = "particles/explosions_fx/c4_train_ground_low_03.vpcf", z_off = 0 },
        {
            path = "particles/explosions_fx/bumpmine_detonate_sparks.vpcf",
            count = 0,
            follow = {
                count_min = 2,
                count_max = 5,
                delay_min = 0.12,
                delay_max = 2.4,
                spread = 28,
                z_min = 28,
                z_max = 68,
            },
        },
        {
            path = "particles/explosions_fx/explosion_flashbang.vpcf",
            z_off = 48,
            count = 1,
            spread = 18,
            z_spread = 12,
            follow = {
                count_min = 2,
                count_max = 5,
                delay_min = 0.18,
                delay_max = 2.6,
                spread = 32,
                z_min = 28,
                z_max = 68,
            },
        },
    },
    {
        {
            path = "particles/explosions_fx/explosion_flashbang.vpcf",
            z_off = 48,
            count = 1,
            spread = 22,
            z_spread = 14,
            follow = {
                count_min = 5,
                count_max = 9,
                delay_min = 0.12,
                delay_max = 2.8,
                spread = 40,
                z_min = 28,
                z_max = 68,
            },
        },
    },
    {
        {
            path = "particles/explosions_fx/bumpmine_detonate_sparks.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 12,
                delay_min = 0.08,
                delay_max = 3.0,
                spread = 48,
                z_min = 28,
                z_max = 78,
            },
        },
        {
            path = "particles/explosions_fx/explosion_flashbang.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 12,
                delay_min = 0.08,
                delay_max = 3.0,
                spread = 24,
                z_min = 28,
                z_max = 78,
            },
        },
    },
    {
        { path = "particles/characters/taser_body_fx.vpcf", z_off = 54 },
        { path = "particles/blood_impact/impact_taser_bodyfx.vpcf", z_off = 50 },
        {
            path = "particles/generic_fx/fx_electric_arc_spark.vpcf",
            count = 0,
            follow = {
                count_min = 5,
                count_max = 9,
                progressive = true,
                delay_min = 0.06,
                delay_max = 2.2,
                radius_min = 6,
                radius_max = 26,
                z_min = 28,
                z_max = 72,
                life = 3.0,
            },
        },
        {
            path = "particles/weapons/cs_weapon_fx/weapon_taser_sparks_impact.vpcf",
            count = 0,
            follow = {
                count_min = 4,
                count_max = 7,
                delay_min = 0.10,
                delay_max = 1.8,
                spread = 14,
                z_min = 34,
                z_max = 66,
                life = 3.0,
            },
        },
        {
            path = "particles/blood_impact/impact_taser_bodyfx_ashes.vpcf",
            count = 0,
            follow = {
                count = 3,
                progressive = true,
                delay_min = 1.4,
                delay_max = 3.2,
                radius_min = 0,
                radius_max = 18,
                z_min = 30,
                z_max = 60,
                life = 4.5,
            },
        },
    },
    {
        { path = "particles/inferno_fx/firework_crate_ground_effect.vpcf", z_off = 2 },
        { path = "particles/inferno_fx/firework_crate_ground_sparks_01.vpcf", z_off = 2 },
        {
            path = "particles/inferno_fx/firework_crate_explosion_01.vpcf",
            count = 0,
            follow = {
                count_min = 4,
                count_max = 6,
                progressive = true,
                delay_min = 0.35,
                delay_max = 2.6,
                radius_min = 8,
                radius_max = 46,
                z_min = 70,
                z_max = 190,
                life = 4.0,
            },
        },
        {
            path = "particles/inferno_fx/firework_crate_explosion_02.vpcf",
            count = 0,
            follow = {
                count_min = 3,
                count_max = 5,
                progressive = true,
                delay_min = 0.55,
                delay_max = 3.0,
                radius_min = 12,
                radius_max = 58,
                z_min = 90,
                z_max = 200,
                life = 4.0,
            },
        },
        {
            path = "particles/inferno_fx/fireworks_explosion_glow_03.vpcf",
            count = 0,
            follow = {
                count = 3,
                progressive = true,
                delay_min = 0.8,
                delay_max = 2.8,
                radius_min = 10,
                radius_max = 40,
                z_min = 100,
                z_max = 180,
                life = 4.0,
            },
        },
        {
            path = "particles/inferno_fx/firework_crate_shower_01b.vpcf",
            count = 0,
            follow = {
                count = 2,
                progressive = true,
                delay_min = 1.1,
                delay_max = 2.4,
                radius_min = 0,
                radius_max = 24,
                z_min = 120,
                z_max = 175,
                life = 4.5,
            },
        },
    },
    {
        { path = "particles/ui/ui_gold_halo_rays_radiate.vpcf", z_off = 54 },
        {
            path = "particles/ui/ui_gold_halo_sparkles.vpcf",
            z_off = 44,
            count = 6,
            arrange = "ring",
            radius = 26,
            z_spread = 6,
        },
        { path = "particles/ui/ui_gold_halo_flare.vpcf", z_off = 60 },
        {
            path = "particles/ui/ui_mvp_embers.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 9,
                progressive = true,
                delay_min = 0.10,
                delay_max = 2.6,
                radius_min = 4,
                radius_max = 30,
                z_min = 4,
                z_max = 76,
                life = 4.0,
            },
        },
    },
    {
        { path = "particles/breakable_fx/break_watermelon_chunks.vpcf", z_off = 52, count = 3, spread = 14, z_spread = 10 },
        { path = "particles/blood_impact/blood_impact_chunks1.vpcf", z_off = 48, count = 2, spread = 10, z_spread = 8 },
        {
            path = "particles/breakable_fx/break_cabbage_chunks.vpcf",
            z_off = 44,
            count = 4,
            arrange = "ring",
            radius = 18,
            z_spread = 12,
        },
        {
            path = "particles/blood_impact/blood_impact_red_01_chunk.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 10,
                progressive = true,
                delay_min = 0.05,
                delay_max = 1.9,
                radius_min = 6,
                radius_max = 54,
                z_min = 10,
                z_max = 66,
                life = 3.5,
            },
        },
        {
            path = "particles/impact_fx/blood_impact_friendly_debris.vpcf",
            count = 0,
            follow = {
                count_min = 4,
                count_max = 7,
                delay_min = 0.20,
                delay_max = 2.6,
                spread = 46,
                z_min = 2,
                z_max = 26,
                life = 4.0,
            },
        },
    },
    {
        { path = "particles/money_fx/moneycrate_burst.vpcf", z_off = 46 },
        { path = "particles/money_fx/moneycrate_burst_money.vpcf", z_off = 54, count = 2, spread = 16, z_spread = 10 },
        { path = "particles/money_fx/moneycrate_burst_confetti.vpcf", z_off = 58, count = 2, spread = 20, z_spread = 12 },
        {
            path = "particles/weapons/cs_weapon_fx/confetti_a.vpcf",
            z_off = 62,
            count = 3,
            arrange = "ring",
            radius = 24,
            z_spread = 8,
        },
        {
            path = "particles/money_fx/money_burst_money_single.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 10,
                progressive = true,
                delay_min = 0.06,
                delay_max = 2.8,
                radius_min = 6,
                radius_max = 62,
                z_min = 30,
                z_max = 96,
                life = 4.5,
            },
        },
        {
            path = "particles/money_fx/money_burst_confetti_single.vpcf",
            count = 0,
            follow = {
                count_min = 5,
                count_max = 8,
                delay_min = 0.12,
                delay_max = 3.0,
                spread = 56,
                z_min = 20,
                z_max = 88,
                life = 4.5,
            },
        },
        {
            path = "particles/weapons/cs_weapon_fx/confetti_b.vpcf",
            count = 0,
            follow = {
                count = 3,
                progressive = true,
                delay_min = 0.40,
                delay_max = 2.4,
                radius_min = 10,
                radius_max = 44,
                z_min = 40,
                z_max = 104,
                life = 4.0,
            },
        },
        {
            path = "particles/weapons/cs_weapon_fx/weapon_confetti_sparks.vpcf",
            count = 0,
            follow = {
                count_min = 3,
                count_max = 5,
                delay_min = 0.25,
                delay_max = 2.0,
                spread = 30,
                z_min = 50,
                z_max = 100,
                life = 3.5,
            },
        },
    },
    {
        { path = "particles/explosions_fx/explosion_c4_debris.vpcf", z_off = 4 },
        { path = "particles/impact_fx/break_concrete_debris.vpcf", z_off = 6, count = 3, spread = 18, z_spread = 10 },
        { path = "particles/impact_fx/break_concrete_smoke.vpcf", z_off = 4, count = 2, spread = 24 },
        {
            path = "particles/explosions_fx/explosion_hegrenade_debris.vpcf",
            z_off = 12,
            count = 3,
            arrange = "ring",
            radius = 22,
            z_spread = 10,
        },
        {
            path = "particles/explosions_fx/explosion_hegrenade_dirt_debris_trails.vpcf",
            count = 0,
            follow = {
                count_min = 5,
                count_max = 8,
                progressive = true,
                delay_min = 0.05,
                delay_max = 2.0,
                radius_min = 10,
                radius_max = 66,
                z_min = 10,
                z_max = 78,
                life = 4.0,
            },
        },
        {
            path = "particles/explosions_fx/explosion_hegrenade_debris_small.vpcf",
            count = 0,
            follow = {
                count_min = 5,
                count_max = 9,
                delay_min = 0.15,
                delay_max = 2.8,
                spread = 58,
                z_min = 2,
                z_max = 34,
                life = 4.0,
            },
        },
        {
            path = "particles/impact_fx/impact_physics_sparks_glow.vpcf",
            count = 0,
            follow = {
                count_min = 3,
                count_max = 6,
                progressive = true,
                delay_min = 0.10,
                delay_max = 2.4,
                radius_min = 8,
                radius_max = 50,
                z_min = 4,
                z_max = 46,
                life = 3.5,
            },
        },
        { path = "particles/impact_fx/impact_physics_dust.vpcf", z_off = 2, count = 3, arrange = "ring", radius = 30 },
    },
    {
        { path = "particles/explosions_fx/explosion_hegrenade_embers.vpcf", z_off = 40 },
        { path = "particles/burning_fx/chaotic_embers_basic.vpcf", z_off = 48, count = 2, spread = 14, z_spread = 12 },
        { path = "particles/ui/hud/ui_mvp_hexplosion_styl_embers.vpcf", z_off = 54 },
        {
            path = "particles/burning_fx/env_embers_small.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 10,
                progressive = true,
                delay_min = 0.05,
                delay_max = 3.0,
                radius_min = 4,
                radius_max = 40,
                z_min = 12,
                z_max = 120,
                life = 5.0,
            },
        },
        {
            path = "particles/burning_fx/env_embers_tiny.vpcf",
            count = 0,
            follow = {
                count_min = 6,
                count_max = 11,
                progressive = true,
                delay_min = 0.10,
                delay_max = 3.4,
                radius_min = 8,
                radius_max = 58,
                z_min = 20,
                z_max = 150,
                life = 5.0,
            },
        },
        {
            path = "particles/burning_fx/smoke_gib_01.vpcf",
            count = 0,
            follow = {
                count_min = 3,
                count_max = 5,
                progressive = true,
                delay_min = 0.35,
                delay_max = 2.8,
                radius_min = 6,
                radius_max = 34,
                z_min = 30,
                z_max = 96,
                life = 5.0,
            },
        },
        { path = "particles/inferno_fx/molotov_groundfire_child_embers.vpcf", z_off = 2, count = 3, arrange = "ring", radius = 26 },
    },
}

local WarnUI = { popup = nil, kind = nil }
M._warnPopupOpen = false

local deathSection = visualsTab:Section("Death Effects")
local deathEnable = deathSection:Checkbox("Enable Death Effects", false)
local deathEffectCombo = deathSection:Combo("Effect", DEATH_EFFECT_NAMES, 1)
local DeathUI = { confirmed = false }
deathSection:Button("Reset Death Effects", function()
    DeathUI.confirmed = false
    deathEnable:Set(false)
    deathEffectCombo:Set(1)
    if WarnUI.kind == "death" then WarnUI.close(true) end
    M:Notify("death effects reset", "info")
end)

local CoachTrail = {
    enabled = false,
    mode = TRAIL_MODE_DEFAULT,
    color = { DEFAULT_TRAIL_COLOR[1], DEFAULT_TRAIL_COLOR[2], DEFAULT_TRAIL_COLOR[3], DEFAULT_TRAIL_COLOR[4] },
    length = DEFAULT_TRAIL_LENGTH,
    thickness = DEFAULT_TRAIL_THICKNESS,
    rate_ms = DEFAULT_TRAIL_RATE_MS,
    rainbow = false,
    points = {},
    last_update = 0,
    last_pos = nil,
    last_append = 0,
    last_frame = 0,
    catching_up = false,
    particles_armed = true,
    restart_accum = 0,
    particle_last_spawn = 0,
    particle_live = {},
    particle_idx = nil,
    particle_fail_streak = 0,
    particle_backoff_until = 0,
    def_type = 1,
    def_color_type = 1,
    def_color = { DEFAULT_TRAIL_DEF_COLOR[1], DEFAULT_TRAIL_DEF_COLOR[2], DEFAULT_TRAIL_DEF_COLOR[3], DEFAULT_TRAIL_DEF_COLOR[4] },
    def_chroma = 1,
    def_seg_exp = 10,
    def_line_size = 1,
    def_rect_w = 1,
    def_rect_h = 1,
    def_x_w = 1,
    def_y_w = 1,
    def_segments = {},
    def_last_origin = nil,
}

local ParticleAPI = {}

local TrailUI = {}

function TrailUI.clearDefaultSegments()
    CoachTrail.def_segments = {}
    CoachTrail.def_last_origin = nil
end

function TrailUI.clearAllRuntime()
    CoachTrail.points = {}
    CoachTrail.last_pos = nil
    CoachTrail.particle_last_spawn = 0
    CoachTrail.particle_fail_streak = 0
    CoachTrail.particle_backoff_until = 0
    CoachTrail.last_append = 0
    CoachTrail.last_frame = 0
    CoachTrail.catching_up = false
    CoachTrail.particles_armed = true
    CoachTrail.restart_accum = 0
    CoachTrail.stopped_since = nil
    TrailUI.clearDefaultSegments()
    if type(ParticleAPI.destroyEffect) == "function" then
        if CoachTrail.particle_idx then
            pcall(ParticleAPI.destroyEffect, CoachTrail.particle_idx)
            CoachTrail.particle_idx = nil
        end
        if CoachTrail.particle_live then
            for i = 1, #CoachTrail.particle_live do
                local e = CoachTrail.particle_live[i]
                if e and e.idx then pcall(ParticleAPI.destroyEffect, e.idx) end
            end
        end
    end
    CoachTrail.particle_live = {}
end

do
    local sec = visualsTab:Section("Coach Trail")
    TrailUI.enable = sec:Checkbox("Enable Coach Trail", false)
    TrailUI.style = sec:Combo("Style", TRAIL_STYLE_NAMES, TRAIL_MODE_DEFAULT)
    TrailUI.defSegExp = sec:Slider("Trail Segment Expiration", 10, 1, 100, 1)
    TrailUI.defType = sec:Combo("Trail Type", TRAIL_DEF_TYPE_NAMES, 1)
    TrailUI.defColorType = sec:Combo("Trail Color Type", TRAIL_DEF_COLOR_NAMES, 1)
    TrailUI.defColor = sec:ColorPicker("Trail Color", DEFAULT_TRAIL_DEF_COLOR)
    TrailUI.defChroma = sec:Slider("Trail Chroma Speed Multiplier", 1, 1, 100, 1)
    TrailUI.defLineSize = sec:Slider("Line Size", 1, 1, 100, 1)
    TrailUI.defRectW = sec:Slider("Rect Width", 1, 1, 100, 1)
    TrailUI.defRectH = sec:Slider("Rect Height", 1, 1, 100, 1)
    TrailUI.defXW = sec:Slider("Trail X Width", 1, 1, 100, 1)
    TrailUI.defYW = sec:Slider("Trail Y Width", 1, 1, 100, 1)
    TrailUI.rainbow = sec:Checkbox("Rainbow", false)
    visualsTab.secs = { vmSection, deathSection, stepSection, sec }
    TrailUI.color = sec:ColorPicker("Trail color", DEFAULT_TRAIL_COLOR)
    TrailUI.length = sec:Slider("Length (points)", DEFAULT_TRAIL_LENGTH, 10, TRAIL_LENGTH_MAX, 1)
    TrailUI.thickness = sec:Slider("Thickness", DEFAULT_TRAIL_THICKNESS, 1, 20, 1)

    function TrailUI.syncVisibility()
        local isDef = (tonumber(TrailUI.style:Get()) or TRAIL_MODE_DEFAULT) == TRAIL_MODE_DEFAULT
        local tType = math.max(1, math.min(3, math.floor(tonumber(TrailUI.defType:Get()) or 1)))
        local cType = math.max(1, math.min(3, math.floor(tonumber(TrailUI.defColorType:Get()) or 1)))
        TrailUI.defSegExp:SetHidden(not isDef)
        TrailUI.defType:SetHidden(not isDef)
        TrailUI.defColorType:SetHidden(not isDef)
        TrailUI.defColor:SetHidden(not (isDef and cType == 1))
        TrailUI.defChroma:SetHidden(not (isDef and cType ~= 1))
        TrailUI.defLineSize:SetHidden(not (isDef and tType == 1))
        TrailUI.defRectW:SetHidden(not (isDef and tType == 3))
        TrailUI.defRectH:SetHidden(not (isDef and tType == 3))
        TrailUI.defXW:SetHidden(not (isDef and tType == 2))
        TrailUI.defYW:SetHidden(not (isDef and tType == 2))
        TrailUI.rainbow:SetHidden(isDef)
        TrailUI.color:SetHidden(isDef)
        TrailUI.length:SetHidden(isDef)
        TrailUI.thickness:SetHidden(isDef)
    end

    sec:Button("Clear trail", function()
        TrailUI.clearAllRuntime()
        M:Notify("trail cleared", "info")
    end)
    sec:Button("Reset Coach Trail", function()
        TrailUI.enable:Set(false)
        TrailUI.style:Set(TRAIL_MODE_DEFAULT)
        TrailUI.defSegExp:Set(10)
        TrailUI.defType:Set(1)
        TrailUI.defColorType:Set(1)
        TrailUI.defColor:Set({ DEFAULT_TRAIL_DEF_COLOR[1], DEFAULT_TRAIL_DEF_COLOR[2], DEFAULT_TRAIL_DEF_COLOR[3], DEFAULT_TRAIL_DEF_COLOR[4] })
        TrailUI.defChroma:Set(1)
        TrailUI.defLineSize:Set(1)
        TrailUI.defRectW:Set(1)
        TrailUI.defRectH:Set(1)
        TrailUI.defXW:Set(1)
        TrailUI.defYW:Set(1)
        TrailUI.rainbow:Set(false)
        TrailUI.color:Set({ DEFAULT_TRAIL_COLOR[1], DEFAULT_TRAIL_COLOR[2], DEFAULT_TRAIL_COLOR[3], DEFAULT_TRAIL_COLOR[4] })
        TrailUI.length:Set(DEFAULT_TRAIL_LENGTH)
        TrailUI.thickness:Set(DEFAULT_TRAIL_THICKNESS)
        TrailUI.particleConfirmed = false
        TrailUI.clearAllRuntime()
        TrailUI.syncVisibility()
        if WarnUI.kind == "particle" then TrailUI.closeWarnPopup(true) end
        M:Notify("coach trail reset", "info")
    end)
    TrailUI.syncVisibility()
end

TrailUI.particleConfirmed = false

function WarnUI.isOpen()
    return M._warnPopupOpen and true or false
end

function WarnUI.close(showMenu)
    WarnUI.popup = nil
    WarnUI.kind = nil
    M._warnPopupOpen = false
    if showMenu ~= false then
        M._menuVisible = true
    end
end

function WarnUI.open(opts)
    opts = opts or {}
    if M._warnPopupOpen then return false end
    WarnUI.kind = opts.kind
    WarnUI.popup = {
        title = opts.title or "Warning",
        body = opts.body or "Warning: can cause crashing.",
        detail = opts.detail or "",
        onOkay = opts.onOkay,
        onCancel = opts.onCancel,
        _mouseDown = true,
        _ignoreUntilUp = true,
    }
    M._warnPopupOpen = true
    return true
end

function TrailUI.openWarnPopup()
    WarnUI.open({
        kind = "particle",
        detail = "Particle trail uses engine effects.",
        onOkay = function() TrailUI.confirmParticle() end,
        onCancel = function() TrailUI.cancelParticle() end,
    })
end

function TrailUI.closeWarnPopup(showMenu)
    WarnUI.close(showMenu)
end

function TrailUI.confirmParticle()
    TrailUI.particleConfirmed = true
    TrailUI.style:Set(TRAIL_MODE_PARTICLE)
    WarnUI.close(true)
    TrailUI.syncVisibility()
    if type(TrailUI._applyFromWidgets) == "function" then
        pcall(TrailUI._applyFromWidgets)
    end
    M:Notify("particle trail enabled", "info")
end

function TrailUI.cancelParticle()
    TrailUI.particleConfirmed = false
    TrailUI.style:Set(TRAIL_MODE_DEFAULT)
    WarnUI.close(true)
    TrailUI.syncVisibility()
    if type(TrailUI._applyFromWidgets) == "function" then
        pcall(TrailUI._applyFromWidgets)
    end
    M:Notify("staying on default trail", "info")
end

function DeathUI.confirmEnable()
    DeathUI.confirmed = true
    deathEnable:Set(true)
    WarnUI.close(true)
    M:Notify("death effects enabled", "info")
end

function DeathUI.cancelEnable()
    DeathUI.confirmed = false
    deathEnable:Set(false)
    WarnUI.close(true)
    M:Notify("death effects not enabled", "info")
end

function DeathUI.pollWarn()
    local on = deathEnable:Get() and true or false
    if not on then
        DeathUI.confirmed = false
        if WarnUI.kind == "death" then WarnUI.close(false) end
        return
    end
    if DeathUI.confirmed then return end
    if WarnUI.isOpen() then return end
    WarnUI.open({
        kind = "death",
        detail = "Death effects use engine particles.",
        onOkay = function() DeathUI.confirmEnable() end,
        onCancel = function() DeathUI.cancelEnable() end,
    })
end

function DeathUI.isArmed()
    return (deathEnable:Get() and true or false) and DeathUI.confirmed
end

function WarnUI.draw()
    local P = WarnUI.popup
    if not P or not M._warnPopupOpen then return end
    local sw, sh = 0, 0
    pcall(function() sw, sh = draw.GetScreenSize() end)
    if not sw or sw < 1 then return end

    local theme = (M and M.T) or {}
    local warnCol = { 255, 176, 46 }
    local section = theme.section or theme.bg2 or { 15, 19, 26, 252 }
    local border = theme.border or { 40, 48, 61, 255 }
    local textCol = theme.text or { 205, 213, 225, 255 }
    local textHi = theme.texthi or { 247, 249, 255, 255 }
    local muted = theme.textdim or { 119, 132, 150, 255 }
    local widget = theme.widget or { 19, 25, 34, 255 }
    local widgetHi = theme.widgethi or { 26, 36, 48, 255 }
    local shadow = theme.shadow or { 0, 0, 0, 115 }
    local bgDeep = theme.bg or { 8, 10, 14, 252 }

    local font, fontB
    if M and type(M.UIFonts) == "function" then
        font, fontB = M:UIFonts()
    end

    local mw, mh = 440, 268
    local x = math.floor((sw - mw) * 0.5)
    local y = math.floor((sh - mh) * 0.5)

    local function col4(c, a)
        return tonumber(c[1]) or 255, tonumber(c[2]) or 255, tonumber(c[3]) or 255, tonumber(a or c[4]) or 255
    end
    local function fill(rx, ry, rw, rh, c, a)
        if not c or rw < 1 or rh < 1 then return end
        pcall(function()
            local r, g, b, aa = col4(c, a)
            draw.Color(r, g, b, aa)
            draw.FilledRect(math.floor(rx), math.floor(ry), math.floor(rx + rw), math.floor(ry + rh))
        end)
    end
    local function rfill(rx, ry, rw, rh, rad, c, a)
        rx, ry, rw, rh = math.floor(rx), math.floor(ry), math.floor(rw), math.floor(rh)
        rad = math.min(rad or 0, math.floor(rw / 2), math.floor(rh / 2))
        if rad <= 0 then fill(rx, ry, rw, rh, c, a); return end
        fill(rx, ry + rad, rw, rh - 2 * rad, c, a)
        for dy = 0, rad - 1 do
            local dx = rad - math.floor(math.sqrt(rad * rad - (rad - dy - 0.5) ^ 2) + 0.5)
            fill(rx + dx, ry + dy, rw - 2 * dx, 1, c, a)
            fill(rx + dx, ry + rh - 1 - dy, rw - 2 * dx, 1, c, a)
        end
    end
    local function rbox(rx, ry, rw, rh, rad, fillC, brdC)
        if brdC then rfill(rx, ry, rw, rh, rad, brdC) end
        rfill(rx + 1, ry + 1, rw - 2, rh - 2, math.max(0, (rad or 0) - 1), fillC)
    end
    local function label(fnt, tx, ty, c, s, centerW)
        if not c or s == nil then return end
        pcall(function()
            if fnt then draw.SetFont(fnt) end
            local r, g, b = col4(c)
            draw.Color(r, g, b, 255)
            local text = tostring(s)
            local lx = math.floor(tx)
            if centerW then
                local tw = 0
                pcall(function() tw = select(1, draw.GetTextSize(text)) or 0 end)
                if type(tw) ~= "number" then tw = 0 end
                lx = math.floor(tx + (centerW - tw) * 0.5)
            end
            draw.Text(lx, math.floor(ty), text)
        end)
    end
    local function hit(mx, my, hx, hy, hw, hh)
        return mx >= hx and mx <= hx + hw and my >= hy and my <= hy + hh
    end
    local function mouse()
        if ms and (ms.x or ms.y) then
            return ms.x or 0, ms.y or 0, ms.down and true or false, ms.pressed and true or false
        end
        local mx, my = 0, 0
        pcall(function()
            if input and input.GetMousePos then
                local p = input.GetMousePos()
                if type(p) == "table" then mx, my = p.x or p[1] or 0, p.y or p[2] or 0
                else mx, my = p, select(2, input.GetMousePos()) end
            end
        end)
        local down = false
        pcall(function()
            if input and input.IsButtonDown then down = input.IsButtonDown(0x01) and true or false end
        end)
        return mx, my, down, false
    end

    fill(0, 0, sw, sh, { 0, 0, 0 }, 150)
    fill(x + 4, y + 7, mw, mh, shadow)
    rbox(x, y, mw, mh, 10, section, border)
    rfill(x + 1, y + 1, mw - 2, 1, 9, { warnCol[1], warnCol[2], warnCol[3], 55 })
    rfill(x, y, mw, 2, 7, warnCol)

    local iconH = 72
    local iconW = math.floor(iconH * 1.18)
    local iconX = x + math.floor((mw - iconW) * 0.5)
    local iconY = y + 22
    local midX = iconX + math.floor(iconW * 0.5)
    for row = 0, iconH - 1 do
        local t = (iconH <= 1) and 1 or (row / (iconH - 1))
        local half = math.max(1, math.floor(iconW * 0.5 * t))
        fill(midX - half, iconY + row, half * 2, 1, warnCol, 255)
    end
    local bang = { 18, 20, 26 }
    local bw = math.max(5, math.floor(iconH * 0.10))
    local bh = math.floor(iconH * 0.36)
    fill(midX - math.floor(bw * 0.5), iconY + math.floor(iconH * 0.28), bw, bh, bang, 255)
    local d = math.max(5, bw + 1)
    fill(midX - math.floor(d * 0.5), iconY + math.floor(iconH * 0.76), d, d, bang, 255)

    label(fontB or font, x, y + 108, textHi, P.title or "Warning", mw)
    label(font, x, y + 136, textCol, P.body or "Warning: can cause crashing.", mw)
    label(font, x, y + 158, muted, P.detail or "", mw)

    local btnW, btnH, gap = 118, 32, 14
    local btnY = y + mh - 50
    local totalW = btnW * 2 + gap
    local btnX0 = x + math.floor((mw - totalW) * 0.5)
    local buttons = {
        { label = "Okay", ok = true, x = btnX0 },
        { label = "Cancel", ok = false, x = btnX0 + btnW + gap },
    }

    local mx, my, mouseDown, mousePressed = mouse()
    local allowClick = true
    if P._ignoreUntilUp then
        if mouseDown then
            P._mouseDown = true
            allowClick = false
        else
            P._ignoreUntilUp = false
            P._mouseDown = false
        end
    end
    local click = allowClick and (mousePressed or (mouseDown and not (P._mouseDown or false)))
    if allowClick then P._mouseDown = mouseDown end

    for _, b in ipairs(buttons) do
        local hover = hit(mx, my, b.x, btnY, btnW, btnH)
        local fillCol, brdCol, textC
        if b.ok then
            fillCol = hover and warnCol or widget
            brdCol = hover and warnCol or border
            textC = hover and bgDeep or textHi
        else
            fillCol = hover and widgetHi or widget
            brdCol = border
            textC = textCol
        end
        rbox(b.x, btnY, btnW, btnH, 6, fillCol, brdCol)
        label(fontB or font, b.x, btnY + 8, textC, b.label, btnW)
        if click and hover and not (ms and ms.consumed) then
            if ms then ms.consumed = true end
            if b.ok then
                if type(P.onOkay) == "function" then pcall(P.onOkay) end
            else
                if type(P.onCancel) == "function" then pcall(P.onCancel) end
            end
            return
        end
    end
end

M._warnDrawPopup = function()
    WarnUI.draw()
end

local function daizInitSkinChanger(skinsTab)
local SKIN_KNIVES = {
    { name = "Default (no swap)", def = nil },
    { name = "Bayonet",        def = 500 }, { name = "Classic Knife",  def = 503 },
    { name = "Flip Knife",     def = 505 }, { name = "Gut Knife",      def = 506 },
    { name = "Karambit",       def = 507 }, { name = "M9 Bayonet",     def = 508 },
    { name = "Huntsman",       def = 509 }, { name = "Falchion",       def = 512 },
    { name = "Bowie Knife",    def = 514 }, { name = "Butterfly",      def = 515 },
    { name = "Shadow Daggers", def = 516 }, { name = "Paracord Knife", def = 517 },
    { name = "Survival Knife", def = 518 }, { name = "Ursus Knife",    def = 519 },
    { name = "Navaja Knife",   def = 520 }, { name = "Nomad Knife",    def = 521 },
    { name = "Stiletto",       def = 522 }, { name = "Talon Knife",    def = 523 },
    { name = "Skeleton Knife", def = 525 }, { name = "Kukri Knife",    def = 526 },
}
local SKIN_WEAPONS = {
    { name = "AK-47",        def = 7  }, { name = "M4A4",         def = 16 },
    { name = "M4A1-S",       def = 60 }, { name = "AWP",          def = 9  },
    { name = "SSG 08",       def = 40 }, { name = "SCAR-20",      def = 38 },
    { name = "G3SG1",        def = 11 }, { name = "SG 553",       def = 39 },
    { name = "AUG",          def = 8  }, { name = "FAMAS",        def = 10 },
    { name = "Galil AR",     def = 13 }, { name = "Desert Eagle", def = 1  },
    { name = "R8 Revolver",  def = 64 }, { name = "Dual Berettas",def = 2  },
    { name = "Five-SeveN",   def = 3  }, { name = "Glock-18",     def = 4  },
    { name = "Tec-9",        def = 30 }, { name = "P2000",        def = 32 },
    { name = "P250",         def = 36 }, { name = "USP-S",        def = 61 },
    { name = "CZ75-Auto",    def = 63 }, { name = "MAC-10",       def = 17 },
    { name = "P90",          def = 19 }, { name = "PP-Bizon",     def = 26 },
    { name = "MP5-SD",       def = 23 }, { name = "MP7",          def = 33 },
    { name = "MP9",          def = 34 }, { name = "UMP-45",       def = 24 },
    { name = "M249",         def = 14 }, { name = "Negev",        def = 28 },
    { name = "XM1014",       def = 25 }, { name = "MAG-7",        def = 27 },
    { name = "Nova",         def = 35 }, { name = "Sawed-Off",    def = 29 },
}
local SKIN_GLOVES = {
    { name = "Default (off)",      def = 0    },
    { name = "Bloodhound Gloves",  def = 5027 }, { name = "Sport Gloves",      def = 5030 },
    { name = "Driver Gloves",      def = 5031 }, { name = "Hand Wraps",        def = 5032 },
    { name = "Moto Gloves",        def = 5033 }, { name = "Specialist Gloves", def = 5034 },
    { name = "Hydra Gloves",       def = 5035 }, { name = "Broken Fang Gloves",def = 4725 },
}

local SKIN_LEGACY_PAINT = {}
do
    local csv = [[5,6,8,9,10,11,12,13,14,15,16,17,20,21,34,36,42,43,44,48,51,59,60,62,67,70,71,73,74,75,76,77,78,83,84,90,92,125,154,155,156,158,159,164,165,166,169,171,172,174,177,178,180,181,182,183,184,185,187,188,189,190,191,192,195,200,202,203,204,207,211,212,213,214,215,217,218,219,220,221,222,223,224,226,227,228,230,231,232,235,236,237,238,240,247,248,249,250,251,252,255,256,257,258,259,260,261,262,263,264,265,266,267,268,270,271,272,273,275,277,278,279,280,281,282,283,284,286,287,288,289,290,291,293,295,296,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,314,315,316,317,318,319,320,321,323,325,326,327,328,329,330,332,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,361,362,363,364,365,366,367,368,370,371,372,373,374,379,380,381,382,383,384,385,386,387,388,389,390,391,393,394,395,396,397,398,399,400,401,402,403,404,405,406,407,409,410,411,413,414,422,423,424,425,426,427,428,429,430,431,432,433,434,435,436,438,439,440,441,445,446,447,449,450,451,452,454,455,456,457,458,459,460,462,463,464,465,466,468,469,470,471,474,475,476,477,478,479,480,481,482,483,484,485,486,487,488,489,490,491,492,493,494,495,496,497,498,499,500,501,502,503,504,505,506,507,508,509,510,511,512,514,515,516,517,518,519,520,521,524,525,526,527,528,529,530,532,533,534,535,537,538,539,540,541,542,543,544,546,547,548,549,550,551,552,553,554,555,556,557,558,559,560,561,562,563,564,565,566,567,573,574,575,576,577,578,579,580,581,582,583,584,585,586,587,588,589,590,591,592,593,594,595,596,597,598,599,600,601,602,603,604,605,606,607,608,609,610,611,612,613,614,615,616,620,622,623,624,625,626,627,628,629,631,632,633,634,635,636,637,638,639,640,641,642,643,644,645,646,650,652,653,654,655,656,657,658,660,661,662,663,664,665,666,667,668,669,670,671,672,673,674,675,676,677,678,679,680,681,682,683,684,685,686,687,688,689,690,691,692,693,694,695,696,697,699,700,701,703,704,705,706,707,708,709,711,712,713,714,715,716,717,718,719,720,721,722,723,724,725,727,729,731,732,734,736,737,738,739,740,741,742,743,744,745,746,747,748,749,750,751,754,755,756,757,758,759,760,761,763,764,775,776,777,778,779,780,781,782,783,784,785,786,787,788,789,790,791,792,793,795,797,800,801,802,803,804,805,806,807,808,809,810,811,812,814,815,816,817,818,819,820,821,822,823,829,836,837,838,839,840,841,843,844,845,846,847,848,849,850,851,856,857,858,859,860,862,863,865,867,868,872,880,884,885,886,887,888,889,890,891,892,893,894,895,897,898,899,900,902,903,904,905,906,907,908,909,910,911,913,914,915,916,917,918,919,920,921,922,923,924,925,926,927,928,929,941,942,943,944,945,946,947,948,949,950,951,952,953,954,955,956,957,958,959,960,961,962,963,964,965,966,967,968,969,970,971,972,973,974,975,976,977,978,979,980,981,982,983,984,985,986,987,988,989,990,991,992,993,994,995,996,997,998,999,1000,1001,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012,1013,1014,1015,1016,1018,1019,1021,1023,1024,1027,1028,1029,1030,1031,1032,1033,1034,1035,1036,1037,1038,1039,1040,1041,1042,1043,1044,1045,1046,1047,1048,1049,1050,1052,1053,1058,1060,1061,1063,1064,1067,1070,1072,1073,1074,1075,1076,1077,1080,1082,1084,1087,1088,1089,1090,1091,1092,1093,1095,1096,1097,1098,1099,1100,1101,1102,1103,1104,1105,1106,1107,1108,1109,1110,1111,1112,1113,1114,1115,1116,1117,1118,1119,1120,1121,1122,1123,1125,1126,1127,1128,1129,1130,1131,1132,1133,1134,1135,1136,1137,1138,1140,1141,1142,1143,1144,1145,1146,1147,1148,1149,1150,1151,1152,1153,1154,1155,1156,1157,1158,1220,1221,1222,1223,1224,1225,1226,1227,1228,1229,1230,1231,1232,1233,1234,1235,1236,1237,1238,1239,1240,1241,1242,1243,1244,1245,1246,1247,1248,1249,1250,1251,1252,1253,1254,1255]]
    local n = 0
    for id in csv:gmatch("%d+") do
        SKIN_LEGACY_PAINT[tonumber(id)] = true
        n = n + 1
    end
end

local SKIN_PAINTS = {
  [1]={{"Blaze",37},{"Blue Ply",945},{"Bronze Deco",425},{"Calligraffiti",114},{"Cobalt Disruption",231},{"Code Red",711},{"Conspiracy",351},{"Corinthian",509},{"Crimson Web",232},{"Directive",603},{"Emerald JГ¶rmungandr",757},{"Fennec Fox",764},{"Firebreathing",1430},{"Golden Koi",185},{"Hand Cannon",328},{"Heat Treated",1054},{"Heirloom",273},{"Hypnotic",61},{"Kumicho Dragon",527},{"Light Rail",841},{"Mecha Industries",805},{"Meteorite",296},{"Midnight Storm",468},{"Mint Fan",1257},{"Mudder",90},{"Mulberry",1318},{"Naga",397},{"Night",40},{"Night Heist",1006},{"Ocean Drive",1090},{"Oxide Blaze",645},{"Pilot",347},{"Printstream",962},{"Serpent Strike",1189},{"Sputnik",1056},{"Starcade",938},{"Sunset Storm еЈ±",469},{"Sunset Storm ејђ",470},{"The Bronze",992},{"The Daily Deagle",1360},{"Tilted",138},{"Trigger Discipline",1050},{"Urban DDPAT",17},{"Urban Rubble",237},{"Eastern Enigma",1458}},
  [2]={{"Angel Eyes",1347},{"Anodized Navy",28},{"Balance",895},{"Black Limba",190},{"BorDeux",1335},{"Briar",330},{"Cartel",528},{"Cobalt Quartz",249},{"Cobra Strike",658},{"Colony",47},{"Contractor",46},{"Demolition",153},{"Dezastre",978},{"Drift Wood",824},{"Dualing Dragons",491},{"Duelist",447},{"Elite 1.6",903},{"Emerald",453},{"Flora Carnivora",1156},{"Heist",1005},{"Hemoglobin",220},{"Hideout",1169},{"Hydro Strike",112},{"Marina",261},{"Melondrama",1126},{"Moon in Libra",450},{"Oil Change",1086},{"Panther",276},{"Polished Malachite",1290},{"Pyre",860},{"Retribution",307},{"Rose Nacre",1263},{"Royal Consorts",625},{"Shred",710},{"Silver Pour",1373},{"Stained",43},{"Sweet Little Angels",139},{"Switch Board",998},{"Tread",1091},{"Twin Turbo",747},{"Urban Shock",396},{"Ventilators",544},{"Mystic Conjunction",1459}},
  [3]={{"Angry Mob",837},{"Anodized Gunmetal",210},{"Autumn Thicket",1336},{"Berries And Cherries",1002},{"Boost Protocol",1093},{"Buddy",906},{"Candy Apple",3},{"Capillary",646},{"Case Hardened",44},{"Contractor",46},{"Coolant",784},{"Copper Galaxy",274},{"Crimson Blossom",729},{"Dark Polymer",1429},{"Fairy Tale",979},{"Fall Hazard",1082},{"Flame Test",693},{"Forest Night",78},{"Fowl Play",352},{"Fraise Crane",1380},{"Heat Treated",831},{"Hot Shot",377},{"Hybrid",1168},{"Hyper Beast",660},{"Jungle",151},{"Kami",265},{"Midnight Paintover",1062},{"Monkey Business",427},{"Neon Kimono",464},{"Nightshade",223},{"Nitro",254},{"Orange Peel",141},{"Retrobution",510},{"Scrawl",1128},{"Scumbria",605},{"Silver Quartz",252},{"Sky Blue",1262},{"Triumvirate",530},{"Urban Hazard",387},{"Violent Daimyo",585},{"Withered Vine",932},{"Desert Seal",1457}},
  [4]={{"AXIA",832},{"Block-18",1167},{"Blue Fissure",278},{"Brass",159},{"Bullet Queen",957},{"Bunsen Burner",479},{"Candy Apple",3},{"Catacombs",399},{"Clear Polymer",1039},{"Coral Bloom",1312},{"Death Rattle",293},{"Dragon Tattoo",48},{"Fade",38},{"Franklin",1016},{"Fully Tuned",1421},{"Gamma Doppler",1119},{"Gamma Doppler",1120},{"Gamma Doppler",1121},{"Gamma Doppler",1122},{"Gamma Doppler",1123},{"Glockingbird",1282},{"Gold Toof",129},{"Green Line",1200},{"Grinder",381},{"Groundwater",2},{"High Beam",799},{"Ironwork",623},{"Mirror Mosaic",1348},{"Moonrise",694},{"Neo-Noir",988},{"Night",40},{"Nuclear Garden",789},{"Ocean Topo",1265},{"Off World",680},{"Oxide Blaze",808},{"Pink DDPAT",84},{"Ramese's Reach",1240},{"Reactor",367},{"Red Tire",1079},{"Royal Legion",532},{"Sacrifice",918},{"Sand Dune",208},{"Shinobu",1208},{"Snack Attack",1100},{"Steel Disruption",230},{"Synth Leaf",732},{"Teal Graf",152},{"Trace Lock",1357},{"Twilight Galaxy",437},{"Umbral Rabbit",1227},{"Vogue",963},{"Warhawk",713},{"Wasteland Rebel",586},{"Water Elemental",353},{"Weasel",607},{"Winterized",1158},{"Wraiths",495},{"Ghost Protocol",1450},{"Ifrit Lattice",1460}},
  [7]={{"Aphrodite",1397},{"Aquamarine Revenge",474},{"Asiimov",801},{"B the Monster",142},{"Baroque Purple",745},{"Black Laminate",172},{"Bloodsport",639},{"Blue Laminate",226},{"Breakthrough",1358},{"Cartel",394},{"Case Hardened",44},{"Crane Flight",1425},{"Crossfade",912},{"Elite Build",422},{"Emerald Pinstripe",300},{"Fire Serpent",180},{"First Class",341},{"Frontside Misty",490},{"Fuel Injector",524},{"Gold Arabesque",921},{"Green Laminate",1070},{"Head Shot",1221},{"Hydroponic",456},{"Ice Coaled",1143},{"Inheritance",1171},{"Jaguar",316},{"Jet Set",340},{"Jungle Spray",122},{"Leet Museo",1087},{"Legion of Anubis",959},{"Midnight Laminate",1218},{"Neon Revolution",600},{"Neon Rider",707},{"Nightwish",1141},{"Nouveau Rouge",1309},{"Olive Polycam",1179},{"Orbit Mk01",656},{"Panthera onca",1018},{"Phantom Disruptor",941},{"Point Disarray",506},{"Predator",170},{"Rat Rod",885},{"Red Laminate",14},{"Redline",282},{"Safari Mesh",72},{"Safety Net",795},{"Searing Rage",1207},{"Slate",1035},{"Steel Delta",1238},{"The Empress",675},{"The Oligarch",1352},{"The Outsiders",113},{"Uncharted",836},{"VariCamo Grey",1288},{"Vulcan",302},{"Wasteland Rebel",380},{"Wild Lotus",724},{"Wintergreen",1283},{"X-Ray",1004},{"AUTOEXEC",1449},{"Consequence of the Jinn",1466}},
  [8]={{"Akihabara Accept",455},{"Amber Fade",246},{"Amber Slipstream",708},{"Anodized Navy",197},{"Arctic Wolf",886},{"Aristocrat",583},{"Bengal Tiger",9},{"Carved Jade",1033},{"Chameleon",280},{"Colony",47},{"Commando Company",1308},{"Condemned",110},{"Contractor",46},{"Copperhead",10},{"Creep",1362},{"Daedalus",444},{"Death by Puppy",913},{"Eye of Zapems",134},{"Flame JГ¶rmungandr",758},{"Fleet Flock",541},{"Hot Rod",33},{"Lil' Pig",173},{"Luxe Trim",121},{"Midnight Lily",727},{"Momentum",845},{"Navy Murano",740},{"Plague",1088},{"Radiation Hazard",375},{"Random Access",779},{"Ricochet",507},{"Sand Storm",823},{"Snake Pit",1249},{"Spalted Wood",927},{"Steel Sentinel",1198},{"Storm",100},{"Stymphalian",690},{"Surveillance",995},{"Sweeper",794},{"Syd Mead",601},{"Tom Cat",942},{"Torque",305},{"Trigger Discipline",1339},{"Triqua",674},{"Wings",73},{"Signal Scanner",1452},{"Lapis Lazuli",1464}},
  [9]={{"Acheron",788},{"Arsenic Spill",1324},{"Asiimov",279},{"Atheris",838},{"Black Nile",1239},{"BOOM",174},{"Capillary",943},{"Chromatic Aberration",1144},{"Chrome Cannon",1170},{"CMYK",163},{"Containment Breach",887},{"Corticera",181},{"Crakow!",137},{"Desert Hydra",819},{"Dragon Lore",344},{"Duality",1222},{"Electric Hive",227},{"Elite Build",525},{"Exoskeleton",975},{"Exothermic",1378},{"Fade",1026},{"Fever Dream",640},{"Graphite",212},{"Green Energy",1280},{"Gungnir",756},{"Hyper Beast",475},{"Ice Coaled",1346},{"Lightning Strike",51},{"LongDog",1213},{"Man-o'-war",395},{"Medusa",446},{"Mortis",691},{"Neo-Noir",803},{"Oni Taiji",662},{"PAW",718},{"Phobos",584},{"Pink DDPAT",84},{"Pit Viper",251},{"POP AWP",1058},{"Printstream",1206},{"Queen's Gambit",1422},{"Redline",259},{"Safari Mesh",72},{"Silk Tiger",1029},{"Snake Camo",30},{"Sun in Leo",451},{"The End",1356},{"The Prince",736},{"Wildfire",917},{"Worm God",424},{"Sovereign Flame",1465},{"Black Box",1467}},
  [10]={{"2A2F",1202},{"Afterimage",154},{"Bad Trip",1184},{"Byproduct",1393},{"CaliCamo",240},{"Colony",47},{"Commemoration",919},{"Contrast Spray",22},{"Crypsis",835},{"Cyanospatter",92},{"Dark Water",60},{"Decommissioned",904},{"Djinn",429},{"Doomkitty",178},{"Eye of Athena",723},{"Faulty Wiring",1066},{"Grey Ghost",1321},{"Half Sleeve",461},{"Halftone Wash",882},{"Hexane",218},{"Macabre",659},{"Mecha Industries",626},{"Meltdown",1053},{"Meow 36",1146},{"Neural Net",477},{"Night Borre",863},{"Palm",1302},{"Prime Conspiracy",999},{"Pulse",260},{"Rapid Eye Movement",1127},{"Roll Cage",604},{"Sergeant",288},{"Spitfire",194},{"Styx",371},{"Sundown",869},{"Survivor Z",492},{"Teardown",244},{"Valence",529},{"Vendetta",1365},{"Waters of Nephthys",1241},{"Yeti Camo",1219},{"ZX Spectron",1092},{"Snake Song",1461},{"Corp Defense",1477}},
  [11]={{"Ancient Ritual",1034},{"Arctic Camo",6},{"Azure Zebra",229},{"Black Sand",891},{"Chronos",438},{"Contractor",46},{"Demeter",195},{"Desert Storm",8},{"Digital Mesh",980},{"Dream Glade",1129},{"Flux",493},{"Green Apple",294},{"Green Cell",1305},{"High Seas",712},{"Hunter",677},{"Jungle Dashed",147},{"Keeping Tabs",1095},{"Murky",382},{"New Roots",930},{"Orange Crash",545},{"Orange Kimono",465},{"Polar Camo",74},{"Red Jasper",1328},{"Safari Mesh",72},{"Scavenger",806},{"Stinger",628},{"The Executioner",511},{"VariCamo",235},{"Ventilator",606},{"Violet Murano",739}},
  [13]={{"Acid Dart",1296},{"Akoben",842},{"Amber Fade",246},{"Aqua Terrace",460},{"Black Sand",629},{"Blue Titanium",216},{"CAUTION!",1071},{"Cerberus",379},{"Chatterbox",398},{"Chromatic Aberration",1038},{"Cold Fusion",790},{"Connexion",972},{"Control",1185},{"Crimson Tsunami",647},{"Destroyer",1147},{"Dusk Ruins",1032},{"Eco",428},{"Firefight",546},{"Galigator",1434},{"Green Apple",294},{"Grey Smoke",1275},{"Hunting Blind",241},{"Kami",308},{"Metallic Squeezer",239},{"NV",939},{"O-Ranger",1314},{"Orange DDPAT",83},{"Phoenix Blacklight",1013},{"Rainbow Spoon",1178},{"Robin's Egg",1264},{"Rocket Pop",478},{"Sage Spray",119},{"Sandstorm",264},{"Shattered",192},{"Signal",807},{"Sky Mandala",1383},{"Stone Cold",494},{"Sugar Rush",661},{"Tornado",101},{"Tuxedo",297},{"Urban Rubble",237},{"Vandal",981},{"VariCamo",235},{"Winter Forest",76}},
  [14]={{"Aztec",902},{"Blizzard Marbleized",75},{"Bock Blocks",1435},{"Contrast Spray",22},{"Deep Relief",983},{"Downtown",1148},{"Emerald Poison Dart",648},{"Gator Mesh",243},{"Humidor",827},{"Hypnosis",120},{"Impact Drill",472},{"Jungle",151},{"Jungle DDPAT",202},{"Magma",266},{"Midnight Palm",933},{"Nebula Crusader",496},{"O.S.I.P.R.",1042},{"Predator",170},{"Sage Camo",1298},{"Shipping Forecast",452},{"Sleet",1370},{"Spectre",547},{"Spectrogram",875},{"Submerged",1242},{"System Lock",401},{"Warbird",900}},
  [16]={{"Aeolian Dark",1364},{"Asiimov",255},{"Bullet Rain",155},{"Buzz Kill",632},{"Choppa",1210},{"Converter",793},{"Cyber Security",985},{"Dark Blossom",730},{"Daybreak",471},{"Desert Storm",8},{"Desert-Strike",336},{"Desolate Space",588},{"Etch Lord",1165},{"Evil Daimyo",480},{"Eye of Horus",1255},{"Faded Zebra",176},{"Full Throttle",1353},{"Global Offensive",993},{"Griffin",384},{"Hellfire",664},{"Hellish",1209},{"Howl",309},{"In Living Color",1041},{"Jungle Tiger",16},{"Magnesium",811},{"Mainframe",780},{"Modern Hunter",164},{"Naval Shred Camo",1266},{"Neo-Noir",695},{"Poly Mag",1149},{"Polysoup",874},{"Poseidon",449},{"Radiation Hazard",167},{"Red DDPAT",926},{"Royal Paladin",512},{"Sheet Lightning",1281},{"Spider Lily",1097},{"Steel Work",1313},{"Temukau",1228},{"The Battlestar",533},{"The Coalition",1063},{"The Emperor",844},{"Tooth Fairy",971},{"Tornado",101},{"Turbine",118},{"Urban DDPAT",17},{"X-Ray",215},{"Zirka",187},{"Zubastick",1432},{"йѕЌзЋ‹ (Dragon King)",400},{"Dark Operative",1446},{"Falak",1463}},
  [17]={{"Acid Hex",1295},{"Allure",965},{"Aloha",665},{"Amber Fade",246},{"Bronzer",1334},{"Button Masher",1045},{"Calf Skin",748},{"Candy Apple",3},{"Carnivore",589},{"Case Hardened",44},{"Cat Fight",1349},{"Classic Crate",908},{"Commuter",343},{"Copper Borre",761},{"Curse",310},{"Derailment",1204},{"Disco Tech",947},{"Echoing Sands",1244},{"Ensnared",1131},{"Fade",38},{"Gold Brick",1025},{"Graven",188},{"Heat",284},{"Hot Snakes",1009},{"Indigo",333},{"Lapis Gator",534},{"Last Dive",651},{"Light Box",1164},{"Malachite",402},{"Monkeyflage",1150},{"Neon Rider",433},{"Nuclear Garden",372},{"Oceanic",682},{"Palm",157},{"Pipe Down",812},{"Pipsqueak",140},{"Poplar Thicket",1285},{"Propaganda",1067},{"Rangeen",498},{"Red Filigree",742},{"SaibДЃ Oni",126},{"Sakkaku",1229},{"Sienna Damask",826},{"Silver",32},{"Snow Splash",1367},{"Stalker",898},{"Storm Camo",1269},{"Strats",1075},{"Surfwood",871},{"Tatter",337},{"Tornado",101},{"Toybox",1098},{"Ultraviolet",98},{"Urban DDPAT",17},{"Whitefish",840},{"Video Cam",1448},{"Arabesque Mosaic",1454}},
  [19]={{"Aeolian Light",1361},{"Ancient Earth",1020},{"Ash Wood",234},{"Asiimov",359},{"Astral JГ¶rmungandr",759},{"Attack Vector",936},{"Baroque Red",744},{"Blind Spot",228},{"Blue Tac",1277},{"Chopper",593},{"Cocoa Rampage",977},{"Cold Blooded",67},{"Death by Kitty",156},{"Death Grip",669},{"Deathgaze",1419},{"Desert DDPAT",925},{"Desert Halftone",1332},{"Desert Warfare",311},{"Elite Build",486},{"Emerald Dragon",182},{"Facility Negative",776},{"Fallout Warning",169},{"Freight",969},{"Glacier Mesh",111},{"Grim",611},{"Leather",342},{"Module",335},{"Mustard Gas",1291},{"Neoqueen",1233},{"Nostalgia",911},{"Off World",849},{"Randy Rush",127},{"Reef Grief",1256},{"Run and Hide",1000},{"Sand Spray",124},{"ScaraB Rush",1250},{"Schematic",1074},{"Scorched",175},{"Shallow Grave",636},{"Shapewood",516},{"Storm",100},{"Straight Dimes",1199},{"Sunset Lily",726},{"Teardown",244},{"Tiger Pit",1015},{"Traction",717},{"Trigon",283},{"Vent Rush",1154},{"Verdant Growth",828},{"Virus",20},{"Wash me",133},{"Wave Breaker",1190}},
  [23]={{"Acid Wash",888},{"Agent",915},{"Autumn Twilly",1061},{"Bamboo Garden",872},{"Co-Processor",781},{"Condition Zero",986},{"Desert Strike",949},{"Dirt Drop",753},{"Focus",1344},{"Gauss",846},{"Gold Leaf",1294},{"Kitbash",974},{"Lab Rats",800},{"Lime Hex",1274},{"Liquidation",1231},{"Necro Jr.",1137},{"Neon Squeezer",161},{"Nitro",798},{"Oxide Oasis",923},{"Phosphor",810},{"Picnic",1385},{"Savannah Halftone",768},{"Snow Splash",1366},{"Statics",1180}},
  [24]={{"Arctic Wolf",704},{"Blaze",37},{"Bone Pile",193},{"Briefing",615},{"Caramel",93},{"Carbon Fiber",70},{"Continuum",1351},{"Corporal",281},{"Crime Scene",1003},{"Crimson Foil",412},{"Day Lily",725},{"Delusion",392},{"Exposure",688},{"Facility Dark",778},{"Fade",879},{"Fallout Warning",169},{"Fragment",1426},{"Full Stop",250},{"Gold Bismuth",990},{"Grand Prix",436},{"Green Swirl",1303},{"Gunsmoke",15},{"Houndstooth",1008},{"Indigo",333},{"K.O. Factory",1194},{"Labyrinth",362},{"Late Night Transit",1203},{"Mechanism",1085},{"Metal Flowers",672},{"Minotaur's Labyrinth",441},{"Momentum",802},{"Moonrise",851},{"Motorized",1175},{"Mudder",90},{"Neo-Noir",131},{"Oscillator",1049},{"Plastique",916},{"Primal Saber",556},{"Riot",488},{"Roadblock",1157},{"Scaffold",652},{"Scorched",175},{"Urban DDPAT",17},{"Warm Blooded",1387},{"Wild Child",1236}},
  [25]={{"Ancient Lore",1021},{"Banana Leaf",731},{"Black Tie",557},{"Blaze Orange",166},{"Blue Spruce",96},{"Blue Steel",42},{"Blue Tire",1078},{"Bone Machine",370},{"CaliCamo",240},{"Canvas Cloud",1333},{"Charter",994},{"Copperflage",1287},{"Elegant Vines",821},{"Entombed",970},{"Fallout Warning",169},{"Frost Borre",760},{"Grassland",95},{"Gum Wall Camo",1267},{"Halftone Shift",834},{"Heaven Guard",314},{"Hieroglyph",1254},{"Incinegator",850},{"Irezumi",1174},{"Jungle",205},{"Mockingbird",1182},{"Monster Melt",146},{"Oxide Blaze",706},{"Quicksilver",407},{"Red Leather",348},{"Red Python",320},{"Run Run Run",1201},{"Scumbria",505},{"Seasons",654},{"Slipstream",616},{"Solitude",1215},{"Teclu Burner",521},{"Tranquility",393},{"Urban Perforated",135},{"VariCamo Blue",238},{"Watchdog",1103},{"XoooM",1381},{"XOXO",1046},{"Ziggy",689},{"Zombie Offensive",1135},{"Black Site",1471}},
  [26]={{"Anolis",829},{"Antique",306},{"Bamboo Print",457},{"Bizoom",1374},{"Blue Streak",13},{"Brass",159},{"Breaker Box",1083},{"Candy Apple",3},{"Carbon Fiber",70},{"Chemical Green",376},{"Cobalt Halftone",267},{"Cold Cell",770},{"Death Rattle",293},{"Embargo",884},{"Facility Sketch",775},{"Forest Leaves",25},{"Fuel Rod",508},{"Harvester",594},{"High Roller",676},{"Irradiated Alert",171},{"Judgement of Anubis",542},{"Jungle Slipstream",641},{"Lumen",1099},{"Modern Hunter",164},{"Night Ops",236},{"Night Riot",692},{"Osiris",349},{"Photic Zone",526},{"RMX",1418},{"Runic",973},{"Rust Coat",203},{"Sand Dashed",148},{"Seabird",873},{"Space Cat",1125},{"Thermal Currents",1392},{"Urban Dashed",149},{"Water Sigil",224},{"Wood Block Camo",1325},{"Traitor",1472}},
  [27]={{"BI83 Spectrum",1089},{"Bulldozer",39},{"Carbon Fiber",70},{"Chainmail",327},{"Cinquedea",737},{"Cobalt Core",499},{"Copper Coated",1245},{"Copper Oxide",1306},{"Core Breach",787},{"Counter Terrace",462},{"Firestarter",385},{"Foresight",1132},{"Hard Water",666},{"Hazard",198},{"Heat",431},{"Heaven Guard",291},{"Insomnia",1220},{"Irradiated Alert",171},{"Justice",948},{"MAGnitude",1355},{"Memento",177},{"Metallic DDPAT",34},{"Monster Call",961},{"Navy Sheen",822},{"Petroglyph",608},{"Popdog",909},{"Praetorian",535},{"Prism Terrace",1072},{"Resupply",1188},{"Rust Coat",754},{"Sand Dune",99},{"Seabird",473},{"Silver",32},{"Sonar",633},{"Storm",100},{"SWAG-7",703},{"Wildwood",773}},
  [28]={{"Anodized Navy",28},{"Army Sheen",298},{"Boroque Sand",920},{"Bratatat",317},{"Bulkhead",783},{"CaliCamo",240},{"Dazzle",610},{"Desert-Strike",355},{"dev_texture",1043},{"Drop Me",1152},{"Infrastructure",1080},{"Lionfish",698},{"Loudmouth",483},{"Man-o'-war",432},{"MjГ¶lnir",763},{"Nuclear Waste",369},{"Palm",201},{"Phoenix Stencil",1012},{"Power Loader",514},{"Prototype",950},{"Raw Ceramic",1300},{"Sour Grapes",1260},{"Terrain",285},{"Ultralight",958},{"Wall Bang",144}},
  [29]={{"Amber Fade",246},{"Analog Input",1160},{"Apocalypto",953},{"Bamboo Shadow",458},{"Black Sand",814},{"Brake Light",797},{"Clay Ambush",1014},{"Copper",41},{"Crimson Batik",1391},{"Devourer",720},{"First Class",345},{"Forest DDPAT",5},{"Fubar",552},{"Full Stop",250},{"Fusion",1427},{"Highwayman",390},{"Irradiated Alert",171},{"Jungle Thicket",870},{"Kissв™ҐLove",1155},{"Limelight",596},{"Morris",673},{"Mosaico",204},{"Orange DDPAT",83},{"Origami",434},{"Parched",880},{"Runoff",1272},{"Rust Coat",323},{"Sage Spray",119},{"Serenity",405},{"Snake Camo",30},{"Spirit Board",1140},{"The Kraken",256},{"Wasteland Princess",638},{"Yorick",517},{"Zander",655},{"Lunar Wyrm",1475}},
  [30]={{"Army Mesh",242},{"Avalanche",520},{"Bamboo Forest",459},{"Bamboozle",839},{"Banana Leaf",1384},{"Blast From the Past",1024},{"Blue Blast",1279},{"Blue Titanium",216},{"Brass",159},{"Brother",964},{"Citric Acid",1322},{"Cracked Opal",684},{"Cut Out",671},{"Decimator",889},{"Flash Out",905},{"Fubar",816},{"Fuel Injector",614},{"Garter-9",1286},{"Groundwater",2},{"Hades",439},{"Ice Cap",599},{"Isaac",303},{"Jambiya",539},{"Mummy's Rot",1252},{"Nuclear Threat",179},{"Orange Murano",738},{"Ossified",36},{"Phoenix Chalk",1010},{"Raw Ceramic",1299},{"Re-Entry",555},{"Rebel",1235},{"Red Quartz",248},{"Remote Control",791},{"Rust Leaf",733},{"Safety Net",795},{"Sandstorm",289},{"Slag",1159},{"Snek-9",722},{"Terrace",463},{"Tiger Stencil",766},{"Titanium Bit",272},{"Tornado",206},{"Toxic",374},{"Urban DDPAT",17},{"VariCamo",235},{"Whiteout",1214},{"Perimeter",1447},{"Sultan",1462}},
  [31]={{"Charged Up",1205},{"Dragon Snore",292},{"Earth Mandala",1382},{"Electric Blue",1268},{"Olympus",1172},{"Swamp DDPAT",1297},{"Tosai",1183}},
  [32]={{"Acid Etched",951},{"Amber Fade",246},{"Chainmail",327},{"Coach Class",346},{"Coral Halftone",878},{"Corticera",184},{"Dispatch",997},{"Fire Elemental",389},{"Gnarled",960},{"Granite Marbleized",21},{"Grassland",95},{"Grassland Leaves",104},{"Grip Tape",1359},{"Handgun",485},{"Imperial",515},{"Imperial Dragon",591},{"Ivory",357},{"Lifted Spirits",1138},{"Marsh",1292},{"Obsidian",894},{"Ocean Foam",211},{"Oceanic",550},{"Panther Camo",1019},{"Pathfinder",443},{"Pulse",338},{"Red FragCam",275},{"Red Wing",1342},{"Royal Baroque",1259},{"Scorpion",71},{"Silver",32},{"Space Race",1055},{"Sure Grip",1181},{"Turf",635},{"Urban Hazard",700},{"Wicked Sick",1224},{"Woodsman",667}},
  [33]={{"Abyssal Apparition",1133},{"Akoben",649},{"Amberline",1436},{"Anodized Navy",28},{"Armor Core",423},{"Army Recon",245},{"Asterion",442},{"Astrolabe",940},{"Bloodsport",696},{"Cirrus",627},{"Coral Paisley",1386},{"Fade",752},{"Forest DDPAT",5},{"Full Stop",250},{"Groundwater",209},{"Guerrilla",1096},{"Gunsmoke",15},{"Impire",536},{"Just Smile",1163},{"Mischief",847},{"Motherboard",782},{"Nemesis",481},{"Neon Ply",893},{"Ocean Foam",213},{"Olive Plaid",365},{"Orange Peel",141},{"Powercore",719},{"Prey",935},{"Scorched",175},{"Short Ochre",1326},{"Skulls",11},{"Smoking Kills",1354},{"Special Delivery",500},{"Sunbaked",1246},{"Tall Grass",1023},{"Teal Blossom",728},{"Urban Hazard",354},{"Vault Heist",1007},{"Whiteout",102},{"Base-2",1468}},
  [34]={{"Airlock",609},{"Arctic Tri-Tone",331},{"Army Sheen",298},{"Bee-Tron",1388},{"Bioleak",549},{"Black Sand",697},{"Broken Record",1341},{"Buff Blue",1278},{"Bulldozer",39},{"Capillary",715},{"Cobalt Paisley",1258},{"Dark Age",329},{"Dart",386},{"Deadly Poison",403},{"Dizzy",1375},{"Dry Season",199},{"Featherweight",1225},{"Food Chain",1037},{"Goo",679},{"Green Plaid",366},{"Hot Rod",33},{"Hydra",910},{"Hypnotic",61},{"Latte Rush",1211},{"Modest Threat",804},{"Mount Fuji",1094},{"Multi-Terrain",1330},{"Music Box",820},{"Nexus",1193},{"Old Roots",931},{"Orange Peel",141},{"Pandora's Box",448},{"Pine",1301},{"Rose Iron",262},{"Ruby Poison Dart",482},{"Sand Dashed",148},{"Sand Scale",630},{"Setting Sun",368},{"Shredded",1310},{"Slide",755},{"Stained Glass",867},{"Starlight Protector",1134},{"Storm",100},{"Urban Sovereign",1423},{"Wild Lily",734},{"Spy Prototype",1469},{"Dune Asp",1473}},
  [35]={{"Antique",286},{"Army Sheen",298},{"Baroque Orange",746},{"Blaze Orange",166},{"Bloomstick",62},{"Caged Steel",299},{"Candy Apple",3},{"Clear Polymer",987},{"Currents",1368},{"Dark Sigil",1162},{"Exo",590},{"Forest Leaves",25},{"Ghost Camo",225},{"Gila",634},{"Graphite",214},{"Green Apple",294},{"Hyper Beast",537},{"Interlock",1077},{"Koi",356},{"Mandrel",785},{"Marsh Grass",1331},{"Modern Hunter",164},{"Moon in Libra",450},{"Ocular",1350},{"Plume",890},{"Polar Mesh",107},{"Predator",170},{"Quick Sand",929},{"Rain Station",1337},{"Ranger",484},{"Red Quartz",248},{"Rising Skull",263},{"Rising Sun",1192},{"Rust Coat",323},{"Sand Dune",99},{"Sobek's Bite",1247},{"Tempest",191},{"Toy Soldier",716},{"Turquoise Pour",1261},{"Walnut",158},{"Wild Six",699},{"Windblown",1051},{"Wood Fired",809},{"Wurst HГ¶lle",145},{"Yorkshire",324},{"Smart Gun",1442},{"Morning Sun",1474}},
  [36]={{"Apep's Curse",1248},{"Asiimov",551},{"Bengal Tiger",1030},{"Black & Tan",928},{"Bone Mask",27},{"Boreal Forest",77},{"Bullfrog",1345},{"Cartel",388},{"Cassette",968},{"Constructivist",1212},{"Contaminant",982},{"Contamination",373},{"Copper Oxide",1307},{"Crimson Kimono",466},{"Cyber Shell",1044},{"Dark Filigree",741},{"Digital Architect",1081},{"Drought",825},{"Epicenter",130},{"Exchanger",786},{"Facets",207},{"Facility Draft",777},{"Forest Night",78},{"Franklin",295},{"Gunsmoke",15},{"Hive",219},{"Inferno",907},{"Iron Clad",592},{"Kintsugi",1420},{"Mehndi",258},{"Metallic DDPAT",34},{"Mint Kimono",467},{"Modern Hunter",164},{"Muertos",404},{"Nevermore",813},{"Nuclear Threat",168},{"Plum Netting",1273},{"Re.built",1230},{"Red Rock",668},{"Red Tide",1315},{"Ripple",650},{"Sand Dune",99},{"Sedimentary",1317},{"See Ya Later",678},{"Sleet",1369},{"Small Game",774},{"Splash",162},{"Steel Disruption",230},{"Supernova",358},{"Undertow",271},{"Valence",426},{"Verdigris",848},{"Vino Primo",749},{"Visions",1153},{"Whiteout",102},{"Wingshot",501},{"X-Ray",125},{"Lotus Imprint",1455}},
  [38]={{"Army Sheen",298},{"Assault",914},{"Bloodsport",597},{"Blueprint",642},{"Brass",159},{"Caged",1343},{"Carbon Fiber",70},{"Cardiac",391},{"Contractor",46},{"Crimson Web",232},{"Cyrex",312},{"Emerald",196},{"Enforcer",954},{"Fragments",1226},{"Green Marine",502},{"Grotto",406},{"Jungle Slipstream",685},{"Magna Carta",1028},{"Outbreak",518},{"Palm",157},{"Poultrygeist",1139},{"Powercore",612},{"Sand Mesh",116},{"Short Ochre",1327},{"Splash Jam",165},{"Stone Mosaico",865},{"Storm",100},{"Torn",896},{"Trail Blazer",117},{"Wild Berry",883},{"Zinc",1371},{"Sirocco Script",1453},{"Arctic Camo Panels",1470}},
  [39]={{"Aerial",598},{"Aloha",702},{"Anodized Navy",28},{"Army Sheen",298},{"Atlas",553},{"Barricade",861},{"Basket Halftone",1320},{"Berry Gel Coat",901},{"Bleached",934},{"Bulldozer",39},{"Candy Apple",864},{"Colony IV",897},{"Cyberforce",1234},{"Cyrex",487},{"Damascus Steel",247},{"Danger Close",815},{"Darkwing",955},{"Desert Blossom",765},{"Dragon Tech",1151},{"Fallout Warning",378},{"Gator Mesh",243},{"Hazard Pay",1084},{"Heavy Metal",1048},{"Hypnotic",61},{"Integrale",750},{"Lush Ruins",1022},{"Night Camo",1270},{"Ol' Rusty",966},{"Phantom",686},{"Pulse",287},{"Safari Print",1394},{"Tiger Moth",519},{"Tornado",101},{"Traveler",363},{"Triarch",613},{"Ultraviolet",98},{"Wave Spray",186},{"Waves Perforated",136}},
  [40]={{"Abyss",361},{"Acid Fade",253},{"Azure Glyph",1251},{"Big Iron",503},{"Blood in the Water",222},{"Bloodshot",899},{"Blue Spruce",96},{"Blush Pour",1316},{"Calligrafaux",1379},{"Carbon Fiber",70},{"Dark Water",60},{"Death Strike",1052},{"Death's Head",670},{"Detour",319},{"Dezastre",1161},{"Dragonfire",624},{"Fever Dream",956},{"Ghost Crusader",554},{"Green Ceramic",1304},{"Grey Smoke",1271},{"Halftone Whorl",877},{"Hand Brake",751},{"Jungle Dashed",147},{"Lichen Dashed",26},{"Mainframe 001",967},{"Mayan Dreams",200},{"Memorial",1187},{"Necropos",538},{"Orange Filigree",743},{"Parallax",989},{"Prey",935},{"Rapid Transit",128},{"Red Stone",762},{"Sand Dune",99},{"Sans Comic",1372},{"Sea Calico",868},{"Slashed",304},{"Spring Twilly",1060},{"Threat Detected",996},{"Tiger Tear",1289},{"Tropical Storm",233},{"Turbo Peek",1101},{"Zeno",513}},
  [60]={{"Atomic Alloy",301},{"Basilisk",383},{"Black Lotus",1166},{"Blood Tiger",217},{"Blue Phosphor",1017},{"Boreal Forest",77},{"Briefing",663},{"Bright Water",189},{"Chantico's Fire",548},{"Control Panel",792},{"Cyrex",360},{"Dark Water",60},{"Decimator",644},{"Electrum",1433},{"Emphorosaur-S",1223},{"Fade",1177},{"Fizzy POP",1059},{"Flashback",631},{"Glitched Paint",1311},{"Golden Coil",497},{"Guardian",257},{"Hot Rod",445},{"Hyper Beast",430},{"Icarus Fell",440},{"Imminent Danger",1073},{"Knight",326},{"Leaded Glass",681},{"Liquidation",1340},{"Master Piece",321},{"Mecha Industries",587},{"Moss Quartz",862},{"Mud-Spec",1243},{"Night Terror",1130},{"Nightmare",714},{"Nitro",254},{"Party Animal",1376},{"Player Two",946},{"Printstream",984},{"Rose Hex",1319},{"Solitude",1338},{"Stratosphere",1216},{"Vaporwave",106},{"VariCamo",235},{"Wash me plz",160},{"Welcome to the Jungle",1001},{"Fatal Glitch",1476}},
  [61]={{"27",115},{"Alpine Camo",830},{"Ancient Visions",1031},{"Black Lotus",1102},{"Bleeding Edge",1323},{"Blood Tiger",217},{"Blueprint",657},{"Business Class",364},{"Caiman",339},{"Check Engine",796},{"Cortex",705},{"Cyrex",637},{"Dark Water",60},{"Desert Tactical",1253},{"Flashback",817},{"Forest Leaves",25},{"Guardian",290},{"Jawbreaker",1173},{"Kill Confirmed",504},{"Lead Conduit",540},{"Monster Mashup",991},{"Neo-Noir",653},{"Night Ops",236},{"Orange Anolis",922},{"Orion",313},{"Overgrowth",183},{"Para Green",454},{"Pathfinder",443},{"PC-GRN",1186},{"Printstream",1142},{"Purple DDPAT",818},{"Road Rash",318},{"Royal Blue",332},{"Royal Guard",1217},{"Serum",221},{"Silent Shot",1431},{"Sleeping Potion",1377},{"Stainless",277},{"Target Acquired",1027},{"The Traitor",1040},{"Ticket to Hell",1136},{"Torque",489},{"Tropical Breeze",1284},{"Whiteout",1065},{"Spiral Glitch",1451}},
  [63]={{"Army Sheen",298},{"Chalice",325},{"Circaetus",1036},{"Copper Fiber",1195},{"Crimson Web",12},{"Distressed",944},{"Eco",709},{"Emerald",453},{"Emerald Quartz",859},{"Framework",1076},{"Green Plaid",366},{"Hexane",218},{"Honey Paisley",1390},{"Imprint",602},{"Indigo",333},{"Jungle Dashed",147},{"Midnight Palm",933},{"Nitro",322},{"Pink Pearl",1329},{"Poison Dart",315},{"Pole Position",435},{"Polymer",622},{"Red Astor",543},{"Silver",32},{"Slalom",937},{"Syndicate",1064},{"Tacticat",687},{"The Fuschia Is Now",269},{"Tigris",350},{"Tread Plate",268},{"Tuxedo",297},{"Twist",334},{"Vendetta",976},{"Victoria",270},{"Xiangliu",643},{"Yellow Jacket",476},{"Hydraulics",1443}},
  [64]={{"Amber Fade",523},{"Banana Cannon",1232},{"Blaze",37},{"Bone Forged",952},{"Bone Mask",27},{"Canal Spray",866},{"Cobalt Grip",1276},{"Crazy 8",1145},{"Crimson Web",12},{"Dark Chamber",1363},{"Desert Brush",924},{"Fade",522},{"Grip",701},{"Inlay",1237},{"Junk Yard",1047},{"Leafhopper",1293},{"Llama Cannon",683},{"Mauve Aside",1389},{"Memento",892},{"Night",40},{"Nitro",798},{"Phoenix Marker",1011},{"Reboot",595},{"Skull Crusher",843},{"Survivalist",721},{"Tango",123},{"Monarch",1445}},
  [500]={{"Autotronic",573},{"Black Laminate",563},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",578},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",580},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",558},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [503]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Fade",38},{"Forest DDPAT",5},{"Night Stripe",735},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Urban Masked",143}},
  [505]={{"Autotronic",574},{"Black Laminate",564},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",578},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",580},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",559},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [506]={{"Autotronic",575},{"Black Laminate",565},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",578},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",580},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",560},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [507]={{"Autotronic",576},{"Black Laminate",566},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",578},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",582},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",561},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [508]={{"Autotronic",577},{"Black Laminate",567},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",579},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",411},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",581},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",562},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [509]={{"Autotronic",1117},{"Black Laminate",1112},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",579},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",411},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",581},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",1107},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",620},{"Urban Masked",143}},
  [512]={{"Autotronic",1116},{"Black Laminate",1111},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",579},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",411},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",581},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",1106},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",621},{"Urban Masked",143}},
  [514]={{"Autotronic",1114},{"Black Laminate",1109},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",579},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",411},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Freehand",581},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",1104},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [515]={{"Autotronic",1115},{"Black Laminate",1110},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",579},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",411},{"Doppler",617},{"Doppler",418},{"Doppler",618},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",619},{"Fade",38},{"Forest DDPAT",5},{"Freehand",581},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",1105},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [516]={{"Autotronic",1118},{"Black Laminate",1113},{"Blue Steel",42},{"Boreal Forest",77},{"Bright Water",579},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",411},{"Doppler",617},{"Doppler",418},{"Doppler",618},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",619},{"Fade",38},{"Forest DDPAT",5},{"Freehand",581},{"Gamma Doppler",568},{"Gamma Doppler",569},{"Gamma Doppler",570},{"Gamma Doppler",571},{"Gamma Doppler",572},{"Lore",1108},{"Marble Fade",413},{"Night",40},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [517]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",621},{"Urban Masked",143}},
  [518]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [519]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",857},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [520]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",857},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [521]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [522]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",857},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [523]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",858},{"Doppler",417},{"Doppler",852},{"Doppler",853},{"Doppler",854},{"Doppler",855},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",856},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [525]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Damascus Steel",410},{"Doppler",417},{"Doppler",418},{"Doppler",419},{"Doppler",420},{"Doppler",421},{"Doppler",415},{"Doppler",416},{"Fade",38},{"Forest DDPAT",5},{"Marble Fade",413},{"Night Stripe",735},{"Rust Coat",414},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Tiger Tooth",409},{"Ultraviolet",98},{"Urban Masked",143}},
  [526]={{"Blue Steel",42},{"Boreal Forest",77},{"Case Hardened",44},{"Crimson Web",12},{"Fade",38},{"Forest DDPAT",5},{"Night Stripe",735},{"Safari Mesh",72},{"Scorched",175},{"Slaughter",59},{"Stained",43},{"Urban Masked",143}},
  [4725]={{"Jade",10085},{"Needle Point",10087},{"Unhinged",10088},{"Yellow-banded",10086}},
  [5027]={{"Bronzed",10008},{"Charred",10006},{"Guerrilla",10039},{"Snakebite",10007}},
  [5030]={{"Amphibious",10045},{"Arid",10019},{"Big Game",10074},{"Blaze",1407},{"Bronze Morph",10046},{"Creme Pinstripe",1408},{"Frosty",1406},{"Hedge Maze",10038},{"Nocts",10076},{"Occult",1417},{"Omega",10047},{"Pandora's Box",10037},{"Red Racer",1409},{"Scarlet Shamagh",10075},{"Slingshot",10073},{"Superconductor",10018},{"Ultra Violent",1410},{"Vice",10048},{"Violet Beadwork",1405}},
  [5031]={{"Black Tie",10072},{"Brocade Crane",1399},{"Brocade Flowers",1400},{"Convoy",10015},{"Crimson Weave",10016},{"Diamondback",10040},{"Dragon Fists",1401},{"Garden",1402},{"Hand Sweaters",1439},{"Imperial Plaid",10042},{"King Snake",10041},{"Lunar Weave",10013},{"Overtake",10043},{"Plum Quill",1412},{"Queen Jaguar",10071},{"Racing Green",10044},{"Rezan the Red",10069},{"Seigaiha",1404},{"Snow Leopard",10070},{"Wave Chaser",1398}},
  [5032]={{"Arboreal",10056},{"Badlands",10036},{"CAUTION!",10084},{"Cobalt Skulls",10053},{"Constrictor",10083},{"Desert Shamagh",10081},{"Duct Tape",10055},{"Giraffe",10082},{"Leather",10009},{"Overprint",10054},{"Slaughter",10021},{"Spruce DDPAT",10010}},
  [5033]={{"3rd Commando Company",10080},{"Blood Pressure",10079},{"Boom!",10027},{"Cool Mint",10028},{"Eclipse",10024},{"Finish Line",10077},{"Polygon",10052},{"POW!",10049},{"Smoke Out",10078},{"Spearmint",10026},{"Transport",10051},{"Turtle",10050}},
  [5034]={{"Big Swell",1437},{"Blackbook",1414},{"Buckshot",10062},{"Chocolate Chesterfield",1415},{"Cloud Chaser",1440},{"Crimson Kimono",10033},{"Crimson Web",10061},{"Emerald Web",10034},{"Fade",10063},{"Field Agent",10068},{"Forest DDPAT",10030},{"Foundation",10035},{"Lime Polycam",1413},{"Lt. Commander",10066},{"Marble Fade",10065},{"Mogul",10064},{"Pillow Punchers",1438},{"Sunburst",1416},{"Tiger Strike",10067}},
  [5035]={{"Case Hardened",10060},{"Emerald",10057},{"Mangrove",10058},{"Rattler",10059}},
}

local SKIN_AGENTS = {
    { name = "1st Lieutenant Farlow | SWAT", team = "CT", def = 4712, path = "agents/models/ctm_swat/ctm_swat_variantf.vmdl" },
    { name = "3rd Commando Company | KSK", team = "CT", def = 5400, path = "agents/models/ctm_st6/ctm_st6_variantk.vmdl" },
    { name = "Aspirant | Gendarmerie Nationale", team = "CT", def = 4752, path = "agents/models/ctm_gendarmerie/ctm_gendarmerie_variantd.vmdl" },
    { name = "B Squadron Officer | SAS", team = "CT", def = 5601, path = "agents/models/ctm_sas/ctm_sas_variantf.vmdl" },
    { name = "Bio-Haz Specialist | SWAT", team = "CT", def = 4714, path = "agents/models/ctm_swat/ctm_swat_varianth.vmdl" },
    { name = "'Blueberries' Buckshot | NSWC SEAL", team = "CT", def = 4619, path = "agents/models/ctm_st6/ctm_st6_variantj.vmdl" },
    { name = "Buckshot | NSWC SEAL", team = "CT", def = 5402, path = "agents/models/ctm_st6/ctm_st6_variantg.vmdl" },
    { name = "Chef d'Escadron Rouchard | Gendarmerie Nationale", team = "CT", def = 4751, path = "agents/models/ctm_gendarmerie/ctm_gendarmerie_variantc.vmdl" },
    { name = "Chem-Haz Capitaine | Gendarmerie Nationale", team = "CT", def = 4750, path = "agents/models/ctm_gendarmerie/ctm_gendarmerie_variantb.vmdl" },
    { name = "Chem-Haz Specialist | SWAT", team = "CT", def = 4716, path = "agents/models/ctm_swat/ctm_swat_variantj.vmdl" },
    { name = "Cmdr. Davida 'Goggles' Fernandez | SEAL Frogman", team = "CT", def = 4757, path = "agents/models/ctm_diver/ctm_diver_varianta.vmdl" },
    { name = "Cmdr. Frank 'Wet Sox' Baroud | SEAL Frogman", team = "CT", def = 4771, path = "agents/models/ctm_diver/ctm_diver_variantb.vmdl" },
    { name = "Cmdr. Mae 'Dead Cold' Jamison | SWAT", team = "CT", def = 4711, path = "agents/models/ctm_swat/ctm_swat_variante.vmdl" },
    { name = "D Squadron Officer | NZSAS", team = "CT", def = 5602, path = "agents/models/ctm_sas/ctm_sas_variantg.vmdl" },
    { name = "John 'Van Healen' Kask | SWAT", team = "CT", def = 4713, path = "agents/models/ctm_swat/ctm_swat_variantg.vmdl" },
    { name = "Lieutenant Rex Krikey | SEAL Frogman", team = "CT", def = 4772, path = "agents/models/ctm_diver/ctm_diver_variantc.vmdl" },
    { name = "Lieutenant 'Tree Hugger' Farlow | SWAT", team = "CT", def = 4756, path = "agents/models/ctm_swat/ctm_swat_variantk.vmdl" },
    { name = "Lt. Commander Ricksaw | NSWC SEAL", team = "CT", def = 5404, path = "agents/models/ctm_st6/ctm_st6_varianti.vmdl" },
    { name = "Markus Delrow | FBI HRT", team = "CT", def = 5306, path = "agents/models/ctm_fbi/ctm_fbi_variantg.vmdl" },
    { name = "Michael Syfers | FBI Sniper", team = "CT", def = 5307, path = "agents/models/ctm_fbi/ctm_fbi_varianth.vmdl" },
    { name = "Officer Jacques Beltram | Gendarmerie Nationale", team = "CT", def = 4753, path = "agents/models/ctm_gendarmerie/ctm_gendarmerie_variante.vmdl" },
    { name = "Operator | FBI SWAT", team = "CT", def = 5305, path = "agents/models/ctm_fbi/ctm_fbi_variantf.vmdl" },
    { name = "Primeiro Tenente | Brazilian 1st Battalion", team = "CT", def = 5405, path = "agents/models/ctm_st6/ctm_st6_variantn.vmdl" },
    { name = "Seal Team 6 Soldier | NSWC SEAL", team = "CT", def = 5401, path = "agents/models/ctm_st6/ctm_st6_variante.vmdl" },
    { name = "Sergeant Bombson | SWAT", team = "CT", def = 4715, path = "agents/models/ctm_swat/ctm_swat_varianti.vmdl" },
    { name = "Sous-Lieutenant Medic | Gendarmerie Nationale", team = "CT", def = 4749, path = "agents/models/ctm_gendarmerie/ctm_gendarmerie_varianta.vmdl" },
    { name = "Special Agent Ava | FBI", team = "CT", def = 5308, path = "agents/models/ctm_fbi/ctm_fbi_variantb.vmdl" },
    { name = "'Two Times' McCoy | TACP Cavalry", team = "CT", def = 4680, path = "agents/models/ctm_st6/ctm_st6_variantl.vmdl" },
    { name = "'Two Times' McCoy | USAF TACP", team = "CT", def = 5403, path = "agents/models/ctm_st6/ctm_st6_variantm.vmdl" },
    { name = "Arno The Overgrown | Guerrilla Warfare", team = "T", def = 4775, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variantc.vmdl" },
    { name = "Blackwolf | Sabre", team = "T", def = 5503, path = "agents/models/tm_balkan/tm_balkan_variantj.vmdl" },
    { name = "Bloody Darryl The Strapped | The Professionals", team = "T", def = 4613, path = "agents/models/tm_professional/tm_professional_varf5.vmdl" },
    { name = "Col. Mangos Dabisi | Guerrilla Warfare", team = "T", def = 4776, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variantd.vmdl" },
    { name = "Crasswater The Forgotten | Guerrilla Warfare", team = "T", def = 4774, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variantb.vmdl" },
    { name = "Dragomir | Sabre", team = "T", def = 5500, path = "agents/models/tm_balkan/tm_balkan_variantf.vmdl" },
    { name = "Dragomir | Sabre Footsoldier", team = "T", def = 5505, path = "agents/models/tm_balkan/tm_balkan_variantl.vmdl" },
    { name = "Elite Trapper Solman | Guerrilla Warfare", team = "T", def = 4773, path = "agents/models/tm_jungle_raider/tm_jungle_raider_varianta.vmdl" },
    { name = "Enforcer | Phoenix", team = "T", def = 5206, path = "agents/models/tm_phoenix/tm_phoenix_variantf.vmdl" },
    { name = "Getaway Sally | The Professionals", team = "T", def = 4730, path = "agents/models/tm_professional/tm_professional_varj.vmdl" },
    { name = "Ground Rebel | Elite Crew", team = "T", def = 5105, path = "agents/models/tm_leet/tm_leet_variantg.vmdl" },
    { name = "Jungle Rebel | Elite Crew", team = "T", def = 5109, path = "agents/models/tm_leet/tm_leet_variantj.vmdl" },
    { name = "Little Kev | The Professionals", team = "T", def = 4728, path = "agents/models/tm_professional/tm_professional_varh.vmdl" },
    { name = "Maximus | Sabre", team = "T", def = 5501, path = "agents/models/tm_balkan/tm_balkan_varianti.vmdl" },
    { name = "'Medium Rare' Crasswater | Guerrilla Warfare", team = "T", def = 4780, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variantb2.vmdl" },
    { name = "Number K | The Professionals", team = "T", def = 4732, path = "agents/models/tm_professional/tm_professional_vari.vmdl" },
    { name = "Osiris | Elite Crew", team = "T", def = 5106, path = "agents/models/tm_leet/tm_leet_varianth.vmdl" },
    { name = "Prof. Shahmat | Elite Crew", team = "T", def = 5107, path = "agents/models/tm_leet/tm_leet_varianti.vmdl" },
    { name = "Rezan The Ready | Sabre", team = "T", def = 5502, path = "agents/models/tm_balkan/tm_balkan_variantg.vmdl" },
    { name = "Rezan the Redshirt | Sabre", team = "T", def = 4718, path = "agents/models/tm_balkan/tm_balkan_variantk.vmdl" },
    { name = "Safecracker Voltzmann | The Professionals", team = "T", def = 4727, path = "agents/models/tm_professional/tm_professional_varg.vmdl" },
    { name = "Sir Bloody Darryl Royale | The Professionals", team = "T", def = 4735, path = "agents/models/tm_professional/tm_professional_varf3.vmdl" },
    { name = "Sir Bloody Loudmouth Darryl | The Professionals", team = "T", def = 4736, path = "agents/models/tm_professional/tm_professional_varf4.vmdl" },
    { name = "Sir Bloody Miami Darryl | The Professionals", team = "T", def = 4726, path = "agents/models/tm_professional/tm_professional_varf.vmdl" },
    { name = "Sir Bloody Silent Darryl | The Professionals", team = "T", def = 4733, path = "agents/models/tm_professional/tm_professional_varf1.vmdl" },
    { name = "Sir Bloody Skullhead Darryl | The Professionals", team = "T", def = 4734, path = "agents/models/tm_professional/tm_professional_varf2.vmdl" },
    { name = "Slingshot | Phoenix", team = "T", def = 5207, path = "agents/models/tm_phoenix/tm_phoenix_variantg.vmdl" },
    { name = "Soldier | Phoenix", team = "T", def = 5205, path = "agents/models/tm_phoenix/tm_phoenix_varianth.vmdl" },
    { name = "Street Soldier | Phoenix", team = "T", def = 5208, path = "agents/models/tm_phoenix/tm_phoenix_varianti.vmdl" },
    { name = "'The Doctor' Romanov | Sabre", team = "T", def = 5504, path = "agents/models/tm_balkan/tm_balkan_varianth.vmdl" },
    { name = "The Elite Mr. Muhlik | Elite Crew", team = "T", def = 5108, path = "agents/models/tm_leet/tm_leet_variantf.vmdl" },
    { name = "Trapper | Guerrilla Warfare", team = "T", def = 4781, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variantf2.vmdl" },
    { name = "Trapper Aggressor | Guerrilla Warfare", team = "T", def = 4778, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variantf.vmdl" },
    { name = "Vypa Sista of the Revolution | Guerrilla Warfare", team = "T", def = 4777, path = "agents/models/tm_jungle_raider/tm_jungle_raider_variante.vmdl" },
}

local TEAMS = { "CT", "T" }

local SKIN_KNIFE_NAMES, SKIN_GLOVE_NAMES = {}, {}
for i = 1, #SKIN_KNIVES do SKIN_KNIFE_NAMES[i] = SKIN_KNIVES[i].name end
for i = 1, #SKIN_GLOVES do SKIN_GLOVE_NAMES[i] = SKIN_GLOVES[i].name end

local SKIN_WEAPON_NAMES, knownWeaponDefs = {}, {}
for i = 1, #SKIN_WEAPONS do
    SKIN_WEAPON_NAMES[i] = SKIN_WEAPONS[i].name
    knownWeaponDefs[SKIN_WEAPONS[i].def] = true
end

local agentsByTeam, agentNamesByTeam = { CT = {}, T = {} }, { CT = {}, T = {} }
for _, team in ipairs(TEAMS) do agentNamesByTeam[team][1] = "None" end
for i = 1, #SKIN_AGENTS do
    local a = SKIN_AGENTS[i]
    local list, names = agentsByTeam[a.team], agentNamesByTeam[a.team]
    if list then
        list[#list + 1] = a
        names[#names + 1] = a.name
    end
end

local function isKnifeDef(def)
    return def == 42 or def == 59 or (def >= 500 and def <= 526)
end

local paintCache = {}
local function paintListFor(def)
    if not def then return { "Default" }, { 0 } end
    local hit = paintCache[def]
    if hit then return hit.names, hit.ids end
    local names, ids = { "Default" }, { 0 }
    local src = SKIN_PAINTS[def]
    if src then
        for i = 1, #src do
            names[i + 1] = src[i][1]
            ids[i + 1] = src[i][2]
        end
    end
    paintCache[def] = { names = names, ids = ids }
    return names, ids
end

local function ensurePaintInList(def, paintId, label)
    paintId = tonumber(paintId) or 0
    if not def or paintId <= 0 then return paintListFor(def) end
    local names, ids = paintListFor(def)
    for i = 1, #ids do
        if ids[i] == paintId then return names, ids end
    end
    local hit = paintCache[def]
    local name = label or ("Paint " .. tostring(paintId))
    hit.names[#hit.names + 1] = name
    hit.ids[#hit.ids + 1] = paintId
    return hit.names, hit.ids
end

local function paintIndexOf(def, paintId)
    local _, ids = paintListFor(def)
    paintId = tonumber(paintId) or 0
    for i = 1, #ids do
        if ids[i] == paintId then return i end
    end
    if paintId > 0 then
        ensurePaintInList(def, paintId)
        _, ids = paintListFor(def)
        for i = 1, #ids do
            if ids[i] == paintId then return i end
        end
    end
    return 1
end

local function paintNameFor(def, paintId)
    local names, ids = paintListFor(def)
    for i = 1, #ids do
        if ids[i] == paintId then return names[i] end
    end
    if paintId and paintId > 0 then return "Paint " .. tostring(paintId) end
    return "Default"
end

local knownGloveDefs = {}
for i = 1, #SKIN_GLOVES do
    local d = SKIN_GLOVES[i].def
    if d and d > 0 then knownGloveDefs[d] = true end
end

local function isGloveDef(def)
    return def ~= nil and knownGloveDefs[def] == true
end

local function cloneInspectStickers(list)
    local out = {}
    for i = 1, #(list or {}) do
        local s = list[i]
        out[#out + 1] = {
            slot = tonumber(s.slot) or 0,
            id = tonumber(s.sticker_id or s.id) or 0,
            wear = tonumber(s.wear) or 0,
            scale = tonumber(s.scale) or 1,
            rotation = tonumber(s.rotation) or 0,
            offset_x = s.offset_x,
            offset_y = s.offset_y,
        }
    end
    return out
end

local function cloneInspectKeychains(list)
    local out = {}
    for i = 1, #(list or {}) do
        local s = list[i]
        local wrapped = tonumber(s.wrapped_sticker or s.paint_kit or s.wrapped)
        out[#out + 1] = {
            slot = tonumber(s.slot) or 0,
            id = tonumber(s.sticker_id or s.id) or 0,
            offset_x = s.offset_x,
            offset_y = s.offset_y,
            offset_z = s.offset_z,
            pattern = s.pattern,
            wrapped_sticker = (wrapped and wrapped > 0) and wrapped or nil,
            highlight_reel = s.highlight_reel,
        }
    end
    return out
end

local function encodeTagName(name)
    return (tostring(name or ""):gsub("([^%w%s%_%.'%-])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+"))
end

local function decodeTagName(body)
    return (tostring(body or ""):gsub("%+", " "):gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16) or 32)
    end))
end

local function inspectResolveTagName(data)
    if not data then return nil end
    local tag = data.customname
    if type(tag) == "string" then
        tag = tag:gsub("^%s+", ""):gsub("%s+$", "")
        if tag ~= "" then return tag end
    end
    local weapon = data.weapon
    local finish = paintNameFor(data.defindex, data.paintindex)
    if finish == "Default" or (finish and finish:match("^Paint ")) then finish = nil end
    if weapon and finish then return weapon .. " | " .. finish end
    return weapon or finish
end

local function encodeDecorSuffix(e)
    local parts = {}
    if e and e.name and e.name ~= "" then
        parts[#parts + 1] = "~n" .. encodeTagName(e.name)
    end
    for _, s in ipairs((e and e.stickers) or {}) do
        parts[#parts + 1] = string.format(
            "~s%d:%d:%.4f:%.4f:%.4f:%.4f:%.4f",
            s.slot or 0, s.id or 0, s.wear or 0, s.scale or 1, s.rotation or 0,
            tonumber(s.offset_x) or 0, tonumber(s.offset_y) or 0
        )
    end
    for _, k in ipairs((e and e.keychains) or {}) do
        local wrapped = tonumber(k.wrapped_sticker or k.paint_kit) or 0
        if wrapped > 0 then
            parts[#parts + 1] = string.format(
                "~k%d:%d:%.4f:%.4f:%.4f:%d:%d",
                k.slot or 0, k.id or 0,
                tonumber(k.offset_x) or 0, tonumber(k.offset_y) or 0, tonumber(k.offset_z) or 0,
                tonumber(k.pattern) or 0, wrapped
            )
        else
            parts[#parts + 1] = string.format(
                "~k%d:%d:%.4f:%.4f:%.4f:%d",
                k.slot or 0, k.id or 0,
                tonumber(k.offset_x) or 0, tonumber(k.offset_y) or 0, tonumber(k.offset_z) or 0,
                tonumber(k.pattern) or 0
            )
        end
    end
    return table.concat(parts)
end

local function parseDecorSuffix(suffix, into)
    into.stickers, into.keychains = {}, {}
    for kind, body in tostring(suffix or ""):gmatch("~([skn])([^~]*)") do
        if kind == "n" then
            local name = decodeTagName(body)
            if name ~= "" then into.name = name end
        elseif kind == "s" then
            local slot, id, wear, scale, rot, ox, oy = body:match(
                "^(%d+):(%d+):([%-%d%.]+):([%-%d%.]+):([%-%d%.]+):([%-%d%.]+):([%-%d%.]+)$"
            )
            if slot then
                into.stickers[#into.stickers + 1] = {
                    slot = tonumber(slot), id = tonumber(id),
                    wear = tonumber(wear) or 0, scale = tonumber(scale) or 1,
                    rotation = tonumber(rot) or 0,
                    offset_x = tonumber(ox), offset_y = tonumber(oy),
                }
            end
        else
            local slot, id, ox, oy, oz, pattern, wrapped = body:match(
                "^(%d+):(%d+):([%-%d%.]+):([%-%d%.]+):([%-%d%.]+):(%d+):(%d+)$"
            )
            if not slot then
                slot, id, ox, oy, oz, pattern = body:match(
                    "^(%d+):(%d+):([%-%d%.]+):([%-%d%.]+):([%-%d%.]+):(%d+)$"
                )
            end
            if slot then
                local kc = {
                    slot = tonumber(slot), id = tonumber(id),
                    offset_x = tonumber(ox), offset_y = tonumber(oy), offset_z = tonumber(oz),
                    pattern = tonumber(pattern),
                }
                local w = tonumber(wrapped)
                if w and w > 0 then kc.wrapped_sticker = w end
                into.keychains[#into.keychains + 1] = kc
            end
        end
    end
    if #into.stickers == 0 then into.stickers = nil end
    if #into.keychains == 0 then into.keychains = nil end
end

local function decorFingerprint(e)
    local parts = {}
    if e and e.name and e.name ~= "" then parts[#parts + 1] = "n:" .. tostring(e.name) end
    for _, s in ipairs((e and e.stickers) or {}) do
        parts[#parts + 1] = string.format("s%d.%d.%.3f.%.3f",
            s.slot or 0, s.id or 0, tonumber(s.offset_x) or 0, tonumber(s.offset_y) or 0)
    end
    for _, k in ipairs((e and e.keychains) or {}) do
        parts[#parts + 1] = string.format("k%d.%d.%d.%d",
            k.slot or 0, k.id or 0, tonumber(k.pattern) or 0,
            tonumber(k.wrapped_sticker or k.paint_kit) or 0)
    end
    return table.concat(parts, ",")
end

local WeaponSel = { CT = {}, T = {} }

local function emptyTeamSel()
    return {
        knifeDef = nil,
        knife = { paint = 0, wear = 0.01, seed = 0 },
        gloveDef = 0,
        glove = { paint = 0, wear = 0.01, seed = 0 },
        agentPath = nil,
    }
end

local Sel = { CT = emptyTeamSel(), T = emptyTeamSel() }
local SkinOn = false
local Engine = { ready = false, busy = false, status = "not started", lastTry = 0 }

local Diag = { ticks = 0, stage = "loop has not run", items = 0 }

local requestReapply

local SKIN_FILE = "DaizML_skins.txt"

local function weaponEntry(team, def)
    local bag = WeaponSel[team]
    local e = bag[def]
    if not e then
        e = { paint = 0, wear = 0.01, seed = 0 }
        bag[def] = e
    end
    return e
end

local UI = { CT = {}, T = {} }

local SkinImg = {
    BASE_URL = "https://raw.githubusercontent.com/ByMykel/CSGO-API/main/public/api/en/base_weapons.json",
    SKINS_URL = "https://raw.githubusercontent.com/ByMykel/CSGO-API/main/public/api/en/skins.json",
    COLS = 3,
    PAGE = 12,
    catalog = { loaded = false, loading = false, baseUrl = {}, byDefPaint = {} },
    order = {},
    _popupBrowser = nil,
}
LiveStatsPos.SkinImg = SkinImg
M._skinCachePopupOpen = false

local KnifeImg = {
    id = "knife",
    title = "knife",
    DIR = "assets/skins/knives/",
    READY = "assets/skins/knives/_ready.txt",
    subDir = "knives",
    step = 1,
    page = 1,
    teamMode = 1,
    def = nil,
    paint = 0,
    wear = 0.01,
    seed = 0,
    paintName = "Default",
    modelName = "Default (no swap)",
    ready = false,
    indexing = false,
    downloading = false,
    queue = {},
    qIndex = 1,
    tex = {},
    texOrder = {},
    texMax = 36,
    status = "idle",
    detail = "",
    _started = false,
    _fail = 0,
    _httpBusy = false,
    _waitStart = nil,
    _sliderGen = 0,
}
local WeaponImg = {
    id = "weapon",
    title = "weapon",
    DIR = "assets/skins/weapons/",
    READY = "assets/skins/weapons/_ready.txt",
    subDir = "weapons",
    step = 1,
    page = 1,
    teamMode = 1,
    def = nil,
    paint = 0,
    wear = 0.01,
    seed = 0,
    paintName = "Default",
    modelName = "AK-47",
    catKey = nil,
    catName = nil,
    ready = false,
    indexing = false,
    downloading = false,
    queue = {},
    qIndex = 1,
    tex = {},
    texOrder = {},
    texMax = 36,
    status = "idle",
    detail = "",
    _started = false,
    _fail = 0,
    _httpBusy = false,
    _waitStart = nil,
    _sliderGen = 0,
}
local GloveImg = {
    id = "glove",
    title = "glove",
    DIR = "assets/skins/gloves/",
    READY = "assets/skins/gloves/_ready.txt",
    subDir = "gloves",
    step = 1,
    page = 1,
    teamMode = 1,
    def = nil,
    paint = 0,
    wear = 0.01,
    seed = 0,
    paintName = "Default",
    modelName = "Default (off)",
    ready = false,
    indexing = false,
    downloading = false,
    queue = {},
    qIndex = 1,
    tex = {},
    texOrder = {},
    texMax = 36,
    status = "idle",
    detail = "",
    _started = false,
    _fail = 0,
    _httpBusy = false,
    _waitStart = nil,
    _sliderGen = 0,
}
local AgentImg = {
    id = "agent",
    title = "agent",
    DIR = "assets/skins/agents/",
    READY = "assets/skins/agents/_ready.txt",
    subDir = "agents",
    AGENTS_URL = "https://raw.githubusercontent.com/ByMykel/CSGO-API/main/public/api/en/agents.json",
    step = 1,
    page = 1,
    teamPick = nil,
    path = nil,
    def = nil,
    modelName = "None",
    byDef = {},
    ready = false,
    indexing = false,
    downloading = false,
    queue = {},
    qIndex = 1,
    tex = {},
    texOrder = {},
    texMax = 48,
    status = "idle",
    detail = "",
    _started = false,
    _fail = 0,
    _httpBusy = false,
    _waitStart = nil,
}

LiveStatsPos.KnifeImg = KnifeImg
LiveStatsPos.WeaponImg = WeaponImg
LiveStatsPos.GloveImg = GloveImg
LiveStatsPos.AgentImg = AgentImg
SkinImg.order = { KnifeImg, WeaponImg, GloveImg, AgentImg }

do
    local DEF_SETS = { knife = {}, weapon = {}, glove = {}, agent = {} }
    for i = 1, #SKIN_KNIVES do
        local d = SKIN_KNIVES[i].def
        if d then DEF_SETS.knife[d] = true end
    end
    for i = 1, #SKIN_WEAPONS do
        DEF_SETS.weapon[SKIN_WEAPONS[i].def] = true
    end
    for i = 1, #SKIN_GLOVES do
        local d = SKIN_GLOVES[i].def
        if d and d > 0 then DEF_SETS.glove[d] = true end
    end
    for i = 1, #SKIN_AGENTS do
        local d = SKIN_AGENTS[i].def
        if d then DEF_SETS.agent[d] = true end
    end

    local ALL_DEFS = {}
    for id, set in pairs(DEF_SETS) do
        if id ~= "agent" then
            for d in pairs(set) do ALL_DEFS[d] = true end
        end
    end

    local AGENT_TEAM_ICON = { CT = 5308, T = 4613 } 

    local function siPath(B, def, paint)
        if B.id == "agent" then
            if not def or def == 0 then return B.DIR .. "none.dat" end
            return B.DIR .. tostring(def) .. ".dat"
        end
        if not def or def == 0 then return B.DIR .. "default.dat" end
        if not paint or paint <= 0 then
            return B.DIR .. tostring(def) .. "_base.dat"
        end
        return B.DIR .. tostring(def) .. "_" .. tostring(paint) .. ".dat"
    end

    local function siCacheReadyOnDisk(B)
        local raw = fileRead(B.READY)
        if type(raw) ~= "string" or #raw < 4 then return false end
        if not raw:find("ok=", 1, true) then return false end
        return true
    end

    local function siEnsureDirs(B)
        pcall(function()
            if file and file.CreateDirectory then
                file.CreateDirectory("assets")
                file.CreateDirectory("assets/skins")
                file.CreateDirectory("assets/skins/" .. tostring(B.subDir))
            end
        end)
    end

    local function siHttpGet(url, cb)
        if type(http) ~= "table" or type(http.Get) ~= "function" then
            if cb then cb(nil) end
            return
        end
        local ok = pcall(function()
            http.Get(url, function(body)
                if cb then cb(body) end
            end)
        end)
        if not ok then
            local body
            pcall(function() body = http.Get(url) end)
            if cb then cb(body) end
        end
    end

    local function siMarkReady(B, n)
        siEnsureDirs(B)
        fileWrite(B.READY, "ok=1\ncount=" .. tostring(n or 0) .. "\n")
        B.ready = true
        B.downloading = false
        B.status = "ready"
        B.indexing = false
        LiveStatsPos._skinHttpBusy = false
        if SkinImg._popupBrowser == B then
            SkinImg._popupBrowser = nil
            M._skinCachePopupOpen = false
        end
    end

    local function siLoadCatalog(cb)
        local cat = SkinImg.catalog
        if cat.loaded then
            if cb then cb(true) end
            return
        end
        if cat.loading then return end
        cat.loading = true
        LiveStatsPos._skinHttpBusy = true

        siHttpGet(SkinImg.BASE_URL, function(baseBody)
            if type(baseBody) == "string" and #baseBody > 100 then
                for def, img in baseBody:gmatch('"def_index"%s*:%s*(%d+).-"image"%s*:%s*"(https://[^"]+)"') do
                    def = tonumber(def)
                    if def and ALL_DEFS[def] then
                        cat.baseUrl[def] = img
                    end
                end
            end
            siHttpGet(SkinImg.SKINS_URL, function(skinsBody)
                if type(skinsBody) == "string" and #skinsBody > 1000 then
                    local matched = 0
                    for wid, paint, img in skinsBody:gmatch(
                        '"weapon_id"%s*:%s*(%d+).-"paint_index"%s*:%s*"(%d+)".-"legacy_model"%s*:%s*%w+%s*,%s*"image"%s*:%s*"(https://[^"]+)"'
                    ) do
                        wid, paint = tonumber(wid), tonumber(paint)
                        if wid and paint and ALL_DEFS[wid] then
                            cat.byDefPaint[tostring(wid) .. "_" .. tostring(paint)] = img
                            matched = matched + 1
                        end
                    end
                    if matched < 50 then
                        local pos = 1
                        while true do
                            local _, we, wid = skinsBody:find('"weapon_id"%s*:%s*(%d+)', pos)
                            if not we then break end
                            wid = tonumber(wid)
                            local _, pe, paint = skinsBody:find('"paint_index"%s*:%s*"(%d+)"', we)
                            if not pe then
                                pos = we + 1
                            else
                                paint = tonumber(paint)
                                local nextSkin = skinsBody:find('"id"%s*:%s*"skin%-', pe + 1)
                                local chunkEnd = nextSkin or (#skinsBody + 1)
                                local chunk = skinsBody:sub(pe, chunkEnd - 1)
                                local lastImg
                                for img in chunk:gmatch('"image"%s*:%s*"(https://[^"]+)"') do
                                    lastImg = img
                                end
                                if wid and paint and ALL_DEFS[wid] and lastImg then
                                    cat.byDefPaint[tostring(wid) .. "_" .. tostring(paint)] = lastImg
                                end
                                pos = pe + 1
                            end
                        end
                    end
                end
                cat.loaded = true
                cat.loading = false
                LiveStatsPos._skinHttpBusy = false
                if cb then cb(true) end
            end)
        end)
    end

    local function siBuildQueue(B)
        if B.id == "agent" then
            local q = {}
            for def, url in pairs(B.byDef or {}) do
                if DEF_SETS.agent[def] then
                    local path = siPath(B, def, 0)
                    local existing = fileRead(path)
                    if type(existing) ~= "string" or #existing < 64 then
                        q[#q + 1] = { path = path, url = url, key = "agent_" .. tostring(def) }
                    end
                end
            end
            return q
        end
        local cat = SkinImg.catalog
        local set = DEF_SETS[B.id]
        local q = {}
        for def, url in pairs(cat.baseUrl) do
            if set[def] then
                local path = siPath(B, def, 0)
                local existing = fileRead(path)
                if type(existing) ~= "string" or #existing < 64 then
                    q[#q + 1] = { path = path, url = url, key = def .. "_base" }
                end
            end
        end
        for key, url in pairs(cat.byDefPaint) do
            local def, paint = key:match("^(%d+)_(%d+)$")
            def, paint = tonumber(def), tonumber(paint)
            if def and paint and set[def] then
                local path = siPath(B, def, paint)
                local existing = fileRead(path)
                if type(existing) ~= "string" or #existing < 64 then
                    q[#q + 1] = { path = path, url = url, key = key }
                end
            end
        end
        return q
    end

    local function siLoadAgentCatalog(cb)
        if AgentImg._catalogLoaded then
            if cb then cb(true) end
            return
        end
        if AgentImg._catalogLoading then return end
        AgentImg._catalogLoading = true
        LiveStatsPos._skinHttpBusy = true
        AgentImg.detail = "Fetching agent catalog…"
        siHttpGet(AgentImg.AGENTS_URL, function(body)
            AgentImg.byDef = AgentImg.byDef or {}
            if type(body) == "string" and #body > 100 then
                local pos = 1
                while true do
                    local _, de, def = body:find('"def_index"%s*:%s*"?(%d+)"?', pos)
                    if not de then break end
                    def = tonumber(def)
                    local nextId = body:find('"id"%s*:%s*"agent%-', de + 1)
                    local chunkEnd = nextId or (#body + 1)
                    local chunk = body:sub(de, chunkEnd - 1)
                    local lastImg
                    for img in chunk:gmatch('"image"%s*:%s*"(https://[^"]+)"') do
                        lastImg = img
                    end
                    if def and DEF_SETS.agent[def] and lastImg then
                        AgentImg.byDef[def] = lastImg
                    end
                    pos = de + 1
                end
            end
            AgentImg._catalogLoaded = true
            AgentImg._catalogLoading = false
            LiveStatsPos._skinHttpBusy = false
            if cb then cb(true) end
        end)
    end

    local function siStartCache(B)
        if B.indexing or B.downloading or B.ready then return end
        B.indexing = true
        B.status = "indexing"
        B.detail = "Fetching " .. B.title .. " catalog…"
        SkinImg._popupBrowser = B
        M._skinCachePopupOpen = true
        LiveStatsPos._skinHttpBusy = true

        local function afterCatalog()
            B.indexing = false
            local q = siBuildQueue(B)
            B.queue = q
            B.qIndex = 1
            if #q == 0 then
                siMarkReady(B, 0)
                return
            end
            B.downloading = true
            B.status = "downloading"
            B.detail = string.format("0 / %d", #q)
            SkinImg._popupBrowser = B
            M._skinCachePopupOpen = true
        end

        if B.id == "agent" then
            siLoadAgentCatalog(afterCatalog)
        else
            siLoadCatalog(afterCatalog)
        end
    end

    local function siPumpDownload(B)
        if not B.downloading then return end
        if LiveStatsPos._avatarHttpBusy then return end
        if B._httpBusy then return end
        local q = B.queue
        local i = B.qIndex or 1
        if i > #q then
            siMarkReady(B, #q)
            M:Notify(B.title .. " images cached", "success")
            return
        end
        local job = q[i]
        B.detail = string.format("%d / %d  %s", i - 1, #q, tostring(job.key or ""))
        B._httpBusy = true
        LiveStatsPos._skinHttpBusy = true
        SkinImg._popupBrowser = B
        M._skinCachePopupOpen = true
        siHttpGet(job.url, function(body)
            B._httpBusy = false
            if type(body) == "string" and #body > 64 then
                siEnsureDirs(B)
                pcall(fileWrite, job.path, body)
            else
                B._fail = (B._fail or 0) + 1
            end
            B.qIndex = i + 1
            B.detail = string.format("%d / %d", i, #q)
            if B.qIndex > #q then
                siMarkReady(B, #q)
                M:Notify(B.title .. " images cached", "success")
            end
        end)
    end

    local function siTexEvict(B)
        while #B.texOrder > B.texMax do
            local old = table.remove(B.texOrder, 1)
            local info = B.tex[old]
            if info and info.tex then
                pcall(function()
                    if draw.DeleteTexture then draw.DeleteTexture(info.tex) end
                end)
            end
            B.tex[old] = nil
        end
    end

    local function siDecode(body)
        if type(body) ~= "string" or #body < 32 then return nil end
        local rgba, w, h
        pcall(function()
            if common.DecodePNG then rgba, w, h = common.DecodePNG(body) end
        end)
        if not (rgba and w and h and w > 0) then
            rgba, w, h = nil, nil, nil
            pcall(function()
                if common.DecodeJPEG then rgba, w, h = common.DecodeJPEG(body) end
            end)
        end
        if not (rgba and w and h and w > 0 and h > 0) then return nil end
        local tex
        pcall(function() tex = draw.CreateTexture(rgba, w, h) end)
        if not tex then return nil end
        return { tex = tex, w = w, h = h }
    end

    local function siGetTex(B, def, paint)
        local key = (def and def ~= 0 and (tostring(def) .. "_" .. tostring(paint or 0))) or "default"
        local hit = B.tex[key]
        if hit then
            for i = 1, #B.texOrder do
                if B.texOrder[i] == key then
                    table.remove(B.texOrder, i)
                    break
                end
            end
            B.texOrder[#B.texOrder + 1] = key
            return hit
        end
        local path = siPath(B, def, paint)
        local body = fileRead(path)
        local info = siDecode(body)
        if not info then return nil end
        B.tex[key] = info
        B.texOrder[#B.texOrder + 1] = key
        siTexEvict(B)
        return info
    end

    local function siTeams(mode)
        mode = mode or 1
        if mode == 1 then return { "CT" } end
        if mode == 2 then return { "T" } end
        return { "CT", "T" }
    end

    local WEAPON_CATS = {
        { key = "rifle",  name = "Rifles",  icon = 7  }, 
        { key = "sniper", name = "Snipers", icon = 9  }, 
        { key = "pistol", name = "Pistols", icon = 1  }, 
        { key = "smg",    name = "SMGs",    icon = 34 },
        { key = "heavy",  name = "Heavy",   icon = 28 }, 
    }
    local WEAPON_CAT_OF = {
        [7] = "rifle", [16] = "rifle", [60] = "rifle", [8] = "rifle",
        [10] = "rifle", [13] = "rifle", [39] = "rifle",
        [9] = "sniper", [40] = "sniper", [38] = "sniper", [11] = "sniper",
        [1] = "pistol", [64] = "pistol", [2] = "pistol", [3] = "pistol",
        [4] = "pistol", [30] = "pistol", [32] = "pistol", [36] = "pistol",
        [61] = "pistol", [63] = "pistol",
        [17] = "smg", [19] = "smg", [26] = "smg", [23] = "smg",
        [33] = "smg", [34] = "smg", [24] = "smg",
        [14] = "heavy", [28] = "heavy", [25] = "heavy", [27] = "heavy",
        [35] = "heavy", [29] = "heavy",
    }

    local function siGlovePreviewPaint(def)
        if not def or def == 0 then return 0 end
        local _, ids = paintListFor(def)
        for i = 1, #ids do
            local p = ids[i]
            if p and p > 0 then return p end
        end
        return 0
    end

    local function siModelItems(B)
        local items = {}
        if B.id == "knife" then
            for i = 1, #SKIN_KNIVES do
                local k = SKIN_KNIVES[i]
                items[#items + 1] = { def = k.def, name = k.name }
            end
        elseif B.id == "weapon" then
            local cat = B.catKey
            for i = 1, #SKIN_WEAPONS do
                local k = SKIN_WEAPONS[i]
                if (not cat) or WEAPON_CAT_OF[k.def] == cat then
                    items[#items + 1] = { def = k.def, name = k.name }
                end
            end
        else
            for i = 1, #SKIN_GLOVES do
                local k = SKIN_GLOVES[i]
                local d = k.def
                if d == 0 then d = nil end
                items[#items + 1] = {
                    def = d,
                    name = k.name,
                    previewPaint = d and siGlovePreviewPaint(d) or 0,
                }
            end
        end
        return items
    end

    local function siMaxStep(B)
        if B.id == "weapon" then return 4 end
        return 3
    end

    local function siFinishStep(B)
        if B.id == "weapon" then return 3 end
        return 2
    end

    local function siCustomizeStep(B)
        return siMaxStep(B)
    end

    local function siModelStep(B)
        if B.id == "weapon" then return 2 end
        return 1
    end

    function KnifeImg.resetDraft()
        KnifeImg.step = 1
        KnifeImg.page = 1
        KnifeImg.def = nil
        KnifeImg.paint = 0
        KnifeImg.wear = 0.01
        KnifeImg.seed = 0
        KnifeImg.paintName = "Default"
        KnifeImg.modelName = "Default (no swap)"
        KnifeImg._sliderGen = (KnifeImg._sliderGen or 0) + 1
    end
    function WeaponImg.resetDraft()
        WeaponImg.step = 1
        WeaponImg.page = 1
        WeaponImg.def = nil
        WeaponImg.paint = 0
        WeaponImg.wear = 0.01
        WeaponImg.seed = 0
        WeaponImg.paintName = "Default"
        WeaponImg.modelName = "AK-47"
        WeaponImg.catKey = nil
        WeaponImg.catName = nil
        WeaponImg._sliderGen = (WeaponImg._sliderGen or 0) + 1
    end
    function GloveImg.resetDraft()
        GloveImg.step = 1
        GloveImg.page = 1
        GloveImg.def = nil
        GloveImg.paint = 0
        GloveImg.wear = 0.01
        GloveImg.seed = 0
        GloveImg.paintName = "Default"
        GloveImg.modelName = "Default (off)"
        GloveImg._sliderGen = (GloveImg._sliderGen or 0) + 1
    end
    function AgentImg.resetDraft()
        AgentImg.step = 1
        AgentImg.page = 1
        AgentImg.teamPick = nil
        AgentImg.path = nil
        AgentImg.def = nil
        AgentImg.modelName = "None"
    end

    local function siBack(B)
        local step = B.step or 1
        if step <= 1 then return end
        if B.id == "agent" then
            B.step = 1
            B.teamPick = nil
            B.path = nil
            B.def = nil
            B.modelName = "None"
            B.page = 1
            return
        end
        if B.id == "weapon" then
            if step == 4 then
                if B.def then B.step = 3 else B.step = 2 end
            elseif step == 3 then
                B.step = 2
            elseif step == 2 then
                B.step = 1
                B.catKey = nil
                B.catName = nil
                B.def = nil
            end
            B.page = 1
            return
        end
        if step == 3 then
            if B.def and B.def ~= 0 then
                B.step = 2
            else
                B.step = 1
            end
        elseif step == 2 then
            B.step = 1
        end
        B.page = 1
    end

    function KnifeImg.back() siBack(KnifeImg) end
    function WeaponImg.back() siBack(WeaponImg) end
    function GloveImg.back() siBack(GloveImg) end
    function AgentImg.back() siBack(AgentImg) end
    KnifeImg.cancel = KnifeImg.back
    WeaponImg.cancel = WeaponImg.back
    GloveImg.cancel = GloveImg.back
    AgentImg.cancel = AgentImg.back

    function AgentImg.apply()
        local team = AgentImg.teamPick
        if team ~= "CT" and team ~= "T" then
            M:Notify("pick CT or T first", "error")
            return
        end
        local sel = Sel[team]
        if not sel then
            Sel[team] = emptyTeamSel()
            sel = Sel[team]
        end
        sel.agentPath = AgentImg.path
        if requestReapply then pcall(requestReapply) end
        pcall(function() if SkinSave then SkinSave() end end)
        local label = AgentImg.modelName or "None"
        M:Notify("applied agent " .. label .. " → " .. team, "success")
    end

    local function siTheme()
        local T = (M and M.T) or {}
        return {
            accent = T.accent or { 74, 166, 255 },
            accent_bg = T.accent_bg or { 20, 43, 68, 255 },
            widget = T.widget or { 19, 25, 34, 255 },
            widgethi = T.widgethi or { 26, 36, 48, 255 },
            border = T.border or { 40, 48, 61, 255 },
            text = T.text or { 205, 213, 225, 255 },
            texthi = T.texthi or { 247, 249, 255, 255 },
        }
    end

    local function siLerpC(a, b, t)
        if type(lerpc) == "function" then return lerpc(a, b, t) end
        t = tonumber(t) or 0
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        local out = {
            math.floor((a[1] or 0) + ((b[1] or 0) - (a[1] or 0)) * t + 0.5),
            math.floor((a[2] or 0) + ((b[2] or 0) - (a[2] or 0)) * t + 0.5),
            math.floor((a[3] or 0) + ((b[3] or 0) - (a[3] or 0)) * t + 0.5),
        }
        if a[4] or b[4] then
            out[4] = math.floor((a[4] or 255) + ((b[4] or 255) - (a[4] or 255)) * t + 0.5)
        end
        return out
    end

    local function siApproach(cur, target, speed)
        if type(approach) == "function" then return approach(cur, target, speed) end
        cur = tonumber(cur) or 0
        target = tonumber(target) or 0
        speed = tonumber(speed) or 16
        local dt = 0.016
        pcall(function()
            if globals and globals.FrameTime then dt = globals.FrameTime() or dt end
        end)
        local step = (target - cur) * math.min(1, speed * dt)
        return cur + step
    end

    local function siDrawTex(info, x, y, boxW, boxH)
        if not (info and info.tex) then return false end
        local iw = tonumber(info.w) or boxW
        local ih = tonumber(info.h) or boxH
        if iw < 1 then iw = boxW end
        if ih < 1 then ih = boxH end
        local scale = math.min(boxW / iw, boxH / ih)
        local dw = iw * scale
        local dh = ih * scale
        local ox = x + (boxW - dw) * 0.5
        local oy = y + (boxH - dh) * 0.5
        pcall(function()
            draw.Color(255, 255, 255, 255)
            draw.SetTexture(info.tex)
            draw.FilledRect(math.floor(ox), math.floor(oy), math.floor(ox + dw), math.floor(oy + dh))
            draw.SetTexture(nil)
        end)
        return true
    end

    local function siTile(ui, x, y, tw, th, label, info, selected, B, tileId)
        local thm = siTheme()
        local hov = ui.hover(x, y, tw, th)
        local anim = 0
        if B and tileId then
            B._hov = B._hov or {}
            anim = siApproach(B._hov[tileId] or 0, (hov or selected) and 1 or 0, 16)
            B._hov[tileId] = anim
        elseif hov or selected then
            anim = 1
        end
        local bg = siLerpC(thm.widget, thm.widgethi, anim)
        local brd = selected and thm.accent or siLerpC(thm.border, thm.accent, anim * 0.55)
        ui.rbox(x, y, tw, th, 8, bg, brd)
        local pad = 8
        local imgH = th - 30
        ui.rfill(x + pad, y + pad, tw - pad * 2, imgH, 6, { 14, 16, 22 })
        if info then
            siDrawTex(info, x + pad, y + pad, tw - pad * 2, imgH)
        end
        local name = tostring(label or "")
        if #name > 18 then name = name:sub(1, 16) .. "…" end
        local col = siLerpC(thm.text, thm.texthi, anim)
        ui.text(x + 8, y + th - 18, name, col)
        return ui.click(x, y, tw, th)
    end

    local function siButton(ui, B, id, x, y, bw, bh, label, kind)
        kind = kind or "normal"
        local thm = siTheme()
        local hov = ui.hover(x, y, bw, bh)
        B._hov = B._hov or {}
        local target = 0
        if kind == "selected" or hov then target = 1 end
        local anim = siApproach(B._hov[id] or 0, target, 16)
        B._hov[id] = anim

        local fill, brd, col
        if kind == "selected" then
            fill = hov and siLerpC(thm.accent_bg, thm.widgethi, 0.35) or thm.accent_bg
            brd = thm.accent
            col = thm.texthi
        elseif kind == "primary" then
            fill = siLerpC(thm.widget, thm.widgethi, anim)
            brd = siLerpC(thm.border, thm.accent, 0.65 + anim * 0.35)
            col = siLerpC(thm.text, thm.texthi, anim)
        else
            fill = siLerpC(thm.widget, thm.widgethi, anim)
            brd = siLerpC(thm.border, thm.accent, anim * 0.55)
            col = siLerpC(thm.text, thm.texthi, anim)
        end
        ui.rbox(x, y, bw, bh, 6, fill, brd)
        local tw = ui.textw(label)
        ui.text(x + (bw - tw) * 0.5, y + math.floor((bh - 14) * 0.5), label, col)
        return ui.click(x, y, bw, bh)
    end

    local function siNavBar(ui, x, y, w, B, pages, showBack)
        local thm = siTheme()
        pages = math.max(1, pages or 1)
        if B.page > pages then B.page = pages end
        if B.page < 1 then B.page = 1 end

        local h = 30
        local gap = 8
        local backW = 72
        local arrowW = 40
        local cx = x

        local multi = pages > 1
        if (not showBack) and (not multi) then
            return y
        end

        if showBack then
            if siButton(ui, B, "nav_back", cx, y, backW, h, "Back", "normal") then
                siBack(B)
            end
            cx = cx + backW + gap
        end

        if not multi then
            return y + h + 8
        end

        if B.page > 1 then
            if siButton(ui, B, "nav_prev", cx, y, arrowW, h, "<", "primary") then
                B.page = B.page - 1
            end
            cx = cx + arrowW + gap
        end

        local rightNeeded = B.page < pages
        local endX = x + w
        if rightNeeded then endX = x + w - arrowW - gap end
        local midW = math.max(48, endX - cx)
        ui.rbox(cx, y, midW, h, 6, thm.widget, thm.border)
        local label = string.format("%d / %d", B.page, pages)
        local lw = ui.textw(label)
        ui.text(cx + (midW - lw) * 0.5, y + 8, label, thm.text)

        if rightNeeded then
            local rx = x + w - arrowW
            if siButton(ui, B, "nav_next", rx, y, arrowW, h, ">", "primary") then
                B.page = B.page + 1
            end
        end

        return y + h + 8
    end

    local function siDrawGrid(ui, x, y, w, B, items, getInfo, onPick)
        local cols = SkinImg.COLS
        local gap = 10
        local tileW = math.floor((w - gap * (cols - 1)) / cols)
        local tileH = 110
        local per = SkinImg.PAGE
        local pages = math.max(1, math.ceil(#items / per))
        if B.page > pages then B.page = pages end
        if B.page < 1 then B.page = 1 end
        local start = (B.page - 1) * per + 1
        local yy = y
        local col = 0
        for i = start, math.min(#items, start + per - 1) do
            local it = items[i]
            local tx = x + col * (tileW + gap)
            local info = getInfo(it)
            local tid = "tile_" .. tostring(B.step) .. "_" .. tostring(i) .. "_" .. tostring(it.def or it.key or it.paint or it.name)
            if siTile(ui, tx, yy, tileW, tileH, it.name, info, false, B, tid) then
                onPick(it)
            end
            col = col + 1
            if col >= cols then
                col = 0
                yy = yy + tileH + gap
            end
        end
        if col ~= 0 then yy = yy + tileH + gap end
        return yy, pages
    end

    local function siDrawWizard(B, ui, x, y, w)
        local accent = (M and M.T and M.T.accent) or { 74, 166, 255 }
        local textCol = (M and M.T and M.T.text) or { 205, 213, 225 }
        local hi = (M and M.T and M.T.texthi) or { 247, 249, 255 }
        local noun = B.title

        if not B.ready then
            ui.text(x, y, noun:sub(1, 1):upper() .. noun:sub(2) .. " images: " .. tostring(B.status), hi)
            ui.text(x, y + 16, tostring(B.detail or "Waiting…"), textCol)
            ui.text(x, y + 34, "A loading popup appears after your avatar finishes loading.", textCol)
            return
        end

        local header = 22
        local step = B.step or 1

        if B.id == "agent" then
            if step == 1 then
                ui.title(x, y, "Select agent team", hi)
                local items = {
                    { key = "CT", name = "CT Agents", icon = AGENT_TEAM_ICON.CT },
                    { key = "T", name = "T Agents", icon = AGENT_TEAM_ICON.T },
                }
                local gap = 12
                local tileW = math.floor((w - gap) * 0.5)
                local tileH = 160
                local yy = y + header
                for i = 1, #items do
                    local it = items[i]
                    local tx = x + (i - 1) * (tileW + gap)
                    local info = siGetTex(B, it.icon, 0)
                    if siTile(ui, tx, yy, tileW, tileH, it.name, info, false, B, "team_" .. it.key) then
                        B.teamPick = it.key
                        B.page = 1
                        B.path = nil
                        B.def = nil
                        B.modelName = "None"
                        B.step = 2
                    end
                end
                return
            end

            local team = B.teamPick or "CT"
            ui.title(x, y, team .. " agents", hi)
            local items = { { def = nil, path = nil, name = "None" } }
            local list = agentsByTeam[team] or {}
            for i = 1, #list do
                local a = list[i]
                items[#items + 1] = { def = a.def, path = a.path, name = a.name }
            end
            local yy, pages = siDrawGrid(ui, x, y + header, w, B, items,
                function(it) return siGetTex(B, it.def, 0) end,
                function(it)
                    B.def = it.def
                    B.path = it.path
                    B.modelName = it.name
                    AgentImg.apply()
                end)
            siNavBar(ui, x, yy + 4, w, B, pages, true)
            return
        end

        if B.id == "weapon" and step == 1 then
            ui.title(x, y, "Select weapon category", hi)
            local items = {}
            for i = 1, #WEAPON_CATS do
                local c = WEAPON_CATS[i]
                items[#items + 1] = { key = c.key, name = c.name, icon = c.icon }
            end
            local yy, pages = siDrawGrid(ui, x, y + header, w, B, items,
                function(it) return siGetTex(B, it.icon, 0) end,
                function(it)
                    B.catKey = it.key
                    B.catName = it.name
                    B.def = nil
                    B.page = 1
                    B.step = 2
                end)
            local navY = siNavBar(ui, x, yy + 4, w, B, pages, false)
            return
        end

        if step == siModelStep(B) then
            local title = "Select " .. noun .. " model"
            if B.id == "weapon" and B.catName then
                title = tostring(B.catName) .. " — select weapon"
            end
            ui.title(x, y, title, hi)
            local items = siModelItems(B)
            local yy, pages = siDrawGrid(ui, x, y + header, w, B, items,
                function(it)
                    local paint = 0
                    if B.id == "glove" then
                        paint = it.previewPaint or siGlovePreviewPaint(it.def) or 0
                    end
                    return siGetTex(B, it.def, paint)
                end,
                function(it)
                    B.def = it.def
                    B.modelName = it.name
                    B.paint = 0
                    B.paintName = "Default"
                    B.wear = 0.01
                    B.seed = 0
                    B.page = 1
                    B._sliderGen = (B._sliderGen or 0) + 1
                    if not it.def or it.def == 0 then
                        B.step = siCustomizeStep(B)
                    else
                        B.step = siFinishStep(B)
                    end
                end)
            local showBack = (B.id == "weapon") 
            siNavBar(ui, x, yy + 4, w, B, pages, showBack)
            return
        end

        if step == siFinishStep(B) then
            ui.title(x, y, tostring(B.modelName) .. " — choose finish", hi)
            local names, ids = paintListFor(B.def)
            local finishes = {}
            for i = 1, #names do
                finishes[#finishes + 1] = { name = names[i], paint = ids[i] or 0 }
            end
            local yy, pages = siDrawGrid(ui, x, y + header, w, B, finishes,
                function(it) return siGetTex(B, B.def, it.paint) end,
                function(it)
                    B.paint = it.paint
                    B.paintName = it.name
                    B._sliderGen = (B._sliderGen or 0) + 1
                    B.step = siCustomizeStep(B)
                end)
            siNavBar(ui, x, yy + 4, w, B, pages, true)
            return
        end

        local thm = siTheme()
        local preview = siGetTex(B, B.def, B.paint)
        ui.title(x, y, "Customize", hi)
        ui.rbox(x, y + 24, 120, 90, 8, thm.widget, thm.border)
        ui.rfill(x + 6, y + 30, 108, 78, 6, { 14, 16, 22 })
        if preview then siDrawTex(preview, x + 6, y + 30, 108, 78) end
        ui.text(x + 136, y + 30, tostring(B.modelName), hi)
        ui.text(x + 136, y + 48, "Finish: " .. tostring(B.paintName), textCol)

        local cy = y + 130
        ui.text(x, cy, "Wear", textCol)
        cy = cy + 18
        do
            local barW, barH = w, 14
            local wear = tonumber(B.wear) or 0.01
            if wear < 0 then wear = 0 elseif wear > 1 then wear = 1 end
            ui.rfill(x, cy, barW, barH, 4, thm.widgethi)
            ui.rfill(x, cy, math.floor(barW * wear), barH, 4, accent)
            if ui.click(x, cy - 4, barW, barH + 8) then
                local mx = x
                if ui.mouse then mx = select(1, ui.mouse()) or mx end
                local t = (mx - x) / barW
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
                B.wear = t
            end
            ui.text(x + barW - 50, cy - 16, string.format("%.3f", wear), textCol)
        end
        cy = cy + 28
        ui.text(x, cy, "Seed", textCol)
        cy = cy + 18
        do
            local barW, barH = w, 14
            local seed = math.floor(tonumber(B.seed) or 0)
            if seed < 0 then seed = 0 elseif seed > 1000 then seed = 1000 end
            local t = seed / 1000
            ui.rfill(x, cy, barW, barH, 4, thm.widgethi)
            ui.rfill(x, cy, math.floor(barW * t), barH, 4, accent)
            if ui.click(x, cy - 4, barW, barH + 8) then
                local mx = x
                if ui.mouse then mx = select(1, ui.mouse()) or mx end
                local nt = (mx - x) / barW
                if nt < 0 then nt = 0 elseif nt > 1 then nt = 1 end
                B.seed = math.floor(nt * 1000 + 0.5)
            end
            ui.text(x + barW - 40, cy - 16, tostring(seed), textCol)
        end
        cy = cy + 32

        local modes = { "Apply to CT", "Apply to T", "Apply to Both" }
        local bw = math.floor((w - 16) / 3)
        for i = 1, 3 do
            local bx = x + (i - 1) * (bw + 8)
            local kind = ((B.teamMode or 1) == i) and "selected" or "normal"
            if siButton(ui, B, "team_" .. i, bx, cy, bw, 26, modes[i], kind) then
                B.teamMode = i
            end
        end
        cy = cy + 40

        local btnW = math.floor((w - 10) * 0.5)
        if siButton(ui, B, "apply", x, cy, btnW, 30, "Apply", "primary") then
            B.apply()
        end
        if siButton(ui, B, "back", x + btnW + 10, cy, btnW, 30, "Back", "normal") then
            siBack(B)
        end
        cy = cy + 40
        ui.layout(x, cy, w)
    end

    function KnifeImg.drawWizard(ui, x, y, w)
        siDrawWizard(KnifeImg, ui, x, y, w)
    end
    function WeaponImg.drawWizard(ui, x, y, w)
        siDrawWizard(WeaponImg, ui, x, y, w)
    end
    function GloveImg.drawWizard(ui, x, y, w)
        siDrawWizard(GloveImg, ui, x, y, w)
    end
    function AgentImg.drawWizard(ui, x, y, w)
        siDrawWizard(AgentImg, ui, x, y, w)
    end

    function KnifeImg.apply()
        local teams = siTeams(KnifeImg.teamMode)
        local def = KnifeImg.def
        local paint = tonumber(KnifeImg.paint) or 0
        local wear = tonumber(KnifeImg.wear) or 0.01
        local seed = math.floor(tonumber(KnifeImg.seed) or 0)
        if wear < 0 then wear = 0 elseif wear > 1 then wear = 1 end
        for i = 1, #teams do
            local team = teams[i]
            local sel = Sel[team]
            if not sel then
                Sel[team] = emptyTeamSel()
                sel = Sel[team]
            end
            if not def then
                sel.knifeDef = nil
                sel.knife = { paint = 0, wear = 0.01, seed = 0 }
            else
                sel.knifeDef = def
                sel.knife = {
                    paint = paint,
                    wear = wear,
                    seed = seed,
                    name = (paint > 0) and KnifeImg.paintName or nil,
                }
                if paint > 0 then
                    ensurePaintInList(def, paint, KnifeImg.paintName)
                end
            end
        end
        if requestReapply then pcall(requestReapply) end
        pcall(function() if SkinSave then SkinSave() end end)
        local label = KnifeImg.modelName or "knife"
        if paint > 0 then label = label .. " | " .. tostring(KnifeImg.paintName) end
        M:Notify("applied " .. label .. " → " .. table.concat(teams, "+"), "success")
    end

    function WeaponImg.apply()
        local teams = siTeams(WeaponImg.teamMode)
        local def = WeaponImg.def
        if not def then
            M:Notify("pick a weapon first", "error")
            return
        end
        local paint = tonumber(WeaponImg.paint) or 0
        local wear = tonumber(WeaponImg.wear) or 0.01
        local seed = math.floor(tonumber(WeaponImg.seed) or 0)
        if wear < 0 then wear = 0 elseif wear > 1 then wear = 1 end
        for i = 1, #teams do
            local team = teams[i]
            if paint <= 0 then
                WeaponSel[team][def] = nil
            else
                local weapon = WeaponImg.modelName
                local finish = WeaponImg.paintName
                local hudName = finish
                if type(weapon) == "string" and weapon ~= ""
                    and type(finish) == "string" and finish ~= "" and finish ~= "Default" then
                    hudName = weapon .. " | " .. finish
                end
                WeaponSel[team][def] = {
                    paint = paint,
                    wear = wear,
                    seed = seed,
                    name = hudName,
                }
                ensurePaintInList(def, paint, WeaponImg.paintName)
            end
        end
        if requestReapply then pcall(requestReapply) end
        pcall(function() if SkinSave then SkinSave() end end)
        local label = WeaponImg.modelName or "weapon"
        if paint > 0 then label = label .. " | " .. tostring(WeaponImg.paintName)
        else label = label .. " (cleared)" end
        M:Notify("applied " .. label .. " → " .. table.concat(teams, "+"), "success")
    end

    function GloveImg.apply()
        local teams = siTeams(GloveImg.teamMode)
        local def = GloveImg.def
        local paint = tonumber(GloveImg.paint) or 0
        local wear = tonumber(GloveImg.wear) or 0.01
        local seed = math.floor(tonumber(GloveImg.seed) or 0)
        if wear < 0 then wear = 0 elseif wear > 1 then wear = 1 end
        for i = 1, #teams do
            local team = teams[i]
            local sel = Sel[team]
            if not sel then
                Sel[team] = emptyTeamSel()
                sel = Sel[team]
            end
            if not def or def == 0 then
                sel.gloveDef = 0
                sel.glove = { paint = 0, wear = 0.01, seed = 0 }
            else
                sel.gloveDef = def
                sel.glove = {
                    paint = paint,
                    wear = wear,
                    seed = seed,
                    name = (paint > 0) and GloveImg.paintName or nil,
                }
                if paint > 0 then
                    ensurePaintInList(def, paint, GloveImg.paintName)
                end
            end
        end
        if requestReapply then pcall(requestReapply) end
        pcall(function() if SkinSave then SkinSave() end end)
        local label = GloveImg.modelName or "gloves"
        if paint > 0 then label = label .. " | " .. tostring(GloveImg.paintName) end
        M:Notify("applied " .. label .. " → " .. table.concat(teams, "+"), "success")
    end

    local function siTickOne(B)
        if B.ready then return false end
        if siCacheReadyOnDisk(B) then
            B.ready = true
            B.status = "ready"
            return false
        end
        local now
        pcall(function() now = globals.RealTime() end)
        now = type(now) == "number" and now or 0
        if not LiveStatsPos._steamAvatarSettled then
            if not B._waitStart then B._waitStart = now end
            if now > 1 and B._waitStart > 0 and (now - B._waitStart) >= 10 then
                LiveStatsPos._steamAvatarSettled = true
            else
                B.status = "wait-avatar"
                return true
            end
        end
        if LiveStatsPos._avatarHttpBusy then
            B.status = "wait-avatar"
            return true
        end
        for i = 1, #SkinImg.order do
            local o = SkinImg.order[i]
            if o ~= B and (o.downloading or o.indexing) then
                B.status = "queued"
                B.detail = "Waiting for " .. tostring(o.title) .. " cache…"
                return true
            end
        end
        if not B._started then
            B._started = true
            B.tex = {}
            B.texOrder = {}
            B.status = "starting"
            B.detail = "Preparing " .. B.title .. " image cache…"
            SkinImg._popupBrowser = B
            M._skinCachePopupOpen = true
            siStartCache(B)
            return true
        end
        if B.downloading then
            siPumpDownload(B)
            return true
        end
        if B.indexing or SkinImg.catalog.loading or AgentImg._catalogLoading then
            return true
        end
        return false
    end

    function SkinImg.tickAll()
        for i = 1, #SkinImg.order do
            if siTickOne(SkinImg.order[i]) then return end
        end
    end

    function KnifeImg.tick() SkinImg.tickAll() end
    function WeaponImg.tick() SkinImg.tickAll() end
    function GloveImg.tick() SkinImg.tickAll() end
    function AgentImg.tick() SkinImg.tickAll() end

    function SkinImg.drawCachePopup()
        local B = SkinImg._popupBrowser
        if not M._skinCachePopupOpen then return end
        if not B or B.ready then
            M._skinCachePopupOpen = false
            SkinImg._popupBrowser = nil
            return
        end
        local sw, sh = 0, 0
        pcall(function() sw, sh = draw.GetScreenSize() end)
        if not sw or sw < 1 then return end
        local font, fontB
        if M and type(M.UIFonts) == "function" then
            font, fontB = M:UIFonts()
        end
        local mw, mh = 420, 160
        local px = math.floor((sw - mw) * 0.5)
        local py = math.floor((sh - mh) * 0.5)
        local accent = (M and M.T and M.T.accent) or { 74, 166, 255 }
        local title = "Caching " .. tostring(B.title) .. " images"
        pcall(function()
            draw.Color(0, 0, 0, 160)
            draw.FilledRect(0, 0, sw, sh)
            draw.Color(15, 19, 26, 252)
            draw.FilledRect(px, py, px + mw, py + mh)
            draw.Color(accent[1], accent[2], accent[3], 255)
            draw.FilledRect(px, py, px + mw, py + 3)
            if fontB then draw.SetFont(fontB) end
            draw.Color(247, 249, 255, 255)
            draw.Text(px + 20, py + 18, title)
            if font then draw.SetFont(font) end
            draw.Color(205, 213, 225, 255)
            draw.Text(px + 20, py + 48, "Please wait — downloading skin changer art.")
            draw.Text(px + 20, py + 70, "This only runs once; images are saved to disk.")
            draw.Color(accent[1], accent[2], accent[3], 255)
            draw.Text(px + 20, py + 100, tostring(B.detail or B.status or ""))
            local qn = #(B.queue or {})
            local done = math.max(0, (B.qIndex or 1) - 1)
            if qn > 0 then
                local frac = done / qn
                draw.Color(30, 36, 46, 255)
                draw.FilledRect(px + 20, py + 128, px + mw - 20, py + 138)
                draw.Color(accent[1], accent[2], accent[3], 255)
                draw.FilledRect(px + 20, py + 128, px + 20 + math.floor((mw - 40) * frac), py + 138)
            end
        end)
    end

    M._skinCacheDrawPopup = SkinImg.drawCachePopup
end

local setupSub = skinsTab:Sub("Setup")
local ctrlSec = setupSub:Section("Skin changer")
local skinEnable = ctrlSec:Checkbox("Enable skin changer", false)
ctrlSec:Custom(74, function(ui, x, y, w)
    ui.text(x, y, "Engine: " .. (SkinOn and Engine.status or "disabled"))
    if SkinInitError then
        ui.text(x, y + 14, "Init failed: " .. tostring(SkinInitError))
    else
        ui.text(x, y + 14, string.format("Loop: %d ticks, %s, %d applied",
            Diag.ticks, Diag.stage, Diag.items))
    end

    local function gunCount(team)
        local n = 0
        for _ in pairs(WeaponSel[team]) do n = n + 1 end
        return n
    end
    ui.text(x, y + 28, string.format(
        "Selected: CT %d guns / knife %s / gloves %s   T %d guns / knife %s / gloves %s",
        gunCount("CT"), tostring(Sel.CT.knifeDef or 0), tostring(Sel.CT.gloveDef or 0),
        gunCount("T"), tostring(Sel.T.knifeDef or 0), tostring(Sel.T.gloveDef or 0)))

    ui.text(x, y + 42, "Saved to " .. SKIN_FILE .. " when you press Save in the title bar.")
end)

ctrlSec:Button("Print diagnostics to console", function()
    print("[DaizML] ---- skin changer diagnostics ----")
    print(string.format("[DaizML] enabled=%s  engine=%s  ready=%s  init_error=%s",
        tostring(SkinOn), tostring(Engine.status), tostring(Engine.ready), tostring(SkinInitError)))
    print(string.format("[DaizML] loop: ticks=%d  stage=%s  applied=%d",
        Diag.ticks, tostring(Diag.stage), Diag.items))

    for _, team in ipairs(TEAMS) do
        local guns = 0
        for def, e in pairs(WeaponSel[team]) do
            guns = guns + 1
            print(string.format("[DaizML]   %s gun def=%s paint=%s wear=%s seed=%s",
                team, tostring(def), tostring(e.paint), tostring(e.wear), tostring(e.seed)))
        end
        local s = Sel[team]
        print(string.format("[DaizML]   %s guns=%d knife=%s paint=%s  glove=%s paint=%s  agent=%s",
            team, guns, tostring(s.knifeDef), tostring(s.knife.paint),
            tostring(s.gloveDef), tostring(s.glove.paint), tostring(s.agentPath)))
    end

    local raw = fileRead(SKIN_FILE)
    print("[DaizML] " .. SKIN_FILE .. ": " .. (raw and (#raw .. " bytes") or "MISSING"))
    if raw then
        for line in tostring(raw):gmatch("[^\r\n]+") do print("[DaizML]   " .. line) end
    end
    print("[DaizML] ---- end ----")
end)

local inspectCrcTable
do
    inspectCrcTable = {}
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if bit.band(c, 1) ~= 0 then
                c = bit.bxor(bit.rshift(c, 1), 0xEDB88320)
            else
                c = bit.rshift(c, 1)
            end
        end
        inspectCrcTable[i] = c
    end
end

local function inspectTou32(n)
    return bit.band(n, 0xFFFFFFFF)
end

local function inspectUrlDecode(s)
    s = tostring(s or ""):gsub("%+", " ")
    local ok, out = pcall(function()
        return (s:gsub("%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
        end))
    end)
    return (ok and out) or s
end

local function inspectIsInventoryLink(s)
    s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if s:match("^[Ss]%d+[Aa]%d+[Dd]%d+[Mm]%d+$") then return true end
    if s:match("[Ss]%d+[Aa]%d+[Dd]%d+[Mm]%d+") then return true end
    if s:match("csgo_econ_action_preview%s+[Ss]%d") then return true end
    return false
end

local function inspectExtractHex(link)
    local raw = tostring(link or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then return nil, "empty inspect link" end
    if inspectIsInventoryLink(raw) then
        return nil, "unsupported link type (inventory S/A/D/M — needs Steam GC)"
    end
    local decoded = inspectUrlDecode(raw)
    local hex = decoded:match(
        "[cC][sS][gG][oO]_[eE][cC][oO][nN]_[aA][cC][tT][iI][oO][nN]_[pP][rR][eE][vV][iI][eE][wW]%s+([0-9A-Fa-f]+)"
    )
    if not hex then
        hex = decoded:match("^([0-9A-Fa-f]+)$")
    end
    if not hex then return nil, "invalid inspect link (need csgo_econ_action_preview hex or raw hex)" end
    if (#hex % 2) ~= 0 then return nil, "invalid inspect hex payload (odd length)" end
    if not hex:match("^[0-9A-Fa-f]+$") then return nil, "invalid inspect hex payload" end
    return hex:upper()
end

local function inspectHexToBytes(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes + 1] = tonumber(hex:sub(i, i + 1), 16)
    end
    return bytes
end

local function inspectXorMask(bytes, key)
    local out = {}
    for i = 1, #bytes do
        out[i] = bit.bxor(bytes[i], key)
    end
    return out
end

local function inspectCrc32(bytes, from, to)
    local crc = 0xFFFFFFFF
    for i = from, to do
        local b = bytes[i]
        crc = bit.bxor(inspectCrcTable[bit.band(bit.bxor(crc, b), 0xFF)], bit.rshift(crc, 8))
    end
    return bit.bxor(crc, 0xFFFFFFFF)
end

local function inspectChecksum(payload)
    local tmp = { 0 }
    for i = 1, #payload do tmp[i + 1] = payload[i] end
    local crc = inspectCrc32(tmp, 1, #tmp) 
    local x = bit.bxor(bit.band(crc, 0xFFFF), (#payload * crc))
    return inspectTou32(x)
end

local function inspectReadU32BE(bytes, i)
    return inspectTou32(
        bit.bor(
            bit.lshift(bytes[i], 24),
            bit.lshift(bytes[i + 1], 16),
            bit.lshift(bytes[i + 2], 8),
            bytes[i + 3]
        )
    ), i + 4
end

local function inspectReadU32LE(bytes, i)
    return inspectTou32(
        bit.bor(
            bytes[i],
            bit.lshift(bytes[i + 1], 8),
            bit.lshift(bytes[i + 2], 16),
            bit.lshift(bytes[i + 3], 24)
        )
    ), i + 4
end

local function inspectBytesToFloat(u32)
    u32 = inspectTou32(u32)
    if type(ffi) == "table" then
        local ok, f = pcall(function()
            local buf = ffi.new("uint32_t[1]", u32)
            return ffi.cast("float*", buf)[0]
        end)
        if ok and type(f) == "number" then return f end
    end
    local sign = bit.band(bit.rshift(u32, 31), 1)
    local exp = bit.band(bit.rshift(u32, 23), 0xFF)
    local mant = bit.band(u32, 0x7FFFFF)
    local f
    if exp == 0 then
        if mant == 0 then f = 0 else f = (mant / 2 ^ 23) * (2 ^ (-126)) end
    elseif exp == 255 then
        if mant == 0 then f = math.huge else f = 0 / 0 end
    else
        f = (1 + mant / 2 ^ 23) * (2 ^ (exp - 127))
    end
    if sign == 1 then f = -f end
    return f
end

local function inspectReadVarint(bytes, i)
    local result = 0
    local shift = 0
    while i <= #bytes do
        local b = bytes[i]
        i = i + 1
        result = result + bit.band(b, 0x7F) * (2 ^ shift)
        if bit.band(b, 0x80) == 0 then
            return result, i
        end
        shift = shift + 7
        if shift > 70 then return nil, i, "varint overflow" end
    end
    return nil, i, "truncated varint"
end

local function inspectParseSticker(bytes)
    local s = {}
    local i = 1
    while i <= #bytes do
        local tag
        tag, i = inspectReadVarint(bytes, i)
        if not tag then break end
        local field = math.floor(tag / 8)
        local wire = tag % 8
        if wire == 0 then
            local v
            v, i = inspectReadVarint(bytes, i)
            if not v then break end
            if field == 1 then s.slot = v
            elseif field == 2 then s.sticker_id = v
            elseif field == 6 then s.tint_id = v
            elseif field == 10 then s.pattern = v
            elseif field == 11 then s.highlight_reel = v
            elseif field == 12 then s.wrapped_sticker = v
            end
        elseif wire == 5 then
            if i + 3 > #bytes then break end
            local u
            u, i = inspectReadU32LE(bytes, i)
            local f = inspectBytesToFloat(u)
            if field == 3 then s.wear = f
            elseif field == 4 then s.scale = f
            elseif field == 5 then s.rotation = f
            elseif field == 7 then s.offset_x = f
            elseif field == 8 then s.offset_y = f
            elseif field == 9 then s.offset_z = f
            end
        elseif wire == 2 then
            local len
            len, i = inspectReadVarint(bytes, i)
            if not len or i + len - 1 > #bytes then break end
            i = i + len
        elseif wire == 1 then
            if i + 7 > #bytes then break end
            i = i + 8
        else
            break
        end
    end
    return s
end

local function inspectParseProtobuf(payload)
    local out = {
        stickers = {},
        keychains = {},
        variations = {},
    }
    local i = 1
    while i <= #payload do
        local tag
        tag, i = inspectReadVarint(payload, i)
        if not tag then return nil, "truncated protobuf tag" end
        local field = math.floor(tag / 8)
        local wire = tag % 8
        if wire == 0 then
            local v
            v, i = inspectReadVarint(payload, i)
            if not v then return nil, "truncated protobuf varint" end
            if field == 1 then out.accountid = v
            elseif field == 2 then out.itemid = v
            elseif field == 3 then out.defindex = v
            elseif field == 4 then out.paintindex = v
            elseif field == 5 then out.rarity = v
            elseif field == 6 then out.quality = v
            elseif field == 7 then out.paintwear = inspectBytesToFloat(v)
            elseif field == 8 then out.paintseed = v
            elseif field == 9 then out.killeaterscoretype = v
            elseif field == 10 then out.killeatervalue = v
            elseif field == 13 then out.inventory = v
            elseif field == 14 then out.origin = v
            elseif field == 15 then out.questid = v
            elseif field == 16 then out.dropreason = v
            elseif field == 17 then out.musicindex = v
            elseif field == 18 then out.entindex = v
            elseif field == 19 then out.petindex = v
            elseif field == 21 then out.style = v
            elseif field == 23 then out.upgrade_level = v
            end
        elseif wire == 2 then
            local len
            len, i = inspectReadVarint(payload, i)
            if not len or i + len - 1 > #payload then return nil, "truncated length-delimited field" end
            local chunk = {}
            for j = 0, len - 1 do chunk[j + 1] = payload[i + j] end
            i = i + len
            if field == 11 then
                local chars = {}
                for j = 1, #chunk do chars[j] = string.char(chunk[j]) end
                out.customname = table.concat(chars)
            elseif field == 12 then
                out.stickers[#out.stickers + 1] = inspectParseSticker(chunk)
            elseif field == 20 then
                out.keychains[#out.keychains + 1] = inspectParseSticker(chunk)
            elseif field == 22 then
                out.variations[#out.variations + 1] = inspectParseSticker(chunk)
            end
        elseif wire == 5 then
            if i + 3 > #payload then return nil, "truncated fixed32" end
            i = i + 4
        elseif wire == 1 then
            if i + 7 > #payload then return nil, "truncated fixed64" end
            i = i + 8
        else
            return nil, "unsupported protobuf wire type " .. tostring(wire)
        end
    end
    return out
end

local function inspectHasPayload(econ)
    return econ.itemid ~= nil
        or econ.defindex ~= nil
        or econ.paintindex ~= nil
        or econ.paintseed ~= nil
        or (econ.stickers and #econ.stickers > 0)
        or (econ.keychains and #econ.keychains > 0)
        or (econ.variations and #econ.variations > 0)
end

local function inspectHasMaskedPayload(econ)
    return econ.itemid ~= nil
        and econ.defindex ~= nil
        and econ.paintindex ~= nil
        and econ.inventory ~= nil
        and econ.origin ~= nil
end

local function inspectResolveWeaponName(def)
    if def == nil then return nil end
    for i = 1, #SKIN_WEAPONS do
        if SKIN_WEAPONS[i].def == def then return SKIN_WEAPONS[i].name end
    end
    for i = 1, #SKIN_KNIVES do
        local k = SKIN_KNIVES[i]
        if k.def and k.def == def then return k.name end
    end
    for i = 1, #SKIN_GLOVES do
        local g = SKIN_GLOVES[i]
        if g.def and g.def == def then return g.name end
    end
    return nil
end

local function inspectDecode(linkOrHex)
    local hex, err = inspectExtractHex(linkOrHex)
    if not hex then return nil, err end
    local bytes = inspectHexToBytes(hex)
    if #bytes < 5 then return nil, "invalid inspect hex payload (too short)" end

    local payload
    local requireMasked = false
    if bytes[1] == 0 then
        payload = {}
        for i = 2, #bytes - 4 do payload[#payload + 1] = bytes[i] end
        local expected = select(1, inspectReadU32BE(bytes, #bytes - 3))
        local actual = inspectChecksum(payload)
        if expected ~= actual then
            return nil, string.format("inspect hex checksum mismatch (got %08X want %08X)", actual, expected)
        end
    else
        requireMasked = true
        local unmasked = inspectXorMask(bytes, bytes[1])
        if unmasked[1] ~= 0 then return nil, "invalid inspect hex payload (mask)" end
        payload = {}
        for i = 2, #unmasked - 4 do payload[#payload + 1] = unmasked[i] end
    end

    local econ, perr = inspectParseProtobuf(payload)
    if not econ then return nil, perr or "protobuf parse failed" end
    if requireMasked then
        if not inspectHasMaskedPayload(econ) then return nil, "invalid inspect hex payload (masked fields)" end
    else
        if not inspectHasPayload(econ) then return nil, "invalid inspect hex payload" end
    end
    econ.weapon = inspectResolveWeaponName(econ.defindex)
    return econ
end

local inspectPopup = nil
local INSPECT_POPUP_DRAW_ID = "daizml_inspect_popup_" .. tostring({}):gsub("%W", ""):sub(-8)

local stickerNameCache, keychainNameCache = {}, {}
local stickerNamesTried = false
local function ensureStickerNameCache()
    if stickerNamesTried then return end
    stickerNamesTried = true
    if type(http) ~= "table" or type(http.Get) ~= "function" then return end
    local function ingest(url, into, prefix)
        local json
        pcall(function() json = http.Get(url) end)
        if type(json) ~= "string" or #json < 32 then return end
        local pat = '"name"%s*:%s*"(' .. prefix .. ' | [^"]+)".-"def_index"%s*:%s*"(%d+)"'
        for name, def in json:gmatch(pat) do
            local id = tonumber(def)
            if id and not into[id] then
                into[id] = name:gsub("^" .. prefix .. " %| ", "")
            end
        end
    end
    ingest(
        "https://raw.githubusercontent.com/ByMykel/CSGO-API/main/public/api/en/stickers.json",
        stickerNameCache,
        "Sticker"
    )
    ingest(
        "https://raw.githubusercontent.com/ByMykel/CSGO-API/main/public/api/en/keychains.json",
        keychainNameCache,
        "Charm"
    )
    if not keychainNameCache[37] then keychainNameCache[37] = "Sticker Slab" end
end

local function inspectStickerLabel(s)
    local id = tonumber(s and (s.sticker_id or s.id)) or 0
    if id <= 0 then return "?" end
    ensureStickerNameCache()
    local name = stickerNameCache[id]
    if name and name ~= "" then return name end
    return "#" .. tostring(id)
end

local function inspectCharmLabel(s)
    local id = tonumber(s and (s.sticker_id or s.id)) or 0
    if id <= 0 then return "?" end
    ensureStickerNameCache()
    local wrapped = tonumber(s and (s.wrapped_sticker or s.paint_kit)) or 0
    if wrapped > 0 then
        local inner = stickerNameCache[wrapped]
        if inner and inner ~= "" then
            return "Slab: " .. inner
        end
        return "Slab: #" .. tostring(wrapped)
    end
    local name = keychainNameCache[id]
    if name and name ~= "" then return name end
    return "#" .. tostring(id)
end

local function inspectBuildPopupLines(data)
    local def = data.defindex
    local paint = data.paintindex or 0
    local weapon = data.weapon or ("Def " .. tostring(def))
    local finish = paintNameFor(def, paint)
    local tagName = inspectResolveTagName(data)
    local nS = #(data.stickers or {})
    local nK = #(data.keychains or {})
    local lines = {
        weapon,
        "Skin: " .. finish,
        string.format("Paint %s   Wear %.4f   Seed %s",
            tostring(paint), tonumber(data.paintwear) or 0, tostring(data.paintseed or 0)),
        "Name: " .. tostring(tagName or "—"),
    }
    if nS > 0 then
        lines[#lines + 1] = string.format("%d sticker%s:", nS, nS == 1 and "" or "s")
        for i = 1, nS do
            lines[#lines + 1] = string.format("  %d. %s", i, inspectStickerLabel(data.stickers[i]))
        end
    else
        lines[#lines + 1] = "Stickers: none"
    end
    if nK > 0 then
        lines[#lines + 1] = string.format("%d charm%s:", nK, nK == 1 and "" or "s")
        for i = 1, nK do
            lines[#lines + 1] = string.format("  %d. %s", i, inspectCharmLabel(data.keychains[i]))
        end
    else
        lines[#lines + 1] = "Charms: none"
    end
    return lines
end

local function inspectOpenPopup(data)
    inspectPopup = {
        data = data,
        lines = inspectBuildPopupLines(data),
        _mouseDown = true,
        _ignoreUntilUp = true,
    }
    M._inspectPopupOpen = true
end

local inspectApplyToTeam 
local inspectLinkInput

local function inspectClosePopup()
    inspectPopup = nil
    M._inspectPopupOpen = false
    if inspectLinkInput then pcall(function() inspectLinkInput:Set("") end) end
end

local inspectSub = skinsTab:Sub("Inspect Link")
local inspectSec = inspectSub:Section("Steam inspect link")
inspectLinkInput = inspectSec:Input("Inspect URL", "", "steam://...csgo_econ_action_preview <hex> or raw hex")
inspectSec:Custom(48, function(ui, x, y)
    ui.text(x, y, "Supports steam://…csgo_econ_action_preview <hex> or raw hex.")
    ui.text(x, y + 14, "Decode shows Apply CT / Apply T / Cancel over the menu.")
    ui.text(x, y + 28, "Inventory S…A…D…M… links are unsupported (need Steam GC).")
end)
inspectSec:Button("Decode", function()
    local raw = inspectLinkInput:Get()
    local data, err = inspectDecode(raw)
    if not data then
        M:Notify("inspect decode failed", "error")
        return
    end
    if not data.defindex or not data.paintindex or data.paintindex <= 0 then
        M:Notify("inspect decode incomplete", "error")
        return
    end
    inspectOpenPopup(data)
    M:Notify("inspect ready — choose CT or T", "info")
end)
inspectSec:Button("Clear", function()
    inspectLinkInput:Set("")
    if inspectPopup then inspectClosePopup() end
    M:Notify("inspect link cleared", "info")
end)

local weaponsSub, knifeSub, glovesSub, agentSub =
    skinsTab:Sub("Weapons"), skinsTab:Sub("Knife"), skinsTab:Sub("Gloves"), skinsTab:Sub("Agent")

do
    local wSec = weaponsSub:Section("Weapons browser")
    wSec:Custom(560, function(ui, x, y, w)
        pcall(WeaponImg.tick)
        pcall(WeaponImg.drawWizard, ui, x, y, w)
    end)
end

do
    local kSec = knifeSub:Section("Knife browser")
    kSec:Custom(560, function(ui, x, y, w)
        pcall(KnifeImg.tick)
        pcall(KnifeImg.drawWizard, ui, x, y, w)
    end)
end

do
    local gSec = glovesSub:Section("Gloves browser")
    gSec:Custom(560, function(ui, x, y, w)
        pcall(GloveImg.tick)
        pcall(GloveImg.drawWizard, ui, x, y, w)
    end)
end

do
    local aSec = agentSub:Section("Agent browser")
    aSec:Custom(560, function(ui, x, y, w)
        pcall(AgentImg.tick)
        pcall(AgentImg.drawWizard, ui, x, y, w)
    end)
end

ctrlSec:Button("Reset everything", function()
    skinEnable:Set(false)
    WeaponSel.CT, WeaponSel.T = {}, {}
    Sel.CT, Sel.T = emptyTeamSel(), emptyTeamSel()
    pcall(KnifeImg.resetDraft)
    pcall(WeaponImg.resetDraft)
    pcall(GloveImg.resetDraft)
    pcall(AgentImg.resetDraft)
    M:Notify("skin changer reset", "info")
end)

M:OnFrame(function()
    SkinOn = skinEnable:Get() and true or false
    pcall(SkinImg.tickAll)
end)

local function clamp01(v, fallback)
    v = tonumber(v) or fallback
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

local function encodeWeaponsBag(bag)
    local defs = {}
    for def in pairs(bag or {}) do defs[#defs + 1] = def end
    table.sort(defs)
    local ws = {}
    for _, def in ipairs(defs) do
        local e = bag[def]
        ws[#ws + 1] = string.format("%d,%d,%.4f,%d", def, e.paint or 0,
            e.wear or 0.01, e.seed or 0) .. encodeDecorSuffix(e)
    end
    return table.concat(ws, ";")
end

local function decodeWeaponsBag(text)
    local bag = {}
    for entry in tostring(text or ""):gmatch("[^;]+") do
        local base, suffix = entry:match("^([^~]+)(~.*)$")
        if not base then base, suffix = entry, "" end
        local def, paint, wear, seed = base:match("^(%d+),(%d+),([%d%.]+),(%d+)$")
        def = tonumber(def)
        if def and knownWeaponDefs[def] then
            local e = {
                paint = tonumber(paint) or 0,
                wear = clamp01(wear, 0.01),
                seed = tonumber(seed) or 0,
            }
            parseDecorSuffix(suffix, e)
            bag[def] = e
        end
    end
    return bag
end

local function encodeTeamSel(team)
    local sel = Sel[team]
    local parts = {}

    local guns = encodeWeaponsBag(WeaponSel[team])
    if guns ~= "" then parts[#parts + 1] = "w:" .. guns end
    if sel.knifeDef then
        parts[#parts + 1] = string.format("k:%d,%d,%.4f,%d", sel.knifeDef,
            sel.knife.paint or 0, sel.knife.wear or 0.01, sel.knife.seed or 0)
            .. encodeDecorSuffix(sel.knife)
    end
    if (sel.gloveDef or 0) > 0 then
        parts[#parts + 1] = string.format("g:%d,%d,%.4f,%d", sel.gloveDef,
            sel.glove.paint or 0, sel.glove.wear or 0.01, sel.glove.seed or 0)
            .. encodeDecorSuffix(sel.glove)
    end
    if sel.agentPath then parts[#parts + 1] = "a:" .. sel.agentPath end

    return table.concat(parts, "|")
end

local function indexOfDef(list, def)
    for i = 1, #list do
        if list[i].def == def then return i end
    end
    return 1
end

local function splitTeamPayload(text)
    local chunks = {}
    for part in tostring(text or ""):gmatch("[^|]+") do
        chunks[#chunks + 1] = part
    end
    local parts = {}
    for i = 1, #chunks do
        local p = chunks[i]
        if p:match("^%a:") then
            parts[#parts + 1] = p
        elseif #parts > 0 then
            parts[#parts] = parts[#parts] .. "|" .. p
        end
    end
    return parts
end

local function decodeTeamSel(team, text)
    local sel = emptyTeamSel()
    Sel[team] = sel
    WeaponSel[team] = {}

    for _, part in ipairs(splitTeamPayload(text)) do
        local tag, body = part:match("^(%a):(.*)$")
        if tag == "w" then
            WeaponSel[team] = decodeWeaponsBag(body)
        elseif tag == "k" or tag == "g" then
            local base, suffix = body:match("^([^~]+)(~.*)$")
            if not base then base, suffix = body, "" end
            local def, paint, wear, seed = base:match("^(%d+),(%d+),([%d%.]+),(%d+)$")
            def = tonumber(def)
            if def then
                local item = { paint = tonumber(paint) or 0, wear = clamp01(wear, 0.01), seed = tonumber(seed) or 0 }
                parseDecorSuffix(suffix, item)
                if tag == "k" then sel.knifeDef, sel.knife = def, item
                else sel.gloveDef, sel.glove = def, item end
            end
        elseif tag == "a" then
            sel.agentPath = body ~= "" and body or nil
        end
    end

    local u = UI[team]
    if not u then return end

    if requestReapply then pcall(requestReapply) end
end

local function encodeSkinFile()
    return table.concat({
        "enabled=" .. (skinEnable:Get() and "1" or "0"),
        "ct=" .. encodeTeamSel("CT"):gsub("[\r\n]", ""),
        "t=" .. encodeTeamSel("T"):gsub("[\r\n]", ""),
    }, "\n") .. "\n"
end

local function parseSkinFile()
    local text = fileRead(SKIN_FILE)
    local enabled, weapons, ct, t = false, "", "", ""
    if type(text) == "string" then
        local seen = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            line = line:gsub("\r", "")
            local key, value = line:match("^([%w_]+)%s*=%s*(.*)$")
            if key and not seen[key] then
                seen[key] = true
                if key == "enabled" then enabled = value == "1" or value == "true"
                elseif key == "weapons" then weapons = value
                elseif key == "ct" then ct = value
                elseif key == "t" then t = value
                end
            end
        end
    end
    return enabled, weapons, ct, t
end

local function legacyWeaponsOf(payload)
    for _, part in ipairs(splitTeamPayload(payload)) do
        local tag, body = part:match("^(%a):(.*)$")
        if tag == "w" then return body end
    end
    return ""
end

local function readConfigFileSkins()
    local text = fileRead(CONFIG_FILE)
    if type(text) ~= "string" or text == "" then text = fileRead(CONFIG_FILE_LEGACY) end
    if type(text) ~= "string" or text == "" then return nil end

    local slots, cur = {}, nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        line = line:gsub("\r", "")
        local id = line:match("^slot%s*=%s*(%d+)$")
        if id then
            cur = {}
            slots[tonumber(id)] = cur
        elseif cur then
            local key, value = line:match("^([%w_]+)%s*=%s*(.*)$")
            if key == "skin_enabled" then cur.enabled = value == "1" or value == "true"
            elseif key == "skin_ct" then cur.ct = value
            elseif key == "skin_t" then cur.t = value
            end
        end
    end

    local function usable(s)
        return s and (((s.ct or "") ~= "") or ((s.t or "") ~= ""))
    end
    local want = slots[tonumber(text:match("default%s*=%s*(%d+)")) or 1]
    if usable(want) then return want end
    for i = 1, CONFIG_SLOTS do
        if usable(slots[i]) then return slots[i] end
    end
    return nil
end

local function loadSkinFile()
    local enabled, weapons, ct, t = parseSkinFile()

    if weapons == "" and ct == "" and t == "" then
        local old = readConfigFileSkins()
        if old then
            enabled = old.enabled == true
            ct, t = old.ct or "", old.t or ""
            M:Info("imported skins from " .. CONFIG_FILE .. " — press Save to keep them")
        end
    end

    local function withGuns(payload, fallback)
        if legacyWeaponsOf(payload) ~= "" then return payload end
        if fallback == "" then return payload end
        if payload == "" then return "w:" .. fallback end
        return "w:" .. fallback .. "|" .. payload
    end
    ct, t = withGuns(ct, weapons), withGuns(t, weapons)

    skinEnable:Set(enabled)
    decodeTeamSel("CT", ct)
    decodeTeamSel("T", t)
end

local function saveSkinFile()
    if fileWrite(SKIN_FILE, encodeSkinFile()) then return true end
    M:Error("failed to write " .. SKIN_FILE)
    return false
end

loadSkinFile()
SkinSave = saveSkinFile

inspectApplyToTeam = function(team, data)
    if team ~= "CT" and team ~= "T" then return false, "bad team" end
    local def = tonumber(data.defindex)
    local paint = tonumber(data.paintindex) or 0
    local wear = tonumber(data.paintwear) or 0.01
    local seed = math.floor(tonumber(data.paintseed) or 0)
    if not def or paint <= 0 then return false, "missing def/paint" end

    local stickers = cloneInspectStickers(data.stickers)
    local keychains = cloneInspectKeychains(data.keychains)
    local tagName = inspectResolveTagName(data)
    local entry = {
        paint = paint,
        wear = wear,
        seed = seed,
        name = tagName,
        stickers = (#stickers > 0) and stickers or nil,
        keychains = (#keychains > 0) and keychains or nil,
    }

    if isGloveDef(def) then
        local sel = Sel[team]
        sel.gloveDef = def
        sel.glove = entry
        ensurePaintInList(def, paint, tagName)
    elseif isKnifeDef(def) then
        local sel = Sel[team]
        sel.knifeDef = def
        sel.knife = entry
        ensurePaintInList(def, paint, tagName)
    elseif knownWeaponDefs[def] then
        ensurePaintInList(def, paint, tagName)
        WeaponSel[team][def] = entry
    else
        return false, "unsupported defindex " .. tostring(def)
    end

    skinEnable:Set(true)
    SkinOn = true
    local okSave = saveSkinFile()
    if requestReapply then pcall(requestReapply) end
    return true, okSave
end

local function inspectPopupMouse()
    if ms and (ms.x or ms.y) then
        return ms.x or 0, ms.y or 0, ms.down and true or false, ms.pressed and true or false
    end
    local mx, my = 0, 0
    pcall(function()
        if input and input.GetMousePos then
            local p = input.GetMousePos()
            if type(p) == "table" then mx, my = p.x or p[1] or 0, p.y or p[2] or 0
            else mx, my = p, select(2, input.GetMousePos()) end
        end
    end)
    local down = false
    pcall(function()
        if input and input.IsButtonDown then down = input.IsButtonDown(0x01) and true or false end
    end)
    return mx, my, down, false
end

local function inspectHit(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function inspectDrawPopup()
    local P = inspectPopup
    if not P or not P.data then return end
    local sw, sh = 0, 0
    pcall(function() sw, sh = draw.GetScreenSize() end)
    if not sw or sw < 1 then return end

    local theme = (M and M.T) or {}
    local accent = theme.accent or { 74, 166, 255 }
    local section = theme.section or theme.bg2 or { 15, 19, 26, 252 }
    local border = theme.border or { 40, 48, 61, 255 }
    local divider = theme.divider or { 29, 36, 47, 255 }
    local textCol = theme.text or { 205, 213, 225, 255 }
    local textHi = theme.texthi or { 247, 249, 255, 255 }
    local muted = theme.textdim or { 119, 132, 150, 255 }
    local widget = theme.widget or { 19, 25, 34, 255 }
    local widgetHi = theme.widgethi or { 26, 36, 48, 255 }
    local shadow = theme.shadow or { 0, 0, 0, 115 }
    local bgDeep = theme.bg or { 8, 10, 14, 252 }

    local font, fontB
    if M and type(M.UIFonts) == "function" then
        font, fontB = M:UIFonts()
    end

    local lines = P.lines or {}
    local lineH = 20
    local mw = 460
    local mh = 126 + (#lines * lineH) + 58
    local x = math.floor((sw - mw) * 0.5)
    local y = math.floor((sh - mh) * 0.5)

    local function col4(c, a)
        return tonumber(c[1]) or 255, tonumber(c[2]) or 255, tonumber(c[3]) or 255, tonumber(a or c[4]) or 255
    end
    local function fill(rx, ry, rw, rh, c, a)
        if not c or rw < 1 or rh < 1 then return end
        pcall(function()
            local r, g, b, aa = col4(c, a)
            draw.Color(r, g, b, aa)
            draw.FilledRect(math.floor(rx), math.floor(ry), math.floor(rx + rw), math.floor(ry + rh))
        end)
    end
    local function rfill(rx, ry, rw, rh, rad, c, a)
        rx, ry, rw, rh = math.floor(rx), math.floor(ry), math.floor(rw), math.floor(rh)
        rad = math.min(rad or 0, math.floor(rw / 2), math.floor(rh / 2))
        if rad <= 0 then fill(rx, ry, rw, rh, c, a); return end
        fill(rx, ry + rad, rw, rh - 2 * rad, c, a)
        for dy = 0, rad - 1 do
            local dx = rad - math.floor(math.sqrt(rad * rad - (rad - dy - 0.5) ^ 2) + 0.5)
            fill(rx + dx, ry + dy, rw - 2 * dx, 1, c, a)
            fill(rx + dx, ry + rh - 1 - dy, rw - 2 * dx, 1, c, a)
        end
    end
    local function rbox(rx, ry, rw, rh, rad, fillC, brdC)
        if brdC then rfill(rx, ry, rw, rh, rad, brdC) end
        rfill(rx + 1, ry + 1, rw - 2, rh - 2, math.max(0, (rad or 0) - 1), fillC)
    end
    local function label(fnt, tx, ty, c, s, centerW)
        if not c or s == nil then return end
        pcall(function()
            if fnt then draw.SetFont(fnt) end
            local r, g, b = col4(c)
            draw.Color(r, g, b, 255)
            local text = tostring(s)
            local lx = math.floor(tx)
            if centerW then
                local tw = 0
                pcall(function() tw = select(1, draw.GetTextSize(text)) or 0 end)
                if type(tw) ~= "number" then tw = 0 end
                lx = math.floor(tx + (centerW - tw) * 0.5)
            end
            draw.Text(lx, math.floor(ty), text)
        end)
    end

    fill(0, 0, sw, sh, { 0, 0, 0 }, 150)
    fill(x + 4, y + 7, mw, mh, shadow)
    rbox(x, y, mw, mh, 10, section, border)
    rfill(x + 1, y + 1, mw - 2, 1, 9, { accent[1], accent[2], accent[3], 50 })
    rfill(x, y, mw, 2, 7, accent)
    rfill(x + 14, y + 16, 3, 14, 1, accent)
    label(fontB or font, x + 24, y + 16, textHi, "Apply inspect skin")
    fill(x + 14, y + 38, mw - 28, 1, divider)

    for i = 1, #lines do
        local col = (i == 1) and textHi or ((i <= 2) and textCol or muted)
        local fnt = (i == 1) and (fontB or font) or font
        label(fnt, x + 24, y + 50 + (i - 1) * lineH, col, lines[i])
    end

    local btnW, btnH, gap = 124, 32, 12
    local btnY = y + mh - 50
    local totalW = btnW * 3 + gap * 2
    local btnX0 = x + math.floor((mw - totalW) * 0.5)
    local buttons = {
        { label = "Apply CT", team = "CT", x = btnX0 },
        { label = "Apply T", team = "T", x = btnX0 + btnW + gap },
        { label = "Cancel", team = nil, x = btnX0 + (btnW + gap) * 2 },
    }

    local function drawButtons(mx, my, mouseDown, mousePressed, allowClick)
        local click = allowClick and (mousePressed or (mouseDown and not (P._mouseDown or false)))
        if allowClick then P._mouseDown = mouseDown end

        for _, b in ipairs(buttons) do
            local hover = inspectHit(mx, my, b.x, btnY, btnW, btnH)
            local fillCol, brdCol, textC
            if b.team then
                fillCol = hover and accent or widget
                brdCol = hover and accent or border
                textC = hover and bgDeep or textHi
            else
                fillCol = hover and widgetHi or widget
                brdCol = border
                textC = textCol
            end
            rbox(b.x, btnY, btnW, btnH, 6, fillCol, brdCol)
            label(fontB or font, b.x, btnY + 8, textC, b.label, btnW)

            if click and hover and not (ms and ms.consumed) then
                if ms then ms.consumed = true end
                if not b.team then
                    inspectClosePopup()
                    M:Notify("inspect apply cancelled", "info")
                elseif inspectApplyToTeam then
                    local ok, saved = inspectApplyToTeam(b.team, P.data)
                    inspectClosePopup()
                    if ok then
                        local name = (P.data.weapon or "skin") .. " → " .. b.team
                        if saved then M:Success("applied & saved " .. name)
                        else M:Notify("applied " .. name .. " (save failed)", "info") end
                    else
                        M:Error("apply failed: " .. tostring(saved))
                    end
                end
            end
        end
    end

    local mx, my, mouseDown, mousePressed = inspectPopupMouse()
    if P._ignoreUntilUp then
        if mouseDown then
            P._mouseDown = true
            drawButtons(mx, my, mouseDown, mousePressed, false)
            return
        end
        P._ignoreUntilUp = false
        P._mouseDown = false
    end
    drawButtons(mx, my, mouseDown, mousePressed, true)
end

M._inspectDrawPopup = inspectDrawPopup
M._inspectPopupOpen = false

pcall(function() callbacks.Unregister("Draw", INSPECT_POPUP_DRAW_ID) end)

if type(ffi) ~= "table" or type(bit) ~= "table" or type(mem) ~= "table" then
    ctrlSec:Custom(16, function(ui, x, y)
        ui.text(x, y, "Unavailable: this build has no FFI/bit/mem access.")
    end)
    return
end
;(function()

local band, rshift = bit.band, bit.rshift

local function r_u8(a) return ffi.cast("uint8_t*", a)[0] end
local function r_u16(a) return ffi.cast("uint16_t*", a)[0] end
local function r_i32(a) return ffi.cast("int32_t*", a)[0] end
local function r_u32(a) return ffi.cast("uint32_t*", a)[0] end
local function r_u64(a) return ffi.cast("uint64_t*", a)[0] end
local function r_ptr(a) return tonumber(ffi.cast("uint64_t*", a)[0]) end
local function w_u8(a, v) ffi.cast("uint8_t*", a)[0] = v end
local function w_u16(a, v) ffi.cast("uint16_t*", a)[0] = v end
local function w_i32(a, v) ffi.cast("int32_t*", a)[0] = v end
local function w_u32(a, v) ffi.cast("uint32_t*", a)[0] = v end
local function w_u64(a, v) ffi.cast("uint64_t*", a)[0] = v end
local function w_f32(a, v) ffi.cast("float*", a)[0] = v end

local function valid(p) return p ~= nil and p > 0x10000 and p < 0x7FFFFFFFFFFF end

local function read_cstr(a, max)
    if not valid(a) then return "" end
    local t = {}
    for i = 0, (max or 160) - 1 do
        local c = r_u8(a + i)
        if c == 0 then break end
        t[#t + 1] = string.char(c)
    end
    return table.concat(t)
end

local function safeWear(w)
    w = tonumber(w) or 0.0001
    if w <= 0 then return 0.0001 end
    if w > 1 then return 1 end
    return w
end

local DUMPER = "https://raw.githubusercontent.com/a2x/cs2-dumper/main/output/"

local SCHEMA_FIELDS = {
    m_pWeaponServices      = "m_pWeaponServices",
    m_hMyWeapons           = "m_hMyWeapons",
    m_hActiveWeapon        = "m_hActiveWeapon",
    m_AttributeManager     = { "m_AttributeManager", "C_EconEntity" },
    m_Item                 = "m_Item",
    m_pGameSceneNode       = "m_pGameSceneNode",
    m_modelState           = { "m_modelState", "CSkeletonInstance" },
    m_MeshGroupMask        = { "m_MeshGroupMask", "CModelState" },
    m_hModel               = { "m_hModel", "CModelState" },
    m_nSubclassID          = "m_nSubclassID",
    m_iTeamNum             = "m_iTeamNum",
    m_iHealth              = "m_iHealth",
    m_lifeState            = "m_lifeState",
    m_hOwnerEntity         = "m_hOwnerEntity",
    m_hPlayerPawn          = "m_hPlayerPawn",
    m_steamID              = "m_steamID",
    m_iItemDefinitionIndex = "m_iItemDefinitionIndex",
    m_bRestoreCustomMat    = "m_bRestoreCustomMaterialAfterPrecache",
    m_iEntityQuality       = "m_iEntityQuality",
    m_iItemID              = "m_iItemID",
    m_iItemIDLow           = "m_iItemIDLow",
    m_iItemIDHigh          = "m_iItemIDHigh",
    m_iAccountID           = "m_iAccountID",
    m_OriginalOwnerXuidLow = { "m_OriginalOwnerXuidLow", "C_EconEntity" },
    m_bInitialized         = "m_bInitialized",
    m_bDisallowSOC         = "m_bDisallowSOC",
    m_AttributeList        = "m_AttributeList",
    m_Attributes           = "m_Attributes",
    m_nFallbackPaintKit    = { "m_nFallbackPaintKit", "C_EconEntity" },
    m_nFallbackSeed        = { "m_nFallbackSeed", "C_EconEntity" },
    m_flFallbackWear       = { "m_flFallbackWear", "C_EconEntity" },
    m_nFallbackStatTrak    = { "m_nFallbackStatTrak", "C_EconEntity" },
    m_bAttributesInitialized = { "m_bAttributesInitialized", "C_EconEntity" },
    m_NetworkedDynamicAttributes = "m_NetworkedDynamicAttributes",
    m_szCustomName         = "m_szCustomName",
    m_hViewmodelAttachment = { "m_hViewmodelAttachment", "C_EconEntity" },
    m_hHudModelArms        = { "m_hHudModelArms", "C_CSPlayerPawn" },
    m_pChild               = { "m_pChild", "CGameSceneNode" },
    m_pNextSibling         = { "m_pNextSibling", "CGameSceneNode" },
    m_pOwner               = { "m_pOwner", "CGameSceneNode" },
    m_EconGloves           = { "m_EconGloves", "C_CSPlayerPawn" },
    m_bNeedToReApplyGloves = { "m_bNeedToReApplyGloves", "C_CSPlayerPawn" },
    m_nKeychainDefID       = { "m_nKeychainDefID", "C_KeychainModule" },
    m_nKeychainSeed        = { "m_nKeychainSeed", "C_KeychainModule" },
}

local SCHEMA_STATIC = {
    m_szWorldModel = 48,
    m_modelState = 336,
    m_hModel = 160,
    m_MeshGroupMask = 520,
    m_hViewmodelAttachment = 5808,
    m_hHudModelArms = 0x1B7C,
    m_pChild = 0x40,
    m_pNextSibling = 0x48,
    m_pOwner = 0x30,
    m_AttributeList = 520,
    m_NetworkedDynamicAttributes = 640,
    m_Attributes = 8,
    m_nKeychainDefID = 4448,
    m_nKeychainSeed = 4452,
}

local REQUIRED_OFFSETS = {
    "m_pWeaponServices", "m_hMyWeapons", "m_AttributeManager", "m_Item",
    "m_pGameSceneNode", "m_nSubclassID", "m_iTeamNum", "m_hOwnerEntity",
    "m_hPlayerPawn", "m_iHealth", "m_lifeState",
    "m_iItemDefinitionIndex", "m_iItemIDHigh", "m_bInitialized",
    "m_AttributeList", "m_Attributes", "m_nFallbackPaintKit",
    "m_nFallbackSeed", "m_flFallbackWear", "m_EconGloves",
}

local off = {}

local classBlockCache = {}
local function classBlock(json, className)
    local hit = classBlockCache[className]
    if hit ~= nil then return hit or nil end
    local s, e = json:find('"' .. className .. '"%s*:%s*{')
    if not s then classBlockCache[className] = false; return nil end
    local depth, i, n = 1, e + 1, #json
    while i <= n and depth > 0 do
        local c = json:sub(i, i)
        if c == "{" then depth = depth + 1
        elseif c == "}" then depth = depth - 1 end
        i = i + 1
    end
    local block = json:sub(e, i - 1)
    classBlockCache[className] = block
    return block
end

local function pullOffset(json, name, after)
    local haystack = json
    if after then
        haystack = classBlock(json, after)
        if not haystack then return nil end
    end
    local v = haystack:match('"' .. name .. '"%s*:%s*(%d+)')
    v = v and tonumber(v) or nil
    if v and (v < 0 or v > 0x20000) then return nil end
    return v
end

local function fetchSchemaOffsets()
    if type(http) ~= "table" or type(http.Get) ~= "function" then return false end
    local json
    pcall(function() json = http.Get(DUMPER .. "client_dll.json") end)
    if type(json) ~= "string" or #json < 1000 then return false end
    classBlockCache = {}
    local n = 0
    for key, spec in pairs(SCHEMA_FIELDS) do
        local name, after = spec, nil
        if type(spec) == "table" then name, after = spec[1], spec[2] end
        local v = pullOffset(json, name, after)
        if v then off[key] = v; n = n + 1 end
    end
    return n > 0
end

local function applyStaticOffsets()
    for key, value in pairs(SCHEMA_STATIC) do
        if type(off[key]) ~= "number" then off[key] = value end
    end
end

applyStaticOffsets()

local function offsetsComplete()
    for i = 1, #REQUIRED_OFFSETS do
        if type(off[REQUIRED_OFFSETS[i]]) ~= "number" then return false, REQUIRED_OFFSETS[i] end
    end
    return true
end

local clientBase, engineBase

local function sigRva(modBase, mod, pattern, instrLen)
    if not modBase then return nil end
    local a
    pcall(function() a = mem.FindPattern(mod, pattern) end)
    if not a or a == 0 then return nil end
    a = tonumber(a)
    return (a + instrLen + r_i32(a + 3)) - modBase
end

local function sigDisp(mod, pattern)
    local a
    pcall(function() a = mem.FindPattern(mod, pattern) end)
    if not a or a == 0 then return nil end
    return r_i32(tonumber(a) + 3)
end

local function resolveGlobals()
    pcall(function() clientBase = tonumber(mem.GetModuleBase("client.dll")) end)
    pcall(function() engineBase = tonumber(mem.GetModuleBase("engine2.dll")) end)
    if not clientBase then return false end

    off.dwEntityList = sigRva(clientBase, "client.dll",
        "48 8B 0D ?? ?? ?? ?? 48 89 7C 24 ?? 8B FA C1 EB", 7)
        or sigRva(clientBase, "client.dll",
        "48 89 0D ?? ?? ?? ?? E9 ?? ?? ?? ?? CC", 7)
        or off.dwEntityList

    off.dwLocalPlayerController = sigRva(clientBase, "client.dll",
        "48 8B 05 ?? ?? ?? ?? 41 89 BE", 7)
        or off.dwLocalPlayerController

    if engineBase then
        off.dwNetworkGameClient = sigRva(engineBase, "engine2.dll",
            "48 89 3D ?? ?? ?? ?? FF 87", 7) or off.dwNetworkGameClient
        off.dwNetworkGameClient_signOnState = sigDisp("engine2.dll",
            "44 8B 81 ?? ?? ?? ?? 48 8D 0D") or off.dwNetworkGameClient_signOnState
    end

    return off.dwEntityList ~= nil and off.dwLocalPlayerController ~= nil
end


local function fetchGlobalOffsets()
    if type(http) ~= "table" or type(http.Get) ~= "function" then return end
    local json
    pcall(function() json = http.Get(DUMPER .. "offsets.json") end)
    if type(json) ~= "string" then return end
    for _, key in ipairs({ "dwEntityList", "dwLocalPlayerController",
                           "dwNetworkGameClient", "dwNetworkGameClient_signOnState" }) do
        local v = pullOffset(json, key)
        if v then off[key] = v end
    end
end

local SIGS = {
    set_model       = "40 53 48 83 EC ?? 48 8B D9 4C 8B C2 48 8B 0D ?? ?? ?? ?? 48 8D 54 24 40",
    update_subclass = "4C 8B DC 53 48 81 EC ?? ?? ?? ?? 48 8B 41",
    set_mesh_mask   = "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? 48 8D 99 ?? ?? ?? ?? 48 8B 71",
    regen_skins     = "48 83 EC ?? E8 ?? ?? ?? ?? 48 85 C0 0F 84 ?? ?? ?? ?? 48 8B 10",
    add_keychain    = "44 88 44 24 ?? 48 89 54 24 ?? 48 89 4C 24 ?? 55 53 56 57 41 54 41 55 41 56 41 57 48 8D AC 24",
}
local SBG_SIG = "E8 ?? ?? ?? ?? EB 0C 48 8B CF"
local PRECACHE_SIG = "40 53 55 57 48 81 EC 80 00 00 00 48 8B 01 49 8B E8 48 8B FA"

local fn, fnptr = {}, {}

local function resolveFunctions()
    for name, pattern in pairs(SIGS) do
        if not fn[name] then
            local a
            pcall(function() a = mem.FindPattern("client.dll", pattern) end)
            if a and a ~= 0 then fn[name] = tonumber(a) end
        end
    end
    if not fn.set_body_group then
        local a
        pcall(function() a = mem.FindPattern("client.dll", SBG_SIG) end)
        if a and a ~= 0 then
            a = tonumber(a)
            fn.set_body_group = a + 5 + r_i32(a + 1)
        end
    end
    pcall(function()
        if fn.set_model and not fnptr.set_model then
            fnptr.set_model = ffi.cast("void(*)(void*, const char*)", fn.set_model)
        end
        if fn.update_subclass and not fnptr.update_subclass then
            fnptr.update_subclass = ffi.cast("void(*)(void*)", fn.update_subclass)
        end
        if fn.set_mesh_mask and not fnptr.set_mesh_mask then
            fnptr.set_mesh_mask = ffi.cast("void(*)(void*, uint64_t)", fn.set_mesh_mask)
        end
        if fn.regen_skins and not fnptr.regen_skins then
            fnptr.regen_skins = ffi.cast("void(*)(void)", fn.regen_skins)
        end
        if fn.add_keychain and not fnptr.add_keychain then
            fnptr.add_keychain = ffi.cast("char(*)(void*, void*, unsigned char)", fn.add_keychain)
        end
        if fn.set_body_group and not fnptr.set_body_group then
            fnptr.set_body_group = ffi.cast("void(*)(void*, const char*, unsigned int)", fn.set_body_group)
        end
    end)
    return fnptr.set_model ~= nil and fnptr.update_subclass ~= nil
end

pcall(function()
    ffi.cdef [[
        void* GetModuleHandleA(const char*);
        void* GetProcAddress(void*, const char*);
        typedef struct {
            int32_t  m_nLength;
            uint32_t m_nAllocatedSize;
            union { char* p; char s[8]; } u;
        } DaizML_CBufStr;
    ]]
end)

local gameAlloc
local function resolveAlloc()
    if gameAlloc then return true end
    pcall(function()
        local tier0 = ffi.C.GetModuleHandleA("tier0.dll")
        if tier0 == nil then return end
        local pa = ffi.C.GetProcAddress(tier0, "MemAlloc_AllocFunc")
        if pa ~= nil then gameAlloc = ffi.cast("void*(*)(size_t)", pa) end
    end)
    return gameAlloc ~= nil
end

local resourceSystem, precachedPaths = nil, {}
local function resolvePrecache()
    if fnptr.precache and resourceSystem and fnptr.cbuf_insert then return true end
    if not fn.precache then
        local a
        pcall(function() a = mem.FindPattern("resourcesystem.dll", PRECACHE_SIG) end)
        if a and a ~= 0 then fn.precache = tonumber(a) end
    end
    pcall(function()
        if fn.precache and not fnptr.precache then
            fnptr.precache = ffi.cast("void*(*)(void*, void*, const char*)", fn.precache)
        end
    end)
    if not resourceSystem then
        pcall(function()
            local rs = ffi.C.GetModuleHandleA("resourcesystem.dll")
            local ci = rs ~= nil and ffi.C.GetProcAddress(rs, "CreateInterface") or nil
            if ci ~= nil then
                local CI = ffi.cast("void*(*)(const char*, int*)", ci)
                local irs = CI("ResourceSystem013", nil)
                if irs ~= nil then resourceSystem = irs end
            end
        end)
    end
    if not fnptr.cbuf_insert then
        pcall(function()
            local t0 = ffi.C.GetModuleHandleA("tier0.dll")
            local ins = t0 ~= nil and ffi.C.GetProcAddress(t0, "?Insert@CBufferString@@QEAAPEBDHPEBDH_N@Z") or nil
            if ins ~= nil then
                fnptr.cbuf_insert = ffi.cast("const char*(*)(void*, int, const char*, int, int)", ins)
            end
        end)
    end
    return fnptr.precache ~= nil and resourceSystem ~= nil and fnptr.cbuf_insert ~= nil
end

local function precacheModel(path)
    if type(path) ~= "string" or path == "" then return end
    if precachedPaths[path] then return end
    if not resolvePrecache() then return end
    pcall(function()
        local cb = ffi.new("DaizML_CBufStr")
        cb.m_nLength = 0
        cb.m_nAllocatedSize = 0xC0000008
        cb.u.p = nil
        fnptr.cbuf_insert(cb, 0, path, -1, 0)
        fnptr.precache(resourceSystem, cb, "")
    end)
    precachedPaths[path] = true
end

local function safeSetModel(ent, path)
    if not fnptr.set_model or not valid(ent) then return false end
    if type(path) ~= "string" or not path:find("%.vmdl") then return false end
    if (ent % 8) ~= 0 or not valid(r_ptr(ent)) then return false end
    precacheModel(path)
    return pcall(function() fnptr.set_model(ffi.cast("void*", ent), path) end)
end

local function vfunc(this, index)
    if not valid(this) then return nil end
    local vt = r_ptr(this)
    if not valid(vt) then return nil end
    local f = r_ptr(vt + index * 8)
    if not valid(f) then return nil end
    return f
end

local function vcallVoid(this, index)
    local f = vfunc(this, index)
    if not f then return end
    pcall(function() ffi.cast("void(*)(void*)", f)(ffi.cast("void*", this)) end)
end

local function vcallBool(this, index, b)
    local f = vfunc(this, index)
    if not f then return end
    pcall(function() ffi.cast("void(*)(void*, int)", f)(ffi.cast("void*", this), b and 1 or 0) end)
end

local function handleToEntity(elist, hnd)
    if not valid(elist) then return nil end
    local idx = band(hnd, 0x7FFF)
    local chunk = r_ptr(elist + 8 * rshift(idx, 9) + 16)
    if not valid(chunk) then return nil end
    local e = r_ptr(chunk + 112 * band(idx, 0x1FF))
    if valid(e) and valid(r_ptr(e)) then return e end
    return nil
end

local function inGame()
    if not engineBase or not off.dwNetworkGameClient then return true end
    local ok, state = pcall(function()
        local client = r_ptr(engineBase + off.dwNetworkGameClient)
        if not valid(client) then return -1 end
        return r_i32(client + (off.dwNetworkGameClient_signOnState or 560))
    end)
    if not ok then return true end
    return state == 6
end

local function pawnAlive(pawn)
    if not valid(pawn) then return false end
    local alive = false
    local ok = pcall(function()
        local hp = r_i32(pawn + off.m_iHealth)
        local ls = r_u8(pawn + off.m_lifeState)
        alive = (ls == 0) and hp > 0 and hp < 100000
    end)
    return ok and alive
end

local bxor, lshift, mfloor = bit.bxor, bit.lshift, math.floor
local MURMUR_M = 0x5bd1e995

local function tou32(x)
    x = x % 0x100000000
    if x < 0 then x = x + 0x100000000 end
    return x
end

local function mul32(a, b)
    a = a % 0x100000000
    b = b % 0x100000000
    local ah, al = mfloor(a / 0x10000), a % 0x10000
    local bh, bl = mfloor(b / 0x10000), b % 0x10000
    return (al * bl + ((al * bh + ah * bl) % 0x10000) * 0x10000) % 0x100000000
end

local function murmur2(str, seed)
    local len = #str
    local h = tou32(bxor(seed, len))
    local i, rem = 1, len
    while rem >= 4 do
        local b0, b1, b2, b3 = str:byte(i, i + 3)
        local k = b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
        k = mul32(k, MURMUR_M)
        k = tou32(bxor(k, rshift(k, 24)))
        k = mul32(k, MURMUR_M)
        h = mul32(h, MURMUR_M)
        h = tou32(bxor(h, k))
        i = i + 4
        rem = rem - 4
    end
    if rem >= 3 then h = tou32(bxor(h, lshift(str:byte(i + 2), 16))) end
    if rem >= 2 then h = tou32(bxor(h, lshift(str:byte(i + 1), 8))) end
    if rem >= 1 then
        h = tou32(bxor(h, str:byte(i)))
        h = mul32(h, MURMUR_M)
    end
    h = tou32(bxor(h, rshift(h, 13)))
    h = mul32(h, MURMUR_M)
    h = tou32(bxor(h, rshift(h, 15)))
    return h
end

local function subclassHash(def) return murmur2(tostring(def):lower(), 0x31415926) end

local ATTR_STRUCT = 72
local itemIdSerial = 0

local function itemPtr(wpn) return wpn + off.m_AttributeManager + off.m_Item end

local function writeFallback(wpn, paint, wear, seed)
    w_i32(wpn + off.m_nFallbackPaintKit, paint)
    w_f32(wpn + off.m_flFallbackWear, safeWear(wear))
    w_i32(wpn + off.m_nFallbackSeed, seed)
    if off.m_nFallbackStatTrak then w_i32(wpn + off.m_nFallbackStatTrak, -1) end
end

local function markItemCustom(item, paint)
    if paint ~= nil and off.m_iItemID then
        w_u8(item + off.m_bInitialized, 0)
        itemIdSerial = (itemIdSerial + 1) % 0x0FFFFFFF
        local cacheID = 0x40000000 + itemIdSerial
        w_u64(item + off.m_iItemID, cacheID)
        if off.m_iItemIDLow then w_u32(item + off.m_iItemIDLow, cacheID) end
    end
    w_u32(item + off.m_iItemIDHigh, 0xFFFFFFFF)
    w_u8(item + off.m_bInitialized, 1)
    if off.m_bDisallowSOC then w_u8(item + off.m_bDisallowSOC, 0) end
    if off.m_bRestoreCustomMat then w_u8(item + off.m_bRestoreCustomMat, 1) end
end

local function allocAttributes(bytes)
    if not resolveAlloc() then return nil end
    local raw
    pcall(function() raw = gameAlloc(bytes) end)
    if raw == nil then return nil end
    local ptr
    pcall(function() ptr = tonumber(ffi.cast("uintptr_t", raw)) end)
    return valid(ptr) and ptr or nil
end

local function attrValueAsFloat(value, asInt)
    if not asInt then return tonumber(value) or 0 end
    local n = math.floor(tonumber(value) or 0)
    local ok, f = pcall(function()
        local buf = ffi.new("int32_t[1]", n)
        return ffi.cast("float*", buf)[0]
    end)
    if ok then return f end
    return n + 0.0
end

local function collectSkinAttrs(paint, wear, seed, stickers, keychains)
    local attrs = {
        { 6, math.max(0, tonumber(paint) or 0), false },
        { 7, math.max(0, tonumber(seed) or 0), false },
        { 8, safeWear(wear), false },
    }
    local stickerCount = 0
    for i = 1, #(stickers or {}) do
        local s = stickers[i]
        local id = tonumber(s.id or s.sticker_id) or 0
        if id > 0 and stickerCount <= 5 then
            local idx = stickerCount
            stickerCount = stickerCount + 1
            local schema = tonumber(s.slot) or 0
            local ox = tonumber(s.offset_x)
            local oy = tonumber(s.offset_y)
            local base = 113 + idx * 4
            attrs[#attrs + 1] = { base, id, true }
            attrs[#attrs + 1] = { base + 1, tonumber(s.wear) or 0, false }
            attrs[#attrs + 1] = { base + 2, tonumber(s.scale) or 1, false }
            attrs[#attrs + 1] = { base + 3, tonumber(s.rotation) or 0, false }
            attrs[#attrs + 1] = { 278 + idx * 2, ox or 0, false }
            attrs[#attrs + 1] = { 279 + idx * 2, oy or 0, false }
            attrs[#attrs + 1] = { 290 + idx, schema, true }
        end
    end
    for _, k in ipairs(keychains or {}) do
        local id = tonumber(k.id or k.sticker_id) or 0
        if id > 0 then
            attrs[#attrs + 1] = { 299, id, true }
            attrs[#attrs + 1] = { 300, tonumber(k.offset_x) or 0, false }
            attrs[#attrs + 1] = { 301, tonumber(k.offset_y) or 0, false }
            attrs[#attrs + 1] = { 302, tonumber(k.offset_z) or 0, false }
            attrs[#attrs + 1] = { 306, tonumber(k.pattern) or 0, true }
            local wrapped = tonumber(k.wrapped_sticker or k.paint_kit) or 0
            if wrapped > 0 then
                attrs[#attrs + 1] = { 321, wrapped, true }
            end
            local hl = tonumber(k.highlight_reel)
            if hl and hl > 0 then
                attrs[#attrs + 1] = { 314, hl, true }
            end
            break
        end
    end
    return attrs
end

local function writeAttrBlock(listAddr, list)
    local n = #list
    if n < 1 then return false end
    local fresh = allocAttributes(ATTR_STRUCT * n)
    if not fresh then return false end
    for q = 0, n * 9 - 1 do w_u64(fresh + q * 8, 0) end
    for i = 1, n do
        local attr = fresh + (i - 1) * ATTR_STRUCT
        local defId, value, asInt = list[i][1], list[i][2], list[i][3]
        local fval = attrValueAsFloat(value, asInt)
        w_u16(attr + 0x30, defId)
        w_f32(attr + 0x34, fval)
        w_f32(attr + 0x38, fval)
    end
    w_u64(listAddr, n)
    w_u64(listAddr + 8, fresh)
    return true
end

local function replaceWeaponAttributes(item, paint, wear, seed, stickers, keychains)
    local list = collectSkinAttrs(paint, wear, seed, stickers, keychains)
    local attrVec = off.m_Attributes or 8
    local listOff = off.m_AttributeList or 520
    local netOff = off.m_NetworkedDynamicAttributes or 640
    local ok = writeAttrBlock(item + listOff + attrVec, list)
    local okNet = writeAttrBlock(item + netOff + attrVec, list)
    return ok or okNet
end

local function syncAttributeList(item, listOffset, paint, seed, wear, createMissing, clearOnly)
    if type(listOffset) ~= "number" then return false end
    local addr = item + listOffset + off.m_Attributes
    local count = r_u32(addr)
    local ptr = r_ptr(addr + 8)
    if count > 32 or (count > 0 and not valid(ptr)) then return false end

    local defs = { 6, 7, 8 }
    local vals = {
        clearOnly and 0 or math.max(0, tonumber(paint) or 0),
        clearOnly and 0 or math.max(0, tonumber(seed) or 0),
        clearOnly and 0 or safeWear(wear),
    }
    local found = { false, false, false }
    for i = 0, count - 1 do
        local attr = ptr + i * ATTR_STRUCT
        local definition = r_u16(attr + 0x30)
        for wanted = 1, 3 do
            if definition == defs[wanted] then
                w_f32(attr + 0x34, vals[wanted])
                w_f32(attr + 0x38, vals[wanted])
                found[wanted] = true
            end
        end
    end
    if clearOnly or not createMissing then return true end

    local missing = 0
    for wanted = 1, 3 do if not found[wanted] then missing = missing + 1 end end
    if missing == 0 then return true end
    if count + missing > 32 then return false end

    local newCount = count + missing
    local newPtr = allocAttributes(ATTR_STRUCT * newCount)
    if not newPtr then return false end
    for q = 0, newCount * 9 - 1 do w_u64(newPtr + q * 8, 0) end
    if count > 0 then
        for q = 0, count * 9 - 1 do w_u64(newPtr + q * 8, r_u64(ptr + q * 8)) end
    end
    local at = count
    for wanted = 1, 3 do
        if not found[wanted] then
            local attr = newPtr + at * ATTR_STRUCT
            w_u16(attr + 0x30, defs[wanted])
            w_f32(attr + 0x34, vals[wanted])
            w_f32(attr + 0x38, vals[wanted])
            at = at + 1
        end
    end
    w_u64(addr + 8, newPtr)
    w_u64(addr, newCount)
    return true
end

local function syncWeaponAttributes(item, paint, wear, seed)
    local a = syncAttributeList(item, off.m_AttributeList, paint, seed, wear, true, false)
    syncAttributeList(item, off.m_NetworkedDynamicAttributes, paint, seed, wear, false, false)
    return a
end

local function attrClear(item)
    syncAttributeList(item, off.m_AttributeList, 0, 0, 0, false, true)
end

local function gloveAttrSet(item, paint, seed, wear)
    if (tonumber(paint) or 0) <= 0 then
        attrClear(item)
        return
    end
    syncAttributeList(item, off.m_AttributeList, paint, seed, wear, true, false)
end

local function meshMaskFor(paint)
    if paint and SKIN_LEGACY_PAINT[paint] then return 2 end
    return 1
end

local function sceneNode(ent)
    if not valid(ent) or not off.m_pGameSceneNode then return nil end
    local node = r_ptr(ent + off.m_pGameSceneNode)
    return valid(node) and node or nil
end

local function writeMeshGroup(ent, mask)
    local node = sceneNode(ent)
    if not node or not off.m_modelState or not off.m_MeshGroupMask then return end
    pcall(function() w_u64(node + off.m_modelState + off.m_MeshGroupMask, mask) end)
end

local function currentMeshGroup(ent)
    local node = sceneNode(ent)
    if not node or not off.m_modelState or not off.m_MeshGroupMask then return nil end
    local v
    pcall(function() v = tonumber(r_u64(node + off.m_modelState + off.m_MeshGroupMask)) end)
    return v
end

local function applyMeshMask(ent, mask, notify)
    if not valid(ent) or not off.m_modelState or not off.m_MeshGroupMask then return end
    local node = sceneNode(ent)
    if not node then return end
    if notify and fnptr.set_mesh_mask then
        if currentMeshGroup(ent) == mask then
            local alt = (mask == 2) and 1 or 2
            pcall(function() fnptr.set_mesh_mask(ffi.cast("void*", node), alt) end)
        end
        local ok = pcall(function() fnptr.set_mesh_mask(ffi.cast("void*", node), mask) end)
        if ok then return end
    end
    writeMeshGroup(ent, mask)
end

local vmQueryReady = false
local function vmReadable(address, bytes)
    if not valid(address) then return false end
    if not vmQueryReady then
        pcall(function() ffi.cdef("size_t VirtualQuery(const void*, void*, size_t);") end)
        vmQueryReady = true
    end
    local info = ffi.new("uint8_t[48]")
    local ok, result = pcall(function()
        return tonumber(ffi.C.VirtualQuery(ffi.cast("void*", address), info, 48))
    end)
    if not ok or not result or result == 0 then return false end
    local base = tonumber(ffi.cast("uintptr_t*", info)[0])
    local region = tonumber(ffi.cast("size_t*", info + 24)[0])
    local state = tonumber(ffi.cast("uint32_t*", info + 32)[0])
    local protect = tonumber(ffi.cast("uint32_t*", info + 36)[0])
    bytes = bytes or 8
    return state == 0x1000 and band(protect, 0x101) == 0
        and address >= base and address + bytes <= base + region
end

local function findHudViewmodel(wpn, pawn, elist)
    if not valid(pawn) or not valid(elist) then return nil end
    if not off.m_hHudModelArms or not off.m_pChild or not off.m_pNextSibling or not off.m_pOwner then return nil end
    if not vmReadable(pawn + off.m_hHudModelArms, 4) then return nil end
    local arms = handleToEntity(elist, r_u32(pawn + off.m_hHudModelArms))
    if not arms or not vmReadable(arms + off.m_pGameSceneNode, 8) then return nil end
    local armsNode = r_ptr(arms + off.m_pGameSceneNode)
    if not vmReadable(armsNode + off.m_pChild, 8) then return nil end
    local node = r_ptr(armsNode + off.m_pChild)
    for _ = 1, 24 do
        if not vmReadable(node, 8) then break end
        if vmReadable(node + off.m_pOwner, 8) then
            local owner = r_ptr(node + off.m_pOwner)
            if owner == wpn then return owner end
            if valid(owner) and vmReadable(owner + off.m_hOwnerEntity, 4) then
                local owned = handleToEntity(elist, r_u32(owner + off.m_hOwnerEntity))
                if owned == wpn then return owner end
            end
        end
        if not vmReadable(node + off.m_pNextSibling, 8) then break end
        node = r_ptr(node + off.m_pNextSibling)
        if not valid(node) then break end
    end
    return nil
end

local function applyViewmodelMesh(wpn, mask, elist, notify, pawn)
    local viewmodel = findHudViewmodel(wpn, pawn, elist)
    if viewmodel then applyMeshMask(viewmodel, mask, notify) end
    if not elist or not off.m_hViewmodelAttachment then return end
    if not vmReadable(wpn + off.m_hViewmodelAttachment, 4) then return end
    local h = r_u32(wpn + off.m_hViewmodelAttachment)
    if h == 0 or h == 0xFFFFFFFF then return end
    local attachment = handleToEntity(elist, h)
    if attachment and attachment ~= viewmodel then applyMeshMask(attachment, mask, notify) end
end

local function applyWeaponMeshes(wpn, paint, elist, notify, pawn)
    local mask = meshMaskFor(paint)
    applyMeshMask(wpn, mask, notify)
    applyViewmodelMesh(wpn, mask, elist, notify, pawn)
    return mask
end

local function refreshEcon(wpn)
    vcallBool(wpn, 10, true)
    vcallBool(wpn, 111, true)
end

local function finalizeWeaponSkin(wpn)
    local update = vfunc(wpn, 111)
    if update then
        pcall(function()
            ffi.cast("void(*)(void*, int)", update)(ffi.cast("void*", wpn), 1)
        end)
    end
    vcallVoid(wpn, 107)
    if off.m_bAttributesInitialized then w_u8(wpn + off.m_bAttributesInitialized, 1) end
end

local function writeItemCustomName(item, name)
    if not name or name == "" then return end
    if type(off.m_szCustomName) ~= "number" then return end
    local s = tostring(name)
    if #s > 160 then s = s:sub(1, 160) end
    local addr = item + off.m_szCustomName
    for i = 1, #s do
        w_u8(addr + (i - 1), string.byte(s, i))
    end
    w_u8(addr + #s, 0)
end

local function resolveWeaponHudName(def, paint, name)
    if type(name) ~= "string" or name == "" then return name end
    if name:find(" | ", 1, true) then return name end
    if type(def) ~= "number" then return name end
    local finish = paintNameFor(def, paint)
    if name ~= finish then return name end
    for i = 1, #SKIN_WEAPONS do
        if SKIN_WEAPONS[i].def == def then
            return SKIN_WEAPONS[i].name .. " | " .. finish
        end
    end
    return name
end

local QUALITY_UNUSUAL = 3

local addKeychainWarned = false
local function applyWeaponKeychain(wpn, item, keychains)
    if not keychains or #keychains < 1 then return end
    local id = 0
    for i = 1, #keychains do
        id = tonumber(keychains[i].id or keychains[i].sticker_id) or 0
        if id > 0 then break end
    end
    if id <= 0 then return end
    if not fnptr.add_keychain then
        if not addKeychainWarned then
            addKeychainWarned = true
            M:Notify("charm spawn unavailable — attrs still written", "warning")
        end
        return
    end
    if not (valid(wpn) and valid(item)) then return end
    pcall(function()
        fnptr.add_keychain(ffi.cast("void*", wpn), ffi.cast("void*", item), 0)
    end)
end

local function clearKeychainModules(root)
    if not valid(root) then return end
    if type(off.m_nKeychainDefID) ~= "number" then return end
    if type(off.m_pGameSceneNode) ~= "number" then return end
    if type(off.m_pChild) ~= "number" or type(off.m_pNextSibling) ~= "number" then return end
    if type(off.m_pOwner) ~= "number" then return end
    local node = r_ptr(root + off.m_pGameSceneNode)
    if not valid(node) then return end
    local child = r_ptr(node + off.m_pChild)
    for _ = 1, 48 do
        if not valid(child) then break end
        local ent = r_ptr(child + off.m_pOwner)
        if valid(ent) and ent ~= root then
            local kid = 0
            pcall(function() kid = r_u32(ent + off.m_nKeychainDefID) end)
            if kid and kid > 0 and kid < 200000 then
                pcall(function()
                    w_u32(ent + off.m_nKeychainDefID, 0)
                    if type(off.m_nKeychainSeed) == "number" then
                        w_u32(ent + off.m_nKeychainSeed, 0)
                    end
                end)
                pcall(applyMeshMask, ent, 0, false)
            end
        end
        child = r_ptr(child + off.m_pNextSibling)
    end
end

local function stripWeaponKeychains(wpn, elist, pawn)
    pcall(clearKeychainModules, wpn)
    if valid(pawn) and valid(elist) then
        local vm = findHudViewmodel(wpn, pawn, elist)
        if vm then pcall(clearKeychainModules, vm) end
    end
end

local function processWeapon(wpn, paint, wear, seed, def, stickers, keychains, name)
    local item = itemPtr(wpn)
    if type(def) ~= "number" then
        pcall(function() def = r_u16(item + off.m_iItemDefinitionIndex) end)
    end
    markItemCustom(item, paint)
    writeFallback(wpn, paint, wear, seed)
    if not replaceWeaponAttributes(item, paint, wear, seed, stickers, keychains) then
        syncWeaponAttributes(item, paint, wear, seed)
    end
    writeItemCustomName(item, resolveWeaponHudName(def, paint, name))
    if keychains and #keychains > 0 then
        pcall(applyWeaponKeychain, wpn, item, keychains)
    end
    if off.m_bAttributesInitialized then w_u8(wpn + off.m_bAttributesInitialized, 0) end
end

local function applyKnifeModel(wpn)
    if fnptr.set_model and off.m_szWorldModel then
        local vdata = r_ptr(wpn + off.m_nSubclassID + 8)
        if valid(vdata) then
            local s = read_cstr(vdata + off.m_szWorldModel, 160)
            if s:find("models/") and s:find("%.vmdl") then
                pcall(function() fnptr.set_model(ffi.cast("void*", wpn), s) end)
            end
        end
    end
    applyMeshMask(wpn, 2, true)
end

local function setKnifeSubclass(wpn, defTarget, quality)
    local item = itemPtr(wpn)
    w_u16(item + off.m_iItemDefinitionIndex, defTarget)
    if off.m_iEntityQuality then w_i32(item + off.m_iEntityQuality, quality) end
    w_u32(wpn + off.m_nSubclassID, subclassHash(defTarget))
    if fnptr.update_subclass then
        pcall(function() fnptr.update_subclass(ffi.cast("void*", wpn)) end)
    end
    applyKnifeModel(wpn)
    return item
end

local function processKnife(wpn, defTarget, paint, wear, seed, stickers, keychains, name)
    local item = setKnifeSubclass(wpn, defTarget, QUALITY_UNUSUAL)
    markItemCustom(item, paint)
    writeFallback(wpn, paint, wear, seed)
    pcall(replaceWeaponAttributes, item, paint, wear, seed, stickers, keychains)
    writeItemCustomName(item, name)
    if keychains and #keychains > 0 then
        pcall(applyWeaponKeychain, wpn, item, keychains)
    end
    refreshEcon(wpn)
    vcallVoid(wpn, 195)
end

local function restoreKnife(wpn, pawn)
    local defTarget = (r_u8(pawn + off.m_iTeamNum) == 2) and 59 or 42
    setKnifeSubclass(wpn, defTarget, 0)
    writeFallback(wpn, 0, 0.0001, 0)
    refreshEcon(wpn)
    vcallVoid(wpn, 195)
end

local function localAccountId()
    if not clientBase or not off.dwLocalPlayerController or not off.m_steamID then return 0 end
    local acc = 0
    pcall(function()
        local ctrl = r_ptr(clientBase + off.dwLocalPlayerController)
        if not valid(ctrl) then return end
        acc = tonumber(r_u64(ctrl + off.m_steamID) % 0x100000000)
    end)
    return acc or 0
end

local gloveKey, gloveApply, gloveNext = nil, 0, 0
local gloveWrote = {}

local function applyGloves(pawn, gdef, paint, wear, seed, name)
    gloveWrote[gdef] = true
    local g = pawn + off.m_EconGloves
    local acc = localAccountId()
    w_u8(g + off.m_bInitialized, 0)
    w_u16(g + off.m_iItemDefinitionIndex, gdef)
    if off.m_iEntityQuality then w_i32(g + off.m_iEntityQuality, 3) end
    w_u32(g + off.m_iItemIDHigh, 0xFFFFFFFF)
    if off.m_iItemIDLow then w_u32(g + off.m_iItemIDLow, 0xFFFFFFFF) end
    if off.m_iAccountID then w_u32(g + off.m_iAccountID, acc) end
    if off.m_OriginalOwnerXuidLow then w_u32(g + off.m_OriginalOwnerXuidLow, acc) end
    gloveAttrSet(g, paint, seed, wear)
    writeItemCustomName(g, name)
    if off.m_bDisallowSOC then w_u8(g + off.m_bDisallowSOC, 0) end
    if off.m_bRestoreCustomMat then w_u8(g + off.m_bRestoreCustomMat, 1) end
    w_u8(g + off.m_bInitialized, 1)
    if off.m_bNeedToReApplyGloves then w_u8(pawn + off.m_bNeedToReApplyGloves, 1) end
    if fnptr.set_body_group then
        pcall(function()
            fnptr.set_body_group(ffi.cast("void*", pawn), "first_or_third_person", 1)
        end)
    end
end

local function resetGloves(pawn)
    local g = pawn + off.m_EconGloves
    w_u8(g + off.m_bInitialized, 0)
    w_u16(g + off.m_iItemDefinitionIndex, 0)
    attrClear(g)
    if off.m_bNeedToReApplyGloves then w_u8(pawn + off.m_bNeedToReApplyGloves, 1) end
    if fnptr.set_body_group then
        pcall(function()
            fnptr.set_body_group(ffi.cast("void*", pawn), "first_or_third_person", 1)
        end)
    end
end

local applied, appliedAgent = {}, nil
local nextTick, stickyNext = 0, 0
local respawnRetries, lastPawn, lastTeam = 0, nil, nil
local hadAlivePawn = false

local function resetSession()
    applied = {}
    appliedAgent = nil
    gloveKey, gloveApply = nil, 0
    respawnRetries = 0
    lastPawn, lastTeam = nil, nil
    hadAlivePawn = false
end
requestReapply = resetSession

local function nowTime()
    local t
    pcall(function() t = globals.RealTime() end)
    return tonumber(t) or 0
end

local function engineInitStep()
    Engine.status = "downloading schema..."
    if not fetchSchemaOffsets() then
        Engine.status = "no schema offsets (enable Lua HTTP)"
        return false
    end
    applyStaticOffsets()
    local complete, missing = offsetsComplete()
    if not complete then
        Engine.status = "missing offset: " .. tostring(missing)
        return false
    end

    if not resolveGlobals() then
        fetchGlobalOffsets()
        if not off.dwEntityList or not off.dwLocalPlayerController then
            Engine.status = "entity list not found"
            return false
        end
    end
    if not resolveFunctions() then
        Engine.status = "signature scan failed"
        return false
    end

    Engine.ready = true
    Engine.status = "ready"
    return true
end

local function engineInit()
    if Engine.ready then return true end
    if Engine.busy then return false end
    if nowTime() < Engine.lastTry then return false end

    Engine.busy = true
    local ok, res = pcall(engineInitStep)
    Engine.busy = false
    Engine.lastTry = nowTime() + 5.0
    if not ok then
        Engine.status = "init error: " .. tostring(res)
        return false
    end
    return res == true
end

local function teamName(team)
    if team == 3 then return "CT" end
    if team == 2 then return "T" end
    return nil
end

local function runTick()
    Diag.ticks = Diag.ticks + 1
    if not SkinOn then
        Diag.stage = "disabled"
        if next(applied) ~= nil or appliedAgent then resetSession() end
        return
    end
    if not Engine.ready then Diag.stage = "engine not ready"; return end
    if not inGame() then
        Diag.stage = "not in a game"
        if next(applied) ~= nil then resetSession() end
        return
    end

    local elist = r_ptr(clientBase + off.dwEntityList)
    if not valid(elist) then Diag.stage = "no entity list"; return end
    local ctrl = r_ptr(clientBase + off.dwLocalPlayerController)
    if not valid(ctrl) then Diag.stage = "no local controller"; return end
    local myHandle = r_u32(ctrl + off.m_hPlayerPawn)
    local pawn = handleToEntity(elist, myHandle)
    if not pawn or not pawnAlive(pawn) then
        Diag.stage = "no living pawn"
        hadAlivePawn = false
        if next(applied) ~= nil then applied = {} end
        gloveApply = 0
        return
    end

    local team = r_u8(pawn + off.m_iTeamNum)
    local tk = teamName(team)
    if not tk then Diag.stage = "not on a team"; return end
    local sel = Sel[tk]
    Diag.stage = "running on " .. tk

    if pawn ~= lastPawn or team ~= lastTeam or not hadAlivePawn then
        lastPawn, lastTeam = pawn, team
        applied = {}
        appliedAgent = nil
        gloveKey = nil
        respawnRetries = 5
    end
    hadAlivePawn = true

    local now = nowTime()

    if sel.agentPath then
        if appliedAgent ~= sel.agentPath then
            if safeSetModel(pawn, sel.agentPath) then
                appliedAgent = sel.agentPath
                if gloveApply < 3 then gloveApply = 3 end
                gloveNext = now
            end
        end
    elseif appliedAgent then
        appliedAgent = nil
    end

    if sel.gloveDef and sel.gloveDef > 0 and sel.glove.paint > 0 then
        local key = table.concat({ tostring(pawn), team, sel.gloveDef,
            sel.glove.paint, sel.glove.seed, math.floor(sel.glove.wear * 100000) }, "|")
        if key ~= gloveKey then
            gloveKey = key
            gloveApply = 5
            gloveNext = now
        end
        local cur = r_u16(pawn + off.m_EconGloves + off.m_iItemDefinitionIndex)
        local init = r_u8(pawn + off.m_EconGloves + off.m_bInitialized)
        if gloveApply <= 0 and (cur ~= sel.gloveDef or init == 0) then
            gloveApply = 2
        end
        if gloveApply > 0 and now >= gloveNext then
            pcall(applyGloves, pawn, sel.gloveDef, sel.glove.paint, sel.glove.wear, sel.glove.seed, sel.glove.name)
            gloveApply = gloveApply - 1
            gloveNext = now + 0.3
        end
    else
        gloveKey, gloveApply = nil, 0
        local cur = r_u16(pawn + off.m_EconGloves + off.m_iItemDefinitionIndex)
        if cur ~= 0 and gloveWrote[cur] then
            pcall(resetGloves, pawn)
        end
    end

    local sticky = now >= stickyNext
    if sticky then stickyNext = now + 1.0 end

    local ws = r_ptr(pawn + off.m_pWeaponServices)
    if not valid(ws) then Diag.stage = "no weapon services"; return end
    local count = r_i32(ws + off.m_hMyWeapons)
    local arr = r_ptr(ws + off.m_hMyWeapons + 8)
    if not valid(arr) or count <= 0 or count > 64 then
        Diag.stage = "no weapon list (" .. tostring(count) .. ")"
        return
    end

    local touched = false
    local live = {}

    for i = 0, count - 1 do
        local wpn = handleToEntity(elist, r_u32(arr + i * 4))
        if wpn and band(r_u32(wpn + off.m_hOwnerEntity), 0x7FFF) == band(myHandle, 0x7FFF) then
            live[wpn] = true
            local item = itemPtr(wpn)
            local def = r_u16(item + off.m_iItemDefinitionIndex)

            if isKnifeDef(def) then
                local kdef, kc = sel.knifeDef, sel.knife
                if kdef and kc.paint > 0 then
                    local key = table.concat({ "k", kdef, kc.paint,
                        math.floor(kc.wear * 100000), kc.seed, decorFingerprint(kc) }, "|")
                    if applied[wpn] ~= key then
                        pcall(processKnife, wpn, kdef, kc.paint, kc.wear, kc.seed, kc.stickers, kc.keychains, kc.name)
                        pcall(applyViewmodelMesh, wpn, 2, elist, true, pawn)
                        applied[wpn] = key
                        touched = true
                    elseif sticky then
                        pcall(writeFallback, wpn, kc.paint, kc.wear, kc.seed)
                        pcall(applyMeshMask, wpn, 2, false)
                    end
                elseif applied[wpn] then
                    pcall(restoreKnife, wpn, pawn)
                    applied[wpn] = nil
                    touched = true
                end
            else
                local e = WeaponSel[tk] and WeaponSel[tk][def]
                if e and e.paint > 0 then
                    local key = table.concat({ "w", def, e.paint,
                        math.floor(e.wear * 100000), e.seed, decorFingerprint(e) }, "|")
                    if applied[wpn] ~= key then
                        pcall(processWeapon, wpn, e.paint, e.wear, e.seed, def, e.stickers, e.keychains, e.name)
                        pcall(applyWeaponMeshes, wpn, e.paint, elist, true, pawn)
                        pcall(finalizeWeaponSkin, wpn)
                        if not (e.keychains and #e.keychains > 0) then
                            pcall(stripWeaponKeychains, wpn, elist, pawn)
                        end
                        applied[wpn] = key
                        touched = true
                    elseif sticky then
                        pcall(writeFallback, wpn, e.paint, e.wear, e.seed)
                        pcall(replaceWeaponAttributes, item, e.paint, e.wear, e.seed, e.stickers, e.keychains)
                        if not (e.keychains and #e.keychains > 0) then
                            pcall(stripWeaponKeychains, wpn, elist, pawn)
                        end
                        if e.name then
                            pcall(writeItemCustomName, item, resolveWeaponHudName(def, e.paint, e.name))
                        end
                        pcall(applyMeshMask, wpn, meshMaskFor(e.paint), false)
                    end
                end
            end
        end
    end

    for wpn in pairs(applied) do
        if not live[wpn] then applied[wpn] = nil end
    end

    local n = 0
    for _ in pairs(applied) do n = n + 1 end
    Diag.items = n + (appliedAgent and 1 or 0)

    if respawnRetries > 0 and sticky then
        respawnRetries = respawnRetries - 1
        applied = {}
    end

    if touched then
        if fnptr.regen_skins then pcall(function() fnptr.regen_skins() end) end
        for i = 0, count - 1 do
            local wpn = handleToEntity(elist, r_u32(arr + i * 4))
            if wpn and applied[wpn] then
                local item = itemPtr(wpn)
                local def = r_u16(item + off.m_iItemDefinitionIndex)
                if isKnifeDef(def) then
                    pcall(applyMeshMask, wpn, 2, true)
                else
                    local e = WeaponSel[tk] and WeaponSel[tk][def]
                    if e then
                        pcall(applyWeaponMeshes, wpn, e.paint, elist, true, pawn)
                    end
                end
            end
        end
    end
end

local skinUid = (tostring({}):gsub("%W", "")):sub(-8)
local SKIN_MOVE_ID = "daizml_skin_m_" .. skinUid
local SKIN_EVENT_ID = "daizml_skin_e_" .. skinUid
local SKIN_BOOT_ID = "daizml_skin_b_" .. skinUid
pcall(function() callbacks.Unregister("CreateMove", "daizml_skin_changer") end)
pcall(function() callbacks.Unregister("FireGameEvent", "daizml_skin_changer_events") end)
pcall(function() callbacks.Unregister("Draw", "daizml_skin_boot") end)

local skinBootPending = false
callbacks.Register("Draw", SKIN_BOOT_ID, function()
    if skinEnable and skinEnable.Get then
        SkinOn = skinEnable:Get() and true or false
    end
    if not SkinOn then
        skinBootPending = false
        return
    end
    if Engine.ready then
        skinBootPending = false
        return
    end
    if Engine.busy then
        skinBootPending = false
    elseif skinBootPending then
        skinBootPending = false
        pcall(engineInit)
    elseif nowTime() >= Engine.lastTry then
        if Engine.status == "not started" or Engine.status == "" then
            Engine.status = "resolving offsets..."
        end
        skinBootPending = true
    end
end)

ctrlSec:Button("Retry engine setup", function()
    Engine.ready = false
    Engine.busy = false
    Engine.lastTry = 0
    Engine.status = "not started"
    skinBootPending = false
    if skinEnable and skinEnable.Get then
        SkinOn = skinEnable:Get() and true or false
    end
    if engineInit() then M:Success("skin engine ready") else M:Error(Engine.status) end
end)

callbacks.Register("CreateMove", SKIN_MOVE_ID, function()
    if skinEnable and skinEnable.Get then
        SkinOn = skinEnable:Get() and true or false
    end
    if not SkinOn then return end
    local now = nowTime()
    if now < nextTick then
        if now + 1.0 < nextTick then resetSession() else return end
    end
    nextTick = now + 0.05
    pcall(runTick)
end)

callbacks.Register("FireGameEvent", SKIN_EVENT_ID, function(event)
    if not event then return end
    local name
    pcall(function() name = event:GetName() end)
    if name == "game_newmap" or name == "server_spawn"
        or name == "cs_game_disconnected" or name == "round_start" then
        resetSession()
    end
end)

end)() 

end 
local function daizInitParticleTester(particlesTab)
local PARTICLE_CATALOG_FILE = "DaizML_particle_catalog.txt"
local PARTICLE_FAVORITES_FILE = "DaizML_particle_favorites.txt"
local PARTICLE_CATALOG_URL = "https://raw.githubusercontent.com/whosdaiz/AW-lua/main/DaizML_particle_catalog.txt"
local PARTICLE_CATALOG_URL_ALT = "https://raw.githubusercontent.com/whosdaiz/AW-lua/refs/heads/main/DaizML_particle_catalog.txt"

local ParticleCatalog = {
    all = {},
    filtered = {},
    display = {},
    filter = "",
    status = "catalog not loaded",
    favSet = {},
    favList = {},
    fetching = false,
}

local function particleCatalogDisplayPath(path)
    path = tostring(path or "")
    if path:sub(1, 10) == "particles/" then
        return path:sub(11)
    end
    return path
end

local function particleNormalizePath(path)
    path = tostring(path or ""):gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
    if path ~= "" and path:sub(1, 10) ~= "particles/" then
        path = "particles/" .. path
    end
    return path
end

local function particleIsFavorite(path)
    path = particleNormalizePath(path)
    return path ~= "" and ParticleCatalog.favSet[path] == true
end

local function particleSaveFavorites()
    local list = {}
    for i = 1, #ParticleCatalog.favList do
        list[i] = ParticleCatalog.favList[i]
    end
    table.sort(list)
    ParticleCatalog.favList = list
    local body = (#list > 0) and (table.concat(list, "\n") .. "\n") or ""
    return fileWrite(PARTICLE_FAVORITES_FILE, body)
end

local function particleLoadFavorites()
    local set, list = {}, {}
    local text = fileRead(PARTICLE_FAVORITES_FILE)
    if type(text) == "string" and text ~= "" then
        for line in text:gmatch("[^\r\n]+") do
            local path = particleNormalizePath(line)
            if path ~= "" and not set[path] then
                set[path] = true
                list[#list + 1] = path
            end
        end
    end
    table.sort(list)
    ParticleCatalog.favSet = set
    ParticleCatalog.favList = list
    return #list
end

local function particleAddFavorite(path)
    path = particleNormalizePath(path)
    if path == "" then return false, "no path" end
    if ParticleCatalog.favSet[path] then return true, "already favourited" end
    ParticleCatalog.favSet[path] = true
    ParticleCatalog.favList[#ParticleCatalog.favList + 1] = path
    particleSaveFavorites()
    return true, "added favourite"
end

local function particleRemoveFavorite(path)
    path = particleNormalizePath(path)
    if path == "" then return false, "no path" end
    if not ParticleCatalog.favSet[path] then return false, "not in favourites" end
    ParticleCatalog.favSet[path] = nil
    local list = {}
    for i = 1, #ParticleCatalog.favList do
        local p = ParticleCatalog.favList[i]
        if p ~= path then list[#list + 1] = p end
    end
    ParticleCatalog.favList = list
    particleSaveFavorites()
    return true, "removed favourite"
end

local function particleGuessMode(path)
    path = tostring(path or ""):lower()
    if path:find("spectator_utility_trail", 1, true) then
        return "beam", "B", "use Spawn beam / recommended"
    end
    if path:find("weapon_tracers", 1, true)
        or path:find("/tracers_", 1, true)
        or path:find("_tracers_", 1, true)
        or path:find("tracer", 1, true) then
        return "trail", "T", "use Spawn trail — should travel eye→target"
    end
    if path:find("trail", 1, true) or path:find("beam", 1, true) or path:find("rope", 1, true) then
        return "maybe", "t", "name says trail — try trail+beam; often still stuck"
    end
    return "point", "P", "use Spawn point — stays in place (normal)"
end

local function particleTaggedDisplay(path)
    local _, tag = particleGuessMode(path)
    local star = particleIsFavorite(path) and "*" or ""
    return string.format("[%s%s] %s", tag, star, particleCatalogDisplayPath(path))
end

local function particleCatalogDefaultText()
    return ''
end

local function particleParseCatalogText(text)
    local all = {}
    if type(text) ~= 'string' or text == '' then return all end
    for line in text:gmatch('[^\r\n]+') do
        line = line:gsub('^%s+', ''):gsub('%s+$', '')
        if line ~= '' and line:sub(1, 1) ~= '#' then
            if line:sub(1, 10) ~= 'particles/' then
                line = 'particles/' .. line
            end
            all[#all + 1] = line
        end
    end
    return all
end

local function particleReadLocalCatalog()
    local text = fileRead(PARTICLE_CATALOG_FILE)
    if type(text) == 'string' and text:find('particles/', 1, true) then
        return text
    end
    return nil
end

local function particleApplyCatalogText(text, source)
    particleLoadFavorites()
    local all = particleParseCatalogText(text)
    if #all == 0 and #ParticleCatalog.favList > 0 then
        all = {}
        for i = 1, #ParticleCatalog.favList do
            all[i] = ParticleCatalog.favList[i]
        end
        source = source or 'favourites'
    end
    ParticleCatalog.all = all
    ParticleCatalog.filtered = all
    local display = {}
    for i = 1, #all do
        display[i] = particleTaggedDisplay(all[i])
    end
    ParticleCatalog.display = display
    ParticleCatalog.filter = ''
    if #all == 0 then
        ParticleCatalog.status = 'no catalog — enable Lua HTTP + Refresh catalog'
    else
        ParticleCatalog.status = string.format(
            '%d particles (%s)  %d favs',
            #all, tostring(source or 'local'), #ParticleCatalog.favList
        )
    end
    return #all
end

local function particleLoadCatalog()
    local text = particleReadLocalCatalog()
    if text then
        return particleApplyCatalogText(text, 'cache')
    end
    particleLoadFavorites()
    if #ParticleCatalog.favList > 0 then
        return particleApplyCatalogText('', 'favourites')
    end
    ParticleCatalog.all = {}
    ParticleCatalog.filtered = {}
    ParticleCatalog.display = {}
    ParticleCatalog.status = 'no cache — press Refresh catalog (needs Lua HTTP)'
    return 0
end

local function particleFetchCatalogFromGitHub(listHandle, modeIndex, filterText)
    local function flog(msg, kind)
        print('[DaizML][particles] ' .. tostring(msg))
        pcall(function()
            if type(particleLog) == 'function' then particleLog(msg, kind) end
        end)
        pcall(function()
            if M and M.Notify then M:Notify(tostring(msg), kind == 'error' and 'error' or 'info') end
        end)
    end

    local function finishWithBody(body, via)
        ParticleCatalog.fetching = false
        local btype = type(body)
        local blen = (btype == 'string') and #body or -1
        flog(string.format('http reply via=%s type=%s len=%s', tostring(via), btype, tostring(blen)), 'success')
        if btype ~= 'string' or blen < 32 or not body:find('particles/', 1, true) then
            local preview = (btype == 'string') and body:sub(1, 120) or tostring(body)
            ParticleCatalog.status = 'GitHub fetch failed'
            flog('bad body preview: ' .. preview, 'error')
            flog('Enable Settings → Lua → Allow Lua HTTP connections', 'error')
            return false
        end
        local wrote = fileWrite(PARTICLE_CATALOG_FILE, body)
        flog(wrote and ('wrote ' .. PARTICLE_CATALOG_FILE) or ('cache write failed: ' .. PARTICLE_CATALOG_FILE), wrote and 'success' or 'error')
        local n = particleApplyCatalogText(body, 'GitHub')
        flog(string.format('catalog ready: %d particles', n), 'success')
        if listHandle then
            pcall(function()
                particleApplyFilter(filterText or '', listHandle, modeIndex or 1)
            end)
        end
        return n > 0
    end

    if ParticleCatalog.fetching then
        flog('catalog fetch already in progress', 'error')
        return
    end
    if type(http) ~= 'table' or type(http.Get) ~= 'function' then
        flog('http.Get missing', 'error')
        return
    end

    ParticleCatalog.fetching = true
    ParticleCatalog.status = 'fetching catalog from GitHub…'
    flog('GET (sync) ' .. PARTICLE_CATALOG_URL, 'success')

    local body
    local okSync, syncErr = pcall(function()
        body = http.Get(PARTICLE_CATALOG_URL)
    end)
    if okSync and finishWithBody(body, 'sync') then
        return
    end
    if not okSync then
        flog('sync Get error: ' .. tostring(syncErr), 'error')
    end

    body = nil
    pcall(function() body = http.Get(PARTICLE_CATALOG_URL_ALT) end)
    if finishWithBody(body, 'sync-alt') then
        return
    end

    flog('trying async callback Get…', 'success')
    ParticleCatalog.fetching = true
    local gotAsync = false
    local okAsync, asyncErr = pcall(function()
        http.Get(PARTICLE_CATALOG_URL, function(data)
            gotAsync = true
            finishWithBody(data, 'async')
        end)
    end)
    if not okAsync then
        ParticleCatalog.fetching = false
        flog('async Get error: ' .. tostring(asyncErr), 'error')
        return
    end
    if not gotAsync then
        flog('async Get dispatched — wait a second, or check Lua HTTP setting', 'success')
    end
end

local function particleApplyFilter(filterText, listHandle, modeIndex)
    filterText = tostring(filterText or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    modeIndex = tonumber(modeIndex) or 1
    local modeWant = ({ [2] = "point", [3] = "trail", [4] = "maybe", [5] = "beam" })[modeIndex]
    local favOnly = (modeIndex == 6)
    ParticleCatalog.filter = filterText
    local all = ParticleCatalog.all
    local filtered, display = {}, {}
    for i = 1, #all do
        local p = all[i]
        local okText = (filterText == "") or (p:lower():find(filterText, 1, true) ~= nil)
        local okFav = (not favOnly) or particleIsFavorite(p)
        if okText and okFav then
            local mode = particleGuessMode(p)
            if (not modeWant) or mode == modeWant then
                filtered[#filtered + 1] = p
                display[#display + 1] = particleTaggedDisplay(p)
            end
        end
    end
    if favOnly then
        local seen = {}
        for i = 1, #filtered do seen[filtered[i]] = true end
        local extra = {}
        for i = 1, #ParticleCatalog.favList do
            local p = ParticleCatalog.favList[i]
            if not seen[p] then
                local okText = (filterText == "") or (p:lower():find(filterText, 1, true) ~= nil)
                if okText then extra[#extra + 1] = p end
            end
        end
        if #extra > 0 then
            local merged, mergedDisp = {}, {}
            for i = 1, #extra do
                merged[#merged + 1] = extra[i]
                mergedDisp[#mergedDisp + 1] = particleTaggedDisplay(extra[i])
            end
            for i = 1, #filtered do
                merged[#merged + 1] = filtered[i]
                mergedDisp[#mergedDisp + 1] = display[i]
            end
            filtered, display = merged, mergedDisp
        end
    end
    ParticleCatalog.filtered = filtered
    ParticleCatalog.display = display
    if listHandle and listHandle.SetItems then
        listHandle:SetItems(display, 1)
    end
    if favOnly then
        ParticleCatalog.status = string.format("%d favourites shown  (%d saved)", #filtered, #ParticleCatalog.favList)
    elseif filterText == "" and not modeWant then
        ParticleCatalog.status = string.format(
            "%d particles  %d favs  *=favourite",
            #filtered, #ParticleCatalog.favList
        )
    else
        ParticleCatalog.status = string.format("%d / %d shown  (%d favs)", #filtered, #all, #ParticleCatalog.favList)
    end
end

local ParticleFFI = {
    ok = false,
    err = nil,
    IParticleManager = nil,
    IGameParticleManager = nil,
    create_mode = nil,
}

local function particleLog(msg, kind)
    msg = tostring(msg or "")
    print("[DaizML][particles] " .. msg)
    if kind == "error" or kind == "success" then
        if M and M.Notify then M:Notify(msg, kind) end
    end
end

local function particleFindPattern(label, patterns)
    for i = 1, #patterns do
        local addr
        pcall(function() addr = mem.FindPattern("client.dll", patterns[i]) end)
        if addr and addr ~= ffi.NULL then
            return addr, i
        end
    end
    return nil, nil
end

local function particleRipGlobal(addr)
    local disp = ffi.cast("int32_t*", addr + 3)[0]
    return ffi.cast("void**", addr + 7 + disp)
end

local function particleVtableOk(p)
    if not p or p == ffi.NULL then return false end
    local ok = false
    pcall(function()
        local vt = ffi.cast("void***", p)[0]
        ok = vt ~= nil and vt ~= ffi.NULL and vt[0] ~= nil and vt[0] ~= ffi.NULL
    end)
    return ok
end

local function particleMakeGetterFromAddr(addr, patIndex)
    local b0 = ffi.cast("uint8_t*", addr)[0]
    local b1 = ffi.cast("uint8_t*", addr)[1]
    local b2 = ffi.cast("uint8_t*", addr)[2]

    if b0 == 0xE8 then
        local rel = ffi.cast("int32_t*", addr + 1)[0]
        local abs = addr + 5 + rel
        local t0 = ffi.cast("uint8_t*", abs)[0]
        local t1 = ffi.cast("uint8_t*", abs)[1]
        local t2 = ffi.cast("uint8_t*", abs)[2]
        if t0 == 0x48 and t1 == 0x8B and (t2 == 0x05 or t2 == 0x0D) then
            local pp = particleRipGlobal(abs)
            return function()
                local p
                pcall(function() p = pp[0] end)
                return p
            end
        end
        local fn = ffi.cast("void*(__fastcall*)()", abs)
        return function()
            local p
            pcall(function() p = fn() end)
            return p
        end
    end

    if b0 == 0x48 and b1 == 0x8B and (b2 == 0x05 or b2 == 0x0D) then
        local pp = particleRipGlobal(addr)
        return function()
            local p
            pcall(function() p = pp[0] end)
            return p
        end
    end

    local fn = ffi.cast("void*(__fastcall*)()", addr)
    return function()
        local p
        pcall(function() p = fn() end)
        return p
    end
end

local function particleInitFFI()
    if ParticleFFI.ok then return true end
    ParticleFFI.err = nil

    local ok, err = xpcall(function()
        assert(ffi, "ffi is not available — enable FFI in Aimware Lua settings")
        assert(mem and mem.FindPattern, "mem.FindPattern missing")

        if not pcall(ffi.sizeof, "struct DaizML_CParticleInformation") then
            ffi.cdef([[
                typedef struct DaizML_Vector {
                    float x, y, z;
                } DaizML_Vector;

                typedef struct DaizML_CBindingData {
                    void* pData;
                    uint64_t nUnknown;
                    uint64_t nUnknown2;
                    uint32_t* pRefCount;
                } DaizML_CBindingData;

                typedef struct DaizML_CStrongHandle {
                    struct DaizML_CBindingData* pBinding;
                } DaizML_CStrongHandle;

                typedef struct DaizML_CParticleColor {
                    float r, g, b;
                } DaizML_CParticleColor;

                typedef struct DaizML_CParticleEffect {
                    const char* szName;
                    char pad_01[0x30];
                } DaizML_CParticleEffect;

                typedef struct DaizML_CParticleInformation {
                    float flTime;
                    float flWidth;
                    float flUnknown;
                } DaizML_CParticleInformation;
            ]])
        end

        if not pcall(ffi.sizeof, "struct DaizML_CParticleDataAG2") then
            ffi.cdef([[
                typedef struct DaizML_CParticleDataAG2 {
                    struct DaizML_Vector* vecPositions;
                    char pad_01[0x74];
                    float* flTimes;
                    void* pUnk1;
                    char pad_02[0x28];
                    float* flTimes2;
                    char pad_03[0x98];
                    void* pUnk2;
                } DaizML_CParticleDataAG2;
            ]])
        end

        local ppParticleManager, ipmPat = particleFindPattern("IParticleManager", {
            "48 8B 0D ?? ?? ?? ?? 4C 8D 85 ?? ?? ?? ?? 48 8D 54 24", 
            "48 8B 0D ?? ?? ?? ?? 4C 8D 85",
            "48 8B 05 ?? ?? ?? ?? 48 8B 08 48 8B 59 68", 
        })
        assert(ppParticleManager, "particle manager pattern not found")
        local pParticleMgrPtr = particleRipGlobal(ppParticleManager)

        local snapIdx = (ipmPat and ipmPat <= 2) and 41 or 42
        local drawIdx = (ipmPat and ipmPat <= 2) and 42 or 43

        local IParticleManager = setmetatable({
            pPatricleManager = nil,
            ppPatricleManager = pParticleMgrPtr,
            snapshot_vfunc = snapIdx,
            draw_vfunc = drawIdx,
        }, {
            __index = {
                Get = function(this) return this.pPatricleManager end,
                Update = function(this)
                    local p
                    pcall(function() p = this.ppPatricleManager[0] end)
                    this.pPatricleManager = p
                end,
                IsValid = function(this)
                    return particleVtableOk(this.pPatricleManager)
                end,
                CallVFunc = function(this, nIndex, szType, ...)
                    if not this:IsValid() then return nil end
                    local pVtable = ffi.cast("void***", this:Get())
                    return ffi.cast(szType, pVtable[0][nIndex])(this:Get(), ...)
                end,
                CreateSnapshot = function(this, pSnapShotHandle)
                    if not this:IsValid() then return false end
                    local pUtlStringData = ffi.new("int64_t[1]")
                    local idx = this.snapshot_vfunc or 42
                    local okCall = pcall(function()
                        this:CallVFunc(idx, "void(__thiscall*)(void*, struct DaizML_CStrongHandle*, int64_t*)", pSnapShotHandle, pUtlStringData)
                    end)
                    return okCall
                end,
                Draw = function(this, pSnapShotHandle, nCount, pEffectData)
                    if not this:IsValid() then return false end

                    local candidates = {}
                    pcall(function()
                        local binding = pSnapShotHandle[0].pBinding
                        if binding and binding ~= ffi.NULL then
                            candidates[#candidates + 1] = ffi.cast("void*", binding)
                            if binding.pData and binding.pData ~= ffi.NULL then
                                candidates[#candidates + 1] = binding.pData
                            end
                        end
                    end)
                    for i = 1, #candidates do
                        local snap = candidates[i]
                        local okSnap = pcall(function()
                            local vt = ffi.cast("void***", snap)[0]
                            assert(vt and vt ~= ffi.NULL and vt[1] ~= nil and vt[1] ~= ffi.NULL)
                            local fn = ffi.cast("uintptr_t", vt[1])
                            assert(fn > 0x10000ULL)
                            ffi.cast("void(__fastcall*)(void*, int, void*)", vt[1])(snap, nCount, pEffectData)
                        end)
                        if okSnap then
                            return true
                        end
                    end

                    local idx = this.draw_vfunc or 42
                    local okU64 = pcall(function()
                        local raw = ffi.new("uint64_t[1]")
                        raw[0] = ffi.cast("uintptr_t", pSnapShotHandle[0].pBinding)
                        local pVtable = ffi.cast("void***", this:Get())
                        ffi.cast("void(__fastcall*)(void*, uint64_t*, uint32_t, void*)", pVtable[0][idx])(
                            this:Get(), raw, nCount, pEffectData
                        )
                    end)
                    if okU64 then
                        return true
                    end

                    local okCall = pcall(function()
                        this:CallVFunc(idx, "void(__thiscall*)(void*, struct DaizML_CStrongHandle*, int, void*)", pSnapShotHandle, nCount, pEffectData)
                    end)
                    return okCall and true or false
                end,
            },
        })

        local setEffectAddr = assert(
            particleFindPattern("SetEffectData", {
                "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? F3 0F 10 1D ?? ?? ?? ?? 41 8B F8 8B DA 4C 8D 05",
                "48 89 5C 24 ?? 48 89 74 24 10 57 48 83 EC ?? ?? ?? ?? ?? ?? ?? ?? ?? 41 8B F8 8B DA 4C",
                "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 41 8B F8 8B DA 4C",
                "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? 41 8B F8 8B DA",
                "48 83 EC 58 F3 41 0F 10 51", 
            }),
            "SetEffectData pattern not found"
        )

        local createIdxAddr = particleFindPattern("CreateEffectIndex", {
            "40 57 48 83 EC 20 49 8B ?? 48 8B",
        })

        local create2Addr = particleFindPattern("CreateEffect2", {
            "4C 8B DC 53 48 81 EC ?? ?? ?? ?? F2 0F 10 05", 
            "4C 8B DC 53 48 83 EC 60 48 8B 84 24",       
            "4C 8B ?? ?? 48 83 ?? ?? 48 8B 84 24 ?? ?? ?? ?? 48 8B DA",
            "4C 8B DC 53 48 81 EC ?? ?? ?? ?? 48 8B 84 24",
        })

        local initEffectAddr, initEffectPat = particleFindPattern("InitEffect", {
            "40 56 48 83 EC ?? 41 8B F0 49 8B C1", 
            "40 56 48 83 EC ?? 41 8B F0",          
            "48 89 74 24 10 57 48 83 EC 30 4C 8B D9 49 8B F9 33 C9 41 8B F0 83 FA FF 0F",
            "48 89 74 24 ?? 57 48 83 EC ?? 4C 8B D9 49 8B F9 33 C9 41 8B F0 83 FA ??",
        })
        assert(initEffectAddr, "InitEffect pattern not found")
        local initEffectByValue = initEffectPat ~= nil and initEffectPat <= 2

        local getGpmAddr, getGpmPat = particleFindPattern("GetGameParticleManager", {
            "E8 ?? ?? ?? ?? 41 B0 01 8B D3",
            "E8 ?? ?? ?? ?? F3 0F 10 45 ?? 4C 8D 4C 24 ?? 8B 97",
            "E8 ?? ?? ?? ?? F3 0F 10 45",
            "E8 ?? ?? ?? ?? 45 33 E4 48 8B E8",
            "48 8B ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 48 89 5C 24 10 57 48 81 EC 70 06 ?? ?? 48 8B 1D",
            "48 8B 05 ?? ?? ?? ?? C3 ?? ?? ?? ?? ?? ?? ?? ?? 40 53",
            "48 8B 05 ?? ?? ?? ?? C3 CC CC CC CC CC CC CC CC",
        })
        assert(getGpmAddr, "GetGameParticleManager pattern not found")
        assert(create2Addr or createIdxAddr, "no CreateEffect signature found (CreateEffect2 + CreateEffectIndex both missed)")

        local destroyAddr = particleFindPattern("DestroyParticle", {
            "83 FA ?? 0F 84 ?? ?? ?? ?? 41 54",
            "83 FA ? 0F 84 ? ? ? ? 41 54",
        })
        if not destroyAddr then
            particleLog("DestroyParticle pattern not found — particle trails may leak until map change", "error")
        end

        local fnGetGpm = particleMakeGetterFromAddr(getGpmAddr, getGpmPat)

        local IGameParticleManager = setmetatable({
            pGameParticleManager = nil,
            fnSetEffectData = ffi.cast("void(__fastcall*)(void*, uint32_t, int, void*, int)", setEffectAddr),
            fnCreateEffectIndex = createIdxAddr and ffi.cast("void(__fastcall*)(void*, uint32_t*, struct DaizML_CParticleEffect*)", createIdxAddr) or nil,
            fnCreateEffect2 = create2Addr and ffi.cast("void(__fastcall*)(void*, uint32_t*, const char*, int, int64_t, int64_t, int64_t, int)", create2Addr) or nil,
            fnDestroyParticle = destroyAddr and ffi.cast("void(__fastcall*)(void*, int, bool, bool)", destroyAddr) or nil,
            initEffectByValue = initEffectByValue,
            fnInitEffectByValue = initEffectByValue
                and ffi.cast("bool(__fastcall*)(void*, uint32_t, uint32_t, struct DaizML_CStrongHandle)", initEffectAddr)
                or nil,
            fnInitEffectByPtr = (not initEffectByValue)
                and ffi.cast("bool(__fastcall*)(void*, int, uint32_t, struct DaizML_CStrongHandle*)", initEffectAddr)
                or nil,
            fnGetGameParticleManager = fnGetGpm,
        }, {
            __index = {
                Get = function(this) return this.pGameParticleManager end,
                Update = function(this)
                    local p
                    pcall(function() p = this.fnGetGameParticleManager() end)
                    this.pGameParticleManager = p
                end,
                IsValid = function(this)
                    return particleVtableOk(this.pGameParticleManager)
                end,
                CreateEffect = function(this, pEffectIndex, szName)
                    if not this:IsValid() then return false end
                    pEffectIndex[0] = 0xFFFFFFFF
                    local okCall, callErr = pcall(function()
                        if this.fnCreateEffect2 then
                            this.fnCreateEffect2(this:Get(), pEffectIndex, szName, 2, 0, 0, 0, 0)
                            if pEffectIndex[0] == 0 or pEffectIndex[0] == 0xFFFFFFFF then
                                this.fnCreateEffect2(this:Get(), pEffectIndex, szName, 8, 0, 0, 0, 0)
                            end
                        else
                            local effect = ffi.new("struct DaizML_CParticleEffect[1]")
                            effect[0].szName = szName
                            this.fnCreateEffectIndex(this:Get(), pEffectIndex, effect)
                        end
                    end)
                    if not okCall then
                        particleLog("CreateEffect faulted: " .. tostring(callErr), "error")
                        return false
                    end
                    return true
                end,
                SetEffectData = function(this, nEffectIndex, nDataIndex, pData, nArg4)
                    if not this:IsValid() then return end
                    pcall(function()
                        this.fnSetEffectData(this:Get(), nEffectIndex, nDataIndex, pData, nArg4)
                    end)
                end,
                InitEffect = function(this, nEffectIndex, nUnknown, pSnapShotHandle)
                    if not this:IsValid() then return false end
                    local okCall, ret = pcall(function()
                        if this.fnInitEffectByValue then
                            return this.fnInitEffectByValue(this:Get(), nEffectIndex, nUnknown, pSnapShotHandle[0])
                        end
                        return this.fnInitEffectByPtr(this:Get(), nEffectIndex, nUnknown, pSnapShotHandle)
                    end)
                    if not okCall then
                        particleLog("InitEffect faulted: " .. tostring(ret), "error")
                        return false
                    end
                    return ret
                end,
                DestroyEffect = function(this, nEffectIndex, bImmediate, bUnk)
                    if not this:IsValid() or not this.fnDestroyParticle then return false end
                    if type(nEffectIndex) ~= "number" then return false end
                    if nEffectIndex < 0 or nEffectIndex == 0xFFFFFFFF then return false end
                    if bImmediate == nil then bImmediate = true end
                    if bUnk == nil then bUnk = true end
                    local okCall = pcall(function()
                        this.fnDestroyParticle(this:Get(), nEffectIndex, bImmediate and true or false, bUnk and true or false)
                    end)
                    return okCall
                end,
                ReleaseParticleIndex = function(this, nEffectIndex)
                    if not this:IsValid() then return false end
                    if type(nEffectIndex) ~= "number" then return false end
                    local okCall = pcall(function()
                        local pVtable = ffi.cast("void***", this:Get())
                        ffi.cast("void(__fastcall*)(void*, int)", pVtable[0][3])(this:Get(), nEffectIndex)
                    end)
                    return okCall
                end,
            },
        })

        IParticleManager:Update()
        IGameParticleManager:Update()
        assert(IParticleManager:IsValid(), "IParticleManager invalid after update (join a map first)")
        assert(IGameParticleManager:IsValid(), "IGameParticleManager invalid after update (join a map first)")

        ParticleFFI.IParticleManager = IParticleManager
        ParticleFFI.IGameParticleManager = IGameParticleManager
        ParticleFFI.create_mode = create2Addr and "CreateEffect2" or "CreateEffectIndex"
        ParticleFFI.ok = true
    end, function(e)
        return tostring(e)
    end)

    if not ok then
        ParticleFFI.err = err
        particleLog("FFI init FAILED: " .. tostring(err), "error")
        return false
    end

    return true
end

local function particleGetSpawnPos(forwardDist, zOff)
    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then return nil, nil, "no local player" end

    local ox, oy, oz
    pcall(function()
        local o = lp:GetAbsOrigin()
        if o then ox, oy, oz = o.x or o[1], o.y or o[2], o.z or o[3] end
    end)
    if type(ox) ~= "number" then return nil, nil, "no origin" end

    local yaw = 0
    pcall(function()
        if engine and engine.GetViewAngles then
            local va = engine.GetViewAngles()
            if va then yaw = tonumber(va.yaw or va.y or va[2]) or 0 end
        end
    end)
    if yaw == 0 then
        pcall(function()
            local a = lp:GetPropVector("m_angEyeAngles")
            if a then yaw = tonumber(a.y or a[2]) or 0 end
        end)
    end

    local rad = math.rad(yaw)
    local dist = tonumber(forwardDist) or 64
    local zx = tonumber(zOff) or 32
    local start = { x = ox, y = oy, z = oz + zx }
    local finish = {
        x = ox + math.cos(rad) * dist,
        y = oy + math.sin(rad) * dist,
        z = oz + zx,
    }
    return start, finish, nil
end

local function particleLerp(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t,
    }
end

local ParticleDestroyedSet = {}
local ParticleReleaseQueue = {} 
local ParticleSessionId = 0
local particleDestroyEffectRef 
local ParticleBeamSnapshots = {}
local ParticleRetiredBuffers = {}
local PARTICLE_BUFFER_GRACE = 1.0
local PARTICLE_RETIRE_SOFT_CAP = 256
local particleNow

local function particleFlushRetired(now)
    local n = #ParticleRetiredBuffers
    if n == 0 then return end
    local keep = {}
    for i = 1, n do
        local e = ParticleRetiredBuffers[i]
        if e and (e.at or 0) > now then keep[#keep + 1] = e end
    end
    ParticleRetiredBuffers = keep
end

local function particleRetireBuffers(effectIdx, now)
    local held = ParticleBeamSnapshots[effectIdx]
    if held == nil then return end
    ParticleBeamSnapshots[effectIdx] = nil
    now = now or particleNow()
    if #ParticleRetiredBuffers >= PARTICLE_RETIRE_SOFT_CAP then
        particleFlushRetired(now)
    end
    ParticleRetiredBuffers[#ParticleRetiredBuffers + 1] = {
        held = held,
        at = now + PARTICLE_BUFFER_GRACE,
    }
end

local function particleRetireAllBuffers(now)
    now = now or particleNow()
    particleFlushRetired(now)
    local at = now + PARTICLE_BUFFER_GRACE
    for idx, held in pairs(ParticleBeamSnapshots) do
        ParticleBeamSnapshots[idx] = nil
        ParticleRetiredBuffers[#ParticleRetiredBuffers + 1] = { held = held, at = at }
    end
end

local function particleBuildBeamData(points, nIndex)
    local pEffectData = ffi.new("struct DaizML_CParticleDataAG2[1]")
    local flTimes = ffi.new("float[?]", nIndex)
    local vecPositions = ffi.new("struct DaizML_Vector[?]", nIndex)
    for nPointIndex = 1, nIndex do
        local pt = points[nPointIndex]
        flTimes[nPointIndex - 1] = 0.015625 * nPointIndex
        vecPositions[nPointIndex - 1].x = pt.x
        vecPositions[nPointIndex - 1].y = pt.y
        vecPositions[nPointIndex - 1].z = pt.z
    end
    pEffectData[0].flTimes = flTimes
    pEffectData[0].flTimes2 = flTimes
    pEffectData[0].vecPositions = vecPositions
    pEffectData[0].pUnk1 = nil
    pEffectData[0].pUnk2 = nil
    return pEffectData, flTimes, vecPositions
end

local function particleSpawnBeamPoints(path, points, color, flTime, flWidth, silent)
    local function tlog() end
    if type(points) ~= "table" or #points < 2 then return false end
    tlog("ENTER spawnBeam pts=%d flTime=%.3f flWidth=%.3f path=%s", #points, tonumber(flTime) or 0, tonumber(flWidth) or 0, tostring(path))
    if not particleInitFFI() then
        tlog("FAIL particleInitFFI")
        return false
    end
    local IPM = ParticleFFI.IParticleManager
    local IGPM = ParticleFFI.IGameParticleManager
    if not IPM or not IGPM then
        tlog("FAIL managers nil IPM=%s IGPM=%s", tostring(IPM ~= nil), tostring(IGPM ~= nil))
        return false
    end
    local managersOk = false
    pcall(function()
        IPM:Update()
        IGPM:Update()
        managersOk = IPM:IsValid() and IGPM:IsValid()
    end)
    if not managersOk then
        tlog("FAIL managers invalid at spawn")
        if not silent then particleLog("managers invalid at spawn time", "error") end
        return false
    end

    local pEffectIndex = ffi.new("uint32_t[1]")
    local pBeamColor = ffi.new("struct DaizML_CParticleColor[1]")
    pBeamColor[0].r = tonumber(color and color[1]) or 255
    pBeamColor[0].g = tonumber(color and color[2]) or 255
    pBeamColor[0].b = tonumber(color and color[3]) or 255

    tlog("BEFORE CreateEffect")
    if not IGPM:CreateEffect(pEffectIndex, path) then
        tlog("FAIL CreateEffect")
        if not silent then particleLog("CreateEffect failed", "error") end
        return false
    end
    tlog("AFTER CreateEffect raw=%s", tostring(pEffectIndex[0]))

    local effectIdx = tonumber(pEffectIndex[0])
    if not effectIdx or effectIdx == 0 or effectIdx == 0xFFFFFFFF then
        tlog("FAIL invalid effectIdx=%s", tostring(effectIdx))
        if not silent then particleLog("CreateEffect returned invalid index", "error") end
        return false
    end

    if ParticleDestroyedSet[effectIdx] then
        tlog("WARN reused destroyed idx=%s clearing queue", tostring(effectIdx))
        ParticleDestroyedSet[effectIdx] = nil
        local keep = {}
        for i = 1, #ParticleReleaseQueue do
            local e = ParticleReleaseQueue[i]
            if e and e.idx ~= effectIdx then
                keep[#keep + 1] = e
            end
        end
        ParticleReleaseQueue = keep
    end

    tlog("do SetEffectData color idx=%s", tostring(effectIdx))
    IGPM:SetEffectData(pEffectIndex[0], 16, pBeamColor, 0)

    local pParticleInformation = ffi.new("struct DaizML_CParticleInformation[1]")
    pParticleInformation[0].flUnknown = 1
    pParticleInformation[0].flWidth = tonumber(flWidth) or 0.2
    pParticleInformation[0].flTime = tonumber(flTime) or 2.0
    tlog("do SetEffectData info")
    IGPM:SetEffectData(pEffectIndex[0], 3, pParticleInformation, 0)

    local nIndex = #points
    local pSnapShotHandle = ffi.new("struct DaizML_CStrongHandle[1]")
    tlog("do BuildBeamData n=%d", nIndex)
    local pEffectData, flTimes, vecPositions = particleBuildBeamData(points, nIndex)
    tlog("AFTER BuildBeamData")

    tlog("BEFORE CreateSnapshot")
    if not IPM:CreateSnapshot(pSnapShotHandle) then
        tlog("FAIL CreateSnapshot idx=%s", tostring(effectIdx))
        if not silent then particleLog("CreateSnapshot failed", "error") end
        if type(particleDestroyEffectRef) == "function" then
            pcall(particleDestroyEffectRef, effectIdx)
        else
            pcall(function() IGPM:DestroyEffect(effectIdx, true, true) end)
        end
        return false
    end
    tlog("AFTER CreateSnapshot")

    tlog("BEFORE InitEffect")
    IGPM:InitEffect(pEffectIndex[0], 0, pSnapShotHandle)
    tlog("AFTER InitEffect / BEFORE Draw n=%d CRASH?", nIndex)
    IPM:Draw(pSnapShotHandle, nIndex, pEffectData)
    tlog("AFTER Draw")
    particleRetireBuffers(effectIdx)
    ParticleBeamSnapshots[effectIdx] = {
        handle = pSnapShotHandle,
        data = pEffectData,
        times = flTimes,
        positions = vecPositions,
    }

    tlog("OK spawnBeam idx=%s releaseQ=%d", tostring(effectIdx), #ParticleReleaseQueue)
    if not silent then
        particleLog(string.format("beam OK idx=%s path=%s", tostring(effectIdx), path), "success")
    end
    return effectIdx
end

local function particleRedrawBeamPoints(effectIdx, points, color, flTime, flWidth, silent)
    local function tlog() end
    if type(effectIdx) ~= "number" or type(points) ~= "table" or #points < 2 then return false end
    if not ParticleFFI.ok then
        tlog("FAIL redraw ParticleFFI not ok idx=%s", tostring(effectIdx))
        return false
    end
    local IPM = ParticleFFI.IParticleManager
    local IGPM = ParticleFFI.IGameParticleManager
    if not IPM or not IGPM then return false end
    local managersOk = false
    pcall(function()
        IPM:Update()
        IGPM:Update()
        managersOk = IPM:IsValid() and IGPM:IsValid()
    end)
    if not managersOk then
        tlog("FAIL redraw managers invalid idx=%s", tostring(effectIdx))
        particleRetireAllBuffers()
        ParticleFFI.IGameParticleManager = nil
        ParticleFFI.IParticleManager = nil
        ParticleFFI.ok = false
        if not silent then particleLog("managers invalid at redraw", "error") end
        return false
    end

    tlog("do redraw SetEffectData idx=%s", tostring(effectIdx))
    pcall(function()
        local pBeamColor = ffi.new("struct DaizML_CParticleColor[1]")
        pBeamColor[0].r = tonumber(color and color[1]) or 255
        pBeamColor[0].g = tonumber(color and color[2]) or 255
        pBeamColor[0].b = tonumber(color and color[3]) or 255
        IGPM:SetEffectData(effectIdx, 16, pBeamColor, 0)

        local pParticleInformation = ffi.new("struct DaizML_CParticleInformation[1]")
        pParticleInformation[0].flUnknown = 1
        pParticleInformation[0].flWidth = tonumber(flWidth) or 0.2
        pParticleInformation[0].flTime = tonumber(flTime) or 2.0
        IGPM:SetEffectData(effectIdx, 3, pParticleInformation, 0)
    end)

    local nIndex = #points
    local pSnapShotHandle = ffi.new("struct DaizML_CStrongHandle[1]")
    local pEffectData, flTimes, vecPositions = particleBuildBeamData(points, nIndex)

    tlog("BEFORE CreateSnapshot (redraw) idx=%s", tostring(effectIdx))
    if not IPM:CreateSnapshot(pSnapShotHandle) then
        tlog("FAIL CreateSnapshot (redraw) idx=%s", tostring(effectIdx))
        if not silent then particleLog("CreateSnapshot failed (redraw)", "error") end
        return false
    end
    tlog("AFTER CreateSnapshot (redraw) idx=%s", tostring(effectIdx))
    particleRetireBuffers(effectIdx)
    ParticleBeamSnapshots[effectIdx] = {
        handle = pSnapShotHandle,
        data = pEffectData,
        times = flTimes,
        positions = vecPositions,
    }
    tlog("BEFORE InitEffect (redraw) idx=%s", tostring(effectIdx))
    pcall(function() IGPM:InitEffect(effectIdx, 0, pSnapShotHandle) end)
    tlog("AFTER InitEffect / BEFORE Draw (redraw) idx=%s n=%d CRASH?", tostring(effectIdx), nIndex)
    local okDraw = false
    pcall(function()
        okDraw = IPM:Draw(pSnapShotHandle, nIndex, pEffectData) and true or false
    end)
    tlog("AFTER Draw (redraw) idx=%s ok=%s", tostring(effectIdx), tostring(okDraw))
    return okDraw
end

local function particleSpawnBeam(path, startPos, endPos, color, flTime, flWidth)
    local mid = particleLerp(startPos, endPos, 0.5)
    local near = particleLerp(startPos, endPos, 0.3)
    return particleSpawnBeamPoints(path, { startPos, near, mid, endPos }, color, flTime, flWidth, false)
end

particleNow = function()
    local t
    pcall(function() t = globals.RealTime() end)
    if type(t) ~= "number" then pcall(function() t = globals.CurTime() end) end
    return type(t) == "number" and t or 0
end

local function particleInvalidateSession(reason)
    ParticleReleaseQueue = {}
    ParticleDestroyedSet = {}
    particleRetireAllBuffers()
    ParticleFFI.IGameParticleManager = nil
    ParticleFFI.IParticleManager = nil
    ParticleFFI.ok = false
    ParticleSessionId = ParticleSessionId + 1
end

local function particleSessionHealthy()
    if not ParticleFFI.ok then return false end
    local IGPM = ParticleFFI.IGameParticleManager
    local IPM = ParticleFFI.IParticleManager
    if not IGPM or not IPM then return false end
    local ok = false
    pcall(function()
        IPM:Update()
        IGPM:Update()
        ok = IPM:IsValid() and IGPM:IsValid()
    end)
    if not ok then
        particleInvalidateSession("managers invalid")
        return false
    end
    return true
end

local function particleFlushReleases(now)
    now = now or particleNow()
    particleFlushRetired(now)
    if #ParticleReleaseQueue == 0 then return end
    if not particleSessionHealthy() then
        ParticleReleaseQueue = {}
        ParticleDestroyedSet = {}
        return
    end
    local IGPM = ParticleFFI.IGameParticleManager
    if not IGPM then return end

    local keep = {}
    for i = 1, #ParticleReleaseQueue do
        local e = ParticleReleaseQueue[i]
        if e and type(e.idx) == "number" then
            if (e.at or 0) <= now then
                pcall(function() IGPM:ReleaseParticleIndex(e.idx) end)
                ParticleDestroyedSet[e.idx] = nil
                particleRetireBuffers(e.idx, now)
            else
                keep[#keep + 1] = e
            end
        end
    end
    ParticleReleaseQueue = keep
end

local function particleDestroyEffect(effectIdx)
    local function tlog() end
    if type(effectIdx) ~= "number" then return false end
    if effectIdx < 0 or effectIdx == 0xFFFFFFFF then return false end
    if ParticleDestroyedSet[effectIdx] then return true end
    tlog("ENTER destroyEffect idx=%s", tostring(effectIdx))
    if not particleSessionHealthy() then
        tlog("FAIL destroyEffect session unhealthy idx=%s", tostring(effectIdx))
        return false
    end
    local IGPM = ParticleFFI.IGameParticleManager
    if not IGPM then return false end

    tlog("BEFORE DestroyEffect idx=%s CRASH?", tostring(effectIdx))
    local okDestroy = IGPM:DestroyEffect(effectIdx, true, true)
    tlog("AFTER DestroyEffect idx=%s ok=%s", tostring(effectIdx), tostring(okDestroy))
    if not okDestroy then return false end
    ParticleDestroyedSet[effectIdx] = true
    local now = particleNow()
    ParticleReleaseQueue[#ParticleReleaseQueue + 1] = { idx = effectIdx, at = now + 0.25 }
    return true
end
particleDestroyEffectRef = particleDestroyEffect

local function particleReleaseEffect(effectIdx)
    if type(effectIdx) ~= "number" then return false end
    if effectIdx < 0 or effectIdx == 0xFFFFFFFF then return false end
    if not particleSessionHealthy() then
        ParticleDestroyedSet[effectIdx] = nil
        return false
    end
    local IGPM = ParticleFFI.IGameParticleManager
    if not IGPM then return false end
    pcall(function() IGPM:ReleaseParticleIndex(effectIdx) end)
    ParticleDestroyedSet[effectIdx] = nil
    particleRetireBuffers(effectIdx)
    if #ParticleReleaseQueue > 0 then
        local keep = {}
        for i = 1, #ParticleReleaseQueue do
            local e = ParticleReleaseQueue[i]
            if e and e.idx ~= effectIdx then
                keep[#keep + 1] = e
            end
        end
        ParticleReleaseQueue = keep
    end
    return true
end

ParticleAPI.spawnBeamPoints = particleSpawnBeamPoints
ParticleAPI.redrawBeamPoints = particleRedrawBeamPoints
ParticleAPI.spawnBeam = particleSpawnBeam
ParticleAPI.destroyEffect = particleDestroyEffect
ParticleAPI.releaseEffect = particleReleaseEffect
ParticleAPI.flushReleases = particleFlushReleases
ParticleAPI.invalidateSession = particleInvalidateSession
ParticleAPI.sessionHealthy = particleSessionHealthy
ParticleAPI.getSessionId = function()
    return ParticleSessionId
end
ParticleAPI.clearBeamSnapshot = function(effectIdx)
    if type(effectIdx) == "number" then
        particleRetireBuffers(effectIdx)
    end
end
ParticleAPI.init = function()
    return particleInitFFI()
end

local function particleSpawnPoint(path, pos, color, silent)
    if not particleInitFFI() then return false end
    local IGPM = ParticleFFI.IGameParticleManager
    local IPM = ParticleFFI.IParticleManager
    IPM:Update()
    IGPM:Update()
    if not IGPM:IsValid() then
        if not silent then particleLog("GameParticleManager invalid", "error") end
        return false
    end

    local function createOnce()
        local pEffectIndex = ffi.new("uint32_t[1]")
        if not IGPM:CreateEffect(pEffectIndex, path) then
            return nil
        end
        local idx = tonumber(pEffectIndex[0]) or 0
        if idx == 0 or idx == 0xFFFFFFFF then
            return nil
        end
        return idx, pEffectIndex
    end

    local idx, pEffectIndex = createOnce()
    if not idx then
        if not silent then particleLog("CreateEffect failed: " .. tostring(path), "error") end
        return false
    end

    if ParticleDestroyedSet[idx] then
        pcall(function() IGPM:ReleaseParticleIndex(idx) end)
        ParticleDestroyedSet[idx] = nil
        local filtered = {}
        for i = 1, #ParticleReleaseQueue do
            local e = ParticleReleaseQueue[i]
            if e and e.idx ~= idx then
                filtered[#filtered + 1] = e
            end
        end
        ParticleReleaseQueue = filtered
        idx, pEffectIndex = createOnce()
        if not idx then
            if not silent then particleLog("CreateEffect retry failed: " .. tostring(path), "error") end
            return false
        end
    end

    local pPos = ffi.new("struct DaizML_Vector[1]")
    pPos[0].x, pPos[0].y, pPos[0].z = pos.x, pos.y, pos.z

    local posSlots = { 0, 1, 2 }
    for i = 1, #posSlots do
        pcall(function()
            IGPM:SetEffectData(pEffectIndex[0], posSlots[i], pPos, 0)
        end)
    end

    if color then
        local pCol = ffi.new("struct DaizML_CParticleColor[1]")
        pCol[0].r = tonumber(color[1]) or 255
        pCol[0].g = tonumber(color[2]) or 255
        pCol[0].b = tonumber(color[3]) or 255
        pcall(function()
            IGPM:SetEffectData(pEffectIndex[0], 16, pCol, 0)
        end)
    end

    if not silent then
        particleLog(string.format("point ok idx=%s %s", tostring(idx), path), "success")
    end
    return idx
end

ParticleAPI.spawnPoint = particleSpawnPoint

local function particleSpawnTracer(path, startPos, endPos, color)
    if not particleInitFFI() then return false end
    local IGPM = ParticleFFI.IGameParticleManager
    local IPM = ParticleFFI.IParticleManager
    IPM:Update()
    IGPM:Update()
    if not IGPM:IsValid() then
        particleLog("GameParticleManager invalid", "error")
        return false
    end

    local pEffectIndex = ffi.new("uint32_t[1]")
    if not IGPM:CreateEffect(pEffectIndex, path) then
        particleLog("CreateEffect failed: " .. tostring(path), "error")
        return false
    end
    local idx = tonumber(pEffectIndex[0]) or 0
    if idx == 0 or idx == 0xFFFFFFFF then
        particleLog("invalid effect index for tracer: " .. tostring(path), "error")
        return false
    end

    local pStart = ffi.new("struct DaizML_Vector[1]")
    local pEnd = ffi.new("struct DaizML_Vector[1]")
    pStart[0].x, pStart[0].y, pStart[0].z = startPos.x, startPos.y, startPos.z
    pEnd[0].x, pEnd[0].y, pEnd[0].z = endPos.x, endPos.y, endPos.z

    IGPM:SetEffectData(idx, 0, pStart, 0)
    IGPM:SetEffectData(idx, 1, pEnd, 0)
    pcall(function() IGPM:SetEffectData(idx, 2, pStart, 0) end)
    pcall(function() IGPM:SetEffectData(idx, 3, pEnd, 0) end)

    if color then
        local pCol = ffi.new("struct DaizML_CParticleColor[1]")
        pCol[0].r = tonumber(color[1]) or 255
        pCol[0].g = tonumber(color[2]) or 255
        pCol[0].b = tonumber(color[3]) or 255
        IGPM:SetEffectData(idx, 16, pCol, 0)
    end

    particleLog(string.format("tracer ok idx=%s %s", tostring(idx), path), "success")
    return true
end

local function particleUsesSnapshotBeam(path)
    path = tostring(path or "")
    return path:find("spectator_utility_trail", 1, true) ~= nil
end

particleLoadCatalog()

local ptSec = particlesTab:Section("Particle catalog")
local ptList
local ptFilter = ptSec:Input("Filter", "", "e.g. money, tracer, blood, explosion")
local ptModeFilter = ptSec:Combo("Guessed type", {
    "All",
    "Point [P] — stay in place",
    "Trail [T] — should travel",
    "Maybe trail [t] — try trail+beam",
    "Beam [B] — snapshot line",
    "Favourites [*]",
}, 1)
local ptCustom = ptSec:Input("Override path", "", "optional full particles/.../*.vpcf")
local ptForward = ptSec:Slider("Forward offset", 200, 0, 600, 1)
local ptZ = ptSec:Slider("Z offset", 40, -64, 128, 1)
local ptTime = ptSec:SliderFloat("Beam duration (sec)", 2.0, 0.2, 5.0, "%.1f", 0.1)
local ptWidth = ptSec:SliderFloat("Beam width", 0.25, 0.01, 2.0, "%.2f", 0.01)
local ptColor = ptSec:ColorPicker("Tint", { 80, 200, 255, 255 })

local function particleResolveSelectedPath()
    local custom = tostring(ptCustom:Get() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if custom ~= "" then return custom end
    if not ptList then return nil end
    local idx = tonumber(ptList:Get()) or 1
    return ParticleCatalog.filtered[idx]
end

local function particleGetSpawnEnds()
    local startPos, endPos, err = particleGetSpawnPos(
        tonumber(ptForward:Get()) or 200,
        tonumber(ptZ:Get()) or 40
    )
    if err or not startPos then
        particleLog("pos failed: " .. tostring(err), "error")
        return nil, nil
    end
    return startPos, endPos
end

local function particleRefreshList()
    particleApplyFilter(ptFilter:Get(), ptList, ptModeFilter:Get())
end

ptSec:Button("Apply filter", function()
    particleRefreshList()
    particleLog(ParticleCatalog.status, "success")
end)

ptSec:Button("Clear filter", function()
    ptFilter:Set("")
    ptModeFilter:Set(1)
    particleRefreshList()
end)

ptSec:Button("Add favourite", function()
    local path = particleResolveSelectedPath()
    if not path then
        particleLog("select a particle first", "error")
        return
    end
    local ok, msg = particleAddFavorite(path)
    particleLog(string.format("%s: %s", tostring(msg), particleCatalogDisplayPath(path)), ok and "success" or "error")
    particleRefreshList()
end)

ptSec:Button("Remove favourite", function()
    local path = particleResolveSelectedPath()
    if not path then
        particleLog("select a particle first", "error")
        return
    end
    local ok, msg = particleRemoveFavorite(path)
    particleLog(string.format("%s: %s", tostring(msg), particleCatalogDisplayPath(path)), ok and "success" or "error")
    particleRefreshList()
end)

ptSec:Button("Spawn recommended", function()
    local path = particleResolveSelectedPath()
    if not path then
        particleLog("no particle selected", "error")
        return
    end
    local mode, _, tip = particleGuessMode(path)
    local eye, endPos = particleGetSpawnEnds()
    if not eye then return end
    local col = ptColor:Get() or { 80, 200, 255, 255 }
    particleLog(string.format("recommended=%s — %s", mode, tip), "success")
    if mode == "beam" then
        particleSpawnBeam(path, eye, endPos, col, tonumber(ptTime:Get()) or 2.0, tonumber(ptWidth:Get()) or 0.25)
    elseif mode == "trail" or mode == "maybe" then
        if particleUsesSnapshotBeam(path) then
            particleSpawnBeam(path, eye, endPos, col, tonumber(ptTime:Get()) or 2.0, tonumber(ptWidth:Get()) or 0.25)
        else
            particleSpawnTracer(path, eye, endPos, col)
        end
    else
        particleSpawnPoint(path, endPos, col)
    end
end)

ptSec:Button("Spawn trail (eye→forward)", function()
    local path = particleResolveSelectedPath()
    if not path then
        particleLog("no particle selected", "error")
        return
    end
    local mode = particleGuessMode(path)
    if mode == "point" then
        particleLog("guess=point — trail often won't move; try Spawn point", "error")
    end
    local eye, endPos = particleGetSpawnEnds()
    if not eye then return end
    local col = ptColor:Get() or { 80, 200, 255, 255 }
    if particleUsesSnapshotBeam(path) then
        particleSpawnBeam(path, eye, endPos, col, tonumber(ptTime:Get()) or 2.0, tonumber(ptWidth:Get()) or 0.25)
    else
        particleSpawnTracer(path, eye, endPos, col)
    end
end)

ptSec:Button("Spawn point (stays here)", function()
    local path = particleResolveSelectedPath()
    if not path then
        particleLog("no particle selected", "error")
        return
    end
    local _, endPos = particleGetSpawnEnds()
    if not endPos then return end
    local col = ptColor:Get() or { 255, 255, 255, 255 }
    particleSpawnPoint(path, endPos, col)
end)

ptSec:Button("Spawn beam (force line)", function()
    local path = particleResolveSelectedPath()
    if not path then
        particleLog("no particle selected", "error")
        return
    end
    local eye, endPos = particleGetSpawnEnds()
    if not eye then return end
    local col = ptColor:Get() or { 80, 200, 255, 255 }
    particleSpawnBeam(path, eye, endPos, col, tonumber(ptTime:Get()) or 2.0, tonumber(ptWidth:Get()) or 0.25)
end)

ptSec:Custom(44, function(ui, x, y, w)
    ui.text(x, y, ParticleCatalog.status or "")
    local path = particleResolveSelectedPath()
    if path then
        local mode, tag, tip = particleGuessMode(path)
        local star = particleIsFavorite(path) and "*" or ""
        ui.text(x, y + 14, string.format("[%s%s] %s%s", tag, star, mode, star ~= "" and "  (favourite)" or ""))
        ui.text(x, y + 28, tip)
    end
end)

ptList = ptSec:Listbox("Particles", ParticleCatalog.display, "fill", 1)
do
    local n = 0
    pcall(function() n = particleLoadCatalog() or 0 end)
    if n > 0 then
        pcall(function()
            particleApplyFilter(ptFilter:Get(), ptList, ptModeFilter:Get())
        end)
        ParticleCatalog.status = ParticleCatalog.status or "catalog loaded from cache"
    else
        particleFetchCatalogFromGitHub(ptList, ptModeFilter:Get(), ptFilter:Get())
    end
end


end
daizInitParticleTester(particlesTab)
do
    local ok, err = pcall(daizInitSkinChanger, skinsTab)
    if not ok then
        SkinInitError = tostring(err)
        print("[DaizML] skin changer init failed: " .. SkinInitError)
        M:Error("skin changer init failed")
    end
end

local GH = {
    FILE = "DaizML_lineups.txt",
    NADE_FILTER = { "Auto (held)", "HE", "Flash", "Smoke", "Molotov", "Incendiary", "Decoy" },
    NADE_FILTER_IDS = { "auto", "he", "flash", "smoke", "molotov", "incendiary", "decoy" },
    AIM_STYLES = { "Circle", "Aim circle", "Crosshair", "Aim Target" },
    lineups = {},
    nextId = 1,
    pulse = 0,
    fonts = {},
    lastMap = "",
    listDirty = true,
    pos = { x = nil, y = nil },
    _drag = nil,
    _mouseDown = false,
    editMode = false,
    _recKeyWas = false,
    _editKeyWas = false,
    _editToggleWas = false,
    play = {
        state = "idle",
        active = nil,
        tick = 0,
        step = 1,
        lastSimTick = -1,
        alignTick = 0,
        awaitRelease = false,
        noMacroTold = false,
        errP = 0,
        errY = 0,
        lastCmd = nil,
        atkHold = 0,
        atk2Hold = 0,
    },
    rec = {
        session = false,
        waiting = false,
        active = false,
        trailing = false,
        trailLeft = 0,
        lastSimTick = -1,
        buf = {},
        meta = nil,
        lastFrames = nil,
        lastMeta = nil,
        lastTicks = 0,
        takes = 0,
        readyFrames = nil,
        readyMeta = nil,
        ticks = 0,
    },
    savePopup = nil,
    editPopup = nil,
    floorMenu = nil,
    floorFocus = nil,
    floorFocusL = nil,
    aimEditL = nil,
    draw = function() end,
    onCreateMove = function() end,
}

;(function()
    local mfloor, mmax, mmin, mabs, msin, mcos, msqrt =
        math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt

    local ghHelper = grenadeTab:Section("Helper")
    GH.enable = ghHelper:Checkbox("Enable grenade helper", false)
    GH.hud = ghHelper:Checkbox("Show hold HUD", true)
    GH.hudOnSpot = ghHelper:Checkbox("HUD only on spot", false)
    GH.showAllSpots = ghHelper:Checkbox("Show all spots", false)
    GH.aimLine = ghHelper:Checkbox("TraceLine", true)
    GH.aimStyle = ghHelper:Combo("Aim spot style", GH.AIM_STYLES, 4)
    GH.showDist = ghHelper:Slider("Spot visibility (units)", 500, 200, 1000, 25)
    GH.executeKey = ghHelper:Keybox("Execute lineup key", 0)
    ghHelper:Button("Reset HUD position", function()
        GH.pos.x, GH.pos.y = nil, nil
        GH._drag = nil
        M:Notify("grenade HUD position reset", "info")
    end)
    ghHelper:Custom(56, function(ui, x, y)
        ui.text(x, y, "Hold Execute on STAND HERE to center and replay the throw.")
        ui.text(x, y + 14, "Show all spots: visuals only — execute still needs the matching nade.")
        ui.text(x, y + 28, "Detect: " .. tostring(GH.lastDetect or "—"))
    end)

    local ghEdit = grenadeTab:Section("Edit mode")
    GH.editModeBox = ghEdit:Checkbox("Enable edit mode", false)
    GH.editToggleKey = ghEdit:Keybox("Toggle edit mode", 0)
    GH.editSpotKey = ghEdit:Keybox("Edit lineup key", 0)
    GH.recordKey = ghEdit:Keybox("Save throw key", 0)
    ghEdit:Custom(32, function(ui, x, y)
        ui.text(x, y, "Edit mode shows every lineup in visibility range (any weapon).")
        ui.text(x, y + 14, "Floor EDIT → lineup menu. Aimspot EDIT → edit that lineup.")
    end)

    local ghLineups = grenadeTab:Section("Lineups")
    GH.list = ghLineups:Listbox("Saved on this map", { "(none)" }, 220, 1)

    local function ghClamp(v, a, b)
        v = tonumber(v) or a
        if v < a then return a end
        if v > b then return b end
        return v
    end

    local function ghNormYaw(y)
        y = tonumber(y) or 0
        while y > 180 do y = y - 360 end
        while y < -180 do y = y + 360 end
        return y
    end

    local function ghMapName()
        local m
        pcall(function() if engine and engine.GetMapName then m = engine.GetMapName() end end)
        if type(m) ~= "string" or m == "" then
            pcall(function() if client and client.GetMapName then m = client.GetMapName() end end)
        end
        if type(m) ~= "string" or m == "" then
            pcall(function() if engine and engine.GetLevelNameShort then m = engine.GetLevelNameShort() end end)
        end
        m = tostring(m or ""):gsub("\\", "/"):lower()
        m = m:match("([^/]+)$") or m
        m = m:gsub("%.bsp$", ""):gsub("%.vpk$", ""):gsub("^maps/", "")
        if m == "" then m = "unknown" end
        return m
    end

    local function ghMapMatch(a, b)
        local function key(s)
            s = tostring(s or ""):lower()
            s = s:gsub("%.bsp$", ""):gsub("%.vpk$", ""):gsub("^maps/", ""):gsub("[^%w]", "")
            return s
        end
        a, b = key(a), key(b)
        if a == "" or b == "" then return false end
        if a == b then return true end
        local function stripRN(s) return (s:gsub("[rn]", "")) end
        return stripRN(a) == stripRN(b)
    end

    local function ghSanitizeField(s)
        return tostring(s or ""):gsub("[|\r\n]", ""):gsub("%%", "")
    end

    local function ghHasMacro(L)
        return type(L) == "table" and type(L.frames) == "table" and #L.frames > 0
    end

    local function ghEncodeFrames(frames)
        if type(frames) ~= "table" or #frames == 0 then return "" end
        local parts = {}
        for i = 1, #frames do
            local f = frames[i]
            if type(f) == "number" then
                parts[i] = tostring(mfloor(f + 0.5))
            elseif type(f) == "table" then
                local cells = {}
                local n = mmax(2, #f)
                for j = 1, n do
                    local x = f[j]
                    if type(x) == "string" then
                        cells[j] = x:gsub("[;,%|]", "")
                    elseif type(x) == "number" then
                        cells[j] = string.format("%.4g", x)
                    else
                        cells[j] = (j <= 2) and "0" or ""
                    end
                end
                while #cells > 2 and (cells[#cells] == "" or cells[#cells] == nil) do
                    cells[#cells] = nil
                end
                parts[i] = table.concat(cells, ",")
            else
                parts[i] = "1"
            end
        end
        return table.concat(parts, ";")
    end

    local function ghDecodeFrames(raw)
        raw = tostring(raw or "")
        if raw == "" then return nil end
        local frames = {}
        for piece in (raw .. ";"):gmatch("([^;]*);") do
            if piece ~= "" then
                if piece:find(",", 1, true) then
                    local cells = {}
                    local idx = 1
                    for cell in (piece .. ","):gmatch("([^,]*),") do
                        if idx <= 2 then
                            cells[idx] = tonumber(cell) or 0
                        elseif idx == 3 then
                            cells[idx] = cell
                        else
                            local num = tonumber(cell)
                            if num ~= nil then cells[idx] = num end
                        end
                        idx = idx + 1
                    end
                    local n = 0
                    for j = 1, 5 do
                        if cells[j] ~= nil then n = j end
                    end
                    local frame = {}
                    for j = 1, n do frame[j] = cells[j] end
                    frames[#frames + 1] = frame
                else
                    local n = tonumber(piece)
                    if n and n > 0 then frames[#frames + 1] = mfloor(n) end
                end
            end
        end
        if #frames == 0 then return nil end
        return frames
    end

    local function ghNadeInfo(lp)
        local info = {
            held = false, id = nil, label = nil,
            color = { 120, 160, 190, 255 },
            debug = "no player",
        }
        if not lp then return info end

        local def, wtype, wid = nil, nil, nil
        local className, wepName = "", ""
        local wep

        pcall(function() wtype = tonumber(lp:GetWeaponType()) end)
        pcall(function() wid = tonumber(lp:GetWeaponID()) end)
        pcall(function() wep = lp:GetPropEntity("m_hActiveWeapon") end)
        if not wep then
            pcall(function()
                if lp.GetActiveWeapon then wep = lp:GetActiveWeapon() end
            end)
        end

        if wep then
            pcall(function() def = tonumber(wep:GetPropInt("m_iItemDefinitionIndex")) end)
            pcall(function()
                if def == nil or def == 0 then
                    def = tonumber(wep:GetPropInt("m_AttributeManager.m_Item.m_iItemDefinitionIndex"))
                end
            end)
            pcall(function()
                if (def == nil or def == 0) and wep.GetWeaponID then
                    def = tonumber(wep:GetWeaponID())
                end
            end)
            pcall(function() if wep.GetClass then className = tostring(wep:GetClass() or "") end end)
            pcall(function() if wep.GetName then wepName = tostring(wep:GetName() or "") end end)
            pcall(function()
                if wep.GetWeaponName then
                    local n = tostring(wep:GetWeaponName() or "")
                    if n ~= "" then wepName = n end
                end
            end)
            pcall(function()
                if (className == "" or className == "nil") and wep.GetClassName then
                    className = tostring(wep:GetClassName() or "")
                end
            end)
        end

        if (def == nil or def == 0) and wid and wid > 0 then def = wid end

        local blob = (tostring(className) .. " " .. tostring(wepName) .. " " .. tostring(def)):lower()
        info.debug = string.format("def=%s type=%s id=%s [%s]",
            tostring(def), tostring(wtype), tostring(wid), blob:sub(1, 48))

        local map = {
            [43] = "flash", [101] = "flash",
            [44] = "he", [102] = "he",
            [45] = "smoke", [100] = "smoke",
            [46] = "molotov", [103] = "molotov",
            [47] = "decoy", [105] = "decoy",
            [48] = "incendiary", [104] = "incendiary",
        }
        local id = map[def]

        if not id then
            if blob:find("flash", 1, true) then id = "flash"
            elseif blob:find("hegrenade", 1, true) or blob:find("he_grenade", 1, true)
                or blob:find("weapon_he", 1, true) or blob:find("explosive", 1, true) then id = "he"
            elseif blob:find("smoke", 1, true) then id = "smoke"
            elseif blob:find("molotov", 1, true) then id = "molotov"
            elseif blob:find("incendiary", 1, true) or blob:find("incgrenade", 1, true)
                or blob:find("weapon_inc", 1, true) then id = "incendiary"
            elseif blob:find("decoy", 1, true) then id = "decoy"
            end
        end

        if not id and wtype == 9 and (def == nil or def == 0) then
            id = "he"
            info.debug = info.debug .. " (type-fallback)"
        end

        local meta = {
            he = { "HE GRENADE", { 255, 106, 74, 255 } },
            flash = { "FLASHBANG", { 245, 215, 110, 255 } },
            smoke = { "SMOKE", { 126, 184, 201, 255 } },
            molotov = { "MOLOTOV", { 255, 90, 54, 255 } },
            incendiary = { "INCENDIARY", { 255, 120, 70, 255 } },
            decoy = { "DECOY", { 107, 203, 119, 255 } },
        }
        if id and meta[id] then
            info.held, info.id = true, id
            info.label, info.color = meta[id][1], meta[id][2]
        end
        return info
    end

    local function ghNadeCompatible(a, b)
        if not a or not b then return false end
        if a == b then return true end
        local fire = (a == "molotov" or a == "incendiary") and (b == "molotov" or b == "incendiary")
        return fire and true or false
    end

    local function ghEye(lp)
        local fx, fy, fz, pitch, yaw
        pcall(function()
            local o = lp:GetAbsOrigin()
            if o then fx, fy, fz = o.x or o[1], o.y or o[2], o.z or o[3] end
        end)
        pcall(function()
            local v = lp:GetPropVector("m_vecAbsOrigin")
            if v and type(fx) ~= "number" then fx, fy, fz = v.x or v[1], v.y or v[2], v.z or v[3] end
        end)
        local viewZ
        pcall(function() viewZ = tonumber(lp:GetPropFloat("m_vecViewOffset[2]")) end)
        if type(viewZ) ~= "number" then viewZ = 64 end

        pcall(function()
            if engine and engine.GetViewAngles then
                local va = engine.GetViewAngles()
                if va then
                    pitch = tonumber(va.pitch or va.x or va[1])
                    yaw = tonumber(va.yaw or va.y or va[2])
                end
            end
        end)
        if pitch == nil or yaw == nil then
            pcall(function()
                local a = lp:GetPropVector("m_angEyeAngles")
                if a then
                    pitch = tonumber(a.x or a[1])
                    yaw = tonumber(a.y or a[2])
                end
            end)
        end
        if type(fx) ~= "number" or type(pitch) ~= "number" then return nil end
        return {
            fx = fx, fy = fy, fz = fz,
            x = fx, y = fy, z = fz + viewZ, 
            viewZ = viewZ,
            pitch = pitch, yaw = ghNormYaw(yaw),
        }
    end

    local EXEC_PITCH_BIAS = 0.15

    local function ghLineupAimAngles(L)
        local pitch = (tonumber(L.pitch) or 0) + EXEC_PITCH_BIAS
        local yaw = tonumber(L.yaw) or 0
        return pitch, yaw
    end

    local function ghAimWorld(L, dist)
        dist = tonumber(dist) or 1100
        local fx, fy, fz = tonumber(L.x) or 0, tonumber(L.y) or 0, tonumber(L.z) or 0
        local viewZ = tonumber(L.viewZ) or 64
        if L.eyeZ then
            viewZ = tonumber(L.eyeZ) - fz
            if viewZ < 40 or viewZ > 80 then viewZ = 64 end
        end
        local pitch, yaw = ghLineupAimAngles(L)
        local pr, yr = math.rad(pitch), math.rad(yaw)
        local cp, sp = mcos(pr), msin(pr)
        local cy, sy = mcos(yr), msin(yr)
        local ex, ey, ez = fx, fy, fz + viewZ
        return {
            x = ex + cy * cp * dist,
            y = ey + sy * cp * dist,
            z = ez - sp * dist,
        }
    end

    local function ghWorldToScreen(wx, wy, wz)
        local sx, sy
        pcall(function()
            if not (client and client.WorldToScreen) then return end
            if Vector3 then
                sx, sy = client.WorldToScreen(Vector3(wx, wy, wz))
            else
                sx, sy = client.WorldToScreen(wx, wy, wz)
            end
        end)
        if type(sx) == "table" then
            sy = sx.y or sx[2]
            sx = sx.x or sx[1]
        end
        if type(sx) == "number" and type(sy) == "number" then return sx, sy end
        return nil
    end

    local function ghSaveLineups()
        local lines = { "# DaizML grenade lineups" }
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L then
                local map = ghSanitizeField(L.map):gsub("%.bsp$", ""):gsub("%.vpk$", ""):lower()
                local id = tonumber(L.id) or i
                lines[#lines + 1] = string.format(
                    "L|%d|%s|%s|%s|%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f",
                    id,
                    map,
                    ghSanitizeField(L.name),
                    ghSanitizeField(L.nade ~= "" and L.nade or "he"),
                    ghSanitizeField(L.desc),
                    tonumber(L.x) or 0, tonumber(L.y) or 0, tonumber(L.z) or 0,
                    tonumber(L.pitch) or 0, tonumber(L.yaw) or 0,
                    tonumber(L.viewZ) or 64
                )
                if ghHasMacro(L) then
                    local enc = ghEncodeFrames(L.frames)
                    if enc ~= "" then
                        local sp = tonumber(L.seedPitch or L.pitch) or 0
                        local sy = tonumber(L.seedYaw or L.yaw) or 0
                        lines[#lines + 1] = string.format("F|%d|%.4f,%.4f|%s", id, sp, sy, enc)
                    end
                end
            end
        end
        local ok = fileWrite(GH.FILE, table.concat(lines, "\n") .. "\n")
        return ok and true or false
    end

    local function ghSplitPipe(line)
        local parts = {}
        local start = 1
        while true do
            local i = line:find("|", start, true)
            if not i then
                parts[#parts + 1] = line:sub(start)
                break
            end
            parts[#parts + 1] = line:sub(start, i - 1)
            start = i + 1
        end
        return parts
    end

    local function ghNormalizeMap(map)
        map = tostring(map or ""):gsub("\\", "/"):lower()
        map = map:match("([^/]+)$") or map
        map = map:gsub("%.bsp$", ""):gsub("%.vpk$", ""):gsub("^maps/", "")
        if map == "" then map = "unknown" end
        return map
    end

    local function ghLoadLineups()
        GH.lineups = {}
        GH.nextId = 1
        local text = fileRead(GH.FILE)
        if type(text) ~= "string" or text == "" then
            GH.listDirty = true
            return 0
        end
        local n = 0
        local frameMap = {}
        for line in text:gmatch("[^\r\n]+") do
            if line:sub(1, 2) == "L|" then
                local p = ghSplitPipe(line)
                if #p >= 11 then
                    local id = tonumber(p[2])
                    local map = ghNormalizeMap(p[3])
                    local ez = tonumber(p[9]) or 0
                    local vz = tonumber(p[12]) or 64
                    local legacy = (#p < 12)
                    if legacy then
                        ez = ez - 64
                        vz = 64
                    end
                    if id then
                        local e = {
                            id = id,
                            map = map,
                            name = (p[4] ~= "" and p[4]) or ("Lineup " .. id),
                            nade = p[5] ~= "" and p[5] or "he",
                            desc = p[6] or "",
                            x = tonumber(p[7]), y = tonumber(p[8]), z = ez,
                            pitch = tonumber(p[10]), yaw = tonumber(p[11]),
                            viewZ = vz,
                        }
                        GH.lineups[#GH.lineups + 1] = e
                        n = n + 1
                        if e.id >= GH.nextId then GH.nextId = e.id + 1 end
                    end
                end
            elseif line:sub(1, 2) == "F|" then
                local p = ghSplitPipe(line)
                local id = tonumber(p[2])
                if id and p[3] then
                    local seedPitch, seedYaw, enc
                    if p[4] then
                        seedPitch, seedYaw = tostring(p[3]):match("^([^,]+),([^,]+)$")
                        seedPitch, seedYaw = tonumber(seedPitch), tonumber(seedYaw)
                        enc = table.concat(p, "|", 4)
                    else
                        enc = table.concat(p, "|", 3)
                    end
                    frameMap[id] = {
                        frames = ghDecodeFrames(enc),
                        seedPitch = seedPitch,
                        seedYaw = seedYaw,
                    }
                end
            end
        end
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            local pack = L and frameMap[L.id]
            if L and pack and pack.frames then
                L.frames = pack.frames
                if pack.seedPitch ~= nil then L.seedPitch = pack.seedPitch end
                if pack.seedYaw ~= nil then L.seedYaw = pack.seedYaw end
                L._macroCmds = nil
            end
        end
        GH.listDirty = true
        return n
    end

    local function ghFilterId()
        return "auto"
    end

    local function ghMapLineups(map)
        map = map or ghMapName()
        local out = {}
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and ghMapMatch(L.map, map) then out[#out + 1] = L end
        end
        return out
    end

    local function ghMigrateMaps(map)
        map = map or ghMapName()
        if map == "unknown" then return false end
        local changed = false
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and ghMapMatch(L.map, map) and L.map ~= map then
                L.map = map
                changed = true
            end
        end
        if changed then pcall(ghSaveLineups) end
        return changed
    end

    local function ghPrettyMap(map)
        map = tostring(map or "unknown"):lower()
        map = map:gsub("%.bsp$", ""):gsub("%.vpk$", ""):gsub("^maps/", "")
        map = map:gsub("^de_", ""):gsub("^cs_", ""):gsub("^gd_", "")
        if map == "" or map == "unknown" then return "unknown" end
        return map:gsub("_", " ")
    end

    local function ghInGame()
        local ok = false
        pcall(function()
            if engine and engine.IsInGame then ok = engine.IsInGame() and true or false end
        end)
        if not ok then
            pcall(function()
                if client and client.IsConnected then ok = client.IsConnected() and true or false end
            end)
        end
        return ok
    end

    local function ghMapSummaryRows()
        local counts = {}
        local order = {}
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L then
                local m = tostring(L.map or "unknown")
                if m == "" then m = "unknown" end
                if not counts[m] then
                    counts[m] = 0
                    order[#order + 1] = m
                end
                counts[m] = counts[m] + 1
            end
        end
        table.sort(order, function(a, b)
            if counts[a] ~= counts[b] then return counts[a] > counts[b] end
            return a < b
        end)
        local rows, labels = {}, {}
        for i = 1, #order do
            local m = order[i]
            local n = counts[m]
            rows[i] = { map = m, count = n }
            labels[i] = string.format("%d x %s", n, ghPrettyMap(m))
        end
        return rows, labels
    end

    local function ghRefreshList()
        local map = ghMapName()
        if map ~= "unknown" then ghMigrateMaps(map) end
        local rows = ghMapLineups(map)
        local labels = {}
        local outOfMap = (not ghInGame()) or map == "unknown" or map == "" or map == "<empty>"
        GH._mapSummary = nil
        if #rows == 0 then
            if #GH.lineups > 0 and outOfMap then
                local summaryRows, summaryLabels = ghMapSummaryRows()
                labels = summaryLabels
                if #labels == 0 then labels[1] = "(no lineups saved)" end
                rows = {}
                GH._mapSummary = summaryRows
            else
                labels[1] = "(no lineups on " .. ghPrettyMap(map) .. ")"
                if #GH.lineups > 0 then
                    labels[1] = labels[1] .. " — " .. tostring(#GH.lineups) .. " saved total"
                end
            end
        else
            for i = 1, #rows do
                local L = rows[i]
                local desc = tostring(L.desc or "")
                local macro = ghHasMacro(L) and "  ·  MACRO" or ""
                if desc ~= "" then
                    labels[i] = string.format("%s  ·  %s  ·  %s%s",
                        tostring(L.name), tostring(L.nade):upper(), desc, macro)
                else
                    labels[i] = string.format("%s  ·  %s%s",
                        tostring(L.name), tostring(L.nade):upper(), macro)
                end
            end
        end
        GH.list:SetItems(labels, 1)
        GH.lastMap = map
        GH.listDirty = false
        GH._mapRows = rows
    end

    local function ghSelectedLineup()
        local rows = GH._mapRows or ghMapLineups()
        if #rows == 0 then return nil end
        local idx = mmax(1, mmin(#rows, mfloor(tonumber(GH.list:Get()) or 1)))
        return rows[idx]
    end

    local function ghSelectedMapSummary()
        local summary = GH._mapSummary
        if type(summary) ~= "table" or #summary == 0 then return nil end
        local idx = mmax(1, mmin(#summary, mfloor(tonumber(GH.list:Get()) or 1)))
        return summary[idx]
    end

    local function ghDeleteLineupsForMap(mapKey)
        mapKey = tostring(mapKey or "")
        if mapKey == "" then return 0 end
        local keep, removed = {}, 0
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and ghMapMatch(L.map, mapKey) then
                removed = removed + 1
            elseif L then
                keep[#keep + 1] = L
            end
        end
        if removed == 0 then return 0 end
        GH.lineups = keep
        ghSaveLineups()
        GH.listDirty = true
        ghRefreshList()
        return removed
    end

    ghLineups:Button("Delete selected", function()
        local L = ghSelectedLineup()
        if L then
            local keep = {}
            for i = 1, #GH.lineups do
                if GH.lineups[i] and GH.lineups[i].id ~= L.id then
                    keep[#keep + 1] = GH.lineups[i]
                end
            end
            GH.lineups = keep
            ghSaveLineups()
            GH.listDirty = true
            ghRefreshList()
            M:Notify("lineup deleted", "info")
            return
        end

        local summary = ghSelectedMapSummary()
        if summary and summary.map then
            local n = ghDeleteLineupsForMap(summary.map)
            if n > 0 then
                M:Notify(string.format("deleted %d lineups on %s", n, ghPrettyMap(summary.map)), "info")
            else
                M:Info("nothing selected")
            end
            return
        end

        M:Info("nothing selected")
    end)

    ghLineups:Button("Reload lineups from disk", function()
        local n = ghLoadLineups() or 0
        ghRefreshList()
        M:Info(string.format("loaded %d lineups", n))
    end)

    local function ghEnsureFonts()
        if GH.fonts.ok then return end
        pcall(function()
            GH.fonts.title = draw.CreateFont("Bahnschrift", 22, 700)
            GH.fonts.body = draw.CreateFont("Segoe UI", 14, 600)
            GH.fonts.small = draw.CreateFont("Segoe UI", 12, 500)
            GH.fonts.ok = true
        end)
        if not GH.fonts.ok then
            pcall(function()
                GH.fonts.title = draw.CreateFont("Segoe UI", 22, 700)
                GH.fonts.body = draw.CreateFont("Segoe UI", 14, 600)
                GH.fonts.small = draw.CreateFont("Segoe UI", 12, 500)
                GH.fonts.ok = true
            end)
        end
    end

    local function ghColor(c, a)
        return {
            tonumber(c[1]) or 255,
            tonumber(c[2]) or 255,
            tonumber(c[3]) or 255,
            tonumber(a or c[4]) or 255,
        }
    end

    local function ghRect(x, y, w, h, c, a)
        if w <= 0 or h <= 0 then return end
        local col = ghColor(c, a)
        pcall(function()
            draw.Color(mfloor(col[1]), mfloor(col[2]), mfloor(col[3]), mfloor(col[4]))
            draw.FilledRect(mfloor(x), mfloor(y), mfloor(x + w), mfloor(y + h))
        end)
    end

    local function ghText(font, x, y, c, a, s)
        if not s or s == "" then return end
        pcall(function()
            if font then draw.SetFont(font) end
            local col = ghColor(c, a)
            draw.Color(mfloor(col[1]), mfloor(col[2]), mfloor(col[3]), mfloor(col[4]))
            draw.Text(mfloor(x), mfloor(y), tostring(s))
        end)
    end

    local function ghTextSize(font, s)
        local w, h = 0, 0
        pcall(function()
            if font then draw.SetFont(font) end
            w, h = draw.GetTextSize(tostring(s or ""))
        end)
        return tonumber(w) or 0, tonumber(h) or 0
    end

    local function ghDist2(ax, ay, az, bx, by, bz)
        local dx, dy, dz = ax - bx, ay - by, az - bz
        return msqrt(dx * dx + dy * dy + dz * dz)
    end

    local function ghNadeColor(id)
        if id == "he" then return { 255, 106, 74, 255 } end
        if id == "flash" then return { 245, 215, 110, 255 } end
        if id == "smoke" then return { 126, 184, 201, 255 } end
        if id == "molotov" then return { 255, 90, 54, 255 } end
        if id == "incendiary" then return { 255, 120, 70, 255 } end
        if id == "decoy" then return { 107, 203, 119, 255 } end
        return { 160, 180, 200, 255 }
    end

    local function ghDescLabel(L)
        if type(L) == "table" then return tostring(L.desc or "") end
        return tostring(L or "")
    end

    local function ghMouse()
        local mx, my = 0, 0
        pcall(function()
            local p = input.GetMousePos()
            if type(p) == "table" then mx, my = p.x or p[1] or 0, p.y or p[2] or 0
            else mx, my = p, select(2, input.GetMousePos()) end
        end)
        pcall(function()
            local x, y = input.GetMousePos()
            if type(x) == "number" and type(y) == "number" then mx, my = x, y end
        end)
        local down = false
        pcall(function() down = input.IsButtonDown(0x01) and true or false end)
        return mx, my, down
    end

    local function ghMenuColors()
        local accent = { 74, 166, 255, 255 }
        local bg = { 9, 11, 16, 214 }
        local bg2 = { 12, 14, 20, 214 }
        local text = { 205, 213, 225, 255 }
        pcall(function()
            local c = uiAccent:Get()
            if type(c) == "table" and c[1] then accent = { c[1], c[2], c[3], c[4] or 255 } end
        end)
        pcall(function()
            local c = uiText:Get()
            if type(c) == "table" and c[1] then text = { c[1], c[2], c[3], c[4] or 255 } end
        end)
        return accent, bg, bg2, text
    end

    local function ghNadeShort(id)
        if id == "he" then return "HE" end
        if id == "flash" then return "FLASH" end
        if id == "smoke" then return "SMOKE" end
        if id == "molotov" then return "MOLO" end
        if id == "incendiary" then return "INC" end
        if id == "decoy" then return "DECOY" end
        return tostring(id or "?"):upper()
    end

    local function ghFade(dist, showDist)
        showDist = mmax(1, tonumber(showDist) or 1200)
        dist = mmax(0, tonumber(dist) or 0)
        if dist >= showDist then return 0 end
        local t = 1 - (dist / showDist)
        return t * t * (3 - 2 * t)
    end

    local function ghLine(x1, y1, x2, y2, c, a, dash)
        x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
        if not (x1 and y1 and x2 and y2) then return end
        a = tonumber(a) or 180
        dash = tonumber(dash) or 0
        local ok = false
        if dash <= 0 then
            pcall(function()
                local col = ghColor(c, a)
                draw.Color(mfloor(col[1]), mfloor(col[2]), mfloor(col[3]), mfloor(col[4]))
                draw.Line(mfloor(x1), mfloor(y1), mfloor(x2), mfloor(y2))
                ok = true
            end)
        end
        if ok then return end
        local dx, dy = x2 - x1, y2 - y1
        local len = msqrt(dx * dx + dy * dy)
        if len < 2 then return end
        local steps = mmax(2, mfloor(len / 4))
        local on, gap = 5, 4
        local seg = 0
        local drawing = true
        for i = 0, steps do
            local t = i / steps
            local px, py = x1 + dx * t, y1 + dy * t
            if dash <= 0 or drawing then
                ghRect(px - 1, py - 1, 2, 2, c, a)
            end
            if dash > 0 then
                seg = seg + 1
                if drawing and seg >= on then drawing, seg = false, 0
                elseif (not drawing) and seg >= gap then drawing, seg = true, 0 end
            end
        end
    end

    local function ghFilledCircle(cx, cy, r, c, a)
        cx, cy, r = tonumber(cx), tonumber(cy), tonumber(r)
        if not (cx and cy and r) or r < 1 then return end
        local ok = false
        pcall(function()
            local col = ghColor(c, a)
            draw.Color(mfloor(col[1]), mfloor(col[2]), mfloor(col[3]), mfloor(col[4]))
            if draw.FilledCircle then
                draw.FilledCircle(mfloor(cx), mfloor(cy), mfloor(r))
                ok = true
            elseif draw.CircleFilled then
                draw.CircleFilled(mfloor(cx), mfloor(cy), mfloor(r))
                ok = true
            end
        end)
        if ok then return end
        local rr = mfloor(r + 0.5)
        for dy = -rr, rr do
            local w = mfloor(msqrt(mmax(0, rr * rr - dy * dy)) + 0.5)
            if w > 0 then ghRect(cx - w, cy + dy, w * 2, 1, c, a) end
        end
    end

    local function ghCircleRing(cx, cy, r, c, a, thick)
        thick = tonumber(thick) or 1
        local outer = tonumber(r) or 1
        for t = 0, mmax(0, thick - 1) do
            local rr = outer - t
            if rr < 1 then break end
            local ok = false
            pcall(function()
                local col = ghColor(c, a)
                draw.Color(mfloor(col[1]), mfloor(col[2]), mfloor(col[3]), mfloor(col[4]))
                if draw.OutlinedCircle then
                    draw.OutlinedCircle(mfloor(cx), mfloor(cy), mfloor(rr))
                    ok = true
                elseif draw.Circle then
                    draw.Circle(mfloor(cx), mfloor(cy), mfloor(rr))
                    ok = true
                end
            end)
            if not ok then
                local steps = mmax(12, mfloor(rr * 4))
                local prevx, prevy
                for i = 0, steps do
                    local ang = (i / steps) * 6.28318530718
                    local px = cx + mcos(ang) * rr
                    local py = cy + msin(ang) * rr
                    if prevx then ghLine(prevx, prevy, px, py, c, a, 0) end
                    prevx, prevy = px, py
                end
            end
        end
    end

    local NADE_ICON_FILES = {
        he = "nade_he.svg",
        flash = "nade_flash.svg",
        smoke = "nade_smoke.svg",
        molotov = "nade_molotov.svg",
        incendiary = "nade_incendiary.svg",
        decoy = "nade_decoy.svg",
    }
    local NADE_ICON_URL =
        "https://raw.githubusercontent.com/whosdaiz/AW-lua/main/assets/"
    local NADE_ICON_URL_ALT =
        "https://raw.githubusercontent.com/whosdaiz/AW-lua/refs/heads/main/assets/"
    if type(GH.nadeTex) ~= "table" then GH.nadeTex = {} end
    if type(GH.nadeSvgFetchTried) ~= "table" then GH.nadeSvgFetchTried = {} end

    local function ghIsSvgBody(data)
        return type(data) == "string" and #data > 40
            and (data:find("<svg", 1, true) or data:find("<SVG", 1, true))
    end

    local function ghReadLocalNadeSvg(fname)
        local paths = { "assets/" .. fname, "Lua/assets/" .. fname}
        for i = 1, #paths do
            local data = fileRead(paths[i])
            if ghIsSvgBody(data) then return data end
        end
        return nil
    end

    local function ghFetchNadeSvg(fname)
        if type(http) ~= "table" or type(http.Get) ~= "function" then return nil end
        local body
        pcall(function() body = http.Get(NADE_ICON_URL .. fname) end)
        if not ghIsSvgBody(body) then
            body = nil
            pcall(function() body = http.Get(NADE_ICON_URL_ALT .. fname) end)
        end
        if ghIsSvgBody(body) then return body end
        return nil
    end

    local function ghCacheNadeSvg(fname, data)
        if not ghIsSvgBody(data) then return end
        fileWrite("assets/" .. fname, data)
    end

    local function ghRasterizeNadeSvg(nadeId, data)
        local rgba, w, h
        local ok = pcall(function()
            rgba, w, h = common.RasterizeSVG(data, 0.5)
        end)
        if not (ok and rgba and w and h and w > 0 and h > 0) then
            return false
        end
        local tex
        ok = pcall(function()
            tex = draw.CreateTexture(rgba, w, h)
        end)
        if not (ok and tex) then return false end
        GH.nadeTex[nadeId] = { tex = tex, w = w, h = h }
        return GH.nadeTex[nadeId]
    end

    local function ghEnsureNadeTex(nadeId)
        nadeId = tostring(nadeId or "he")
        local cached = GH.nadeTex[nadeId]
        if cached ~= nil then return cached end
        local fname = NADE_ICON_FILES[nadeId]
        if not fname then
            GH.nadeTex[nadeId] = false
            return false
        end

        local data = ghReadLocalNadeSvg(fname)
        if not data and not GH.nadeSvgFetchTried[fname] then
            GH.nadeSvgFetchTried[fname] = true
            data = ghFetchNadeSvg(fname)
            if data then ghCacheNadeSvg(fname, data) end
        end
        if not data then
            GH.nadeTex[nadeId] = false
            return false
        end

        local info = ghRasterizeNadeSvg(nadeId, data)
        if not info then
            GH.nadeTex[nadeId] = false
            return false
        end
        return info
    end

    local function ghPrefetchNadeIcons()
        for id in pairs(NADE_ICON_FILES) do
            pcall(ghEnsureNadeTex, id)
        end
    end

    local function ghDrawNadeIconFallback(x, y, nadeId, a)
        local col = ghNadeColor(nadeId)
        if nadeId == "flash" then
            ghFilledCircle(x + 6, y + 6, 5, col, a)
            ghRect(x + 5, y + 1, 2, 3, col, a)
            ghRect(x + 1, y + 5, 3, 2, col, a)
            ghRect(x + 10, y + 5, 3, 2, col, a)
        elseif nadeId == "smoke" then
            ghFilledCircle(x + 5, y + 7, 4, col, a * 0.85)
            ghFilledCircle(x + 9, y + 6, 4, col, a)
            ghFilledCircle(x + 7, y + 4, 3, col, a * 0.7)
        elseif nadeId == "molotov" or nadeId == "incendiary" then
            ghRect(x + 5, y + 8, 4, 3, col, a)
            ghRect(x + 6, y + 4, 2, 4, col, a)
            ghRect(x + 4, y + 2, 2, 3, col, a * 0.8)
            ghRect(x + 8, y + 1, 2, 3, col, a * 0.7)
        elseif nadeId == "decoy" then
            ghCircleRing(x + 6, y + 6, 5, col, a, 2)
            ghFilledCircle(x + 6, y + 6, 2, col, a)
        else 
            ghRect(x + 3, y + 3, 8, 8, col, a)
            ghRect(x + 5, y + 1, 4, 2, col, a)
            ghRect(x + 5, y + 5, 4, 2, { 20, 22, 26 }, a * 0.7)
        end
    end

    local function ghDrawNadeIcon(x, y, nadeId, a, size)
        a = tonumber(a) or 255
        nadeId = tostring(nadeId or "he")
        local th = tonumber(size) or 14
        if th < 8 then th = 8 end
        local info = ghEnsureNadeTex(nadeId)
        if info and info.tex then
            local tw = (info.w / info.h) * th
            local drawn = false
            pcall(function()
                draw.Color(255, 255, 255, mfloor(a))
                draw.SetTexture(info.tex)
                draw.FilledRect(mfloor(x), mfloor(y), mfloor(x + tw), mfloor(y + th))
                draw.SetTexture(nil)
                drawn = true
            end)
            if drawn then return tw, th end
        end
        local s = th / 14
        if s > 1.05 then
            local ox = x + (th - 14) * 0.5
            local oy = y + (th - 14) * 0.5
            ghDrawNadeIconFallback(ox, oy, nadeId, a)
        else
            ghDrawNadeIconFallback(x, y, nadeId, a)
        end
        return th, th
    end

    local GROUP_DIST = 52

    local function ghDrawWorldFloorDisc(wx, wy, wz, radius, col, a)
        wx, wy, wz = tonumber(wx), tonumber(wy), tonumber(wz)
        radius = tonumber(radius)
        if not (wx and wy and wz and radius) or radius < 1 then return end
        a = tonumber(a) or 255
        local z = wz + 0.15
        local segs = 40
        local cx, cy = ghWorldToScreen(wx, wy, z)
        local edge = {}
        for i = 0, segs do
            local ang = (i / segs) * 6.28318530718
            local sx, sy = ghWorldToScreen(wx + mcos(ang) * radius, wy + msin(ang) * radius, z)
            edge[i + 1] = (sx and sy) and { sx, sy } or nil
        end

        local filled = false
        if cx and cy then
            pcall(function()
                local c = ghColor(col, a * 0.42)
                draw.Color(mfloor(c[1]), mfloor(c[2]), mfloor(c[3]), mfloor(c[4]))
                for i = 1, segs do
                    local p1, p2 = edge[i], edge[i + 1]
                    if p1 and p2 then
                        if draw.Triangle then
                            draw.Triangle(cx, cy, p1[1], p1[2], p2[1], p2[2])
                            filled = true
                        elseif draw.FilledTriangle then
                            draw.FilledTriangle(cx, cy, p1[1], p1[2], p2[1], p2[2])
                            filled = true
                        end
                    end
                end
            end)
        end

        if not filled then
            local rings = 12
            for ri = 1, rings do
                local rr = radius * (ri / rings)
                local aa = a * (0.10 + 0.50 * (ri / rings))
                local prevx, prevy
                for i = 0, segs do
                    local ang = (i / segs) * 6.28318530718
                    local sx, sy = ghWorldToScreen(wx + mcos(ang) * rr, wy + msin(ang) * rr, z)
                    if sx and sy and prevx and prevy then
                        ghLine(prevx, prevy, sx, sy, col, aa, 0)
                    end
                    if sx and sy then prevx, prevy = sx, sy else prevx, prevy = nil, nil end
                end
            end
            if cx and cy then
                for i = 1, segs, 2 do
                    local p = edge[i]
                    if p then ghLine(cx, cy, p[1], p[2], col, a * 0.18, 0) end
                end
            end
        end

        local prevx, prevy
        for i = 1, #edge do
            local p = edge[i]
            if p and prevx and prevy then
                ghLine(prevx, prevy, p[1], p[2], col, a * 0.95, 0)
            end
            if p then prevx, prevy = p[1], p[2] else prevx, prevy = nil, nil end
        end
    end

    local function ghDrawEditPrompt(sx, sy, ly, pulse, lineup)
        local editCol = { 255, 200, 80 }
        local prompt = "EDIT"
        local keyName = nil
        pcall(function()
            local code = tonumber(GH.editSpotKey and GH.editSpotKey:Get()) or 0
            if code ~= 0 and M and M.KeyName then
                keyName = M:KeyName(code)
            end
        end)
        if type(keyName) == "string" and keyName ~= "" and keyName ~= "none" and keyName ~= "None" then
            prompt = "EDIT  ·  " .. keyName
        end
        local pw = ghTextSize(GH.fonts.small, prompt)
        local px = sx - (pw + 16) * 0.5
        local py = ly - 20
        ghRect(px + 2, py + 2, pw + 16, 16, { 0, 0, 0 }, 70)
        ghRect(px, py, pw + 16, 16, editCol, 200 + 40 * (pulse or 0))
        ghText(GH.fonts.small, px + 8, py + 2, { 12, 14, 18 }, 255, prompt)
        if lineup then
            local hits = GH._editPromptHits
            if type(hits) ~= "table" then
                hits = {}
                GH._editPromptHits = hits
            end
            hits[#hits + 1] = { x = px, y = py, w = pw + 16, h = 16, L = lineup }
        end
    end

    local function ghPollEditPromptClicks()
        if not GH.editMode then
            GH._editPromptHits = nil
            GH._editPromptMouseWas = false
            return
        end
        if GH.savePopup or GH.editPopup or GH.floorMenu then
            GH._editPromptHits = nil
            return
        end
        if GH.rec and (GH.rec.active or GH.rec.trailing) then
            GH._editPromptHits = nil
            return
        end
        local hits = GH._editPromptHits
        GH._editPromptHits = nil
        if type(hits) ~= "table" or #hits == 0 then
            GH._editPromptMouseWas = select(3, ghMouse())
            return
        end
        local mx, my, mouseDown = ghMouse()
        local click = mouseDown and not (GH._editPromptMouseWas or false)
        GH._editPromptMouseWas = mouseDown
        if not click then return end
        for i = 1, #hits do
            local h = hits[i]
            if h and mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
                if h.floor and h.members then
                    GH._pendingFloorMembers = h.members
                    return
                end
                if h.L then
                    GH._pendingEditL = h.L
                    return
                end
            end
        end
    end

    local function ghDrawFloorGroup(wx, wy, wz, members, focusL, fade, near, pulse, editHint, editLineup, sw, sh)
        if fade <= 0.02 or not members or #members == 0 then return end
        local a = 255 * fade

        local focus = focusL or members[1]
        local col = ghNadeColor(focus.nade)
        local sameNade = true
        for i = 2, #members do
            if members[i].nade ~= members[1].nade then sameNade = false; break end
        end
        if sameNade then col = ghNadeColor(members[1].nade) end

        local worldR = near and (10 + (pulse or 0) * 1.5) or 8
        ghDrawWorldFloorDisc(wx, wy, wz, worldR, col, a * 0.55)
        if near then
            ghDrawWorldFloorDisc(wx, wy, wz, worldR * 0.4, col, a * (0.35 + 0.18 * (pulse or 0)))
        end

        local sx, sy = ghWorldToScreen(wx, wy, (tonumber(wz) or 0) + 2)
        if not sx or not sy then return end

        local accent, bg, _, text = ghMenuColors()
        local editCol = { 255, 200, 80 }
        local n = #members
        local rowH = 16
        local MAX_CHIP_ROWS = 3
        local shown = n
        if shown > MAX_CHIP_ROWS then shown = MAX_CHIP_ROWS end
        local overflow = n - shown
        local headerH = (n > 1) and 14 or 0
        local iconPad = 18
        local chipH = headerH + shown * rowH + (overflow > 0 and rowH or 0) + 10
        local chipW = 160
        local chipStart = 1
        if focus and overflow > 0 then
            local focusIdx = 1
            for i = 1, n do
                if members[i] and members[i].id == focus.id then
                    focusIdx = i
                    break
                end
            end
            chipStart = mmax(1, mmin(focusIdx - shown + 1, n - shown + 1))
        end
        for i = 0, shown - 1 do
            local L = members[chipStart + i]
            if L then
                local line = string.format("%s  ·  %s", tostring(L.name), ghDescLabel(L))
                local tw = ghTextSize(GH.fonts.small, line)
                if tw + 28 + iconPad > chipW then chipW = tw + 28 + iconPad end
            end
        end
        if n > 1 then
            local hw = ghTextSize(GH.fonts.small, n .. " LINEUPS")
            if hw + 28 > chipW then chipW = hw + 28 end
        end
        if overflow > 0 then
            local ow = ghTextSize(GH.fonts.small, "+" .. overflow .. " more — open edit")
            if ow + 28 > chipW then chipW = ow + 28 end
        end

        local lx = sx - chipW * 0.5
        local ly = sy - chipH - 16
        local screenH = tonumber(sh) or 0
        if screenH > 0 then
            local hudTop = screenH - 170
            local promptH = editHint and 22 or 0
            local bottom = ly + chipH
            if bottom > hudTop then
                local lift = bottom - hudTop
                ly = ly - lift
                sy = sy - lift
            end
            if editHint and (ly - promptH) < 8 then
                local bump = 8 - (ly - promptH)
                ly = ly + bump
                sy = sy + bump
            end
        end

        local top = editHint and editCol or accent
        ghRect(lx + 2, ly + 3, chipW, chipH, { 0, 0, 0 }, a * 0.35)
        ghRect(lx, ly, chipW, chipH, bg, a * 0.9)
        ghRect(lx, ly, 2, chipH, col, a * 0.95)
        ghRect(lx, ly, chipW, 1, top, a * (editHint and 1 or (near and 0.9 or 0.35)))
        if editHint then
            ghRect(lx + chipW - 2, ly, 2, chipH, editCol, 180 + 50 * (pulse or 0))
        end

        local cy = ly + 5
        if n > 1 then
            ghText(GH.fonts.small, lx + 10, cy, accent, a * 0.95, n .. " LINEUPS")
            cy = cy + headerH
        end
        for i = 0, shown - 1 do
            local L = members[chipStart + i]
            if L then
                local isFocus = focus and L.id == focus.id
                local rowCol = ghNadeColor(L.nade)
                local desc = ghDescLabel(L)
                local line = desc ~= "" and string.format("%s  ·  %s", tostring(L.name), desc) or tostring(L.name)
                if isFocus and n > 1 then
                    ghRect(lx + 4, cy - 1, chipW - 8, rowH, rowCol, a * 0.22)
                end
                ghDrawNadeIcon(lx + 8, cy + 1, L.nade, a * (isFocus and 1 or 0.75))
                ghText(GH.fonts.small, lx + 8 + iconPad, cy + 1, isFocus and text or rowCol, a * (isFocus and 1 or 0.75), line)
                cy = cy + rowH
            end
        end
        if overflow > 0 then
            ghText(GH.fonts.small, lx + 10, cy + 1, editHint and editCol or accent, a * 0.9, "+" .. overflow .. " more — open edit")
        end

        if editHint then
            ghDrawEditPrompt(sx, sy, ly, pulse, nil)
            local hits = GH._editPromptHits
            if type(hits) ~= "table" then
                hits = {}
                GH._editPromptHits = hits
            end
            hits[#hits + 1] = { x = lx, y = ly - 22, w = chipW, h = chipH + 22, floor = true, members = members }
        elseif near then
            local tag = n > 1 and ("STAND HERE · " .. n) or "STAND HERE"
            local tw = ghTextSize(GH.fonts.small, tag)
            ghRect(sx - tw * 0.5 - 6, sy + 18, tw + 12, 14, bg, a * 0.75)
            ghText(GH.fonts.small, sx - tw * 0.5, sy + 19, accent, a, tag)
        end
    end

    local function ghPickFocus(members, eye)
        if not members or #members == 0 then return nil, 1 end
        if #members == 1 then return members[1], 1 end
        local best, bestScore, bestIdx = members[1], 1e9, 1
        for i = 1, #members do
            local L = members[i]
            local aimP, aimY = ghLineupAimAngles(L)
            local dPitch = mabs(aimP - (eye and eye.pitch or 0))
            local dYaw = mabs(ghNormYaw(aimY - (eye and eye.yaw or 0)))
            local score = dPitch + dYaw
            if score < bestScore then
                bestScore, best, bestIdx = score, L, i
            end
        end
        return best, bestIdx
    end

    local EDIT_AIM_TOL = 1.25
    local LINEUP_PICK_TOL = 12
    local EDIT_FLOOR_TOL = 2.5

    local function ghAimClose(L, eye, tol)
        if not (L and eye) then return false end
        tol = tonumber(tol) or EDIT_AIM_TOL
        local aimP, aimY = ghLineupAimAngles(L)
        local dPitch = mabs(aimP - (eye.pitch or 0))
        local dYaw = mabs(ghNormYaw(aimY - (eye.yaw or 0)))
        return dPitch <= tol and dYaw <= tol
    end

    local function ghLookAtPos(eye, wx, wy, wz, tol)
        if not eye then return false, 1e9 end
        tol = tonumber(tol) or EDIT_FLOOR_TOL
        local ex = tonumber(eye.x) or tonumber(eye.fx) or 0
        local ey = tonumber(eye.y) or tonumber(eye.fy) or 0
        local ez = tonumber(eye.z) or ((tonumber(eye.fz) or 0) + (tonumber(eye.viewZ) or 64))
        local dx = (tonumber(wx) or 0) - ex
        local dy = (tonumber(wy) or 0) - ey
        local dz = (tonumber(wz) or 0) - ez
        local horiz = msqrt(dx * dx + dy * dy)
        if horiz < 0.001 and mabs(dz) < 0.001 then
            return true, 0
        end
        local wantYaw = math.deg(math.atan2(dy, dx))
        local wantPitch = math.deg(math.atan2(-dz, mmax(horiz, 0.001)))
        local dPitch = mabs(wantPitch - (eye.pitch or 0))
        local dYaw = mabs(ghNormYaw(wantYaw - (eye.yaw or 0)))
        return (dPitch <= tol and dYaw <= tol), (dPitch + dYaw)
    end

    local function ghAimScore(L, eye)
        if not (L and eye) then return 1e9 end
        local aimP, aimY = ghLineupAimAngles(L)
        local dPitch = mabs(aimP - (eye.pitch or 0))
        local dYaw = mabs(ghNormYaw(aimY - (eye.yaw or 0)))
        return dPitch + dYaw, dPitch, dYaw
    end

    local function ghBindLabel(keybox, fallback)
        local code = tonumber(keybox and keybox:Get()) or 0
        local name = fallback or "key"
        pcall(function() name = M:KeyName(code) end)
        if code == 0 or not name or name == "" or name == "none" or name == "None" then
            return fallback or "key"
        end
        return tostring(name)
    end

    local function ghDrawAimPoint(L, eye, sw, sh, col, onSpot, editHint)
        if not onSpot then return false, nil, nil end
        local aim = ghAimWorld(L, 1000)
        local sx, sy = ghWorldToScreen(aim.x, aim.y, aim.z)
        if not (sx and sy) then return false, nil, nil end
        if sx < -80 or sy < -80 or sx > sw + 80 or sy > sh + 80 then return false, nil, nil end

        local aimP, aimY = ghLineupAimAngles(L)
        local dPitch = aimP - eye.pitch
        local dYaw = ghNormYaw(aimY - eye.yaw)
        local locked = mabs(dPitch) <= 0.55 and mabs(dYaw) <= 0.55

        local pulse = 0.5 + 0.5 * msin((GH.pulse or 0) * 3.4)
        local accent, bg, _, text = ghMenuColors()
        local a = locked and 255 or (190 + 50 * pulse)
        local style = mmax(1, mmin(4, mfloor(tonumber(GH.aimStyle and GH.aimStyle:Get()) or 4)))
        local editCol = { 255, 200, 80 }

        if style == 1 then
            local r = locked and 4 or 3
            ghFilledCircle(sx, sy, r, col, locked and 160 or 110)
        elseif style == 2 then
            ghFilledCircle(sx, sy, locked and 4 or 3, col, a)
            ghCircleRing(sx, sy, locked and 12 or 10, col, a * 0.9, 2)
            if locked then ghCircleRing(sx, sy, 15, col, 160, 1) end
        elseif style == 3 then
            local arm = locked and 12 or 9
            ghRect(sx - arm, sy - 1, arm * 2, 2, col, a)
            ghRect(sx - 1, sy - arm, 2, arm * 2, col, a)
            ghFilledCircle(sx, sy, 2, { 255, 255, 255 }, locked and 240 or 180)
            ghFilledCircle(sx, sy, 1, col, 255)
        else
            local arm = locked and 14 or 11
            local gap = locked and 5 or 6
            local t = 2
            ghRect(sx - arm, sy - arm, arm - gap, t, col, a)
            ghRect(sx - arm, sy - arm, t, arm - gap, col, a)
            ghRect(sx + gap, sy - arm, arm - gap, t, col, a)
            ghRect(sx + arm - t, sy - arm, t, arm - gap, col, a)
            ghRect(sx - arm, sy + arm - t, arm - gap, t, col, a)
            ghRect(sx - arm, sy + gap, t, arm - gap, col, a)
            ghRect(sx + gap, sy + arm - t, arm - gap, t, col, a)
            ghRect(sx + arm - t, sy + gap, t, arm - gap, col, a)
            ghRect(sx - 3, sy - 1, 6, 2, { 255, 255, 255 }, locked and 240 or 160)
            ghRect(sx - 1, sy - 3, 2, 6, { 255, 255, 255 }, locked and 240 or 160)
            ghRect(sx - 1, sy - 1, 2, 2, col, 255)
            if locked then
                ghRect(sx - arm - 2, sy - arm - 2, (arm + 2) * 2, 1, col, 220)
                ghRect(sx - arm - 2, sy + arm + 1, (arm + 2) * 2, 1, col, 220)
            end
        end

        local desc = ghDescLabel(L)
        local title = tostring(L.name)
        local sub = desc ~= "" and string.format("%s  ·  %s", ghNadeShort(L.nade), desc) or ghNadeShort(L.nade)
        local tw1 = ghTextSize(GH.fonts.body, title)
        local tw2 = ghTextSize(GH.fonts.small, sub)
        local iconPad = 18
        local chipW = mmax(tw1, tw2) + 22 + iconPad
        local chipH = 36
        local lx = sx - chipW * 0.5
        local ly = sy - 48
        local top = editHint and editCol or col
        ghRect(lx + 2, ly + 3, chipW, chipH, { 0, 0, 0 }, 70)
        ghRect(lx, ly, chipW, chipH, bg, 220)
        ghRect(lx, ly, chipW, 2, top, editHint and 255 or (locked and 255 or 170))
        ghRect(lx, ly, 2, chipH, top, 230)
        if editHint then
            ghRect(lx + chipW - 2, ly, 2, chipH, editCol, 180 + 50 * pulse)
        end
        ghDrawNadeIcon(lx + 8, ly + 11, L.nade, 255)
        ghText(GH.fonts.body, lx + 8 + iconPad, ly + 6, text, 255, title)
        ghText(GH.fonts.small, lx + 8 + iconPad, ly + 20, col, 230, sub)

        if editHint then
            ghDrawEditPrompt(sx, sy, ly, pulse, L)
        end
        return locked, sx, sy
    end

    local function ghDrawAimLine(sw, sh, ax, ay, col, locked)
        if not (GH.aimLine and GH.aimLine.Get and GH.aimLine:Get()) then return end
        if not (ax and ay) then return end
        local cx, cy = sw * 0.5, sh * 0.5
        local baseA = locked and 255 or 200
        local dx, dy = ax - cx, ay - cy
        local len = msqrt(dx * dx + dy * dy)
        if len < 4 then return end
        local steps = mmax(8, mfloor(len / 3))
        for i = 0, steps do
            local t = i / steps
            local px = cx + dx * t
            local py = cy + dy * t
            local aa = baseA * (1 - t * 0.55)
            if i > 0 then
                local pt = (i - 1) / steps
                local ppx = cx + dx * pt
                local ppy = cy + dy * pt
                ghLine(ppx, ppy, px, py, col, aa, 0)
            end
        end
    end

    local function ghCountLineups(nadeId)
        local map = ghMapName()
        local total, typed = 0, 0
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and ghMapMatch(L.map, map) then
                total = total + 1
                if nadeId and ghNadeCompatible(L.nade, nadeId) then typed = typed + 1 end
            end
        end
        return total, typed
    end

    local function ghDrawHud(sw, sh, nade, nearby, aligned, alignL, groupCount, focusIdx)
        if not (GH.hud:Get() and true or false) then return end
        local onlySpot = GH.hudOnSpot and GH.hudOnSpot:Get() and true or false
        local menuOpen = M._open and true or false
        if onlySpot and not nearby and not menuOpen and not GH.editMode and not (GH.rec and GH.rec.session)
            and not (GH.play and (GH.play.state == "macro" or GH.play.state == "align")) then
            return
        end
        local accent, bg, bg2, text = ghMenuColors()
        local nadeCol = (nade and nade.held and nade.color) or accent
        local pulse = 0.5 + 0.5 * msin((GH.pulse or 0) * 3.2)
        local capturing = GH.rec and (GH.rec.active or GH.rec.trailing)
        local editing = GH.editMode or capturing
        local idleEdit = GH.editMode and not capturing

        local muted = {
            mfloor(((text[1] or 205) + 110) * 0.5),
            mfloor(((text[2] or 213) + 120) * 0.5),
            mfloor(((text[3] or 225) + 130) * 0.5),
        }

        local header, title, tip, tip2, tip3 = "GRENADE HELPER", "GRENADE HELPER", nil, nil, nil
        local titleCol = nadeCol
        local tag = nil
        local topCol = accent

        if GH.rec and (GH.rec.active or GH.rec.trailing) then topCol = { 255, 90, 90, 255 }
        elseif GH.play and GH.play.state == "macro" then topCol = { 120, 220, 140, 255 }
        elseif GH.play and GH.play.state == "align" then topCol = { 120, 200, 255, 255 }
        elseif GH.editMode and GH.rec and (GH.rec.takes or 0) > 0 then topCol = { 255, 180, 70, 255 }
        elseif GH.editMode then topCol = { 255, 200, 80, 255 }
        end

        local function tickInterval()
            local ti = 1 / 64
            pcall(function()
                local t = globals.TickInterval and globals.TickInterval() or (1 / 64)
                if type(t) == "number" and t > 0 then ti = t end
            end)
            return ti
        end

        if GH.play and GH.play.state == "align" then
            header = "GRENADE HELPER"
            title = "LOCKING AIM"
            titleCol = topCol
            if GH.play._onSpot == false then
                tip = "Centering on spot…"
                tip2 = "Hold execute — release cancels"
            else
                tip = "Settling onto aimspot…"
                tip2 = "Throw starts after lock"
            end
            if nearby and alignL then
                tag = aligned and "ALIGNED" or "ON SPOT"
            end
        elseif GH.play and GH.play.state == "macro" then
            header = "GRENADE HELPER"
            title = "EXECUTING"
            titleCol = topCol
            local L = GH.play.active
            tip = L and tostring(L.name or "lineup") or "Executing lineup"
            tip2 = "Hold execute — release cancels"
            if nearby and alignL then
                tag = aligned and "ALIGNED" or "ON SPOT"
            end
        elseif editing then
            local R = GH.rec
            titleCol = topCol
            if R and (R.active or R.trailing) then
                local ti = tickInterval()
                header = "RECORDING"
                title = string.format("%.2fs  ·  %d ticks", (R.ticks or 0) * ti, R.ticks or 0)
                tip = "Capturing throw…"
            elseif R and (R.takes or 0) > 0 then
                local ti = tickInterval()
                local ticks = tonumber(R.lastTicks) or 0
                header = "TAKE READY"
                title = string.format("%.2fs  ·  %d ticks", ticks * ti, ticks)
                tip = string.format("Press %s to save", ghBindLabel(GH.recordKey, "save"))
                tip2 = "Throw again to replace this take"
            else
                header = "GRENADE HELPER"
                title = "EDIT MODE"
                if GH.aimEditL then
                    local L = GH.aimEditL
                    local desc = ghDescLabel(L)
                    tip = desc ~= ""
                        and string.format("%s  ·  %s", tostring(L.name or "Aimspot"), desc)
                        or tostring(L.name or "Aimspot")
                    tip2 = string.format("Press %s to edit", ghBindLabel(GH.editSpotKey, "edit"))
                    tip3 = nil
                    tag = "EDIT"
                elseif GH.floorFocusL then
                    local L = GH.floorFocusL
                    local n = (GH.floorFocus and GH.floorFocus.members and #GH.floorFocus.members) or 1
                    tip = n > 1
                        and string.format("%s   ·   %d lineups", tostring(L.name or "Spot"), n)
                        or tostring(L.name or "Floor spot")
                    tip2 = string.format("Press %s for lineup menu", ghBindLabel(GH.editSpotKey, "edit"))
                    tip3 = nil
                    tag = "EDIT"
                else
                    tip = "Throw a grenade to record"
                    tip2 = string.format("Press %s to save last throw", ghBindLabel(GH.recordKey, "save"))
                    tip3 = string.format("Press %s to edit", ghBindLabel(GH.editSpotKey, "edit"))
                end
            end
            if GH.aimEditL or GH.floorFocusL then
                tag = "EDIT"
            elseif nearby and alignL then
                tag = aligned and "ALIGNED" or "ON SPOT"
            end
        else
            header = "GRENADE HELPER"
            title = (nade and nade.held and nade.label) or "GRENADE HELPER"
            titleCol = nadeCol
            if nearby and alignL then
                local desc = ghDescLabel(alignL)
                tip = desc ~= "" and string.format("%s  ·  %s", tostring(alignL.name), desc) or tostring(alignL.name)
                groupCount = tonumber(groupCount) or 1
                focusIdx = tonumber(focusIdx) or 1
                if groupCount > 1 then
                    tip = string.format("%s   %d/%d", tip, focusIdx, groupCount)
                    tip2 = "Look at an aimspot, then execute / edit"
                end
                tag = aligned and "ALIGNED" or "ON SPOT"
            else
                local total, typed = ghCountLineups(nade and nade.id or nil)
                if nade and nade.held and nade.id then
                    tip = string.format("%d %s lineups on map", typed, ghNadeShort(nade.id))
                else
                    tip = string.format("%d lineups on map", total)
                end
            end
        end

        local cardH = 88
        if tip3 and tip3 ~= "" then cardH = 120
        elseif tip2 and tip2 ~= "" then cardH = 104 end
        local pad = 28
        local iconExtra = 0
        local previewIcon = nil
        if nade and nade.held and nade.id then
            previewIcon = nade.id
        elseif alignL and alignL.nade then
            previewIcon = alignL.nade
        end
        if previewIcon then iconExtra = 38 end
        local need = 300
        need = mmax(need, ghTextSize(GH.fonts.small, header) + pad + iconExtra)
        need = mmax(need, ghTextSize(GH.fonts.title, title) + pad + iconExtra)
        if tip and tip ~= "" then need = mmax(need, ghTextSize(GH.fonts.body, tip) + pad) end
        if tip2 and tip2 ~= "" then need = mmax(need, ghTextSize(GH.fonts.body, tip2) + pad) end
        if tip3 and tip3 ~= "" then need = mmax(need, ghTextSize(GH.fonts.body, tip3) + pad) end
        if tag then
            local tagW = ghTextSize(GH.fonts.small, tag) + 28
            need = mmax(need, ghTextSize(GH.fonts.small, header) + tagW + 36 + iconExtra)
            need = mmax(need, ghTextSize(GH.fonts.title, title) + tagW + 36 + iconExtra)
        end
        local cardW = mmin(mmax(300, mfloor(need + 0.5)), mmax(300, sw - 16))

        local x = mfloor((sw - cardW) * 0.5)
        local y = mfloor(sh - cardH - 48)
        if GH.pos.x ~= nil and GH.pos.y ~= nil then
            x, y = mfloor(GH.pos.x), mfloor(GH.pos.y)
        end
        if x < 0 then x = 0 elseif x > sw - cardW then x = mmax(0, sw - cardW) end
        if y < 0 then y = 0 elseif y > sh - cardH then y = mmax(0, sh - cardH) end

        local mx, my, mouseDown = ghMouse()
        local pressed = mouseDown and not GH._mouseDown
        GH._mouseDown = mouseDown
        if menuOpen then
            local hov = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH
            if pressed and hov then
                GH._drag = { dx = mx - x, dy = my - y }
            end
            if GH._drag then
                if mouseDown then
                    x = mx - GH._drag.dx
                    y = my - GH._drag.dy
                    if x < 0 then x = 0 elseif x > sw - cardW then x = mmax(0, sw - cardW) end
                    if y < 0 then y = 0 elseif y > sh - cardH then y = mmax(0, sh - cardH) end
                    GH.pos.x, GH.pos.y = x, y
                else
                    GH._drag = nil
                end
            end
        else
            GH._drag = nil
        end

        local borderA = (GH._drag and 220) or (menuOpen and 90) or 18
        local tagCol = editing and topCol or nadeCol
        ghRect(x + 3, y + 5, cardW, cardH, { 0, 0, 0 }, 55)
        ghRect(x, y, cardW, cardH, bg, 214)
        ghRect(x, y, cardW, 2, topCol, 235)
        ghRect(x, y + cardH - 1, cardW, 1, { 0, 0, 0 }, 150)
        ghRect(x, y + 2, 1, cardH - 3, { 255, 255, 255 }, borderA)
        ghRect(x + cardW - 1, y + 2, 1, cardH - 3, { 255, 255, 255 }, borderA)

        local iconId = nil
        if nade and nade.held and nade.id then
            iconId = nade.id
        elseif alignL and alignL.nade then
            iconId = alignL.nade
        end
        local iconReserve = 0
        local iconH = 22
        if iconId then
            local info = ghEnsureNadeTex(iconId)
            local iw = (info and info.w and info.h and info.h > 0) and ((info.w / info.h) * iconH) or iconH
            iconReserve = iw + 14
            local ix = x + cardW - 12 - iw
            local iy = y + 10
            ghDrawNadeIcon(ix, iy, iconId, 255, iconH)
        end

        if tag then
            local tw = ghTextSize(GH.fonts.small, tag)
            local tx = x + cardW - 14 - tw - iconReserve
            ghRect(tx - 8, y + 12, tw + 16, 18, tagCol, aligned and 210 or (55 + 45 * pulse))
            ghText(GH.fonts.small, tx, y + 15, aligned and { 12, 14, 18 } or text, 255, tag)
        end

        ghText(GH.fonts.small, x + 14, y + 8, muted, 220, header)
        ghText(GH.fonts.title, x + 14, y + 22, titleCol, 255, title)
        if tip and tip ~= "" then
            ghText(GH.fonts.body, x + 14, y + 50, text, 230, tip)
        end
        if tip2 and tip2 ~= "" then
            ghText(GH.fonts.body, x + 14, y + 70, text, 230, tip2)
        end
        if tip3 and tip3 ~= "" then
            ghText(GH.fonts.body, x + 14, y + 90, text, 230, tip3)
        end
    end

    local STAND_RANGE = 17

    local function ghStandRange()
        return STAND_RANGE
    end

    local function ghDrawMarkers(eye, heldId, standRange, showDist, sw, sh)
        if not eye then return nil, false, 1, 1, nil end
        standRange = tonumber(standRange) or STAND_RANGE
        local editBrowse = GH.editMode and not (GH.rec and (GH.rec.active or GH.rec.trailing))
        if not editBrowse and not heldId then return nil, false, 1, 1, nil end
        local map = ghMapName()
        local matchOnly = (not editBrowse) and not (GH.showAllSpots and GH.showAllSpots:Get() and true or false)
        local pulse = 0.5 + 0.5 * msin((GH.pulse or 0) * 3.0)
        local items = {}
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and ghMapMatch(L.map, map) then
                local show = (not matchOnly) or (heldId and ghNadeCompatible(L.nade, heldId))
                if show then
                    local dist = ghDist2(eye.fx, eye.fy, eye.fz, L.x, L.y, L.z)
                    local fade = ghFade(dist, showDist)
                    if fade > 0.02 then
                        items[#items + 1] = {
                            L = L,
                            dist = dist,
                            fade = fade,
                            onSpot = dist <= standRange,
                        }
                    end
                end
            end
        end

        local used = {}
        local groups = {}
        for i = 1, #items do
            if not used[i] then
                local seed = items[i]
                local g = {
                    members = { seed.L },
                    dist = seed.dist,
                    fade = seed.fade,
                    onSpot = seed.onSpot,
                    x = tonumber(seed.L.x) or 0,
                    y = tonumber(seed.L.y) or 0,
                    z = tonumber(seed.L.z) or 0,
                    n = 1,
                }
                used[i] = true
                for j = i + 1, #items do
                    if not used[j] then
                        local o = items[j]
                        local d = ghDist2(g.x, g.y, g.z, o.L.x, o.L.y, o.L.z)
                        if d <= GROUP_DIST then
                            used[j] = true
                            g.members[#g.members + 1] = o.L
                            g.n = g.n + 1
                            g.x = (g.x * (g.n - 1) + (tonumber(o.L.x) or 0)) / g.n
                            g.y = (g.y * (g.n - 1) + (tonumber(o.L.y) or 0)) / g.n
                            g.z = (g.z * (g.n - 1) + (tonumber(o.L.z) or 0)) / g.n
                            if o.dist < g.dist then g.dist = o.dist end
                            if o.fade > g.fade then g.fade = o.fade end
                            if o.onSpot then g.onSpot = true end
                        end
                    end
                end
                groups[#groups + 1] = g
            end
        end

        local best, bestDist, bestAligned = nil, 1e9, false
        local bestCount, bestIdx = 1, 1
        local floorLook, floorScore = nil, 1e9
        local cx = (tonumber(sw) or 0) * 0.5
        local cy = (tonumber(sh) or 0) * 0.5
        local aimEditReady = false
        if editBrowse and eye then
            for gi = 1, #groups do
                local g = groups[gi]
                if g.onSpot then
                    for mi = 1, #g.members do
                        if ghAimClose(g.members[mi], eye, EDIT_AIM_TOL) then
                            aimEditReady = true
                            break
                        end
                    end
                end
                if aimEditReady then break end
            end
        end

        if editBrowse and (not aimEditReady) and eye then
            for gi = 1, #groups do
                local g = groups[gi]
                local okLook, score = ghLookAtPos(
                    eye, g.x, g.y, (tonumber(g.z) or 0) + 18, EDIT_FLOOR_TOL
                )
                if okLook and score < floorScore then
                    floorScore, floorLook = score, g
                end
            end
            if (not floorLook) and cx > 0 and cy > 0 then
                for gi = 1, #groups do
                    local g = groups[gi]
                    local fsx, fsy = ghWorldToScreen(g.x, g.y, (tonumber(g.z) or 0) + 2)
                    if fsx and fsy then
                        local n = #g.members
                        local shown = n > 3 and 3 or n
                        local overflow = n - shown
                        local chipH = ((n > 1) and 14 or 0) + shown * 16 + (overflow > 0 and 16 or 0) + 10
                        local chipW = 220
                        local lx = fsx - chipW * 0.5
                        local ly = fsy - chipH - 16
                        local hudTop = (tonumber(sh) or 0) - 170
                        if (tonumber(sh) or 0) > 0 and (ly + chipH) > hudTop then
                            ly = ly - ((ly + chipH) - hudTop)
                        end
                        if cx >= lx and cx <= lx + chipW and cy >= (ly - 22) and cy <= (ly + chipH) then
                            local dx = cx - fsx
                            local dy = cy - (ly + chipH * 0.5)
                            local score = msqrt(dx * dx + dy * dy) + (g.dist or 0) * 0.01
                            if score < floorScore then
                                floorScore, floorLook = score, g
                            end
                        end
                    end
                end
            end
        end

        local floorEditL = nil
        if floorLook and floorLook.members and #floorLook.members > 0 then
            floorEditL = (#floorLook.members == 1)
                and floorLook.members[1]
                or select(1, ghPickFocus(floorLook.members, eye))
        end

        local aimEditL = nil
        for gi = 1, #groups do
            local g = groups[gi]
            local focus, fIdx = ghPickFocus(g.members, eye)
            local floorHint = (floorLook ~= nil and g == floorLook)
            ghDrawFloorGroup(
                g.x, g.y, g.z, g.members, focus, g.fade, g.onSpot, pulse,
                floorHint, floorHint and floorEditL or nil, sw, sh
            )

            if g.onSpot and focus then
                local canEdit = editBrowse
                for mi = 1, #g.members do
                    local L = g.members[mi]
                    local col = ghNadeColor(L.nade)
                    local isFocus = focus.id == L.id
                    local editHint = canEdit and isFocus and ghAimClose(L, eye, EDIT_AIM_TOL)
                    if editHint then aimEditL = L end
                    local locked, ax, ay = ghDrawAimPoint(L, eye, sw, sh, col, true, editHint)
                    if ax and ay then
                        ghDrawAimLine(sw, sh, ax, ay, col, locked or isFocus)
                    end
                    if isFocus and g.dist < bestDist then
                        bestDist, best, bestAligned = g.dist, L, locked
                        bestCount, bestIdx = g.n, fIdx
                    end
                end
            elseif g.dist < bestDist then
                bestDist, best, bestAligned = g.dist, focus, false
                bestCount, bestIdx = g.n, fIdx
            end
        end

        GH.aimEditL = (editBrowse and aimEditL) or nil
        if editBrowse and floorLook and floorEditL and not aimEditL then
            GH.floorFocus = floorLook
            GH.floorFocusL = floorEditL
        elseif editBrowse then
            GH.floorFocus, GH.floorFocusL = nil, nil
        end

        if best and bestDist <= standRange then
            if not bestAligned then
                local aimP, aimY = ghLineupAimAngles(best)
                local dPitch = aimP - eye.pitch
                local dYaw = ghNormYaw(aimY - eye.yaw)
                bestAligned = mabs(dPitch) <= 0.55 and mabs(dYaw) <= 0.55
            end
            return best, bestAligned, bestCount, bestIdx, floorLook
        end
        return nil, false, 1, 1, floorLook
    end

    local IN_ATTACK, IN_JUMP, IN_DUCK = 1, 2, 4
    local IN_FORWARD, IN_BACK = 8, 16
    local IN_USE = 32
    local IN_MOVELEFT, IN_MOVERIGHT = 512, 1024
    local IN_ATTACK2 = 2048
    local IN_SPEED = 65536
    local BTN_ORDER = {
        "in_attack", "in_jump", "in_duck", "in_forward", "in_moveleft",
        "in_moveright", "in_back", "in_use", "in_attack2", "in_speed"
    }
    local BTN_CHARS = {
        in_attack = "A", in_jump = "J", in_duck = "D",
        in_forward = "F", in_moveleft = "L", in_moveright = "R",
        in_back = "B", in_use = "U", in_attack2 = "Z", in_speed = "S"
    }

    local function ghFlagDown(buttons, flag)
        if bit and bit.band then return bit.band(buttons, flag) ~= 0 end
        return math.floor(buttons / flag) % 2 == 1
    end

    local function ghCalcMove(btn1, btn2)
        if btn1 then return 1 end
        if btn2 then return -1 end
        return 0
    end

    local function ghCaptureCmdFrame(cmd)
        local buttons = 0
        pcall(function() buttons = math.floor(cmd:GetButtons() or 0) end)
        local view
        pcall(function() view = cmd:GetViewAngles() end)
        if view == nil then
            pcall(function() if engine and engine.GetViewAngles then view = engine.GetViewAngles() end end)
        end
        local pitch, yaw = 0, 0
        if view then
            pitch = tonumber(view.pitch or view.x or view[1]) or 0
            yaw = tonumber(view.yaw or view.y or view[2]) or 0
        end
        local fwd, side = 0, 0
        pcall(function() fwd = cmd:GetForwardMove() or 0 end)
        pcall(function() side = cmd:GetSideMove() or 0 end)
        return {
            pitch = pitch, yaw = yaw,
            forwardmove = fwd, sidemove = side,
            in_attack = ghFlagDown(buttons, IN_ATTACK),
            in_attack2 = ghFlagDown(buttons, IN_ATTACK2),
            in_jump = ghFlagDown(buttons, IN_JUMP),
            in_duck = ghFlagDown(buttons, IN_DUCK),
            in_forward = ghFlagDown(buttons, IN_FORWARD),
            in_back = ghFlagDown(buttons, IN_BACK),
            in_moveleft = ghFlagDown(buttons, IN_MOVELEFT),
            in_moveright = ghFlagDown(buttons, IN_MOVERIGHT),
            in_use = ghFlagDown(buttons, IN_USE),
            in_speed = ghFlagDown(buttons, IN_SPEED),
        }
    end

    local function ghCompressUsercmds(usercmds)
        if type(usercmds) ~= "table" or #usercmds == 0 then return {} end
        local frames = {}
        local current = {
            viewangles = { pitch = usercmds[1].pitch, yaw = usercmds[1].yaw },
            buttons = {},
        }
        for _, key in ipairs(BTN_ORDER) do current.buttons[key] = false end
        local empty_count = 0
        for _, cmd in ipairs(usercmds) do
            local buttons = ""
            for _, btn in ipairs(BTN_ORDER) do
                local value_prev = current.buttons[btn]
                if cmd[btn] and not value_prev then
                    buttons = buttons .. BTN_CHARS[btn]
                elseif not cmd[btn] and value_prev then
                    buttons = buttons .. string.lower(BTN_CHARS[btn])
                end
                current.buttons[btn] = cmd[btn] and true or false
            end
            local frame = {
                cmd.pitch - current.viewangles.pitch,
                cmd.yaw - current.viewangles.yaw,
                buttons,
                cmd.forwardmove,
                cmd.sidemove,
            }
            current.viewangles = { pitch = cmd.pitch, yaw = cmd.yaw }
            if frame[#frame] == ghCalcMove(cmd.in_moveright, cmd.in_moveleft) then
                frame[#frame] = nil
                if frame[#frame] == ghCalcMove(cmd.in_forward, cmd.in_back) then
                    frame[#frame] = nil
                    if frame[#frame] == "" then
                        frame[#frame] = nil
                        if frame[#frame] == 0 then
                            frame[#frame] = nil
                            if frame[#frame] == 0 then frame[#frame] = nil end
                        end
                    end
                end
            end
            if #frame > 0 then
                if empty_count > 0 then
                    frames[#frames + 1] = empty_count
                    empty_count = 0
                end
                frames[#frames + 1] = frame
            else
                empty_count = empty_count + 1
            end
        end
        if empty_count > 0 then frames[#frames + 1] = empty_count end
        return frames
    end

    local BTN_CHARS_INV = {
        A = "in_attack", J = "in_jump", D = "in_duck",
        F = "in_forward", L = "in_moveleft", R = "in_moveright",
        B = "in_back", U = "in_use", Z = "in_attack2", S = "in_speed",
    }

    local function ghParseButtonsStr(str)
        local down, up = {}, {}
        if type(str) ~= "string" then return down, up end
        for i = 1, #str do
            local c = str:sub(i, i)
            local lower = c:lower()
            if c == lower then
                up[#up + 1] = BTN_CHARS_INV[c:upper()]
            else
                down[#down + 1] = BTN_CHARS_INV[c]
            end
        end
        return down, up
    end

    local function ghDecompressFrames(raw_frames, base_ang)
        if type(raw_frames) ~= "table" then return nil end
        local expanded = {}
        for _, frame in ipairs(raw_frames) do
            if type(frame) == "number" then
                if frame <= 0 then return nil end
                for _ = 1, frame do expanded[#expanded + 1] = {} end
            elseif type(frame) == "table" then
                expanded[#expanded + 1] = frame
            else
                return nil
            end
        end
        local current = {
            viewangles = {
                pitch = (base_ang and base_ang.pitch) or 0,
                yaw = (base_ang and base_ang.yaw) or 0,
            },
            buttons = {},
            forwardmove = 0,
            sidemove = 0,
        }
        for _, key in ipairs(BTN_ORDER) do current.buttons[key] = false end
        local out = {}
        for i, value in ipairs(expanded) do
            local pitch = value[1]
            local yaw = value[2]
            local buttons = value[3]
            local forwardmove = value[4]
            local sidemove = value[5]
            current.viewangles.pitch = current.viewangles.pitch + (pitch or 0)
            current.viewangles.yaw = current.viewangles.yaw + (yaw or 0)
            if type(buttons) == "string" then
                local buttons_down, buttons_up = ghParseButtonsStr(buttons)
                for _, btn in ipairs(buttons_down) do
                    if btn then current.buttons[btn] = true end
                end
                for _, btn in ipairs(buttons_up) do
                    if btn then current.buttons[btn] = false end
                end
            end
            if type(forwardmove) == "number" then
                current.forwardmove = forwardmove
            else
                current.forwardmove = ghCalcMove(current.buttons.in_forward, current.buttons.in_back)
            end
            if type(sidemove) == "number" then
                current.sidemove = sidemove
            else
                current.sidemove = ghCalcMove(current.buttons.in_moveright, current.buttons.in_moveleft)
            end
            local row = {
                pitch = current.viewangles.pitch,
                yaw = current.viewangles.yaw,
                forwardmove = current.forwardmove,
                sidemove = current.sidemove,
            }
            for btn, pressed in pairs(current.buttons) do
                row[btn] = pressed
            end
            out[i] = row
        end
        return out
    end

    local function ghEnsureMacroCmds(L)
        if not L then return nil end
        if L._macroCmds then return L._macroCmds end
        if not ghHasMacro(L) then return nil end
        local base = {
            pitch = tonumber(L.seedPitch or L.pitch) or 0,
            yaw = tonumber(L.seedYaw or L.yaw) or 0,
        }
        local ok, cmds = pcall(ghDecompressFrames, L.frames, base)
        if not ok or type(cmds) ~= "table" or #cmds == 0 then return nil end
        L._macroCmds = cmds
        return cmds
    end

    local function ghBitBand(a, b)
        if bit and bit.band then return bit.band(a, b) end
        local r, p = 0, 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) and (b % 2 == 1) then r = r + p end
            a, b, p = mfloor(a / 2), mfloor(b / 2), p * 2
        end
        return r
    end

    local function ghBitBor(a, b)
        if bit and bit.bor then return bit.bor(a, b) end
        local r, p = 0, 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) or (b % 2 == 1) then r = r + p end
            a, b, p = mfloor(a / 2), mfloor(b / 2), p * 2
        end
        return r
    end

    local function ghBitBnot(a)
        if bit and bit.bnot then return bit.bnot(a) end
        return (0xFFFFFFFF - a)
    end

    local function ghClearControlledButtons(buttons)
        buttons = ghBitBand(buttons, ghBitBnot(IN_ATTACK))
        buttons = ghBitBand(buttons, ghBitBnot(IN_ATTACK2))
        buttons = ghBitBand(buttons, ghBitBnot(IN_JUMP))
        buttons = ghBitBand(buttons, ghBitBnot(IN_DUCK))
        buttons = ghBitBand(buttons, ghBitBnot(IN_FORWARD))
        buttons = ghBitBand(buttons, ghBitBnot(IN_BACK))
        buttons = ghBitBand(buttons, ghBitBnot(IN_MOVELEFT))
        buttons = ghBitBand(buttons, ghBitBnot(IN_MOVERIGHT))
        return buttons
    end

    local function ghApplyView(cmd, pitch, yaw)
        pitch = mmax(-89, mmin(89, tonumber(pitch) or 0))
        yaw = ghNormYaw(yaw)
        local ang
        pcall(function()
            if EulerAngles then
                ang = EulerAngles(pitch, yaw, 0)
                if ang.Normalize then ang:Normalize() end
                if ang.Clamp then ang:Clamp() end
            end
        end)
        if ang then
            pcall(function() if engine and engine.SetViewAngles then engine.SetViewAngles(ang) end end)
            pcall(function() cmd:SetViewAngles(ang) end)
        else
            pcall(function()
                if engine and engine.SetViewAngles then
                    engine.SetViewAngles({ pitch = pitch, yaw = yaw, roll = 0 })
                end
            end)
            pcall(function() cmd:SetViewAngles({ pitch = pitch, yaw = yaw, roll = 0 }) end)
        end
        return pitch, yaw
    end

    local function ghWriteMacro(cmd, frame, opts)
        if not frame then return end
        opts = opts or {}
        if not opts.keepView then
            local pitch = (tonumber(frame.pitch) or 0) + EXEC_PITCH_BIAS
            local yaw = tonumber(frame.yaw) or 0
            ghApplyView(cmd, pitch, yaw)
        end
        local fwd = opts.zeroMove and 0 or (tonumber(frame.forwardmove) or 0)
        local side = opts.zeroMove and 0 or (tonumber(frame.sidemove) or 0)
        pcall(function() cmd:SetForwardMove(fwd) end)
        pcall(function() cmd:SetSideMove(side) end)
        pcall(function() cmd:SetUpMove(0) end)
        local buttons = 0
        pcall(function() buttons = math.floor(cmd:GetButtons() or 0) end)
        buttons = ghClearControlledButtons(buttons)
        buttons = ghBitBand(buttons, ghBitBnot(IN_USE))
        buttons = ghBitBand(buttons, ghBitBnot(IN_SPEED))
        local allowThrow = not opts.noThrow
        if allowThrow then
            if opts.forceAttack2 then
                if frame.in_attack or frame.in_attack2 then
                    buttons = ghBitBor(buttons, IN_ATTACK2)
                end
            else
                if frame.in_attack then buttons = ghBitBor(buttons, IN_ATTACK) end
                if frame.in_attack2 then buttons = ghBitBor(buttons, IN_ATTACK2) end
            end
            if frame.in_jump then buttons = ghBitBor(buttons, IN_JUMP) end
        end
        if opts.keepAttack then buttons = ghBitBor(buttons, IN_ATTACK) end
        if opts.keepAttack2 then
            buttons = ghBitBand(buttons, ghBitBnot(IN_ATTACK))
            buttons = ghBitBor(buttons, IN_ATTACK2)
        end
        if frame.in_duck then buttons = ghBitBor(buttons, IN_DUCK) end
        if (not opts.zeroMove) and frame.in_forward then buttons = ghBitBor(buttons, IN_FORWARD) end
        if (not opts.zeroMove) and frame.in_back then buttons = ghBitBor(buttons, IN_BACK) end
        if (not opts.zeroMove) and frame.in_moveleft then buttons = ghBitBor(buttons, IN_MOVELEFT) end
        if (not opts.zeroMove) and frame.in_moveright then buttons = ghBitBor(buttons, IN_MOVERIGHT) end
        if frame.in_use then buttons = ghBitBor(buttons, IN_USE) end
        if frame.in_speed then buttons = ghBitBor(buttons, IN_SPEED) end
        pcall(function() cmd:SetButtons(buttons) end)
    end

    local EXEC_ALIGN_TICKS = 18
    local EXEC_SNAP_XY = 0.55
    local EXEC_SNAP_SPEED = 40
    local EXEC_POST_AIM_WAIT = 10
    local EXEC_ALIGN_MAX_TICKS = 64
    local EXEC_APPROACH_SPEED = 1.0

    local function ghAlignAimFrame(fromP, fromY, toP, toY, tick)
        local t = mmax(1, tonumber(tick) or 1)
        local u = mmin(1, t / EXEC_ALIGN_TICKS)
        u = u * u * (3 - 2 * u) 
        return {
            pitch = fromP + (toP - fromP) * u,
            yaw = ghNormYaw(fromY + ghNormYaw(toY - fromY) * u),
            forwardmove = 0,
            sidemove = 0,
            in_attack = false,
            in_attack2 = false,
            in_jump = false,
            in_duck = false,
            in_forward = false,
            in_back = false,
            in_moveleft = false,
            in_moveright = false,
            in_use = false,
            in_speed = false,
        }
    end

    local function ghApplySpotApproach(frame, lp, L, yaw)
        if not (frame and lp and L) then return true end
        local ox, oy = nil, nil
        pcall(function()
            local o = lp:GetAbsOrigin()
            if o then ox, oy = o.x or o[1], o.y or o[2] end
        end)
        if type(ox) ~= "number" then
            pcall(function()
                local v = lp:GetPropVector("m_vecAbsOrigin")
                if v then ox, oy = v.x or v[1], v.y or v[2] end
            end)
        end
        if type(ox) ~= "number" then return true end
        local tx, ty = tonumber(L.x) or ox, tonumber(L.y) or oy
        local dx, dy = tx - ox, ty - oy
        local dist = msqrt(dx * dx + dy * dy)
        if dist <= EXEC_SNAP_XY then
            frame.forwardmove = 0
            frame.sidemove = 0
            frame.in_forward = false
            frame.in_back = false
            frame.in_moveleft = false
            frame.in_moveright = false
            return true
        end
        yaw = tonumber(yaw) or 0
        local wish = math.deg(math.atan2(dy, dx))
        local yd = math.rad(ghNormYaw(wish - yaw))
        local scale = 1
        if dist < 8 then
            scale = mmax(0.18, dist / 8)
        end
        local spd = EXEC_APPROACH_SPEED * scale
        frame.forwardmove = mcos(yd) * spd
        frame.sidemove = msin(yd) * spd
        frame.in_forward = frame.forwardmove > 0.05
        frame.in_back = frame.forwardmove < -0.05
        frame.in_moveright = frame.sidemove > 0.05
        frame.in_moveleft = frame.sidemove < -0.05
        return false
    end

    local function ghApplyAttackLag(frame, P)
        if not frame then return frame end
        local out = {}
        for k, v in pairs(frame) do out[k] = v end
        local atk = frame.in_attack and true or false
        local atk2 = frame.in_attack2 and true or false
        if P._atkWas and not atk then
            out.in_attack = true
            P._atkWas = false
        else
            P._atkWas = atk
        end
        if P._atk2Was and not atk2 then
            out.in_attack2 = true
            P._atk2Was = false
        else
            P._atk2Was = atk2
        end
        return out
    end

    local function ghAlignWriteOpts(P)
        local opts = { noThrow = true }
        local code = tonumber(GH.executeKey and GH.executeKey:Get()) or 0
        if not (code == 1 or code == 0x01) then return opts end
        if P and P._throwMode == "attack2" then
            opts.keepAttack2 = true
        else
            opts.keepAttack = true
        end
        return opts
    end

    local function ghMacroWriteOpts(P)
        if P and P._throwMode == "attack2" then
            return { forceAttack2 = true }
        end
        return nil
    end

    local function ghWriteCurrentPlayback(cmd)
        local P = GH.play
        if not P or not P.lastCmd then return end
        if P.state ~= "macro" and P.state ~= "align" then return end
        local opts
        if P.state == "align" then
            opts = ghAlignWriteOpts(P)
        else
            opts = ghMacroWriteOpts(P)
        end
        ghWriteMacro(cmd, P.lastCmd, opts)
    end

    local function ghStripAttackButtons(cmd)
        local buttons = 0
        pcall(function() buttons = math.floor(cmd:GetButtons() or 0) end)
        buttons = ghBitBand(buttons, ghBitBnot(IN_ATTACK))
        buttons = ghBitBand(buttons, ghBitBnot(IN_ATTACK2))
        pcall(function() cmd:SetButtons(buttons) end)
    end

    local function ghPlayerSpeed2d(lp)
        local vx, vy = 0, 0
        pcall(function()
            local v = lp:GetPropVector("m_vecAbsVelocity")
            if v then vx, vy = v.x or 0, v.y or 0 end
        end)
        return msqrt(vx * vx + vy * vy)
    end

    local function ghKeyDown(code)
        code = tonumber(code) or 0
        if code == 0 then return false end
        local down = false
        pcall(function() down = input.IsButtonDown(code) and true or false end)
        return down
    end

    local function ghOpenSavePopup(meta, frames)
        local nadeId = "he"
        if meta and type(meta.weapon) == "string" then
            local w = meta.weapon:lower()
            if w:find("flash", 1, true) then nadeId = "flash"
            elseif w:find("smoke", 1, true) then nadeId = "smoke"
            elseif w:find("molotov", 1, true) then nadeId = "molotov"
            elseif w:find("inc", 1, true) then nadeId = "incendiary"
            elseif w:find("decoy", 1, true) then nadeId = "decoy"
            elseif w:find("he", 1, true) then nadeId = "he"
            end
        end
        local defName = ""
        local defDesc = ""
        GH.savePopup = {
            name = defName,
            desc = defDesc,
            nadeId = nadeId,
            meta = meta,
            frames = frames,
            focus = "name",
            _mouseDown = true,
        }
    end

    local function ghFinalizeTake()
        local R = GH.rec
        if #R.buf > 0 and R.meta then
            local f0 = R.buf[1]
            if f0 and R.meta then
                R.meta.ang = {
                    pitch = tonumber(f0.pitch) or (R.meta.ang and R.meta.ang.pitch) or 0,
                    yaw = tonumber(f0.yaw) or (R.meta.ang and R.meta.ang.yaw) or 0,
                }
            end
            R.lastTicks = #R.buf
            local ok, frames = pcall(ghCompressUsercmds, R.buf)
            if ok and type(frames) == "table" and #frames > 0 then
                R.lastFrames, R.lastMeta = frames, R.meta
            else
                R.lastFrames, R.lastMeta = nil, R.meta
            end
            R.takes = (R.takes or 0) + 1
            M:Info(string.format("take %d ready — press save if you like it", R.takes))
        end
        R.active, R.trailing = false, false
        R.trailLeft = 0
        R.buf, R.meta, R.ticks = {}, nil, 0
        R.waiting = true
    end

    local function ghArmEditRecording()
        local R = GH.rec
        R.session = true
        R.waiting, R.active, R.trailing = true, false, false
        R.trailLeft = 0
        R.buf, R.meta, R.ticks = {}, nil, 0
    end

    local function ghDisarmEditRecording()
        local R = GH.rec
        R.session = false
        R.active, R.waiting, R.trailing = false, false, false
        R.trailLeft = 0
        R.buf, R.meta, R.ticks = {}, nil, 0
        R.lastFrames, R.lastMeta, R.lastTicks, R.takes = nil, nil, 0, 0
        R.readyFrames, R.readyMeta = nil, nil
    end

    local function ghTrySaveLastThrow()
        if not GH.editMode then
            M:Info("enable edit mode first")
            return
        end
        local R = GH.rec
        if R.active or R.trailing then
            M:Info("still capturing — wait for the throw to finish")
            return
        end
        if not R.lastMeta then
            M:Info("no throw to save — throw a grenade first")
            return
        end
        ghOpenSavePopup(R.lastMeta, R.lastFrames)
        M:Success(string.format("saving take %d", R.takes or 1))
    end

    local function ghSavePopupCommit()
        local P = GH.savePopup
        if not P or not P.meta then GH.savePopup = nil; return end
        local meta = P.meta
        local name = tostring(P.name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local desc = tostring(P.desc or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then
            name = string.format("%s lineup", tostring(P.nadeId):upper())
        end
        local eyeZ = (meta.pos and meta.pos.z or 0)
        local viewZ = tonumber(meta.viewZ) or 64
        local entry = {
            id = GH.nextId,
            map = ghNormalizeMap(meta.map or ghMapName()),
            name = name,
            nade = P.nadeId or "he",
            desc = desc,
            x = meta.pos and meta.pos.x or 0,
            y = meta.pos and meta.pos.y or 0,
            z = eyeZ,
            viewZ = viewZ,
            pitch = meta.ang and meta.ang.pitch or 0,
            yaw = meta.ang and meta.ang.yaw or 0,
            seedPitch = meta.ang and meta.ang.pitch or 0,
            seedYaw = meta.ang and meta.ang.yaw or 0,
            frames = P.frames,
        }
        GH.nextId = GH.nextId + 1
        GH.lineups[#GH.lineups + 1] = entry
        local wrote = ghSaveLineups()
        GH.listDirty = true
        ghRefreshList()
        GH.savePopup = nil
        local R = GH.rec
        if R then
            R.lastFrames, R.lastMeta, R.lastTicks, R.takes = nil, nil, 0, 0
        end
        if wrote then M:Success("saved lineup: " .. name)
        else M:Error("saved in memory; disk write failed") end
    end

    local function ghDrawSavePopup(sw, sh)
        local P = GH.savePopup
        if not P then return end
        local accent, bg, bg2, text = ghMenuColors()
        local mw, mh = 400, 250
        local x = mfloor((sw - mw) * 0.5)
        local y = mfloor((sh - mh) * 0.5)
        ghRect(0, 0, sw, sh, { 0, 0, 0 }, 120)
        ghRect(x + 4, y + 6, mw, mh, { 0, 0, 0 }, 80)
        ghRect(x, y, mw, mh, bg, 240)
        ghRect(x, y, mw, 2, accent, 255)
        ghText(GH.fonts.title, x + 16, y + 14, accent, 255, "SAVE LINEUP")

        ghText(GH.fonts.small, x + 16, y + 46, text, 200, "Name")
        ghRect(x + 16, y + 62, mw - 32, 24, bg2, 255)
        ghRect(x + 16, y + 62, mw - 32, 1, accent, P.focus == "name" and 220 or 60)
        local shownName = P.name or ""
        if P.focus == "name" and (mfloor((GH.pulse or 0) * 2) % 2 == 0) then shownName = shownName .. "|" end
        ghText(GH.fonts.body, x + 22, y + 66, text, 255, shownName ~= "" and shownName or "type a name…")

        ghText(GH.fonts.small, x + 16, y + 100, text, 200, "Description")
        ghRect(x + 16, y + 116, mw - 32, 24, bg2, 255)
        ghRect(x + 16, y + 116, mw - 32, 1, accent, P.focus == "desc" and 220 or 60)
        local shownDesc = P.desc or ""
        if P.focus == "desc" and (mfloor((GH.pulse or 0) * 2) % 2 == 0) then shownDesc = shownDesc .. "|" end
        ghText(GH.fonts.body, x + 22, y + 120, text, 255, shownDesc ~= "" and shownDesc or "description (optional)")

        ghText(GH.fonts.small, x + 16, y + 156, text, 180, "Nade: " .. tostring(P.nadeId):upper())

        local saveW, cancelW = 100, 100
        local btnY = y + mh - 40
        ghRect(x + mw - 16 - saveW - 8 - cancelW, btnY, cancelW, 26, bg2, 255)
        ghText(GH.fonts.small, x + mw - 16 - saveW - 8 - cancelW + 28, btnY + 6, text, 255, "Cancel")
        ghRect(x + mw - 16 - saveW, btnY, saveW, 26, accent, 230)
        ghText(GH.fonts.small, x + mw - 16 - saveW + 34, btnY + 6, { 12, 14, 18 }, 255, "Save")

        local mx, my, mouseDown = ghMouse()
        local click = mouseDown and not (P._mouseDown or false)
        P._mouseDown = mouseDown
        if not click then return end
        if my >= y + 62 and my <= y + 86 and mx >= x + 16 and mx <= x + mw - 16 then
            P.focus = "name"
        elseif my >= y + 116 and my <= y + 140 and mx >= x + 16 and mx <= x + mw - 16 then
            P.focus = "desc"
        end
        if my >= btnY and my <= btnY + 26 then
            local cancelX = x + mw - 16 - saveW - 8 - cancelW
            local saveX = x + mw - 16 - saveW
            if mx >= cancelX and mx <= cancelX + cancelW then
                GH.savePopup = nil
                M:Info("save cancelled")
            elseif mx >= saveX and mx <= saveX + saveW then
                ghSavePopupCommit()
            end
        end
    end

    local function ghPollSavePopupKeys()
        local P = GH.savePopup or GH.editPopup
        if not P then return end
        if P.focus ~= "name" and P.focus ~= "desc" then return end
        local function pressed(code)
            local v = false
            pcall(function() v = input.IsButtonPressed(code) and true or false end)
            return v
        end
        local field = P.focus
        if pressed(0x09) then 
            P.focus = (field == "name") and "desc" or "name"
            return
        end
        if pressed(0x08) then
            P[field] = tostring(P[field] or ""):sub(1, math.max(0, #tostring(P[field] or "") - 1))
        end
        if pressed(0x0D) then
            if GH.savePopup then
                ghSavePopupCommit()
            elseif GH.editPopup and GH._editPopupCommit then
                GH._editPopupCommit(false)
            end
            return
        end
        if pressed(0x1B) then
            GH.savePopup = nil
            GH.editPopup = nil
            return
        end
        local map = {
            [0x20] = " ",
            [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
            [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
        }
        for i = 0, 25 do map[0x41 + i] = string.char(97 + i) end
        local cur = tostring(P[field] or "")
        local limit = (field == "desc") and 60 or 40
        for code, ch in pairs(map) do
            if pressed(code) and #cur < limit then
                cur = cur .. ch
                P[field] = cur
            end
        end
    end

    local function ghOnSpotGroupMembers(eye, maxDist, heldId, opts)
        if not eye then return nil end
        opts = opts or {}
        maxDist = tonumber(maxDist) or STAND_RANGE
        local map = ghMapName()
        local matchOnly = opts.matchNade == true
            or (opts.matchNade ~= false and not (GH.showAllSpots and GH.showAllSpots:Get() and true or false))
        local items = {}
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and ghMapMatch(L.map, map) then
                local show = (not matchOnly) or (not heldId) or ghNadeCompatible(L.nade, heldId)
                if show then
                    local d = ghDist2(eye.fx, eye.fy, eye.fz, L.x, L.y, L.z)
                    if d <= maxDist + GROUP_DIST then
                        items[#items + 1] = {
                            L = L,
                            dist = d,
                            onSpot = d <= maxDist,
                            x = tonumber(L.x) or 0,
                            y = tonumber(L.y) or 0,
                            z = tonumber(L.z) or 0,
                        }
                    end
                end
            end
        end
        if #items == 0 then return nil end

        local used = {}
        local groups = {}
        for i = 1, #items do
            if not used[i] then
                local seed = items[i]
                local g = {
                    members = { seed.L },
                    dist = seed.dist,
                    onSpot = seed.onSpot,
                    x = seed.x, y = seed.y, z = seed.z,
                    n = 1,
                }
                used[i] = true
                for j = i + 1, #items do
                    if not used[j] then
                        local o = items[j]
                        local d = ghDist2(g.x, g.y, g.z, o.x, o.y, o.z)
                        if d <= GROUP_DIST then
                            used[j] = true
                            g.members[#g.members + 1] = o.L
                            g.n = g.n + 1
                            g.x = (g.x * (g.n - 1) + o.x) / g.n
                            g.y = (g.y * (g.n - 1) + o.y) / g.n
                            g.z = (g.z * (g.n - 1) + o.z) / g.n
                            if o.dist < g.dist then g.dist = o.dist end
                            if o.onSpot then g.onSpot = true end
                        end
                    end
                end
                groups[#groups + 1] = g
            end
        end

        local best = nil
        for gi = 1, #groups do
            local g = groups[gi]
            if g.onSpot and (not best or g.dist < best.dist) then
                best = g
            end
        end
        return best and best.members or nil
    end

    local function ghPickStandLineup(eye, maxDist, heldId, opts)
        if not eye then return nil end
        opts = opts or {}
        maxDist = tonumber(maxDist) or STAND_RANGE

        local hudFocus = GH.spotFocus
        if hudFocus then
            local nadeOk = (not opts.matchNade) or (not heldId) or ghNadeCompatible(hudFocus.nade, heldId)
            local macroOk = (not opts.requireMacro) or ghHasMacro(hudFocus)
            if nadeOk and macroOk and ghAimClose(hudFocus, eye, LINEUP_PICK_TOL) then
                return hudFocus
            end
        end

        local members = ghOnSpotGroupMembers(eye, maxDist, heldId, opts)
        if not members or #members == 0 then return nil end

        local pool = members
        if opts.requireMacro or opts.matchNade then
            pool = {}
            for i = 1, #members do
                local L = members[i]
                if L then
                    local nadeOk = (not opts.matchNade) or (not heldId) or ghNadeCompatible(L.nade, heldId)
                    local macroOk = (not opts.requireMacro) or ghHasMacro(L)
                    if nadeOk and macroOk then
                        pool[#pool + 1] = L
                    end
                end
            end
        end
        if #pool == 0 then return nil end

        local focus = (#pool == 1) and pool[1] or select(1, ghPickFocus(pool, eye))
        if focus and ghAimClose(focus, eye, LINEUP_PICK_TOL) then
            return focus
        end
        return nil
    end

    local function ghFindClosestLineup(eye, maxDist, heldId)
        return ghPickStandLineup(eye, maxDist, heldId, {
            matchNade = not (GH.showAllSpots and GH.showAllSpots:Get() and true or false),
        })
    end

    local function ghDeleteLineupById(id)
        if id == nil then return false end
        local keep, found = {}, false
        for i = 1, #GH.lineups do
            local L = GH.lineups[i]
            if L and L.id == id then
                found = true
            elseif L then
                keep[#keep + 1] = L
            end
        end
        if not found then return false end
        GH.lineups = keep
        ghSaveLineups()
        GH.listDirty = true
        ghRefreshList()
        return true
    end

    local function ghOpenEditPopup(L, opts)
        if not L then return end
        opts = opts or {}
        GH._pendingEditL = nil
        GH._pendingFloorMembers = nil
        GH.floorMenu = nil
        GH.floorFocus, GH.floorFocusL = nil, nil
        GH.editPopup = {
            id = L.id,
            name = tostring(L.name or ""),
            desc = tostring(L.desc or ""),
            nadeId = L.nade or "he",
            focus = "name",
            _mouseDown = true,
        }
    end
    GH.openEditPopup = ghOpenEditPopup

    local function ghOpenFloorMenu(members, selHint)
        if type(members) ~= "table" or #members == 0 then return end
        local sel = 1
        if selHint then
            for i = 1, #members do
                if members[i] and members[i].id == selHint.id then
                    sel = i
                    break
                end
            end
        end
        GH._pendingEditL = nil
        GH._pendingFloorMembers = nil
        GH.editPopup = nil
        GH.floorMenu = {
            members = members,
            sel = sel,
            scroll = 0,
            _mouseDown = true,
        }
    end

    local function ghFlushPendingEdit()
        local floorMembers = GH._pendingFloorMembers
        if floorMembers then
            GH._pendingFloorMembers = nil
            GH._pendingEditL = nil
            ghOpenFloorMenu(floorMembers, nil)
            return
        end
        local L = GH._pendingEditL
        if not L then return end
        GH._pendingEditL = nil
        ghOpenEditPopup(L)
    end

    local function ghEditPopupCommit(doDelete)
        local P = GH.editPopup
        if not P then return end
        local target
        for i = 1, #GH.lineups do
            if GH.lineups[i] and GH.lineups[i].id == P.id then
                target = GH.lineups[i]
                break
            end
        end
        if not target then
            GH.editPopup = nil
            M:Info("lineup no longer exists")
            return
        end
        if doDelete then
            GH.editPopup = nil
            if ghDeleteLineupById(P.id) then
                M:Notify("lineup deleted", "info")
            else
                M:Info("lineup no longer exists")
            end
            return
        end

        local name = tostring(P.name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local desc = tostring(P.desc or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then name = tostring(target.name or "Lineup") end
        target.name = name
        target.desc = desc

        ghSaveLineups()
        GH.listDirty = true
        ghRefreshList()
        GH.editPopup = nil
        M:Success("updated labels: " .. name)
    end
    GH._editPopupCommit = ghEditPopupCommit

    local function ghFloorFocusLineup(eye)
        if GH.floorFocusL then return GH.floorFocusL end
        local g = GH.floorFocus
        if not (g and g.members and #g.members > 0) then return nil end
        if #g.members == 1 then return g.members[1] end
        return select(1, ghPickFocus(g.members, eye))
    end

    local function ghUpdateFloorFocus(floorLook, eye)
        if not GH.editMode or (GH.rec and (GH.rec.active or GH.rec.trailing)) then
            GH.floorFocus, GH.floorFocusL = nil, nil
            return
        end
        if GH.savePopup or GH.editPopup or GH.floorMenu then
            return
        end
        if eye and GH.spotFocus and ghAimClose(GH.spotFocus, eye, EDIT_AIM_TOL) then
            GH.floorFocus, GH.floorFocusL = nil, nil
            return
        end
        GH.floorFocus = floorLook
        if floorLook and floorLook.members and #floorLook.members > 0 then
            GH.floorFocusL = (#floorLook.members == 1)
                and floorLook.members[1]
                or select(1, ghPickFocus(floorLook.members, eye))
        else
            GH.floorFocusL = nil
        end
    end

    local function ghDrawFloorMenu(sw, sh)
        local P = GH.floorMenu
        if not P or type(P.members) ~= "table" or #P.members == 0 then
            GH.floorMenu = nil
            return
        end
        local accent, bg, bg2, text = ghMenuColors()
        local n = #P.members
        local rowH = 28
        local MAX_VISIBLE = 8
        local visible = n < MAX_VISIBLE and n or MAX_VISIBLE
        local maxScroll = mmax(0, n - visible)
        local scroll = math.floor(tonumber(P.scroll) or 0)
        if scroll < 0 then scroll = 0 end
        if scroll > maxScroll then scroll = maxScroll end
        P.scroll = scroll
        local listH = visible * rowH
        local mw = 420
        local mh = 86 + listH + 48
        local x = mfloor((sw - mw) * 0.5)
        local y = mfloor((sh - mh) * 0.5)
        ghRect(0, 0, sw, sh, { 0, 0, 0 }, 120)
        ghRect(x + 4, y + 6, mw, mh, { 0, 0, 0 }, 80)
        ghRect(x, y, mw, mh, bg, 240)
        ghRect(x, y, mw, 2, accent, 255)
        ghText(GH.fonts.title, x + 16, y + 14, accent, 255, "FLOOR SPOT")
        local sub = n .. " lineup" .. (n == 1 and "" or "s") .. " — select one, then Edit / Delete"
        if maxScroll > 0 then
            sub = sub .. string.format("  ·  %d–%d", scroll + 1, scroll + visible)
        end
        ghText(GH.fonts.small, x + 16, y + 40, text, 180, sub)

        local listY = y + 62
        if (tonumber(P.sel) or 1) < 1 then P.sel = 1 end
        if (tonumber(P.sel) or 1) > n then P.sel = n end
        local sel = tonumber(P.sel) or 1
        if sel < scroll + 1 then P.scroll = sel - 1; scroll = P.scroll end
        if sel > scroll + visible then P.scroll = sel - visible; scroll = P.scroll end

        for vi = 1, visible do
            local i = scroll + vi
            local L = P.members[i]
            local ry = listY + (vi - 1) * rowH
            local selected = (tonumber(P.sel) or 1) == i
            ghRect(x + 12, ry, mw - 24, rowH - 4, selected and accent or bg2, selected and 210 or 255)
            if L then
                ghDrawNadeIcon(x + 20, ry + 4, L.nade, 255)
                local desc = ghDescLabel(L)
                local line = desc ~= ""
                    and string.format("%s  ·  %s  ·  %s", tostring(L.name), ghNadeShort(L.nade), desc)
                    or string.format("%s  ·  %s", tostring(L.name), ghNadeShort(L.nade))
                ghText(
                    GH.fonts.body, x + 44, ry + 5,
                    selected and { 12, 14, 18 } or text, 255, line
                )
            end
        end

        local editW, delW, cancelW = 90, 90, 90
        local btnY = y + mh - 40
        local gap = 8
        local cancelX = x + mw - 16 - cancelW
        local delX = cancelX - gap - delW
        local editX = delX - gap - editW
        ghRect(editX, btnY, editW, 26, accent, 230)
        ghText(GH.fonts.small, editX + 30, btnY + 6, { 12, 14, 18 }, 255, "Edit")
        ghRect(delX, btnY, delW, 26, { 180, 60, 60 }, 230)
        ghText(GH.fonts.small, delX + 22, btnY + 6, { 255, 255, 255 }, 255, "Delete")
        ghRect(cancelX, btnY, cancelW, 26, bg2, 255)
        ghText(GH.fonts.small, cancelX + 22, btnY + 6, text, 255, "Cancel")

        local mx, my, mouseDown = ghMouse()
        local click = mouseDown and not (P._mouseDown or false)
        P._mouseDown = mouseDown

        local function pressed(code)
            local v = false
            pcall(function() v = input.IsButtonPressed(code) and true or false end)
            return v
        end
        if pressed(0x1B) then 
            GH.floorMenu = nil
            M:Info("cancelled")
            return
        end
        if pressed(0x26) then 
            P.sel = mmax(1, (tonumber(P.sel) or 1) - 1)
        elseif pressed(0x28) then 
            P.sel = mmin(n, (tonumber(P.sel) or 1) + 1)
        elseif pressed(0x0D) then 
            local pick = P.members[tonumber(P.sel) or 1]
            if pick then ghOpenEditPopup(pick, { metaOnly = true }) end
            return
        end

        if not click then return end
        for vi = 1, visible do
            local i = scroll + vi
            local ry = listY + (vi - 1) * rowH
            if my >= ry and my <= ry + rowH - 2 and mx >= x + 12 and mx <= x + mw - 12 then
                P.sel = i
                return
            end
        end
        if my >= btnY and my <= btnY + 26 then
            local pick = P.members[tonumber(P.sel) or 1]
            if mx >= editX and mx <= editX + editW then
                if pick then ghOpenEditPopup(pick, { metaOnly = true }) end
            elseif mx >= delX and mx <= delX + delW then
                if pick and ghDeleteLineupById(pick.id) then
                    GH.floorMenu = nil
                    M:Notify("lineup deleted", "info")
                else
                    M:Info("lineup no longer exists")
                    GH.floorMenu = nil
                end
            elseif mx >= cancelX and mx <= cancelX + cancelW then
                GH.floorMenu = nil
                M:Info("cancelled")
            end
        end
    end

    local function ghDrawEditPopup(sw, sh)
        local P = GH.editPopup
        if not P then return end
        local accent, bg, bg2, text = ghMenuColors()
        local mw, mh = 400, 270
        local x = mfloor((sw - mw) * 0.5)
        local y = mfloor((sh - mh) * 0.5)
        ghRect(0, 0, sw, sh, { 0, 0, 0 }, 120)
        ghRect(x + 4, y + 6, mw, mh, { 0, 0, 0 }, 80)
        ghRect(x, y, mw, mh, bg, 240)
        ghRect(x, y, mw, 2, accent, 255)
        ghText(GH.fonts.title, x + 16, y + 14, accent, 255, "EDIT LINEUP")

        ghText(GH.fonts.small, x + 16, y + 46, text, 200, "Name")
        ghRect(x + 16, y + 62, mw - 32, 24, bg2, 255)
        ghRect(x + 16, y + 62, mw - 32, 1, accent, P.focus == "name" and 220 or 60)
        local shownName = P.name or ""
        if P.focus == "name" and (mfloor((GH.pulse or 0) * 2) % 2 == 0) then shownName = shownName .. "|" end
        ghText(GH.fonts.body, x + 22, y + 66, text, 255, shownName ~= "" and shownName or "type a name…")

        ghText(GH.fonts.small, x + 16, y + 100, text, 200, "Description")
        ghRect(x + 16, y + 116, mw - 32, 24, bg2, 255)
        ghRect(x + 16, y + 116, mw - 32, 1, accent, P.focus == "desc" and 220 or 60)
        local shownDesc = P.desc or ""
        if P.focus == "desc" and (mfloor((GH.pulse or 0) * 2) % 2 == 0) then shownDesc = shownDesc .. "|" end
        ghText(GH.fonts.body, x + 22, y + 120, text, 255, shownDesc ~= "" and shownDesc or "description (optional)")

        ghText(
            GH.fonts.small, x + 16, y + 156, text, 180,
            "Nade: " .. tostring(P.nadeId):upper() .. "  ·  Save updates name/description only"
        )

        local saveW, delW, cancelW = 90, 90, 90
        local btnY = y + mh - 40
        local gap = 8
        local cancelX = x + mw - 16 - cancelW
        local delX = cancelX - gap - delW
        local saveX = delX - gap - saveW
        ghRect(saveX, btnY, saveW, 26, accent, 230)
        ghText(GH.fonts.small, saveX + 28, btnY + 6, { 12, 14, 18 }, 255, "Save")
        ghRect(delX, btnY, delW, 26, { 180, 60, 60 }, 230)
        ghText(GH.fonts.small, delX + 22, btnY + 6, { 255, 255, 255 }, 255, "Delete")
        ghRect(cancelX, btnY, cancelW, 26, bg2, 255)
        ghText(GH.fonts.small, cancelX + 22, btnY + 6, text, 255, "Cancel")

        local mx, my, mouseDown = ghMouse()
        local click = mouseDown and not (P._mouseDown or false)
        P._mouseDown = mouseDown
        if not click then return end
        if my >= y + 62 and my <= y + 86 and mx >= x + 16 and mx <= x + mw - 16 then
            P.focus = "name"
        elseif my >= y + 116 and my <= y + 140 and mx >= x + 16 and mx <= x + mw - 16 then
            P.focus = "desc"
        end
        if my >= btnY and my <= btnY + 26 then
            if mx >= saveX and mx <= saveX + saveW then
                ghEditPopupCommit(false)
            elseif mx >= delX and mx <= delX + delW then
                ghEditPopupCommit(true)
            elseif mx >= cancelX and mx <= cancelX + cancelW then
                GH.editPopup = nil
                M:Info("edit cancelled")
            end
        end
    end

    local function ghUpdateEditToggleKey()
        if GH.savePopup or GH.editPopup or GH.floorMenu then
            GH._editToggleWas = false
            return
        end
        local code = tonumber(GH.editToggleKey and GH.editToggleKey:Get()) or 0
        local down = ghKeyDown(code)
        if code ~= 0 and down and not GH._editToggleWas then
            local on = not (GH.editModeBox and GH.editModeBox:Get() and true or false)
            if GH.editModeBox then
                pcall(function() GH.editModeBox:Set(on) end)
            end
            GH.editMode = on
            if on then
                ghArmEditRecording()
                M:Info("edit mode on — throw to record")
            else
                ghDisarmEditRecording()
                GH.editPopup = nil
                GH.floorMenu = nil
                GH.floorFocus, GH.floorFocusL = nil, nil
                M:Info("edit mode off")
            end
        end
        GH._editToggleWas = down
    end

    local function ghUpdateSpotEditKey()
        if GH.savePopup or GH.editPopup or GH.floorMenu then return end
        if not GH.editMode then
            GH._editKeyWas = false
            return
        end
        if GH.rec and (GH.rec.active or GH.rec.trailing) then return end
        local code = tonumber(GH.editSpotKey and GH.editSpotKey:Get()) or 0
        local saveCode = tonumber(GH.recordKey and GH.recordKey:Get()) or 0
        local down = ghKeyDown(code)
        if code ~= 0 and down and not GH._editKeyWas then
            local lp
            pcall(function() lp = entities.GetLocalPlayer() end)
            local eye = lp and ghEye(lp) or nil
            local nade = lp and ghNadeInfo(lp) or {}
            local standRange = ghStandRange()
            if GH.floorFocus and GH.floorFocus.members and #GH.floorFocus.members > 0 then
                ghOpenFloorMenu(GH.floorFocus.members, GH.floorFocusL)
            elseif GH.spotFocus and eye and ghAimClose(GH.spotFocus, eye, EDIT_AIM_TOL) then
                ghOpenEditPopup(GH.spotFocus)
            elseif GH.spotFocus and eye and ghAimClose(GH.spotFocus, eye, LINEUP_PICK_TOL) then
                ghOpenEditPopup(GH.spotFocus)
            else
                local L = ghFindClosestLineup(eye, standRange, nade.id)
                if L then
                    ghOpenEditPopup(L)
                elseif code ~= saveCode then
                    M:Info("look at a floor spot or aimspot to edit")
                end
            end
        end
        GH._editKeyWas = down
    end

    local function ghSyncEditMode()
        local on = GH.editModeBox and GH.editModeBox:Get() and true or false
        local R = GH.rec
        if on ~= GH.editMode then
            GH.editMode = on
            if on then
                ghArmEditRecording()
                M:Info("edit mode on — throw to record")
            else
                ghDisarmEditRecording()
                GH.editPopup = nil
                GH.floorMenu = nil
                GH.floorFocus, GH.floorFocusL = nil, nil
            end
        elseif on then
            if not (R and R.session) then ghArmEditRecording() end
        else
            if R and R.session then ghDisarmEditRecording() end
            GH.floorMenu = nil
            GH.floorFocus, GH.floorFocusL = nil, nil
        end
    end

    local function ghEditTargetAvailable()
        if not GH.editMode then return false end
        if GH.rec and (GH.rec.active or GH.rec.trailing) then return false end
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        local eye = lp and ghEye(lp) or nil
        if not eye then return false end
        if GH.spotFocus and ghAimClose(GH.spotFocus, eye, EDIT_AIM_TOL) then
            return true
        end
        if GH.floorFocus and ghFloorFocusLineup(eye) then
            return true
        end
        if GH.spotFocus and ghAimClose(GH.spotFocus, eye, LINEUP_PICK_TOL) then
            return true
        end
        local nade = lp and ghNadeInfo(lp) or {}
        return ghFindClosestLineup(eye, ghStandRange(), nade.id) ~= nil
    end

    local function ghUpdateRecordKey()
        local recCode = tonumber(GH.recordKey and GH.recordKey:Get()) or 0
        local recDown = recCode ~= 0 and ghKeyDown(recCode) or false
        if GH.savePopup or GH.editPopup or GH.floorMenu then
            GH._recKeyWas = recDown
            return
        end
        if recCode ~= 0 and recDown and not GH._recKeyWas then
            local editCode = tonumber(GH.editSpotKey and GH.editSpotKey:Get()) or 0
            if editCode ~= 0 and editCode == recCode and ghEditTargetAvailable() then
                GH._recKeyWas = recDown
                return
            end
            ghTrySaveLastThrow()
        end
        GH._recKeyWas = recDown
    end

    local function ghDrawEditWarning(sw, sh)
        if not GH.editMode then return end
        if GH.rec and (GH.rec.active or GH.rec.trailing) then return end
        if GH.hud and GH.hud:Get() then return end
        local lines = {
            "EDIT MODE — all spots visible in range",
            "Look at floor/aim until EDIT prompt, then press edit",
            string.format("Edit: %s   ·   Save take: %s", ghBindLabel(GH.editSpotKey, "edit"), ghBindLabel(GH.recordKey, "save")),
        }
        local maxW = 0
        for i = 1, #lines do
            maxW = mmax(maxW, ghTextSize(GH.fonts.body, lines[i]))
        end
        local lineH = 16
        local padX, padY = 10, 6
        local boxH = padY * 2 + (#lines * lineH)
        local x = mfloor((sw - maxW) * 0.5)
        local y = 28
        ghRect(x - padX, y - padY, maxW + padX * 2, boxH, { 0, 0, 0 }, 230)
        for i = 1, #lines do
            ghText(GH.fonts.body, x, y + (i - 1) * lineH, { 255, 70, 70 }, 255, lines[i])
        end
    end

    local REC_TRAIL_FRAMES = 20

    local function ghIsThrowClick(cmd)
        local buttons = 0
        pcall(function() buttons = math.floor(cmd:GetButtons() or 0) end)
        return ghFlagDown(buttons, IN_ATTACK) or ghFlagDown(buttons, IN_ATTACK2)
    end

    local function ghSimTick()
        local tc = 0
        pcall(function()
            if globals and globals.TickCount then tc = tonumber(globals.TickCount()) or 0 end
        end)
        return tc
    end

    local function ghDetectPlayStep(cmds)
        if type(cmds) ~= "table" or #cmds < 16 then return 1 end
        local function near(a, b)
            if not (a and b) then return false end
            if mabs((a.pitch or 0) - (b.pitch or 0)) >= 0.02 then return false end
            if mabs(ghNormYaw((a.yaw or 0) - (b.yaw or 0))) >= 0.02 then return false end
            if mabs((a.forwardmove or 0) - (b.forwardmove or 0)) >= 0.05 then return false end
            if mabs((a.sidemove or 0) - (b.sidemove or 0)) >= 0.05 then return false end
            if (a.in_attack and true or false) ~= (b.in_attack and true or false) then return false end
            if (a.in_attack2 and true or false) ~= (b.in_attack2 and true or false) then return false end
            if (a.in_jump and true or false) ~= (b.in_jump and true or false) then return false end
            if (a.in_duck and true or false) ~= (b.in_duck and true or false) then return false end
            return true
        end
        local pairDup, crossDiff = 0, 0
        for i = 1, 14, 2 do
            local a, b, c = cmds[i], cmds[i + 1], cmds[i + 2]
            if near(a, b) then
                pairDup = pairDup + 1
                if c and not near(b, c) then crossDiff = crossDiff + 1 end
            end
        end
        if pairDup >= 6 and crossDiff >= 3 then return 2 end
        return 1
    end

    local function ghResetPlayback()
        local P = GH.play
        P.state = "idle"
        P.active = nil
        P.tick = 0
        P.step = 1
        P.alignTick = 0
        P.alignTotal = 0
        P.settleTick = 0
        P._postAimWait = 0
        P.lastSimTick = -1
        P.lastCmd = nil
        P.errP, P.errY = 0, 0
        P._atkWas, P._atk2Was = false, false
        P.atkHold, P.atk2Hold = 0, 0
        P._onSpot = nil
        P._throwMode = nil
    end

    local function ghFindExecuteCandidate(eye, heldId)
        if not eye or not heldId then return nil end
        return ghPickStandLineup(eye, ghStandRange(), heldId, {
            matchNade = true,
            requireMacro = true,
        })
    end

    local function ghFindNearbySpotNoMacro(eye, heldId)
        if not eye or not heldId then return nil end
        local standRange = ghStandRange()
        local members = ghOnSpotGroupMembers(eye, standRange, heldId, { matchNade = true })
        if not members then return nil end
        for i = 1, #members do
            local L = members[i]
            if L and ghNadeCompatible(L.nade, heldId) and not ghHasMacro(L) then
                return L
            end
        end
        return nil
    end

    local function ghMacroThrowMode(cmds)
        if type(cmds) ~= "table" then return "attack" end
        local a1, a2 = 0, 0
        local n = #cmds
        if n > 240 then n = 240 end
        for i = 1, n do
            local f = cmds[i]
            if f then
                if f.in_attack then a1 = a1 + 1 end
                if f.in_attack2 then a2 = a2 + 1 end
            end
        end
        if a2 > 0 and a2 >= a1 then return "attack2" end
        return "attack"
    end

    local function ghIsLmbExecute()
        local code = tonumber(GH.executeKey and GH.executeKey:Get()) or 0
        return code == 1 or code == 0x01
    end

    local function ghBlockEarlyPin(cmd, lp)
        if not ghIsLmbExecute() then return end
        if not ghKeyDown(1) then return end
        if GH.editMode then return end
        if GH.rec and (GH.rec.active or GH.rec.trailing) then return end
        local P = GH.play
        if P and P.state == "macro" then return end
        if P and (P.state == "align") then
            if P._throwMode == "attack2" then
                local buttons = 0
                pcall(function() buttons = math.floor(cmd:GetButtons() or 0) end)
                buttons = ghBitBand(buttons, ghBitBnot(IN_ATTACK))
                buttons = ghBitBor(buttons, IN_ATTACK2)
                pcall(function() cmd:SetButtons(buttons) end)
            end
            return
        end
        if not lp then return end
        local nade = ghNadeInfo(lp)
        if not (nade and nade.held and nade.id) then return end
        local eye = ghEye(lp)
        if not eye then return end
        if not ghFindExecuteCandidate(eye, nade.id) then return end
        local buttons = 0
        pcall(function() buttons = math.floor(cmd:GetButtons() or 0) end)
        if ghFlagDown(buttons, IN_ATTACK) or ghFlagDown(buttons, IN_ATTACK2) then
            return
        end
        ghStripAttackButtons(cmd)
    end

    local function ghUpdatePlayback(cmd, lp)
        local P = GH.play
        if not P then return end
        if GH.savePopup or GH.editPopup or GH.floorMenu then
            if P.state == "macro" or P.state == "align" then ghResetPlayback(); P.awaitRelease = true end
            return
        end
        if GH.rec and (GH.rec.active or GH.rec.trailing) then
            if P.state == "macro" or P.state == "align" then ghResetPlayback(); P.awaitRelease = true end
            return
        end

        local execCode = tonumber(GH.executeKey and GH.executeKey:Get()) or 0
        local execDown = execCode ~= 0 and ghKeyDown(execCode)

        if GH.editMode then
            if P.state == "macro" or P.state == "align" then
                ghResetPlayback()
                P.awaitRelease = true
            end
            if execDown and not P._editPlayTold then
                P._editPlayTold = true
                M:Error("grenade playback not available in edit mode — exit edit mode to playback throws")
            elseif not execDown then
                P._editPlayTold = false
            end
            return
        end
        P._editPlayTold = false

        if not execDown then
            if P.state == "macro" or P.state == "align" then ghResetPlayback() end
            P.awaitRelease = false
            P.noMacroTold = false
            return
        end

        if P.awaitRelease then
            return
        end

        local function startMacroFromAlign()
            local L = P.active
            local cmds = L and ghEnsureMacroCmds(L)
            if not cmds or not cmds[1] then
                ghResetPlayback()
                P.awaitRelease = true
                return
            end
            P.state = "macro"
            P.step = ghDetectPlayStep(cmds)
            P.tick = 1
            P._atkWas, P._atk2Was = false, false
            local frame = ghApplyAttackLag(cmds[1], P)
            P.lastCmd = frame
            ghWriteMacro(cmd, frame, ghMacroWriteOpts(P))
        end

        if P.state == "align" then
            local L = P.active
            local cmds = L and ghEnsureMacroCmds(L)
            local first = cmds and cmds[1]
            if not first then
                ghResetPlayback()
                P.awaitRelease = true
                return
            end
            local sim = ghSimTick()
            if P.lastSimTick == sim and P.lastCmd then
                ghWriteMacro(cmd, P.lastCmd, ghAlignWriteOpts(P))
                return
            end
            P.lastSimTick = sim
            P.alignTotal = (P.alignTotal or 0) + 1
            P.alignTick = (P.alignTick or 0) + 1
            local aimTick = mmin(P.alignTick, EXEC_ALIGN_TICKS)
            local aligned = ghAlignAimFrame(
                P._fromP or first.pitch,
                P._fromY or first.yaw,
                first.pitch,
                first.yaw,
                aimTick
            )
            local onSpot = ghApplySpotApproach(aligned, lp, L, aligned.yaw)
            P._onSpot = onSpot
            P.lastCmd = aligned
            ghWriteMacro(cmd, aligned, ghAlignWriteOpts(P))

            if onSpot then
                local speed = ghPlayerSpeed2d(lp)
                if speed <= EXEC_SNAP_SPEED then
                    P.settleTick = (P.settleTick or 0) + 1
                else
                    P.settleTick = 0
                end
            else
                P.settleTick = 0
            end

            local aimDone = (P.alignTick or 0) >= EXEC_ALIGN_TICKS
            if aimDone then
                P._postAimWait = (P._postAimWait or 0) + 1
            else
                P._postAimWait = 0
            end
            local posReady = onSpot and (P.settleTick or 0) >= 1
            local postAimTimeout = aimDone and (P._postAimWait or 0) >= EXEC_POST_AIM_WAIT
            local timedOut = (P.alignTotal or 0) >= EXEC_ALIGN_MAX_TICKS
            if (aimDone and posReady) or postAimTimeout or timedOut then
                startMacroFromAlign()
            end
            return
        end

        if P.state == "macro" then
            local L = P.active
            local cmds = L and ghEnsureMacroCmds(L)
            if not cmds then
                ghResetPlayback()
                P.awaitRelease = true
                return
            end

            local sim = ghSimTick()
            if P.lastSimTick == sim and P.lastCmd then
                ghWriteMacro(cmd, P.lastCmd, ghMacroWriteOpts(P))
                return
            end
            P.lastSimTick = sim

            local step = mmax(1, tonumber(P.step) or 1)
            P.tick = (P.tick or 0) + step
            local frame = cmds[P.tick]
            if not frame then
                ghResetPlayback()
                P.awaitRelease = true
                return
            end
            frame = ghApplyAttackLag(frame, P)
            P.lastCmd = frame
            ghWriteMacro(cmd, frame, ghMacroWriteOpts(P))
            return
        end

        local nade = ghNadeInfo(lp)
        if not (nade and nade.held) then
            return
        end

        local eye = ghEye(lp)
        if not eye then return end

        local L = ghFindExecuteCandidate(eye, nade.id)
        if not L then
            if not P.noMacroTold and ghFindNearbySpotNoMacro(eye, nade.id) then
                P.noMacroTold = true
                M:Info("no recorded throw on this lineup")
            end
            return
        end
        local cmds = ghEnsureMacroCmds(L)
        if not cmds or not cmds[1] then
            if not P.noMacroTold then
                P.noMacroTold = true
                M:Info("no recorded throw on this lineup")
            end
            return
        end

        local first = cmds[1]
        P.active = L
        P.state = "align"
        P.alignTick = 1
        P.alignTotal = 0
        P.settleTick = 0
        P._postAimWait = 0
        P._onSpot = nil
        P._throwMode = ghMacroThrowMode(cmds)
        P.step = ghDetectPlayStep(cmds)
        P.tick = 0
        P.lastSimTick = ghSimTick()
        P._fromP = eye.pitch or 0
        P._fromY = eye.yaw or 0
        P._atkWas, P._atk2Was = false, false
        P.noMacroTold = false
        local aligned = ghAlignAimFrame(P._fromP, P._fromY, first.pitch, first.yaw, 1)
        local onSpot = ghApplySpotApproach(aligned, lp, L, aligned.yaw)
        P._onSpot = onSpot
        P.lastCmd = aligned
        ghWriteMacro(cmd, aligned, ghAlignWriteOpts(P))
    end

    local function ghPushRecFrame(cmd, replaceSameTick)
        local R = GH.rec
        local sim = ghSimTick()
        local frame = ghCaptureCmdFrame(cmd)
        if replaceSameTick and R.lastSimTick == sim and #R.buf > 0 then
            R.buf[#R.buf] = frame
        else
            R.lastSimTick = sim
            R.buf[#R.buf + 1] = frame
        end
        R.ticks = #R.buf
    end

    GH.onCreateMove = function(cmd)
        if not (GH.enable and GH.enable:Get()) then return end
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        if not lp then return end

        local R = GH.rec
        if GH.editMode and R.session then
            if R.waiting and not R.active and not R.trailing then
                local nade = ghNadeInfo(lp)
                if nade.held and ghIsThrowClick(cmd) then
                    local eye = ghEye(lp)
                    if eye then
                        R.buf = {}
                        R.lastSimTick = -1
                        ghPushRecFrame(cmd, false)
                        local f = R.buf[1]
                        local ap = (f and tonumber(f.pitch)) or eye.pitch
                        local ay = (f and tonumber(f.yaw)) or eye.yaw
                        R.meta = {
                            pos = { x = eye.fx, y = eye.fy, z = eye.fz },
                            ang = { pitch = ap, yaw = ay },
                            weapon = nade.id or "he",
                            map = ghMapName(),
                            viewZ = eye.viewZ or 64,
                        }
                        R.active, R.waiting, R.trailing = true, false, false
                        R.trailLeft = 0
                        return
                    end
                end
            elseif R.active then
                ghPushRecFrame(cmd, true)
                if not ghIsThrowClick(cmd) then
                    R.active = false
                    R.trailing = true
                    R.trailLeft = REC_TRAIL_FRAMES
                end
                return
            elseif R.trailing then
                ghPushRecFrame(cmd, true)
                local sim = ghSimTick()
                if R._trailSim ~= sim then
                    R._trailSim = sim
                    R.trailLeft = (R.trailLeft or 0) - 1
                end
                if R.trailLeft <= 0 then
                    ghFinalizeTake()
                end
                return
            end
        end

        ghBlockEarlyPin(cmd, lp)
        ghUpdatePlayback(cmd, lp)
        ghBlockEarlyPin(cmd, lp)
    end

    GH.onPreMove = function(cmd)
        if not (GH.enable and GH.enable:Get()) then return end
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        ghBlockEarlyPin(cmd, lp)
        ghWriteCurrentPlayback(cmd)
        ghBlockEarlyPin(cmd, lp)
    end
    GH.onPostMove = function(cmd)
        if not (GH.enable and GH.enable:Get()) then return end
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        ghWriteCurrentPlayback(cmd)
        ghBlockEarlyPin(cmd, lp)
    end

    GH.draw = function()
        if not (GH.enable and GH.enable.Get and GH.enable:Get()) then
            GH._drag = nil
            return
        end
        ghEnsureFonts()
        ghUpdateEditToggleKey()
        ghSyncEditMode()
        ghPollSavePopupKeys()

        local map = ghMapName()
        if GH.listDirty or map ~= GH.lastMap then ghRefreshList() end

        local now = miscNow()
        GH.pulse = now

        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        if not lp then
            GH._drag = nil
            GH.spotFocus = nil
            GH.aimEditL = nil
            GH.floorFocus, GH.floorFocusL = nil, nil
            return
        end
        local alive = false
        pcall(function() alive = lp:IsAlive() and true or false end)
        if not alive then
            GH._drag = nil
            GH.spotFocus = nil
            GH.aimEditL = nil
            GH.floorFocus, GH.floorFocusL = nil, nil
            return
        end

        local sw, sh = 0, 0
        pcall(function() sw, sh = draw.GetScreenSize() end)
        if sw < 10 or sh < 10 then return end

        local nade = ghNadeInfo(lp)
        GH.lastDetect = nade.held
            and (tostring(nade.id) .. " · " .. tostring(nade.debug))
            or ("none · " .. tostring(nade.debug))

        local eye = ghEye(lp)
        local standRange = ghStandRange()
        local showDist = ghClamp(GH.showDist and GH.showDist:Get() or 1200, 200, 3000)
        local nearL, aligned, groupCount, focusIdx = nil, false, 1, 1
        local editBrowse = GH.editMode and not (GH.rec and (GH.rec.active or GH.rec.trailing))

        GH._editPromptHits = {}
        if eye and (editBrowse or nade.held) then
            local ok, a, b, c, d = pcall(
                ghDrawMarkers, eye, nade.held and nade.id or nil, standRange, showDist, sw, sh
            )
            if ok then
                nearL, aligned, groupCount, focusIdx = a, b, c, d
            else
                GH.floorFocus, GH.floorFocusL = nil, nil
                GH.aimEditL = nil
                if tostring(a) ~= tostring(GH._lastMarkerErr) then
                    GH._lastMarkerErr = tostring(a)
                    pcall(function() print("[DaizML] marker draw: " .. tostring(a)) end)
                end
            end
        else
            GH.floorFocus, GH.floorFocusL = nil, nil
            GH.aimEditL = nil
        end
        GH.spotFocus = nearL
        if GH.aimEditL or (eye and GH.spotFocus and ghAimClose(GH.spotFocus, eye, EDIT_AIM_TOL)) then
            GH.floorFocus, GH.floorFocusL = nil, nil
            if not GH.aimEditL and GH.spotFocus then
                GH.aimEditL = GH.spotFocus
            end
        end

        local hudNade = nade.held and nade or {
            held = false, label = "GRENADE HELPER", color = select(1, ghMenuColors()),
        }
        local hudNearby = (nearL ~= nil) or (GH.floorFocusL ~= nil) or (GH.aimEditL ~= nil) or editBrowse
        ghDrawHud(
            sw, sh, hudNade, hudNearby, aligned,
            GH.aimEditL or nearL or GH.floorFocusL, groupCount, focusIdx
        )
        ghDrawEditWarning(sw, sh)

        ghUpdateSpotEditKey()
        ghUpdateRecordKey()
        ghPollEditPromptClicks()
        ghFlushPendingEdit()

        if GH.savePopup then
            ghDrawSavePopup(sw, sh)
        elseif GH.editPopup then
            ghDrawEditPopup(sw, sh)
        elseif GH.floorMenu then
            ghDrawFloorMenu(sw, sh)
        end
    end

    pcall(ghLoadLineups)
    pcall(ghRefreshList)
    pcall(ghPrefetchNadeIcons)
    grenadeTab.secs = { ghHelper, ghEdit, ghLineups }
    print("[DaizML] grenade helper ready")
end)()

local function applyCoachTrailFromWidgets()
    local c = TrailUI.color:Get() or DEFAULT_TRAIL_COLOR
    local dc = TrailUI.defColor:Get() or DEFAULT_TRAIL_DEF_COLOR
    local prevMode = CoachTrail.mode
    local requested = math.max(1, math.min(2, math.floor(tonumber(TrailUI.style:Get()) or TRAIL_MODE_DEFAULT)))
    if requested == TRAIL_MODE_DEFAULT then
        TrailUI.particleConfirmed = false
        if WarnUI.kind == "particle" then TrailUI.closeWarnPopup(false) end
    elseif requested == TRAIL_MODE_PARTICLE and not TrailUI.particleConfirmed then
        TrailUI.openWarnPopup()
        requested = TRAIL_MODE_DEFAULT
    end
    CoachTrail.enabled = TrailUI.enable:Get() and true or false
    CoachTrail.mode = requested
    CoachTrail.rainbow = TrailUI.rainbow:Get() and true or false
    CoachTrail.color = {
        tonumber(c[1]) or 255,
        tonumber(c[2]) or 255,
        tonumber(c[3]) or 255,
        tonumber(c[4]) or 255,
    }
    CoachTrail.length = math.min(TRAIL_LENGTH_MAX, math.max(2, math.floor(tonumber(TrailUI.length:Get()) or DEFAULT_TRAIL_LENGTH)))
    CoachTrail.thickness = math.max(1, math.floor(tonumber(TrailUI.thickness:Get()) or DEFAULT_TRAIL_THICKNESS))
    CoachTrail.rate_ms = DEFAULT_TRAIL_RATE_MS
    CoachTrail.def_type = math.max(1, math.min(3, math.floor(tonumber(TrailUI.defType:Get()) or 1)))
    CoachTrail.def_color_type = math.max(1, math.min(3, math.floor(tonumber(TrailUI.defColorType:Get()) or 1)))
    CoachTrail.def_color = {
        tonumber(dc[1]) or 246,
        tonumber(dc[2]) or 34,
        tonumber(dc[3]) or 34,
        tonumber(dc[4]) or 255,
    }
    CoachTrail.def_chroma = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defChroma:Get()) or 1)))
    CoachTrail.def_seg_exp = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defSegExp:Get()) or 10)))
    CoachTrail.def_line_size = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defLineSize:Get()) or 1)))
    CoachTrail.def_rect_w = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defRectW:Get()) or 1)))
    CoachTrail.def_rect_h = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defRectH:Get()) or 1)))
    CoachTrail.def_x_w = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defXW:Get()) or 1)))
    CoachTrail.def_y_w = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defYW:Get()) or 1)))
    if prevMode ~= CoachTrail.mode then
        if CoachTrail.mode == TRAIL_MODE_DEFAULT then
            CoachTrail.points = {}
            CoachTrail.catching_up = false
            CoachTrail.particles_armed = true
            CoachTrail.restart_accum = 0
            CoachTrail.stopped_since = nil
            if type(trailDestroyAllParticles) == "function" then
                pcall(trailDestroyAllParticles)
            end
        else
            TrailUI.clearDefaultSegments()
        end
    end
    if not CoachTrail.enabled then
        TrailUI.clearAllRuntime()
    else
        while #CoachTrail.points > CoachTrail.length do
            table.remove(CoachTrail.points, 1)
        end
    end
    TrailUI.syncVisibility()
end
TrailUI._applyFromWidgets = applyCoachTrailFromWidgets

local function coachTrailFingerprint()
    local c = TrailUI.color:Get() or DEFAULT_TRAIL_COLOR
    local dc = TrailUI.defColor:Get() or DEFAULT_TRAIL_DEF_COLOR
    return string.format(
        "%d|%d|%d|%d,%d,%d,%d|%d|%d|%d|%d|%d,%d,%d,%d|%d|%d|%d|%d|%d|%d|%d",
        TrailUI.enable:Get() and 1 or 0,
        tonumber(TrailUI.style:Get()) or TRAIL_MODE_DEFAULT,
        TrailUI.rainbow:Get() and 1 or 0,
        c[1], c[2], c[3], c[4] or 255,
        tonumber(TrailUI.length:Get()) or DEFAULT_TRAIL_LENGTH,
        tonumber(TrailUI.thickness:Get()) or DEFAULT_TRAIL_THICKNESS,
        tonumber(TrailUI.defType:Get()) or 1,
        tonumber(TrailUI.defColorType:Get()) or 1,
        dc[1], dc[2], dc[3], dc[4] or 255,
        tonumber(TrailUI.defChroma:Get()) or 1,
        tonumber(TrailUI.defSegExp:Get()) or 10,
        tonumber(TrailUI.defLineSize:Get()) or 1,
        tonumber(TrailUI.defRectW:Get()) or 1,
        tonumber(TrailUI.defRectH:Get()) or 1,
        tonumber(TrailUI.defXW:Get()) or 1,
        tonumber(TrailUI.defYW:Get()) or 1
    )
end
local StepEsp = {
    enabled = false,
    color = { DEFAULT_STEP_COLOR[1], DEFAULT_STEP_COLOR[2], DEFAULT_STEP_COLOR[3], DEFAULT_STEP_COLOR[4] },
    duration = DEFAULT_STEP_DURATION,
    max_radius = DEFAULT_STEP_RADIUS,
    interval = 20,
    thickness = 10,
    rings = {},
    state = {},
}

local function applyStepEspFromWidgets()
    local c = stepColor:Get() or DEFAULT_STEP_COLOR
    local dur = tonumber(stepDuration:Get()) or DEFAULT_STEP_DURATION
    StepEsp.enabled = stepEnable:Get() and true or false
    StepEsp.color = {
        tonumber(c[1]) or 74,
        tonumber(c[2]) or 166,
        tonumber(c[3]) or 255,
        tonumber(c[4]) or 220,
    }
    StepEsp.duration = dur
    StepEsp.max_radius = tonumber(stepRadius:Get()) or DEFAULT_STEP_RADIUS
    StepEsp.interval = math.max(1, math.floor(tonumber(stepInterval:Get()) or 20))
    StepEsp.thickness = 10
end

local function stepEspFingerprint()
    local c = stepColor:Get() or DEFAULT_STEP_COLOR
    return string.format(
        "%d|%d,%d,%d,%d|%.2f|%d|%d",
        stepEnable:Get() and 1 or 0,
        c[1], c[2], c[3], c[4] or 220,
        tonumber(stepDuration:Get()) or DEFAULT_STEP_DURATION,
        tonumber(stepRadius:Get()) or DEFAULT_STEP_RADIUS,
        tonumber(stepInterval:Get()) or 20
    )
end

applyWatermarkFromWidgets = function()
    local accent = uiAccent:Get() or DEFAULT_ACCENT
    local text = uiText:Get() or DEFAULT_TEXT
    local bg = { 9, 11, 16, 214 }
    local scale = tonumber(wmScale:Get()) or DEFAULT_WM_SCALE
    if scale < 0.7 then scale = 0.7 elseif scale > 2.0 then scale = 2.0 end
    local dim = {
        math.max(80, math.floor((text[1] or 205) * 0.72)),
        math.max(90, math.floor((text[2] or 213) * 0.72)),
        math.max(100, math.floor((text[3] or 225) * 0.72)),
        255,
    }
    local on = wmEnable:Get() and true or false
    M:Watermark(on)
    M:WatermarkSet({
        enabled = on,
        accent = {
            tonumber(accent[1]) or 74,
            tonumber(accent[2]) or 166,
            tonumber(accent[3]) or 255,
            tonumber(accent[4]) or 255,
        },
        bg = {
            tonumber(bg[1]) or 9,
            tonumber(bg[2]) or 11,
            tonumber(bg[3]) or 16,
            tonumber(bg[4]) or 214,
        },
        text = {
            tonumber(text[1]) or 205,
            tonumber(text[2]) or 213,
            tonumber(text[3]) or 225,
            tonumber(text[4]) or 255,
        },
        text_dim = dim,
        border = { 40, 48, 61, 255 },
        font = "Segoe UI",
        scale = scale,
        custom_text = tostring(wmCustomText:Get() or DEFAULT_WM_CUSTOM_TEXT),
        parts = wmSelToParts(wmParts:Get()),
        order = normalizeWmOrder(M._watermark and M._watermark.order),
        labels = wmLabels:Get() and true or false,
        labels_invert = wmLabelsInvert:Get() and true or false,
    })
    M:RefreshWatermarkFonts()
end

watermarkFingerprint = function()
    local a = uiAccent:Get() or DEFAULT_ACCENT
    local t = uiText:Get() or DEFAULT_TEXT
    local scale = tonumber(wmScale:Get()) or DEFAULT_WM_SCALE
    local order = encodeWmOrder(M._watermark and M._watermark.order)
    return string.format(
        "%d|%d,%d,%d|9,11,16|%d,%d,%d|%.2f|%s|%s|%s|%d|%d",
        wmEnable:Get() and 1 or 0,
        a[1] or 0, a[2] or 0, a[3] or 0,
        t[1] or 0, t[2] or 0, t[3] or 0,
        scale,
        fingerprintWmParts(wmParts:Get()),
        tostring(wmCustomText:Get() or ""),
        order,
        wmLabels:Get() and 1 or 0,
        wmLabelsInvert:Get() and 1 or 0
    )
end

gatherValues = function()
    local accent = uiAccent:Get() or DEFAULT_ACCENT
    local bg = uiBg:Get() or DEFAULT_BG
    local bg2 = uiBg2:Get() or DEFAULT_BG2
    local text = uiText:Get() or DEFAULT_TEXT
    local wm = M._watermark or {}
    local function menuGeom(n)
        n = tonumber(n)
        if n == nil then return nil end
        return math.floor(n + 0.5)
    end
    local values = {
        menu_key = tonumber(menuKey:Get()) or DEFAULT_MENU_KEY,
        follow_aimware = followAimware:Get() and true or false,
        menu_x = M._win and menuGeom(M._win.x) or nil,
        menu_y = M._win and menuGeom(M._win.y) or nil,
        menu_w = M._win and menuGeom(M._win.w) or nil,
        menu_h = M._win and menuGeom(M._win.h) or nil,
        sidebar_collapsed = M._sidebarCollapsed and true or false,
        misc_enable = false,
        misc_mode = 1,
        misc_amount = 50,
        misc_color = { 74, 166, 255, 255 },
        misc_hotkey = 0,
        misc_note = "",
        wm_x = wm.x,
        wm_y = wm.y,
        wm_enabled = wmEnable:Get() and true or false,
        wm_bg = { 9, 11, 16, 214 },
        wm_accent = { tonumber(accent[1]) or 74, tonumber(accent[2]) or 166, tonumber(accent[3]) or 255, tonumber(accent[4]) or 255 },
        wm_text = { tonumber(text[1]) or 205, tonumber(text[2]) or 213, tonumber(text[3]) or 225, tonumber(text[4]) or 255 },
        wm_scale = tonumber(wmScale:Get()) or DEFAULT_WM_SCALE,
        wm_font = "Segoe UI",
        wm_custom_text = tostring(wmCustomText:Get() or DEFAULT_WM_CUSTOM_TEXT),
        wm_parts = wmSelToParts(wmParts:Get()),
        wm_order = normalizeWmOrder(M._watermark and M._watermark.order),
        wm_labels = wmLabels:Get() and true or false,
        wm_labels_invert = wmLabelsInvert:Get() and true or false,
        ui_accent = { tonumber(accent[1]) or 74, tonumber(accent[2]) or 166, tonumber(accent[3]) or 255, tonumber(accent[4]) or 255 },
        ui_bg = { tonumber(bg[1]) or 8, tonumber(bg[2]) or 10, tonumber(bg[3]) or 14, tonumber(bg[4]) or 252 },
        ui_bg2 = { tonumber(bg2[1]) or 11, tonumber(bg2[2]) or 14, tonumber(bg2[3]) or 19, tonumber(bg2[4]) or 252 },
        ui_text = { tonumber(text[1]) or 205, tonumber(text[2]) or 213, tonumber(text[3]) or 225, tonumber(text[4]) or 255 },
        ui_font = FONT_OPTIONS[tonumber(uiFont:Get()) or 1] or DEFAULT_FONT,
        ui_font_size = tonumber(uiFontSize:Get()) or DEFAULT_FONT_SIZE,
        step_enabled = stepEnable:Get() and true or false,
        step_enemies_only = true,
        step_show_local = false,
        step_color = (function()
            local c = stepColor:Get() or DEFAULT_STEP_COLOR
            return { tonumber(c[1]) or 74, tonumber(c[2]) or 166, tonumber(c[3]) or 255, tonumber(c[4]) or 220 }
        end)(),
        step_duration = tonumber(stepDuration:Get()) or DEFAULT_STEP_DURATION,
        step_fade = DEFAULT_STEP_FADE,
        step_radius = tonumber(stepRadius:Get()) or DEFAULT_STEP_RADIUS,
        step_interval = tonumber(stepInterval:Get()) or 20,
        step_layers = 2,
        step_style = DEFAULT_STEP_STYLE,
        trail_enabled = TrailUI.enable:Get() and true or false,
        trail_mode = math.max(1, math.min(2, math.floor(tonumber(TrailUI.style:Get()) or TRAIL_MODE_DEFAULT))),
        trail_color = (function()
            local c = TrailUI.color:Get() or DEFAULT_TRAIL_COLOR
            return { tonumber(c[1]) or 255, tonumber(c[2]) or 255, tonumber(c[3]) or 255, tonumber(c[4]) or 255 }
        end)(),
        trail_length = math.min(TRAIL_LENGTH_MAX, math.max(10, math.floor(tonumber(TrailUI.length:Get()) or DEFAULT_TRAIL_LENGTH))),
        trail_thickness = tonumber(TrailUI.thickness:Get()) or DEFAULT_TRAIL_THICKNESS,
        trail_rate_ms = DEFAULT_TRAIL_RATE_MS,
        trail_rainbow = TrailUI.rainbow:Get() and true or false,
        trail_def_type = math.max(1, math.min(3, math.floor(tonumber(TrailUI.defType:Get()) or 1))),
        trail_def_color_type = math.max(1, math.min(3, math.floor(tonumber(TrailUI.defColorType:Get()) or 1))),
        trail_def_color = (function()
            local c = TrailUI.defColor:Get() or DEFAULT_TRAIL_DEF_COLOR
            return { tonumber(c[1]) or 246, tonumber(c[2]) or 34, tonumber(c[3]) or 34, tonumber(c[4]) or 255 }
        end)(),
        trail_def_chroma = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defChroma:Get()) or 1))),
        trail_def_seg_exp = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defSegExp:Get()) or 10))),
        trail_def_line_size = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defLineSize:Get()) or 1))),
        trail_def_rect_w = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defRectW:Get()) or 1))),
        trail_def_rect_h = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defRectH:Get()) or 1))),
        trail_def_x_w = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defXW:Get()) or 1))),
        trail_def_y_w = math.max(1, math.min(100, math.floor(tonumber(TrailUI.defYW:Get()) or 1))),
        left_hand_knife = leftHandKnife:Get() and true or false,
        sniper_qs = sniperQuickSwitch:Get() and true or false,
        sniper_qs_delay = math.max(0, math.floor(tonumber(sniperQsDelay:Get()) or 0)),
        deagle_qs = deagleQuickSwitch:Get() and true or false,
        deagle_qs_delay = math.max(0, math.floor(tonumber(deagleQsDelay:Get()) or 0)),
        velocity_graph = velocityGraph:Get() and true or false,
        velo_x = VeloPos.x,
        velo_y = VeloPos.y,
        live_stats = liveStats and liveStats:Get() and true or false,
        live_stats_x = LiveStatsPos.x,
        live_stats_y = LiveStatsPos.y,
        radar_hud = LiveStatsPos.RadarHud and LiveStatsPos.RadarHud.enabled and LiveStatsPos.RadarHud.enabled:Get() and true or false,
        radar_x = LiveStatsPos.RadarHud and LiveStatsPos.RadarHud.x or nil,
        radar_y = LiveStatsPos.RadarHud and LiveStatsPos.RadarHud.y or nil,
        radar_size = LiveStatsPos.RadarHud and tonumber(LiveStatsPos.RadarHud.size) or 200,
        radar_zoom = (function()
            local R = LiveStatsPos.RadarHud
            if R and R.zoomSlider and R.zoomSlider.Get then
                return math.floor(tonumber(R.zoomSlider:Get()) or 100)
            end
            return 100
        end)(),
        radar_dot_size = (function()
            local R = LiveStatsPos.RadarHud
            if R and R.dotSize and R.dotSize.Get then
                return math.floor(tonumber(R.dotSize:Get()) or 4)
            end
            return 4
        end)(),
        radar_circle = LiveStatsPos.RadarHud and LiveStatsPos.RadarHud.circleMap and LiveStatsPos.RadarHud.circleMap:Get() and true or false,
        radar_hide_panel = (function()
            local R = LiveStatsPos.RadarHud
            if not (R and R.hidePanel and R.hidePanel.Get) then return true end
            return R.hidePanel:Get() and true or false
        end)(),
        radar_follow = (function()
            local R = LiveStatsPos.RadarHud
            if not (R and R.follow and R.follow.Get) then return true end
            return R.follow:Get() and true or false
        end)(),
        radar_show_team = (function()
            local R = LiveStatsPos.RadarHud
            if not (R and R.showTeam and R.showTeam.Get) then return true end
            return R.showTeam:Get() and true or false
        end)(),
        radar_gridlines = (function()
            local R = LiveStatsPos.RadarHud
            if not (R and R.gridlines and R.gridlines.Get) then return true end
            return R.gridlines:Get() and true or false
        end)(),
        movement_keys = movementKeys:Get() and true or false,
        keys_jump = tonumber(jumpKey:Get()) or 0x20,
        keys_bg = keysBackground:Get() and true or false,
        keys_layout = KEY_LAYOUT_FROM_COMBO[math.max(1, math.min(3, math.floor(tonumber(keysLayout:Get()) or 1)))] or 3,
        keys_x = KeysPos.x,
        keys_y = KeysPos.y,
        death_fx_enabled = DeathUI.isArmed(),
        death_fx_effect = math.max(1, math.min(#DEATH_EFFECT_NAMES, math.floor(tonumber(deathEffectCombo:Get()) or 1))),
        gh_enabled = GH.enable and GH.enable:Get() and true or false,
        gh_hud = (not GH.hud) or (GH.hud:Get() and true or false),
        gh_hud_on_spot = GH.hudOnSpot and GH.hudOnSpot:Get() and true or false,
        gh_show_all_spots = GH.showAllSpots and GH.showAllSpots:Get() and true or false,
        gh_aim_line = (not GH.aimLine) or (GH.aimLine:Get() and true or false),
        gh_aim_style = math.max(1, math.min(4, math.floor(tonumber(GH.aimStyle and GH.aimStyle:Get()) or 4))),
        gh_range = 17,
        gh_show_dist = math.max(200, math.min(3000, math.floor(tonumber(GH.showDist and GH.showDist:Get()) or 1200))),
        gh_edit_mode = GH.editModeBox and GH.editModeBox:Get() and true or false,
        gh_edit_toggle_key = tonumber(GH.editToggleKey and GH.editToggleKey:Get()) or 0,
        gh_edit_key = tonumber(GH.editSpotKey and GH.editSpotKey:Get()) or 0,
        gh_record_key = tonumber(GH.recordKey and GH.recordKey:Get()) or 0,
        gh_execute_key = tonumber(GH.executeKey and GH.executeKey:Get()) or 0,
        gh_x = GH.pos and GH.pos.x or nil,
        gh_y = GH.pos and GH.pos.y or nil,
        vm_enabled = VM.enable:Get() and true or false,
        vm_x = VM.clamp(VM.x:Get(), VM.LIMIT_X[1], VM.LIMIT_X[2]),
        vm_y = VM.clamp(VM.y:Get(), VM.LIMIT_Y[1], VM.LIMIT_Y[2]),
        vm_z = VM.clamp(VM.z:Get(), VM.LIMIT_Z[1], VM.LIMIT_Z[2]),
        vm_fov_enabled = VM.fovEnable:Get() and true or false,
        vm_fov = math.floor(VM.clamp(VM.fov:Get(), 60, 120)),
    }

    return values
end

M._applyMenuGeometry = function(slot)
    if not slot or type(M._win) ~= "table" then return false end
    local sw, sh = 1920, 1080
    pcall(function() sw, sh = draw.GetScreenSize() end)
    sw, sh = sw or 1920, sh or 1080

    local mx = tonumber(slot.menu_x)
    local my = tonumber(slot.menu_y)
    local mw = tonumber(slot.menu_w)
    local mh = tonumber(slot.menu_h)
    local changed = false

    if mx ~= nil then
        M._win.x = math.max(0, math.min(sw - 80, math.floor(mx + 0.5)))
        changed = true
    end
    if my ~= nil then
        M._win.y = math.max(0, math.min(sh - 80, math.floor(my + 0.5)))
        changed = true
    end
    if mw ~= nil then
        M._win.w = math.max(560, math.min(sw - 40, math.floor(mw + 0.5)))
        M._autoH = false
        changed = true
    end
    if mh ~= nil then
        M._win.h = math.max(360, math.min(sh - 40, math.floor(mh + 0.5)))
        M._autoH = false
        changed = true
    end
    return changed
end

applyValues = function(slot)
    if not slot then return end
    menuKey:Set(tonumber(slot.menu_key) or DEFAULT_MENU_KEY)
    followAimware:Set(slot.follow_aimware and true or false)

    M._applyMenuGeometry(slot)

    M._sidebarCollapsed = slot.sidebar_collapsed and true or false
    M._sidebarAnim = M._sidebarCollapsed and 0 or 1

    local accent = slot.ui_accent or DEFAULT_ACCENT
    local bg = slot.ui_bg or DEFAULT_BG
    local bg2 = slot.ui_bg2 or DEFAULT_BG2
    local text = slot.ui_text or DEFAULT_TEXT
    uiAccent:Set({ tonumber(accent[1]) or 74, tonumber(accent[2]) or 166, tonumber(accent[3]) or 255, tonumber(accent[4]) or 255 })
    uiBg:Set({ tonumber(bg[1]) or 8, tonumber(bg[2]) or 10, tonumber(bg[3]) or 14, tonumber(bg[4]) or 252 })
    uiBg2:Set({ tonumber(bg2[1]) or 11, tonumber(bg2[2]) or 14, tonumber(bg2[3]) or 19, tonumber(bg2[4]) or 252 })
    uiText:Set({ tonumber(text[1]) or 205, tonumber(text[2]) or 213, tonumber(text[3]) or 225, tonumber(text[4]) or 255 })
    uiFont:Set(fontIndex(slot.ui_font or DEFAULT_FONT))
    uiFontSize:Set(tonumber(slot.ui_font_size) or DEFAULT_FONT_SIZE)

    local wScale = tonumber(slot.wm_scale) or DEFAULT_WM_SCALE
    if wScale < 0.7 then wScale = 0.7 elseif wScale > 2.0 then wScale = 2.0 end
    wmScale:Set(wScale)
    wmCustomText:Set(tostring(slot.wm_custom_text or DEFAULT_WM_CUSTOM_TEXT))
    wmParts:Set(wmPartsToSel(slot.wm_parts or { custom = true, name = true, uuid = true, map = true, fps = true, ping = true }))
    M._watermark.order = normalizeWmOrder(slot.wm_order or DEFAULT_WM_ORDER)
    wmLabels:Set(slot.wm_labels == true)
    wmLabelsInvert:Set(slot.wm_labels_invert == true)
    wmEnable:Set(slot.wm_enabled == true)

    leftHandKnife:Set(slot.left_hand_knife == true)
    sniperQuickSwitch:Set(slot.sniper_qs == true)
    sniperQsDelay:Set(math.max(0, math.min(600, tonumber(slot.sniper_qs_delay) or 0)))
    deagleQuickSwitch:Set(slot.deagle_qs == true)
    deagleQsDelay:Set(math.max(0, math.min(600, tonumber(slot.deagle_qs_delay) or 0)))
    velocityGraph:Set(slot.velocity_graph == true)
    if slot.velo_x ~= nil and slot.velo_y ~= nil then
        VeloPos.x, VeloPos.y = tonumber(slot.velo_x), tonumber(slot.velo_y)
    else
        VeloPosReset()
    end
    if liveStats then liveStats:Set(slot.live_stats == true) end
    if LiveStatsPos.RadarHud and LiveStatsPos.RadarHud.enabled then
        LiveStatsPos.RadarHud.enabled:Set(slot.radar_hud == true)
        local R = LiveStatsPos.RadarHud
        if slot.radar_x ~= nil and slot.radar_y ~= nil then
            R.x, R.y = tonumber(slot.radar_x), tonumber(slot.radar_y)
        else
            R.x, R.y = nil, nil
        end
        R.size = math.max(80, math.min(512, tonumber(slot.radar_size) or 200))
        if R.zoomSlider and R.zoomSlider.Set then
            R.zoomSlider:Set(math.max(100, math.min(250, tonumber(slot.radar_zoom) or 100)))
        end
        if R.dotSize and R.dotSize.Set then
            R.dotSize:Set(math.max(2, math.min(12, tonumber(slot.radar_dot_size) or 4)))
        end
        if R.circleMap and R.circleMap.Set then R.circleMap:Set(slot.radar_circle == true) end
        if R.hidePanel and R.hidePanel.Set then R.hidePanel:Set(slot.radar_hide_panel ~= false) end
        if R.follow and R.follow.Set then R.follow:Set(slot.radar_follow ~= false) end
        if R.showTeam and R.showTeam.Set then R.showTeam:Set(slot.radar_show_team ~= false) end
        if R.gridlines and R.gridlines.Set then R.gridlines:Set(slot.radar_gridlines ~= false) end
    end
    if slot.live_stats_x ~= nil and slot.live_stats_y ~= nil then
        LiveStatsPos.x, LiveStatsPos.y = tonumber(slot.live_stats_x), tonumber(slot.live_stats_y)
    else
        LiveStatsPosReset()
    end
    movementKeys:Set(slot.movement_keys == true)
    jumpKey:Set(tonumber(slot.keys_jump) or 0x20)
    keysBackground:Set(slot.keys_bg ~= false)
    keysLayout:Set(KEY_LAYOUT_TO_COMBO[math.max(1, math.min(3, math.floor(tonumber(slot.keys_layout) or 3)))] or 1)
    if slot.keys_x ~= nil and slot.keys_y ~= nil then
        KeysPos.x, KeysPos.y = tonumber(slot.keys_x), tonumber(slot.keys_y)
    else
        KeysPosReset()
    end

    DeathUI.confirmed = slot.death_fx_enabled == true
    deathEnable:Set(slot.death_fx_enabled == true)
    deathEffectCombo:Set(math.max(1, math.min(#DEATH_EFFECT_NAMES, math.floor(tonumber(slot.death_fx_effect) or 1))))

    if GH.enable then
        GH.enable:Set(slot.gh_enabled == true)
        GH.hud:Set(slot.gh_hud ~= false)
        if GH.hudOnSpot then GH.hudOnSpot:Set(slot.gh_hud_on_spot == true) end
        if GH.showAllSpots then
            local showAll = slot.gh_show_all_spots == true
            if slot.gh_show_all_spots == nil and slot.gh_match_nade ~= nil then
                showAll = slot.gh_match_nade == false
            end
            GH.showAllSpots:Set(showAll)
        end
        if GH.aimLine then GH.aimLine:Set(slot.gh_aim_line ~= false) end
        if GH.editModeBox then
            GH.editModeBox:Set(slot.gh_edit_mode == true)
            GH.editMode = slot.gh_edit_mode == true
        end
        if GH.editToggleKey then GH.editToggleKey:Set(tonumber(slot.gh_edit_toggle_key) or 0) end
        if GH.editSpotKey then GH.editSpotKey:Set(tonumber(slot.gh_edit_key) or 0) end
        if GH.aimStyle then
            GH.aimStyle:Set(math.max(1, math.min(4, math.floor(tonumber(slot.gh_aim_style) or 4))))
        end
        if GH.showDist then
            GH.showDist:Set(math.max(200, math.min(3000, math.floor(tonumber(slot.gh_show_dist) or 1200))))
        end
        if GH.recordKey then GH.recordKey:Set(tonumber(slot.gh_record_key) or 0) end
        if GH.executeKey then GH.executeKey:Set(tonumber(slot.gh_execute_key) or 0) end
        if slot.gh_x ~= nil and slot.gh_y ~= nil then
            GH.pos.x, GH.pos.y = tonumber(slot.gh_x), tonumber(slot.gh_y)
        else
            GH.pos.x, GH.pos.y = nil, nil
        end
        GH._drag = nil
    end

    VM.enable:Set(slot.vm_enabled == true)
    VM.x:Set(VM.clamp(tonumber(slot.vm_x) or VM.DEFAULT.x, VM.LIMIT_X[1], VM.LIMIT_X[2]))
    VM.y:Set(VM.clamp(tonumber(slot.vm_y) or VM.DEFAULT.y, VM.LIMIT_Y[1], VM.LIMIT_Y[2]))
    VM.z:Set(VM.clamp(tonumber(slot.vm_z) or VM.DEFAULT.z, VM.LIMIT_Z[1], VM.LIMIT_Z[2]))
    VM.fovEnable:Set(slot.vm_fov_enabled == true)
    VM.fov:Set(math.floor(VM.clamp(tonumber(slot.vm_fov) or VM.DEFAULT.fov, 60, 120)))
    VM.lastSig, VM.lastFovValue = "", nil

    stepEnable:Set(slot.step_enabled == true)
    local sc = slot.step_color or DEFAULT_STEP_COLOR
    stepColor:Set({ tonumber(sc[1]) or 74, tonumber(sc[2]) or 166, tonumber(sc[3]) or 255, tonumber(sc[4]) or 220 })
    stepDuration:Set(tonumber(slot.step_duration) or DEFAULT_STEP_DURATION)
    stepRadius:Set(tonumber(slot.step_radius) or DEFAULT_STEP_RADIUS)
    stepInterval:Set(tonumber(slot.step_interval) or 20)

    TrailUI.enable:Set(slot.trail_enabled == true)
    do
        local mode = math.max(1, math.min(2, math.floor(tonumber(slot.trail_mode) or TRAIL_MODE_PARTICLE)))
        TrailUI.particleConfirmed = (mode == TRAIL_MODE_PARTICLE)
        TrailUI.style:Set(mode)
    end
    TrailUI.rainbow:Set(slot.trail_rainbow == true)
    local tc = slot.trail_color or DEFAULT_TRAIL_COLOR
    TrailUI.color:Set({ tonumber(tc[1]) or 255, tonumber(tc[2]) or 255, tonumber(tc[3]) or 255, tonumber(tc[4]) or 255 })
    TrailUI.length:Set(math.min(TRAIL_LENGTH_MAX, math.max(10, math.floor(tonumber(slot.trail_length) or DEFAULT_TRAIL_LENGTH))))
    TrailUI.thickness:Set(tonumber(slot.trail_thickness) or DEFAULT_TRAIL_THICKNESS)
    TrailUI.defType:Set(math.max(1, math.min(3, math.floor(tonumber(slot.trail_def_type) or 1))))
    TrailUI.defColorType:Set(math.max(1, math.min(3, math.floor(tonumber(slot.trail_def_color_type) or 1))))
    local tdc = slot.trail_def_color or DEFAULT_TRAIL_DEF_COLOR
    TrailUI.defColor:Set({ tonumber(tdc[1]) or 246, tonumber(tdc[2]) or 34, tonumber(tdc[3]) or 34, tonumber(tdc[4]) or 255 })
    TrailUI.defChroma:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_chroma) or 1))))
    TrailUI.defSegExp:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_seg_exp) or 10))))
    TrailUI.defLineSize:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_line_size) or 1))))
    TrailUI.defRectW:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_rect_w) or 1))))
    TrailUI.defRectH:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_rect_h) or 1))))
    TrailUI.defXW:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_x_w) or 1))))
    TrailUI.defYW:Set(math.max(1, math.min(100, math.floor(tonumber(slot.trail_def_y_w) or 1))))

    M._menuToggleKey = tonumber(slot.menu_key) or DEFAULT_MENU_KEY
    M._followAimwareMenu = slot.follow_aimware and true or false

    if slot.wm_x ~= nil and slot.wm_y ~= nil then
        M:WatermarkSet({ x = slot.wm_x, y = slot.wm_y })
    else
        M:WatermarkResetPos()
    end

    applyAppearanceFromWidgets()
    applyWatermarkFromWidgets()
    applyStepEspFromWidgets()
    applyCoachTrailFromWidgets()
end

do
    local i = Config.default or 1
    configSlot:Set(i)
    syncNameFromSlot()
    applyValues(Config.slots[i])
end

local lastConfigSlot = selectedSlotIndex()
local lastAppearance = appearanceFingerprint()
local lastWatermark = watermarkFingerprint()
local lastStepEsp = stepEspFingerprint()
local lastCoachTrail = coachTrailFingerprint()
applyAppearanceFromWidgets()
applyWatermarkFromWidgets()
applyStepEspFromWidgets()
applyCoachTrailFromWidgets()

local aimwareUser
pcall(function() aimwareUser = cheat.GetUserName() end)
aimwareUser = tostring(aimwareUser or ""):gsub("[%c%z]", ""):gsub("^%s+", ""):gsub("%s+$", "")
if aimwareUser == "" then aimwareUser = nil end

M:Watermark(wmEnable:Get() and true or false)
M:WatermarkSet({
    user = aimwareUser,
    pos = "top-right",
})

do
    local slot = Config.slots[Config.default or 1]
    if slot and slot.wm_x ~= nil and slot.wm_y ~= nil then
        M:WatermarkSet({ x = slot.wm_x, y = slot.wm_y })
    end
end

M._debug = false
M._forceOpen = false
M._followAimwareMenu = followAimware:Get() and true or false
M._menuVisible = false
M._menuToggleKey = tonumber(menuKey:Get()) or DEFAULT_MENU_KEY

local buildOk, buildErr = pcall(function()
    local slot = Config.slots[Config.default or 1] or {}
    local bw = tonumber(slot.menu_w)
    local bh = tonumber(slot.menu_h)
    local bx = tonumber(slot.menu_x)
    local by = tonumber(slot.menu_y)
    local opts = {
        w = (bw and math.max(560, math.floor(bw + 0.5))) or 780,
        h = (bh and math.max(360, math.floor(bh + 0.5))) or 480,
        autoH = false,
        resize = true,
        debug = false,
        forceOpen = false,
    }
    if bx ~= nil then opts.x = math.floor(bx + 0.5) end
    if by ~= nil then opts.y = math.floor(by + 0.5) end
    M:Build(opts)
end)
if not buildOk then
    print("[DaizML] Build FAILED: " .. tostring(buildErr))
    return
end
if type(M._tick) ~= "function" then
    print("[DaizML] Build did not prepare M._tick")
    return
end

do
    local slot = Config.slots[Config.default or 1]
    if slot then
        M._applyMenuGeometry(slot)
        M._sidebarCollapsed = slot.sidebar_collapsed and true or false
        M._sidebarAnim = M._sidebarCollapsed and 0 or 1
    end
end

applyAppearanceFromWidgets()
applyWatermarkFromWidgets()
applyStepEspFromWidgets()
applyCoachTrailFromWidgets()
lastAppearance = appearanceFingerprint()
lastWatermark = watermarkFingerprint()
lastStepEsp = stepEspFingerprint()
lastCoachTrail = coachTrailFingerprint()

do
    local keyCode = tonumber(menuKey:Get()) or DEFAULT_MENU_KEY
    local keyLabel = M:KeyName(keyCode)
    M:Info("Press " .. tostring(keyLabel) .. " to toggle menu (rebind in Settings)")
end

local stepUpdate, stepDraw, trailUpdate, trailDraw, deathFxUpdate, veloDraw, keysDraw
stepUpdate, stepDraw, trailUpdate, trailDraw, deathFxUpdate, veloDraw, keysDraw = (function()
local STEP_SEGMENTS = 16
local STEP_DIST = 42.0
local STEP_MAX_DZ = 18.0
local STEP_MAX_RINGS = 24
local STEP_CULL_PAD = 80

local STEP_UNIT = {}
do
    for s = 0, STEP_SEGMENTS do
        local ang = (s / STEP_SEGMENTS) * math.pi * 2
        STEP_UNIT[s + 1] = { math.cos(ang), math.sin(ang) }
    end
end

local function stepNow()
    local t
    pcall(function() t = globals.RealTime() end)
    if type(t) ~= "number" then pcall(function() t = globals.CurTime() end) end
    return type(t) == "number" and t or 0
end

local function stepXYZ(o)
    if not o then return nil end
    local x, y, z = o.x or o[1], o.y or o[2], o.z or o[3]
    if type(x) == "number" and type(y) == "number" and type(z) == "number" then
        return x, y, z
    end
end

local function stepOrigin(ent)
    local ox, oy, oz
    pcall(function() ox, oy, oz = stepXYZ(ent:GetAbsOrigin()) end)
    if ox then return ox, oy, oz end
    local v
    pcall(function() v = ent:GetPropVector("m_vOldOrigin") end)
    if not v then pcall(function() v = ent:GetPropVector("m_vecAbsOrigin") end) end
    return stepXYZ(v)
end

local function stepIsEnemy(lp, pawn)
    if not lp or not pawn then return false end
    local ok = false
    pcall(function()
        local li, pi = lp:GetIndex(), pawn:GetIndex()
        if li and pi and li == pi then return end
        local lt, pt = lp:GetTeamNumber(), pawn:GetTeamNumber()
        if type(lt) ~= "number" or type(pt) ~= "number" then return end
        if pt <= 1 or lt <= 1 then return end
        local dm = false
        pcall(function()
            local cv = client.GetConVar("mp_teammates_are_enemies")
            dm = (cv == true or cv == 1 or cv == "1")
        end)
        ok = dm or (lt ~= pt)
    end)
    return ok
end

local function stepAlive(ent)
    local alive = false
    pcall(function() alive = ent:IsAlive() end)
    if alive then return true end
    local hp
    pcall(function() hp = ent:GetHealth() end)
    if type(hp) ~= "number" then pcall(function() hp = ent:GetPropInt("m_iHealth") end) end
    return type(hp) == "number" and hp > 0
end

local function stepEnemyPawns()
    local out, seen = {}, {}
    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then return out end

    local list
    pcall(function() list = entities.FindByClass("C_CSPlayerPawn") end)
    if not list then return out end

    for i = 1, #list do
        local pawn = list[i]
        if pawn then
            local idx
            pcall(function() idx = pawn:GetIndex() end)
            if idx and not seen[idx] and stepAlive(pawn) and stepIsEnemy(lp, pawn) then
                seen[idx] = true
                out[#out + 1] = pawn
            end
        end
    end
    return out
end

local function stepWorldToScreen(wx, wy, wz)
    local sx, sy
    pcall(function()
        if not (client and client.WorldToScreen) then return end
        if Vector3 then
            sx, sy = client.WorldToScreen(Vector3(wx, wy, wz))
        else
            sx, sy = client.WorldToScreen(wx, wy, wz)
        end
    end)
    if type(sx) == "table" then
        sy = sx.y or sx[2]
        sx = sx.x or sx[1]
    end
    if type(sx) == "number" and type(sy) == "number" then
        return sx, sy
    end
end

local function stepPushRing(x, y, z, born, duration, maxRadius)
    local rings = StepEsp.rings
    if type(rings) ~= "table" then
        rings = {}
        StepEsp.rings = rings
    end
    if #rings >= STEP_MAX_RINGS then
        table.remove(rings, 1)
    end
    rings[#rings + 1] = {
        x = x,
        y = y,
        z = z,
        born = born,
        duration = duration,
        maxRadius = maxRadius,
    }
end

local function stepSpawn(x, y, z)
    local now = stepNow()
    local radius = math.max(4, tonumber(StepEsp.max_radius) or DEFAULT_STEP_RADIUS)
    local duration = math.max(0.15, tonumber(StepEsp.duration) or DEFAULT_STEP_DURATION)
    stepPushRing(x, y, z, now, duration, radius)
end

local function stepCleanupRings(now)
    local rings = StepEsp.rings
    if type(rings) ~= "table" then
        StepEsp.rings = {}
        return
    end
    local keep = {}
    for i = 1, #rings do
        local r = rings[i]
        if r then
            local dur = math.max(0.05, tonumber(r.duration) or 0.5)
            if now < (r.born or 0) + dur then
                keep[#keep + 1] = r
            end
        end
    end
    StepEsp.rings = keep
end

local stepLastTick = -1
local stepLastNow = 0

local function stepResetRuntime()
    StepEsp.rings = {}
    StepEsp.state = {}
    stepLastTick = -1
    stepLastNow = 0
end

local function stepUpdate()
    if not StepEsp.enabled then
        if (StepEsp.rings and #StepEsp.rings > 0) or next(StepEsp.state) ~= nil then
            stepResetRuntime()
        end
        return
    end

    local tick = 0
    pcall(function() tick = globals.TickCount() end)
    if type(tick) ~= "number" then tick = 0 end
    if tick == stepLastTick then return end
    stepLastTick = tick

    local now = stepNow()
    if now + 0.05 < stepLastNow then
        stepResetRuntime()
        now = stepNow()
        stepLastTick = tick
    end
    stepLastNow = now

    stepCleanupRings(now)

    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then
        if (StepEsp.rings and #StepEsp.rings > 0) or next(StepEsp.state) ~= nil then
            stepResetRuntime()
        end
        return
    end

    local enemies = stepEnemyPawns()
    local live = {}
    local interval = math.max(1, StepEsp.interval or 20)

    for i = 1, #enemies do
        local pawn = enemies[i]
        local idx
        pcall(function() idx = pawn:GetIndex() end)
        if idx then
            live[idx] = true
            local ox, oy, oz = stepOrigin(pawn)
            if ox then
                local st = StepEsp.state[idx]
                if not st then
                    StepEsp.state[idx] = { x = ox, y = oy, z = oz, accum = 0, lastSpawnTick = -9999 }
                else
                    local dx, dy, dz = ox - st.x, oy - st.y, oz - (st.z or oz)
                    local dist2d = math.sqrt(dx * dx + dy * dy)
                    st.x, st.y, st.z = ox, oy, oz

                    if math.abs(dz) <= STEP_MAX_DZ and dist2d >= 0.5 then
                        st.accum = (st.accum or 0) + dist2d
                        while st.accum >= STEP_DIST do
                            st.accum = st.accum - STEP_DIST
                            if (tick - (st.lastSpawnTick or -9999)) >= interval then
                                st.lastSpawnTick = tick
                                stepSpawn(ox, oy, oz)
                            end
                        end
                    elseif math.abs(dz) > STEP_MAX_DZ then
                        st.accum = 0
                    end
                end
            end
        end
    end

    for k in pairs(StepEsp.state) do
        if not live[k] then StepEsp.state[k] = nil end
    end
end

local function stepDrawRing(ring, now, sw, sh)
    local born = tonumber(ring.born) or 0
    local dur = math.max(0.05, tonumber(ring.duration) or 0.5)
    local age = now - born
    if age < 0 or age >= dur then return end

    local t = age / dur
    local radius = (tonumber(ring.maxRadius) or DEFAULT_STEP_RADIUS) * (0.15 + 0.85 * t)
    local col = StepEsp.color or DEFAULT_STEP_COLOR
    local a = (tonumber(col[4]) or 220) * (1.0 - t)
    if a < 4 then return end

    local z = (tonumber(ring.z) or 0) + 0.5
    local wx, wy = tonumber(ring.x), tonumber(ring.y)
    if not (wx and wy) then return end

    local cx, cy = stepWorldToScreen(wx, wy, z)
    if not cx then return end
    if sw > 0 and sh > 0 then
        if cx < -STEP_CULL_PAD or cy < -STEP_CULL_PAD
            or cx > sw + STEP_CULL_PAD or cy > sh + STEP_CULL_PAD then
            return
        end
    end

    local r = tonumber(col[1]) or 74
    local g = tonumber(col[2]) or 166
    local b = tonumber(col[3]) or 255
    draw.Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a))

    local thickness = math.max(1, math.floor(tonumber(StepEsp.thickness) or 2))
    local passes = (thickness >= 4) and 2 or 1

    for pass = 0, passes - 1 do
        local rr = radius + (pass - (passes - 1) * 0.5) * 0.8
        if rr > 0.5 then
            if pass > 0 then
                draw.Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a * 0.55))
            end
            local prevx, prevy
            for s = 1, #STEP_UNIT do
                local u = STEP_UNIT[s]
                local sx, sy = stepWorldToScreen(wx + u[1] * rr, wy + u[2] * rr, z)
                if sx and sy and prevx then
                    draw.Line(math.floor(prevx), math.floor(prevy), math.floor(sx), math.floor(sy))
                end
                if sx and sy then
                    prevx, prevy = sx, sy
                else
                    prevx, prevy = nil, nil
                end
            end
        end
    end
end

local function stepDraw()
    if not StepEsp.enabled then return end
    local rings = StepEsp.rings
    if type(rings) ~= "table" or #rings == 0 then return end
    local now = stepNow()
    local sw, sh = 0, 0
    pcall(function() sw, sh = draw.GetScreenSize() end)
    sw = tonumber(sw) or 0
    sh = tonumber(sh) or 0
    pcall(function()
        for i = 1, #rings do
            stepDrawRing(rings[i], now, sw, sh)
        end
    end)
end

local function trailTeamOk(lp)
    local team
    pcall(function() team = lp:GetTeamNumber() end)
    if type(team) ~= "number" then
        pcall(function() team = lp:GetPropInt("m_iTeamNum") end)
    end
    return type(team) == "number" and team >= 2
end

local function trailHSV(h, s, v)
    h = h % 1
    if h < 0 then h = h + 1 end
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

local function trailScheduleFade(now)
    local live = CoachTrail.particle_live
    if type(live) ~= "table" then return end
    local fadeAt = now + TRAIL_STOP_FADE
    for i = 1, #live do
        local e = live[i]
        if e then
            local cur = e.expire or fadeAt
            e.expire = (cur < fadeAt) and cur or fadeAt
        end
    end
end

local function trailRetractFront(pts, budget)
    if not pts or #pts < 2 or budget <= 0 then return end
    while #pts > 2 and budget > 0 do
        local a, b = pts[1], pts[2]
        local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
        local seg = math.sqrt(dx * dx + dy * dy + dz * dz)
        if seg < 0.001 then
            table.remove(pts, 1)
        elseif seg <= budget then
            budget = budget - seg
            table.remove(pts, 1)
        else
            local t = budget / seg
            a.x = a.x + dx * t
            a.y = a.y + dy * t
            a.z = a.z + dz * t
            budget = 0
        end
    end
    if #pts == 2 and budget > 0 then
        local a, b = pts[1], pts[2]
        local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
        local seg = math.sqrt(dx * dx + dy * dy + dz * dz)
        if seg <= budget or seg < 0.5 then
            a.x, a.y, a.z = b.x, b.y, b.z
        else
            local t = budget / seg
            a.x = a.x + dx * t
            a.y = a.y + dy * t
            a.z = a.z + dz * t
        end
    end
end

local function trailClearPointsTo(ox, oy, oz, now)
    local pts = CoachTrail.points
    while #pts > 0 do table.remove(pts) end
    pts[1] = { x = ox, y = oy, z = oz, t = now }
end

local function trailFinishCatchup(ox, oy, oz, now)
    CoachTrail.catching_up = false
    trailScheduleFade(now)
    trailClearPointsTo(ox, oy, oz, now)
end

local function trailDoCatchup(ox, oy, oz, now, dt)
    local pts = CoachTrail.points
    if #pts < 2 then
        trailFinishCatchup(ox, oy, oz, now)
        return
    end

    local last = pts[#pts]
    local spanX, spanY = last.x - pts[1].x, last.y - pts[1].y
    local span = math.sqrt(spanX * spanX + spanY * spanY)
    if #pts <= 2 and span <= TRAIL_CATCHUP_MIN_SPAN then
        trailFinishCatchup(ox, oy, oz, now)
        return
    end

    CoachTrail.catching_up = true
    last.x, last.y, last.z, last.t = ox, oy, oz, now
    trailRetractFront(pts, TRAIL_CATCHUP_SPEED * dt)

    if #pts >= 2 then
        local a, b = pts[1], pts[#pts]
        local adx, ady = b.x - a.x, b.y - a.y
        if (adx * adx + ady * ady) < (TRAIL_CATCHUP_MIN_SPAN * TRAIL_CATCHUP_MIN_SPAN) then
            trailFinishCatchup(ox, oy, oz, now)
        end
    else
        trailFinishCatchup(ox, oy, oz, now)
    end
end

local function trailTickPoints(ox, oy, oz, now, dt)
    local pts = CoachTrail.points
    local maxLen = math.min(TRAIL_LENGTH_MAX, math.max(2, CoachTrail.length or DEFAULT_TRAIL_LENGTH))
    local sampleSec = (DEFAULT_TRAIL_RATE_MS or 20) / 1000
    dt = math.max(dt, 0.001)

    local prevX, prevY = CoachTrail.frame_x, CoachTrail.frame_y
    local frameDist = 0
    local speed = 0
    if prevX ~= nil and prevY ~= nil then
        local fdx, fdy = ox - prevX, oy - prevY
        frameDist = math.sqrt(fdx * fdx + fdy * fdy)
        speed = frameDist / dt
    end
    CoachTrail.frame_x, CoachTrail.frame_y, CoachTrail.frame_z = ox, oy, oz

    local moving = speed >= TRAIL_STOP_SPEED

    if not CoachTrail.particles_armed then
        if CoachTrail.catching_up then
            if moving then
                trailFinishCatchup(ox, oy, oz, now)
                CoachTrail.stopped_since = nil
                CoachTrail.restart_accum = (CoachTrail.restart_accum or 0) + frameDist
            else
                trailDoCatchup(ox, oy, oz, now, dt)
            end
            return
        end

        if moving then
            CoachTrail.stopped_since = nil
            CoachTrail.restart_accum = (CoachTrail.restart_accum or 0) + frameDist
            if (CoachTrail.restart_accum or 0) >= TRAIL_RESTART_DIST then
                trailClearPointsTo(ox, oy, oz, now)
                CoachTrail.last_append = now
                CoachTrail.restart_accum = 0
                CoachTrail.particles_armed = true
                CoachTrail.catching_up = false
            end
        end
        return
    end

    if #pts == 0 then
        pts[1] = { x = ox, y = oy, z = oz, t = now }
        CoachTrail.last_append = now
        CoachTrail.catching_up = false
        CoachTrail.stopped_since = nil
        return
    end

    local last = pts[#pts]
    local ldx, ldy = ox - last.x, oy - last.y
    local dist2d = math.sqrt(ldx * ldx + ldy * ldy)

    if moving then
        CoachTrail.stopped_since = nil
        CoachTrail.catching_up = false
        CoachTrail.restart_accum = 0
        if now >= (CoachTrail.last_append or 0) + sampleSec and dist2d >= TRAIL_MIN_MOVE then
            CoachTrail.last_append = now
            pts[#pts + 1] = { x = ox, y = oy, z = oz, t = now }
            while #pts > maxLen do
                table.remove(pts, 1)
            end
        end
        return
    end

    if not CoachTrail.stopped_since then
        CoachTrail.stopped_since = now
    end
    if (now - CoachTrail.stopped_since) < TRAIL_STOP_DWELL then
        return
    end

    CoachTrail.particles_armed = false
    CoachTrail.restart_accum = 0
    CoachTrail.catching_up = true
    trailDoCatchup(ox, oy, oz, now, dt)
end

local COACH_TRAIL_PARTICLE = "particles/entity/spectator_utility_trail.vpcf"
local TRAIL_PARTICLE_INTERVAL = 0.08
local TRAIL_PARTICLE_INTERVAL_CATCHUP = 0.033
local TRAIL_PARTICLE_MAX_LIVE = 2
local TRAIL_PARTICLE_MAX_PTS = 32
local TRAIL_PARTICLE_MIN_AGE = 0.04
local TRAIL_PARTICLE_FAIL_LIMIT = 3
local TRAIL_PARTICLE_BACKOFF = 2.5

local function trailNoteParticleFail(now)
    CoachTrail.particle_fail_streak = (CoachTrail.particle_fail_streak or 0) + 1
    if (CoachTrail.particle_fail_streak or 0) >= TRAIL_PARTICLE_FAIL_LIMIT then
        CoachTrail.particle_backoff_until = now + TRAIL_PARTICLE_BACKOFF
        CoachTrail.particle_fail_streak = 0
    end
end

local function trailNoteParticleOk()
    CoachTrail.particle_fail_streak = 0
end

local function trailSessionId()
    local id
    if type(ParticleAPI.getSessionId) == "function" then
        pcall(function() id = ParticleAPI.getSessionId() end)
    end
    return tonumber(id) or 0
end

local function trailEntryIsStale(entry, sessionId)
    if not entry then return true end
    return (entry.session or -1) ~= sessionId
end

local function trailDestroyParticleEntry(entry, sessionId)
    if not entry or type(entry.idx) ~= "number" then return end
    if sessionId and trailEntryIsStale(entry, sessionId) then return end
    if type(ParticleAPI.destroyEffect) == "function" then
        pcall(ParticleAPI.destroyEffect, entry.idx)
    end
end

local function trailDestroyAllParticles()
    local sessionId = trailSessionId()
    if type(ParticleAPI.destroyEffect) == "function"
        and type(CoachTrail.particle_idx) == "number"
        and (CoachTrail.particle_session or -1) == sessionId then
        pcall(ParticleAPI.destroyEffect, CoachTrail.particle_idx)
    end
    CoachTrail.particle_idx = nil
    CoachTrail.particle_session = nil
    local live = CoachTrail.particle_live
    if type(live) == "table" then
        for i = 1, #live do
            trailDestroyParticleEntry(live[i], sessionId)
        end
    end
    CoachTrail.particle_live = {}
    if type(ParticleAPI.flushReleases) == "function" then
        pcall(ParticleAPI.flushReleases, stepNow())
    end
end

local function trailCleanupParticles(now, forceAll)
    if type(ParticleAPI.flushReleases) == "function" then
        pcall(ParticleAPI.flushReleases, now)
    end
    if forceAll then
        trailDestroyAllParticles()
        return
    end
    local live = CoachTrail.particle_live
    if type(live) ~= "table" then
        CoachTrail.particle_live = {}
        return
    end
    local sessionId = trailSessionId()
    local keep = {}
    for i = 1, #live do
        local e = live[i]
        if e and type(e.idx) == "number" and not trailEntryIsStale(e, sessionId) then
            local age = now - (e.born or 0)
            if (e.expire or 0) <= now and age >= TRAIL_PARTICLE_MIN_AGE then
                trailDestroyParticleEntry(e, sessionId)
            else
                keep[#keep + 1] = e
            end
        end
    end
    while #keep > TRAIL_PARTICLE_MAX_LIVE do
        local e = keep[1]
        local age = now - (e.born or 0)
        if age >= TRAIL_PARTICLE_MIN_AGE then
            trailDestroyParticleEntry(e, sessionId)
            table.remove(keep, 1)
        else
            break
        end
    end
    CoachTrail.particle_live = keep
end

local function trailResetRuntime()
    trailDestroyAllParticles()
    CoachTrail.points = {}
    CoachTrail.last_update = 0
    CoachTrail.last_pos = nil
    CoachTrail.last_append = 0
    CoachTrail.last_frame = 0
    CoachTrail.frame_x, CoachTrail.frame_y, CoachTrail.frame_z = nil, nil, nil
    CoachTrail.stopped_since = nil
    CoachTrail.catching_up = false
    CoachTrail.particles_armed = true
    CoachTrail.restart_accum = 0
    CoachTrail.particle_last_spawn = 0
    CoachTrail.particle_fail_streak = 0
    CoachTrail.particle_backoff_until = 0
    TrailUI.clearDefaultSegments()
end

local function trailBuildBeamPts(pts, maxPts)
    local n = #pts
    if n < 2 then return nil end
    maxPts = math.max(2, math.floor(maxPts or TRAIL_PARTICLE_MAX_PTS))
    local out = {}
    if n <= maxPts then
        for i = 1, n do
            local p = pts[i]
            out[i] = { x = p.x, y = p.y, z = p.z }
        end
        return out
    end
    for i = 1, maxPts do
        local t = (i - 1) / (maxPts - 1)
        local idx = 1 + math.floor(t * (n - 1) + 0.5)
        local p = pts[idx]
        out[i] = { x = p.x, y = p.y, z = p.z }
    end
    return out
end

local function trailSpawnParticleRibbon(now)
    if type(ParticleAPI.spawnBeamPoints) ~= "function" then return end

    trailCleanupParticles(now, false)

    local pts = CoachTrail.points
    local catchingUp = CoachTrail.catching_up and true or false
    local armed = CoachTrail.particles_armed and true or false

    if catchingUp then
        if not pts or #pts < 2 then
            return
        end
        local a, b = pts[1], pts[#pts]
        local dx, dy = b.x - a.x, b.y - a.y
        if (dx * dx + dy * dy) < (TRAIL_CATCHUP_MIN_SPAN * TRAIL_CATCHUP_MIN_SPAN) then
            return
        end
    elseif not armed then
        return
    end

    if not pts or #pts < 2 then return end

    if now < (CoachTrail.particle_backoff_until or 0) then
        return
    end

    local interval = catchingUp and TRAIL_PARTICLE_INTERVAL_CATCHUP or TRAIL_PARTICLE_INTERVAL
    if now < (CoachTrail.particle_last_spawn or 0) + interval then return end

    local live = CoachTrail.particle_live
    if type(live) ~= "table" then
        live = {}
        CoachTrail.particle_live = live
    end
    local sessionId = trailSessionId()

    if #live >= TRAIL_PARTICLE_MAX_LIVE then
        local e = live[1]
        if e and (now - (e.born or 0)) >= TRAIL_PARTICLE_MIN_AGE then
            trailDestroyParticleEntry(e, sessionId)
            table.remove(live, 1)
        else
            return
        end
    end

    local beamPts = trailBuildBeamPts(pts, TRAIL_PARTICLE_MAX_PTS)
    if not beamPts or #beamPts < 2 then return end

    local col = CoachTrail.color or DEFAULT_TRAIL_COLOR
    local r, g, b
    if CoachTrail.rainbow then
        r, g, b = trailHSV((now * 0.2) % 1, 1.0, 1.0)
    else
        r = tonumber(col[1]) or 255
        g = tonumber(col[2]) or 255
        b = tonumber(col[3]) or 255
    end

    local thickness = math.max(1, math.floor(CoachTrail.thickness or DEFAULT_TRAIL_THICKNESS))
    local flWidth = 0.08 + (thickness - 1) * 0.06
    local flTime = catchingUp and math.max(0.14, interval * 4.5) or math.max(0.22, interval * 3.0)

    CoachTrail.particle_last_spawn = now

    local idx
    pcall(function()
        idx = ParticleAPI.spawnBeamPoints(COACH_TRAIL_PARTICLE, beamPts, { r, g, b }, flTime, flWidth, true)
    end)
    if type(idx) ~= "number" then
        trailNoteParticleFail(now)
        return
    end

    trailNoteParticleOk()
    live[#live + 1] = {
        idx = idx,
        born = now,
        expire = now + flTime + 0.05,
        session = sessionId,
    }
    CoachTrail.particle_idx = idx
    CoachTrail.particle_session = sessionId
end

local function trailUpdate()
    if not CoachTrail.enabled then
        if CoachTrail.particle_idx
            or (CoachTrail.particle_live and #CoachTrail.particle_live > 0)
            or #CoachTrail.points > 0
            or (CoachTrail.def_segments and #CoachTrail.def_segments > 0)
            or (CoachTrail.last_update or 0) ~= 0 then
            trailResetRuntime()
        end
        return
    end

    local now = stepNow()
    if now + 0.05 < (CoachTrail.last_update or 0) then
        trailResetRuntime()
        now = stepNow()
    end

    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp or not stepAlive(lp) or not trailTeamOk(lp) then
        if #CoachTrail.points > 0 or (CoachTrail.last_update or 0) ~= 0
            or (CoachTrail.def_segments and #CoachTrail.def_segments > 0)
            or CoachTrail.particle_idx
            or (CoachTrail.particle_live and #CoachTrail.particle_live > 0) then
            trailResetRuntime()
        end
        return
    end

    local ox, oy, oz = stepOrigin(lp)
    if not ox then return end
    CoachTrail.last_pos = { x = ox, y = oy, z = oz }

    local dt = now - (CoachTrail.last_frame or now)
    if dt < 0 or dt > 0.25 then dt = (DEFAULT_TRAIL_RATE_MS or 20) / 1000 end
    CoachTrail.last_frame = now
    CoachTrail.last_update = now
    CoachTrail.rate_ms = DEFAULT_TRAIL_RATE_MS

    if (CoachTrail.mode or TRAIL_MODE_DEFAULT) == TRAIL_MODE_DEFAULT then
        if CoachTrail.particle_idx or (CoachTrail.particle_live and #CoachTrail.particle_live > 0) then
            trailDestroyAllParticles()
        end
        CoachTrail.points = {}
        local last = CoachTrail.def_last_origin
        local dist = 0
        if last then
            local dx, dy, dz = ox - last.x, oy - last.y, oz - last.z
            dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        end
        if not CoachTrail.def_segments then CoachTrail.def_segments = {} end
        if dist ~= 0 or not last then
            if dist ~= 0 then
                local segs = CoachTrail.def_segments
                segs[#segs + 1] = {
                    x = ox, y = oy, z = oz,
                    exp = now + (CoachTrail.def_seg_exp or 10) * 0.1,
                }
            end
        end
        CoachTrail.def_last_origin = { x = ox, y = oy, z = oz }
        local segs = CoachTrail.def_segments
        for i = #segs, 1, -1 do
            if (segs[i].exp or 0) < now then
                table.remove(segs, i)
            end
        end
        return
    end

    TrailUI.clearDefaultSegments()
    trailTickPoints(ox, oy, oz, now, dt)
    trailSpawnParticleRibbon(now)
end

local function trailDefWorldToScreen(wx, wy, wz)
    local sx, sy
    pcall(function()
        if not (client and client.WorldToScreen) then return end
        if Vector3 then
            sx, sy = client.WorldToScreen(Vector3(wx, wy, wz))
        else
            sx, sy = client.WorldToScreen(wx, wy, wz)
        end
    end)
    if type(sx) == "table" then
        sy = sx.y or sx[2]
        sx = sx.x or sx[1]
    end
    if type(sx) == "number" and type(sy) == "number" then return sx, sy end
    return nil
end

local function trailDefFadeRGB(seed, speed)
    local t
    pcall(function() t = globals.RealTime() end)
    if type(t) ~= "number" then t = stepNow() end
    speed = (tonumber(speed) or 1) * 0.1
    seed = tonumber(seed) or 0
    local r = math.floor(math.sin((t + seed) * speed) * 127 + 128)
    local g = math.floor(math.sin((t + seed) * speed + 2) * 127 + 128)
    local b = math.floor(math.sin((t + seed) * speed + 4) * 127 + 128)
    return r, g, b
end

local function trailDraw()
    if not CoachTrail.enabled then return end
    if (CoachTrail.mode or TRAIL_MODE_DEFAULT) ~= TRAIL_MODE_DEFAULT then return end
    local segs = CoachTrail.def_segments
    if type(segs) ~= "table" or #segs < 1 then return end

    local colorType = CoachTrail.def_color_type or 1
    local trailType = CoachTrail.def_type or 1
    local chromaSpeed = CoachTrail.def_chroma or 1
    local static = CoachTrail.def_color or DEFAULT_TRAIL_DEF_COLOR

    for i, segment in ipairs(segs) do
        local x, y = trailDefWorldToScreen(segment.x, segment.y, segment.z)
        if x and y then
            local seed = (colorType == 3) and i or 0
            local r, g, b
            if colorType == 1 then
                r, g, b = static[1] or 246, static[2] or 34, static[3] or 34
            else
                r, g, b = trailDefFadeRGB(seed, chromaSpeed)
            end
            local a = static[4] or 255
            draw.Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a))

            if trailType == 1 or trailType == 2 then
                if i < #segs then
                    local s2 = segs[i + 1]
                    local x2, y2 = trailDefWorldToScreen(s2.x, s2.y, s2.z)
                    if x2 and y2 then
                        if trailType == 2 then
                            local xw = CoachTrail.def_x_w or 1
                            local yw = CoachTrail.def_y_w or 1
                            for o = 1, xw do
                                pcall(function()
                                    draw.Line(math.floor(x + o), math.floor(y), math.floor(x2 + o), math.floor(y2))
                                end)
                            end
                            for o = 1, yw do
                                pcall(function()
                                    draw.Line(math.floor(x), math.floor(y + o), math.floor(x2), math.floor(y2 + o))
                                end)
                            end
                        else
                            local sz = CoachTrail.def_line_size or 1
                            for o = 1, sz do
                                pcall(function()
                                    draw.Line(
                                        math.floor(x + o), math.floor(y + o),
                                        math.floor(x2 + o), math.floor(y2 + o)
                                    )
                                end)
                            end
                        end
                    end
                end
            else
                local rw = CoachTrail.def_rect_w or 1
                local rh = CoachTrail.def_rect_h or 1
                pcall(function()
                    draw.FilledRect(
                        math.floor(x), math.floor(y),
                        math.floor(x + rw), math.floor(y + rh)
                    )
                end)
            end
        end
    end
end

local DEATH_FX_MIN_ALIVE = 0.35
local DEATH_FX_DEFAULT_Z = 8
local DEATH_FX_SPAWN_DELAY = 0
local DEATH_FX_MAX_LIVE = 48
local DeathFxState = {}
local DeathFxPending = {}
local DeathFxEventQueue = {} 
local DeathFxDeferred = {} 
local DeathFxFollow = {} 
local DeathFxRetired = {} 

local function deathFxClearFollow()
    DeathFxFollow = {}
end

local function deathFxRandDisk(spread, zSpread)
    spread = tonumber(spread) or 0
    zSpread = tonumber(zSpread) or 0
    local dx, dy, dz = 0, 0, 0
    if spread > 0 then
        local ang = math.random() * (math.pi * 2)
        local r = math.sqrt(math.random()) * spread
        dx = math.cos(ang) * r
        dy = math.sin(ang) * r
    end
    if zSpread > 0 then
        dz = ((math.random() * 2) - 1) * zSpread
    end
    return dx, dy, dz
end

local function deathFxFlushPending(now)
    if #DeathFxPending == 0 then return end
    if type(ParticleAPI.flushReleases) == "function" then
        pcall(ParticleAPI.flushReleases, now)
    end
    local keep = {}
    for i = 1, #DeathFxPending do
        local e = DeathFxPending[i]
        if e and type(e.idx) == "number" then
            if (e.at or 0) <= now then
                if type(ParticleAPI.destroyEffect) == "function" then
                    pcall(ParticleAPI.destroyEffect, e.idx)
                end
            else
                keep[#keep + 1] = e
            end
        end
    end
    DeathFxPending = keep
end

local function deathFxRetireLive()
    for i = 1, #DeathFxPending do
        local e = DeathFxPending[i]
        if e and type(e.idx) == "number" then
            if type(ParticleAPI.destroyEffect) == "function" then
                pcall(ParticleAPI.destroyEffect, e.idx)
            end
            DeathFxRetired[#DeathFxRetired + 1] = e.idx
        end
    end
    DeathFxPending = {}
    deathFxClearFollow()
    DeathFxDeferred = {}
end

local function deathFxReleaseRetired()
    if #DeathFxRetired == 0 then return end
    if type(ParticleAPI.releaseEffect) == "function" then
        for i = 1, #DeathFxRetired do
            pcall(ParticleAPI.releaseEffect, DeathFxRetired[i])
        end
    end
    DeathFxRetired = {}
end

local function deathFxCullOldest()
    while #DeathFxPending > DEATH_FX_MAX_LIVE do
        local e = table.remove(DeathFxPending, 1)
        if e and type(e.idx) == "number" then
            if type(ParticleAPI.destroyEffect) == "function" then
                pcall(ParticleAPI.destroyEffect, e.idx)
            end
            DeathFxRetired[#DeathFxRetired + 1] = e.idx
        end
    end
end

local function deathFxRetireByPaths(pathSet)
    if type(pathSet) ~= "table" then return end
    local keep = {}
    for i = 1, #DeathFxPending do
        local e = DeathFxPending[i]
        if e and type(e.idx) == "number" and e.path and pathSet[e.path] then
            if type(ParticleAPI.destroyEffect) == "function" then
                pcall(ParticleAPI.destroyEffect, e.idx)
            end
            DeathFxRetired[#DeathFxRetired + 1] = e.idx
        elseif e then
            keep[#keep + 1] = e
        end
    end
    DeathFxPending = keep
end

local function deathFxExclusivePathSet(paths)
    if type(paths) ~= "table" or not paths.exclusive then return nil end
    local pathSet = {}
    for i = 1, #paths do
        local entry = paths[i]
        local p = type(entry) == "table" and (entry.path or entry[1]) or entry
        if type(p) == "string" then pathSet[p] = true end
    end
    return pathSet
end

local function deathFxFindLiveIdx(idx)
    for i = 1, #DeathFxPending do
        local e = DeathFxPending[i]
        if e and e.idx == idx then return i end
    end
    return nil
end

local function deathFxSpawnOne(path, x, y, z, now, life)
    if type(path) ~= "string" or type(ParticleAPI.spawnPoint) ~= "function" then return end
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then return end
    if #DeathFxRetired > 0 then
        deathFxReleaseRetired()
    end

    local idx
    pcall(function()
        idx = ParticleAPI.spawnPoint(path, { x = x, y = y, z = z }, nil, true)
    end)
    if type(idx) ~= "number" then
        DeathFxFollow[#DeathFxFollow + 1] = {
            path = path,
            x = x,
            y = y,
            z = z,
            at = now + 0.05,
            life = tonumber(life) or 6.0,
        }
        return
    end

    local conflict = deathFxFindLiveIdx(idx)
    if conflict then
        local old = table.remove(DeathFxPending, conflict)
        if old and type(old.idx) == "number" then
            if type(ParticleAPI.destroyEffect) == "function" then
                pcall(ParticleAPI.destroyEffect, old.idx)
            end
            DeathFxRetired[#DeathFxRetired + 1] = old.idx
        end
        DeathFxFollow[#DeathFxFollow + 1] = {
            path = path,
            x = x,
            y = y,
            z = z,
            at = now + 0.05,
            life = tonumber(life) or 6.0,
        }
        return
    end

    DeathFxPending[#DeathFxPending + 1] = {
        idx = idx,
        at = now + (tonumber(life) or 6.0),
        path = path,
    }
    deathFxCullOldest()
end

local function deathFxScheduleFollow(entry, path, x, y, zBase, zOff, now)
    local f = entry and entry.follow
    if type(f) ~= "table" then return end
    local nMin = tonumber(f.count_min)
    local nMax = tonumber(f.count_max)
    local n
    if nMin or nMax then
        nMin = math.max(0, math.floor(nMin or nMax or 0))
        nMax = math.max(nMin, math.floor(nMax or nMin))
        n = nMin + math.floor(math.random() * (nMax - nMin + 1))
    else
        n = math.max(0, math.floor(tonumber(f.count) or 0))
    end
    if n <= 0 then return end
    local dMin = tonumber(f.delay_min) or 0.25
    local dMax = tonumber(f.delay_max) or 2.5
    if dMax < dMin then dMax = dMin end
    local spread = tonumber(f.spread) or tonumber(entry.spread) or 0
    local zSpread = tonumber(f.z_spread) or tonumber(entry.z_spread) or 0
    local zMin = tonumber(f.z_min)
    local zMax = tonumber(f.z_max)
    local life = tonumber(f.life) or 4.0

    local progressive = f.progressive and true or false
    local rMin = tonumber(f.radius_min) or 0
    local rMax = tonumber(f.radius_max) or spread
    local baseAng = math.random() * (math.pi * 2)

    for i = 1, n do
        local delay, dx, dy, dz, zz
        if progressive then
            local t = (n > 1) and ((i - 1) / (n - 1)) or 0
            delay = dMin + (dMax - dMin) * t
            local r = rMin + (rMax - rMin) * t
            local ang = baseAng + (i - 1) * 2.39996
            dx = math.cos(ang) * r
            dy = math.sin(ang) * r
            dz = (zSpread > 0) and (((math.random() * 2) - 1) * zSpread) or 0
            if zMin and zMax then
                local hi = (zMax < zMin) and zMin or zMax
                zz = zBase + zMin + (hi - zMin) * t + dz
            else
                zz = zBase + (zOff or 0) + dz
            end
        else
            delay = dMin + math.random() * (dMax - dMin)
            dx, dy, dz = deathFxRandDisk(spread, zSpread)
            if zMin and zMax then
                local hi = (zMax < zMin) and zMin or zMax
                zz = zBase + zMin + math.random() * (hi - zMin) + dz
            else
                zz = zBase + (zOff or 0) + dz
            end
        end
        DeathFxFollow[#DeathFxFollow + 1] = {
            path = path,
            x = x + dx,
            y = y + dy,
            z = zz,
            at = now + delay,
            life = life,
        }
    end
end

local function deathFxCreateNow(x, y, zBase)
    local sel = math.max(1, math.min(#DEATH_EFFECT_PATHS, math.floor(tonumber(deathEffectCombo:Get()) or 1)))
    local paths = DEATH_EFFECT_PATHS[sel]
    if type(paths) ~= "table" or type(ParticleAPI.spawnPoint) ~= "function" then return end
    if type(x) ~= "number" or type(y) ~= "number" or type(zBase) ~= "number" then return end

    local now = stepNow()
    for i = 1, #paths do
        local entry = paths[i]
        local path, zOff = nil, DEATH_FX_DEFAULT_Z
        local count, spread, zSpread, life = 1, 0, 0, 6.0
        local arrange, arrangeR = nil, 0
        if type(entry) == "table" then
            path = entry.path or entry[1]
            zOff = tonumber(entry.z_off or entry.z or entry[2]) or DEATH_FX_DEFAULT_Z
            if entry.count ~= nil then
                count = math.max(0, math.floor(tonumber(entry.count) or 0))
            else
                count = 1
            end
            spread = tonumber(entry.spread) or 0
            zSpread = tonumber(entry.z_spread) or 0
            life = tonumber(entry.life) or 6.0
            arrange = entry.arrange
            arrangeR = tonumber(entry.radius) or spread
        elseif type(entry) == "string" then
            path = entry
        end
        if path then
            local ringBase = math.random() * (math.pi * 2)
            for n = 1, count do
                local dx, dy, dz = 0, 0, 0
                if arrange == "ring" and arrangeR > 0 then
                    local ang = ringBase + ((n - 1) / count) * math.pi * 2
                    dx = math.cos(ang) * arrangeR
                    dy = math.sin(ang) * arrangeR
                    if zSpread > 0 then dz = ((math.random() * 2) - 1) * zSpread end
                elseif count > 1 or spread > 0 or zSpread > 0 then
                    dx, dy, dz = deathFxRandDisk(spread, zSpread)
                end
                deathFxSpawnOne(path, x + dx, y + dy, zBase + zOff + dz, now, life)
            end
            deathFxScheduleFollow(entry, path, x, y, zBase, zOff, now)
        end
    end
end

local function deathFxQueueSpawn(x, y, zBase)
    if type(x) ~= "number" or type(y) ~= "number" or type(zBase) ~= "number" then return end
    local sel = math.max(1, math.min(#DEATH_EFFECT_PATHS, math.floor(tonumber(deathEffectCombo:Get()) or 1)))
    local paths = DEATH_EFFECT_PATHS[sel]
    local pathSet = deathFxExclusivePathSet(paths)
    if pathSet then
        deathFxRetireByPaths(pathSet)
    end
    local now = stepNow()
    DeathFxDeferred[#DeathFxDeferred + 1] = {
        x = x, y = y, z = zBase, at = now + DEATH_FX_SPAWN_DELAY,
    }
end

local function deathFxPumpDeferred(now)
    if #DeathFxDeferred == 0 then return end
    local keep = {}
    for i = 1, #DeathFxDeferred do
        local e = DeathFxDeferred[i]
        if e and (e.at or 0) <= now then
            deathFxCreateNow(e.x, e.y, e.z)
        elseif e then
            keep[#keep + 1] = e
        end
    end
    DeathFxDeferred = keep
end

local function deathFxPumpFollow(now)
    if #DeathFxFollow == 0 then return end
    local keep = {}
    for i = 1, #DeathFxFollow do
        local e = DeathFxFollow[i]
        if e and (e.at or 0) <= now then
            deathFxSpawnOne(e.path, e.x, e.y, e.z, now, e.life)
        elseif e then
            keep[#keep + 1] = e
        end
    end
    DeathFxFollow = keep
end

local function deathFxResolveVictim(userid)
    if type(userid) ~= "number" then return nil end
    local victim
    pcall(function() victim = entities.GetByUserID(userid) end)
    if victim then return victim end
    local pidx
    pcall(function() pidx = client.GetPlayerIndexByUserID(userid) end)
    if type(pidx) == "number" then
        pcall(function() victim = entities.GetByIndex(pidx) end)
        if victim then return victim end
    end
    local list
    pcall(function() list = entities.FindByClass("C_CSPlayerPawn") end)
    if not list then return nil end
    for i = 1, #list do
        local pawn = list[i]
        if pawn then
            local match = false
            pcall(function()
                local ctrl = pawn:GetPropEntity("m_hController")
                if ctrl and ctrl.GetPropInt then
                    local u = ctrl:GetPropInt("m_iUserID")
                    if u == userid then match = true end
                end
            end)
            if not match then
                pcall(function()
                    local u = pawn:GetPropInt("m_iUserID")
                    if u == userid then match = true end
                end)
            end
            if match then return pawn end
        end
    end
    return nil
end

local function deathFxOnGameEvent(ev)
    if not DeathUI.isArmed() then return end
    local name
    pcall(function() name = ev:GetName() end)
    if name ~= "player_death" then return end
    local userid
    pcall(function() userid = ev:GetInt("userid") end)
    local victim = deathFxResolveVictim(userid)
    local ox, oy, oz
    if victim then
        ox, oy, oz = stepOrigin(victim)
    end
    if not (ox and oy and oz) then return end

    if victim then
        local idx
        pcall(function() idx = victim:GetIndex() end)
        if idx then
            local st = DeathFxState[idx]
            if st and st.fired then return end
            if st then
                st.fired = true
                st.alive = false
            else
                DeathFxState[idx] = { alive = false, fired = true, x = ox, y = oy, z = oz }
            end
            DeathFxEventQueue[#DeathFxEventQueue + 1] = { x = ox, y = oy, z = oz, ent = idx }
            return
        end
    end
    DeathFxEventQueue[#DeathFxEventQueue + 1] = { x = ox, y = oy, z = oz }
end

pcall(function()
    callbacks.Register("FireGameEvent", "daizml_death_fx", deathFxOnGameEvent)
end)

pcall(function()
    callbacks.Unregister("FireGameEvent", "daizml_trail_round")
end)
pcall(function()
    if client and client.AllowListener then client.AllowListener("round_start") end
end)
pcall(function()
    callbacks.Register("FireGameEvent", "daizml_trail_round", function(ev)
        local name
        pcall(function() name = ev:GetName() end)
        if name == "round_start" then
            TrailUI.clearDefaultSegments()
        end
    end)
end)


local function deathFxUpdate()
    local now = stepNow()
    deathFxFlushPending(now)
    deathFxPumpDeferred(now)
    deathFxPumpFollow(now)

    if not DeathUI.isArmed() then
        if #DeathFxPending > 0 or #DeathFxFollow > 0 or #DeathFxDeferred > 0 then
            deathFxRetireLive()
        end
        if next(DeathFxState) then DeathFxState = {} end
        if #DeathFxEventQueue > 0 then DeathFxEventQueue = {} end
        if #DeathFxRetired > 0 then DeathFxRetired = {} end
        return
    end

    if #DeathFxEventQueue > 0 then
        for i = 1, #DeathFxEventQueue do
            local e = DeathFxEventQueue[i]
            if e and e.x and e.y and e.z then
                deathFxQueueSpawn(e.x, e.y, e.z)
            end
        end
        DeathFxEventQueue = {}
    end

    local list
    pcall(function() list = entities.FindByClass("C_CSPlayerPawn") end)
    if not list then return end

    local seen = {}
    for i = 1, #list do
        local pawn = list[i]
        if pawn then
            local idx
            pcall(function() idx = pawn:GetIndex() end)
            if idx then
                seen[idx] = true
                local alive = stepAlive(pawn)
                local ox, oy, oz = stepOrigin(pawn)
                local st = DeathFxState[idx]

                if alive then
                    if not st then
                        DeathFxState[idx] = {
                            alive = true,
                            fired = false,
                            aliveSince = now,
                            x = ox,
                            y = oy,
                            z = oz,
                        }
                    elseif not st.alive then
                        st.alive = true
                        st.aliveSince = now
                        if ox and oy and oz then
                            st.x, st.y, st.z = ox, oy, oz
                        end
                    else
                        if st.fired and (now - (st.aliveSince or 0)) >= DEATH_FX_MIN_ALIVE then
                            st.fired = false
                        end
                        if ox and oy and oz then
                            st.x, st.y, st.z = ox, oy, oz
                        end
                    end
                else
                    if st and st.alive and not st.fired
                        and st.x and st.y and st.z
                        and (now - (st.aliveSince or 0)) >= DEATH_FX_MIN_ALIVE then
                        local dx = ox or st.x
                        local dy = oy or st.y
                        local dz = oz or st.z
                        st.fired = true
                        st.alive = false
                        deathFxQueueSpawn(dx, dy, dz)
                    elseif st then
                        st.alive = false
                    else
                        DeathFxState[idx] = { alive = false, fired = true }
                    end
                end
            end
        end
    end

    for k in pairs(DeathFxState) do
        if not seen[k] then DeathFxState[k] = nil end
    end
end

local VELO_SAMPLES = 120
local VELO_RATE = 1 / 60
local VELO_FLOOR = 340      
local VELO_RUN = 250      
local VELO_W, VELO_H = 258, 96
local VELO_PAD = 9
local VELO_PEAK_HOLD = 2.5

local mfloor, msqrt, mmin, mmax = math.floor, math.sqrt, math.min, math.max

local VELO_READERS = {
    function(e) return e:GetFieldVector("m_vecAbsVelocity") end,
    function(e) return e:GetFieldVector("m_vecVelocity") end,
    function(e) return e:GetField("m_vecAbsVelocity") end,
    function(e) return e:GetField("m_vecVelocity") end,
    function(e) return e:GetPropVector("m_vecVelocity") end,
}

local Velo = {
    buf = {},
    head = 0,
    count = 0,
    nextAt = 0,
    scale = VELO_FLOOR,
    speed = 0,
    shown = 0,
    peak = 0,
    peakAt = 0,
    reader = nil,
    lastX = nil,
    lastY = nil,
    lastAt = nil,
    fonts = false,
    _drag = nil,
    _mouseDown = false,
}

local function veloMouse()
    local mx, my = 0, 0
    pcall(function()
        local p = input.GetMousePos()
        if type(p) == "table" then mx, my = p.x or p[1] or 0, p.y or p[2] or 0
        else mx, my = p, select(2, input.GetMousePos()) end
    end)
    pcall(function()
        local x, y = input.GetMousePos()
        if type(x) == "number" and type(y) == "number" then mx, my = x, y end
    end)
    local down = false
    pcall(function() down = input.IsButtonDown(0x01) and true or false end)
    return mx, my, down
end

local function veloReset()
    Velo.buf, Velo.head, Velo.count = {}, 0, 0
    Velo.speed, Velo.shown, Velo.peak, Velo.peakAt = 0, 0, 0, 0
    Velo.scale = VELO_FLOOR
    Velo.nextAt = 0
    Velo.reader = nil 
    Velo.lastX, Velo.lastY, Velo.lastAt = nil, nil, nil
end

local function veloReadSpeed(lp, now)
    local vx, vy
    if Velo.reader ~= false then
        if Velo.reader then
            local ok, v = pcall(VELO_READERS[Velo.reader], lp)
            if ok and v ~= nil then
                local x, y = stepXYZ(v)
                if x then vx, vy = x, y end
            end
            if not vx then Velo.reader = nil end
        end
        if not vx then
            for i = 1, #VELO_READERS do
                local ok, v = pcall(VELO_READERS[i], lp)
                if ok and v ~= nil then
                    local x, y = stepXYZ(v)
                    if x then
                        Velo.reader = i
                        vx, vy = x, y
                        break
                    end
                end
            end
        end
    end

    if not vx then
        local ox, oy = stepOrigin(lp)
        if not ox then return nil end
        local dt = Velo.lastAt and (now - Velo.lastAt) or 0
        if Velo.lastX and dt > 0 and dt <= 0.1 then
            vx, vy = (ox - Velo.lastX) / dt, (oy - Velo.lastY) / dt
        else
            vx, vy = 0, 0
        end
        Velo.lastX, Velo.lastY, Velo.lastAt = ox, oy, now
    end

    local sp = msqrt(vx * vx + vy * vy)
    if sp ~= sp or sp > 5000 then return nil end
    return sp
end

local function veloMix(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
    }
end

local function veloTint(sp, accent)
    if sp <= VELO_RUN then return accent end
    if sp <= 450 then
        return veloMix(accent, { 255, 176, 64 }, (sp - VELO_RUN) / (450 - VELO_RUN))
    end
    local t = (sp - 450) / 250
    if t > 1 then t = 1 end
    return veloMix({ 255, 176, 64 }, { 255, 86, 86 }, t)
end

local function veloRect(x, y, w, h, c, a)
    if w <= 0 or h <= 0 then return end
    draw.Color(mfloor(c[1]), mfloor(c[2]), mfloor(c[3]), mfloor(a))
    draw.FilledRect(mfloor(x), mfloor(y), mfloor(x + w), mfloor(y + h))
end

local function veloDraw()
    if not (velocityGraph and velocityGraph:Get()) then
        if Velo.count > 0 then veloReset() end
        return
    end

    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then
        if Velo.count > 0 then veloReset() end
        return
    end

    local hp
    pcall(function() hp = lp:GetHealth() end)
    if type(hp) ~= "number" then pcall(function() hp = lp:GetPropInt("m_iHealth") end) end
    if type(hp) == "number" and hp <= 0 then
        if Velo.count > 0 then veloReset() end
        return
    end

    local now = stepNow()
    local sp = veloReadSpeed(lp, now)
    if sp then Velo.speed = sp end
    sp = Velo.speed

    if type(Velo.nextAt) ~= "number" or Velo.nextAt - now > 0.5 or now - Velo.nextAt > 2 then
        Velo.nextAt = now
    end
    if now >= Velo.nextAt then
        if now - Velo.nextAt > 0.5 then Velo.nextAt = now end
        repeat
            Velo.head = Velo.head % VELO_SAMPLES + 1
            Velo.buf[Velo.head] = sp
            if Velo.count < VELO_SAMPLES then Velo.count = Velo.count + 1 end
            Velo.nextAt = Velo.nextAt + VELO_RATE
        until now < Velo.nextAt
    end

    if sp >= Velo.peak or (now - Velo.peakAt) > VELO_PEAK_HOLD then
        if sp >= Velo.peak then Velo.peakAt = now end
        Velo.peak = sp
    end
    Velo.shown = Velo.shown + (sp - Velo.shown) * 0.25

    local hi = 0
    for i = 1, Velo.count do
        local v = Velo.buf[i]
        if v and v > hi then hi = v end
    end
    hi = hi * 1.12
    if hi < VELO_FLOOR then hi = VELO_FLOOR end
    Velo.scale = Velo.scale + (hi - Velo.scale) * 0.08
    if Velo.scale < VELO_FLOOR then Velo.scale = VELO_FLOOR end

    if not Velo.fonts then
        Velo.fonts = true
        pcall(function()
            Velo.fBig = draw.CreateFont("Segoe UI", 30, 700)
            Velo.fMid = draw.CreateFont("Segoe UI", 14, 600)
            Velo.fSmall = draw.CreateFont("Segoe UI", 12, 500)
        end)
    end

    local sw, sh = 1920, 1080
    pcall(function() sw, sh = draw.GetScreenSize() end)

    local x = mfloor((sw - VELO_W) * 0.5)
    local y = mfloor(sh * 0.80)
    if VeloPos.x ~= nil and VeloPos.y ~= nil then
        x, y = mfloor(VeloPos.x), mfloor(VeloPos.y)
    end
    if x < 0 then x = 0 elseif x > sw - VELO_W then x = mmax(0, sw - VELO_W) end
    if y < 0 then y = 0 elseif y > sh - VELO_H then y = mmax(0, sh - VELO_H) end

    local menuOpen = M._open and true or false
    local mx, my, mouseDown = veloMouse()
    local pressed = mouseDown and not Velo._mouseDown
    Velo._mouseDown = mouseDown
    if menuOpen then
        local hov = mx >= x and mx <= x + VELO_W and my >= y and my <= y + VELO_H
        if pressed and hov then
            Velo._drag = { dx = mx - x, dy = my - y }
        end
        if Velo._drag then
            if mouseDown then
                x = mx - Velo._drag.dx
                y = my - Velo._drag.dy
                if x < 0 then x = 0 elseif x > sw - VELO_W then x = mmax(0, sw - VELO_W) end
                if y < 0 then y = 0 elseif y > sh - VELO_H then y = mmax(0, sh - VELO_H) end
                VeloPos.x, VeloPos.y = x, y
            else
                Velo._drag = nil
            end
        end
    else
        Velo._drag = nil
    end

    local acc = { 74, 166, 255 }
    pcall(function()
        local c = uiAccent:Get()
        if type(c) == "table" and c[1] then acc = { c[1], c[2], c[3] } end
    end)
    local tint = veloTint(sp, acc)
    local borderA = (Velo._drag and 220) or (menuOpen and 90) or 18
    veloRect(x, y, VELO_W, VELO_H, { 9, 11, 16 }, 214)
    veloRect(x, y, VELO_W, 2, tint, 235)
    veloRect(x, y + VELO_H - 1, VELO_W, 1, { 0, 0, 0 }, 150)
    veloRect(x, y + 2, 1, VELO_H - 3, { 255, 255, 255 }, borderA)
    veloRect(x + VELO_W - 1, y + 2, 1, VELO_H - 3, { 255, 255, 255 }, borderA)
    if menuOpen then
        veloRect(x, y + 2, VELO_W, 1, { 255, 255, 255 }, 28)
        veloRect(x, y + VELO_H - 2, VELO_W, 1, { 255, 255, 255 }, 28)
    end

    local gx = x + VELO_PAD
    local gy = y + 44
    local gw = VELO_W - VELO_PAD * 2
    local gh = VELO_H - 44 - VELO_PAD

    pcall(function()
        if Velo.fBig then draw.SetFont(Velo.fBig) end
        local label = tostring(mfloor(Velo.shown + 0.5))
        draw.Color(mfloor(tint[1]), mfloor(tint[2]), mfloor(tint[3]), 255)
        draw.Text(gx, y + 8, label)

        local tw = draw.GetTextSize(label) or 0

        if Velo.fSmall then draw.SetFont(Velo.fSmall) end
        draw.Color(150, 160, 176, 220)
        draw.Text(gx + tw + 5, y + 24, "u/s")

        local pk = "PEAK " .. tostring(mfloor(Velo.peak + 0.5))
        local pw = draw.GetTextSize(pk) or 0
        draw.Color(150, 160, 176, 210)
        draw.Text(gx + gw - pw, y + 12, pk)

        local sc = tostring(mfloor(Velo.scale + 0.5))
        local scw = draw.GetTextSize(sc) or 0
        draw.Color(110, 120, 136, 190)
        draw.Text(gx + gw - scw, y + 27, sc)
    end)

    veloRect(gx, gy, gw, gh, { 255, 255, 255 }, 10)
    if VELO_RUN < Velo.scale then
        local ry = gy + gh - (VELO_RUN / Velo.scale) * gh
        local dx = 0
        while dx < gw do
            veloRect(gx + dx, ry, 3, 1, { 255, 255, 255 }, 42)
            dx = dx + 7
        end
    end

    local cw = gw / VELO_SAMPLES
    for i = 1, Velo.count do
        local slot = (Velo.head - Velo.count + i - 1) % VELO_SAMPLES + 1
        local v = Velo.buf[slot] or 0
        local bh = (v / Velo.scale) * gh
        if bh > gh then bh = gh end
        if bh > 0 then
            local bx = gx + (i - 1 + VELO_SAMPLES - Velo.count) * cw
            local bw = cw + 1
            local ct = veloTint(v, acc)
            veloRect(bx, gy + gh - bh, bw, bh, ct, 52)
            veloRect(bx, gy + gh - bh, bw, mmin(2, bh), ct, 240)
        end
    end
    veloRect(gx + gw - 1, gy, 1, gh, tint, 120)
end

local KEY_SIZE = 38
local KEY_GAP = 6
local KEY_PAD = 10
local KEY_WIDE = 58
local KEY_SPACE = 86
local KEY_SIDE_GAP = 14
local WASD_W = KEY_SIZE * 3 + KEY_GAP * 2
local WASD_H = KEY_SIZE * 2 + KEY_GAP

local KEY_DEFS = {
    { id = "w",      label = "W",      code = 0x57, col = 1, row = 0 },
    { id = "a",      label = "A",      code = 0x41, col = 0, row = 1 },
    { id = "s",      label = "S",      code = 0x53, col = 1, row = 1 },
    { id = "d",      label = "D",      code = 0x44, col = 2, row = 1 },
    { id = "crouch", label = "CROUCH", code = 0x11 },
    { id = "jump",   label = "JUMP",   code = 0x20 },
}

local function keysPanelSize(layout)
    layout = tonumber(layout) or 3
    if layout == 1 then
        return KEY_PAD * 2 + WASD_W + KEY_SIDE_GAP + KEY_SPACE,
               KEY_PAD * 2 + WASD_H
    elseif layout == 2 then
        return KEY_PAD * 2 + WASD_W + KEY_SIDE_GAP + KEY_WIDE + KEY_GAP + KEY_SPACE,
               KEY_PAD * 2 + WASD_H
    end
    return KEY_PAD * 2 + WASD_W,
           KEY_PAD * 2 + KEY_SIZE * 3 + KEY_GAP * 2
end

local function keysKeyRect(layout, id, originX, originY, panelW)
    local cell = KEY_SIZE + KEY_GAP
    if id == "w" or id == "a" or id == "s" or id == "d" then
        local col = (id == "a" and 0) or (id == "w" or id == "s") and 1 or 2
        local row = (id == "w") and 0 or 1
        return originX + col * cell, originY + row * cell, KEY_SIZE, KEY_SIZE
    end

    layout = tonumber(layout) or 3
    if layout == 1 then
        local sx = originX + WASD_W + KEY_SIDE_GAP
        if id == "jump" then
            return sx, originY, KEY_SPACE, KEY_SIZE
        end
        return sx, originY + WASD_H - KEY_SIZE, KEY_SPACE, KEY_SIZE
    elseif layout == 2 then
        local midY = originY + mfloor((WASD_H - KEY_SIZE) * 0.5)
        local sx = originX + WASD_W + KEY_SIDE_GAP
        if id == "crouch" then
            return sx, midY, KEY_WIDE, KEY_SIZE
        end
        return sx + KEY_WIDE + KEY_GAP, midY, KEY_SPACE, KEY_SIZE
    end

    local ky = originY + 2 * cell
    if id == "crouch" then
        return originX, ky, KEY_WIDE, KEY_SIZE
    end
    return originX + KEY_WIDE + KEY_GAP, ky, panelW - KEY_PAD * 2 - KEY_WIDE - KEY_GAP, KEY_SIZE
end

local Keys = {
    fonts = false,
    amount = {},
    _drag = nil,
    _mouseDown = false,
    wheelUpAt = 0,
    wheelDownAt = 0,
    wheelPrev = nil,
    wheelMode = nil, 
}

local function keysReadWheelNotch()
    local raw = nil
    pcall(function()
        if input.GetMouseWheelDelta then
            local v = input.GetMouseWheelDelta()
            if type(v) == "number" then raw = v; Keys.wheelMode = Keys.wheelMode or "accum" end
        end
        if raw == nil and input.GetMouseWheel then
            local v = input.GetMouseWheel()
            if type(v) == "number" then raw = v; Keys.wheelMode = Keys.wheelMode or "frame" end
        end
    end)
    if raw == nil then return 0 end

    if Keys.wheelMode == "accum" then
        if Keys.wheelPrev == nil then
            Keys.wheelPrev = raw
            return 0
        end
        local d = raw - Keys.wheelPrev
        Keys.wheelPrev = raw
        return d
    end

    if Keys.wheelPrev ~= nil and raw ~= 0 and Keys.wheelPrev ~= 0 and raw ~= Keys.wheelPrev
        and ((raw > 0 and Keys.wheelPrev > 0) or (raw < 0 and Keys.wheelPrev < 0)) then
        Keys.wheelMode = "accum"
        local d = raw - Keys.wheelPrev
        Keys.wheelPrev = raw
        return d
    end
    Keys.wheelPrev = raw
    return raw
end

local function keysPollWheel()
    local wheel = keysReadWheelNotch()
    local t = stepNow()
    if wheel > 0 then Keys.wheelUpAt = t
    elseif wheel < 0 then Keys.wheelDownAt = t end
end

local function keysDown(code)
    code = tonumber(code) or 0
    if code == 0x700 then
        return (stepNow() - (Keys.wheelUpAt or 0)) < 0.22
    end
    if code == 0x701 then
        return (stepNow() - (Keys.wheelDownAt or 0)) < 0.22
    end
    if code <= 0 or code > 255 then return false end
    local down = false
    pcall(function() down = input.IsButtonDown(code) and true or false end)
    if not down and code == 0x11 then
        pcall(function() down = input.IsButtonDown(0xA2) and true or false end)
        if not down then pcall(function() down = input.IsButtonDown(0xA3) and true or false end) end
    end
    return down
end

pcall(function()
    callbacks.Register("CreateMove", "daizml_keys_input", function(cmd)
        if not (movementKeys and movementKeys:Get()) then return end
        keysPollWheel()
        local jumpCode = 0x20
        pcall(function() jumpCode = tonumber(jumpKey:Get()) or 0x20 end)
        if jumpCode ~= 0x700 and jumpCode ~= 0x701 then return end
        local buttons = 0
        pcall(function() if cmd then buttons = tonumber(cmd:GetButtons()) or 0 end end)
        local jumping = false
        pcall(function()
            if bit and bit.band then
                jumping = bit.band(buttons, 2) ~= 0
            else
                jumping = (math.floor(buttons / 2) % 2) == 1
            end
        end)
        if jumping then 
            local t = stepNow()
            if jumpCode == 0x701 then Keys.wheelDownAt = t else Keys.wheelUpAt = t end
        end
    end)
end)

local function keysColor(c)
    if type(c) ~= "table" then return { 8, 10, 14 } end
    return { tonumber(c[1]) or 8, tonumber(c[2]) or 10, tonumber(c[3]) or 14 }
end

local function keysGlow(x, y, w, h, accent, strength)
    if strength <= 0.01 then return end
    for i = 1, 5 do
        local expand = i * 2
        local gy = y + h + (i - 1) * 2
        local ga = mfloor(70 * strength * (1 - (i - 1) / 5))
        if ga > 0 then
            veloRect(x - expand, gy, w + expand * 2, 2, accent, ga)
        end
    end
    veloRect(x - 1, y + h - 1, w + 2, 3, accent, mfloor(90 * strength))
end

local function keysDrawKey(kx, ky, kw, kh, label, amount, bg, accent, font)
    local pressed = amount > 0.04
    local fill = bg
    local textCol = { 255, 255, 255 }
    if pressed then
        fill = {
            mfloor(bg[1] + (accent[1] - bg[1]) * amount),
            mfloor(bg[2] + (accent[2] - bg[2]) * amount),
            mfloor(bg[3] + (accent[3] - bg[3]) * amount),
        }
        textCol = { 255, 255, 255 }
    end

    keysGlow(kx, ky, kw, kh, accent, amount)

    veloRect(kx, ky, kw, kh, fill, 230)
    local edge = pressed and mfloor(40 + 120 * amount) or 28
    veloRect(kx, ky, kw, 1, { 255, 255, 255 }, edge)
    veloRect(kx, ky + kh - 1, kw, 1, { 0, 0, 0 }, 120)
    veloRect(kx, ky + 1, 1, kh - 2, { 255, 255, 255 }, mfloor(edge * 0.55))
    veloRect(kx + kw - 1, ky + 1, 1, kh - 2, { 255, 255, 255 }, mfloor(edge * 0.55))
    if pressed then
        veloRect(kx + 1, ky + 1, kw - 2, 2, accent, mfloor(200 * amount))
    end

    pcall(function()
        if font then draw.SetFont(font) end
        local tw, th = draw.GetTextSize(label)
        tw = tw or (#label * 7)
        th = th or 12
        draw.Color(textCol[1], textCol[2], textCol[3], mfloor(200 + 55 * amount))
        draw.Text(mfloor(kx + (kw - tw) * 0.5), mfloor(ky + (kh - th) * 0.5 - 1), label)
    end)
end

local function keysDraw()
    if not (movementKeys and movementKeys:Get()) then
        Keys._drag = nil
        return
    end

    local lp
    pcall(function() lp = entities.GetLocalPlayer() end)
    if not lp then
        Keys._drag = nil
        return
    end
    local hp
    pcall(function() hp = lp:GetHealth() end)
    if type(hp) ~= "number" then pcall(function() hp = lp:GetPropInt("m_iHealth") end) end
    if type(hp) == "number" and hp <= 0 then
        Keys._drag = nil
        return
    end

    if not Keys.fonts then
        Keys.fonts = true
        pcall(function()
            Keys.fLabel = draw.CreateFont("Segoe UI", 13, 700)
            Keys.fWide = draw.CreateFont("Segoe UI", 11, 700)
        end)
    end

    keysPollWheel()

    local jumpCode = 0x20
    pcall(function() jumpCode = tonumber(jumpKey:Get()) or 0x20 end)
    if jumpCode == 0 then jumpCode = 0x20 end

    local layout = 3
    pcall(function()
        local combo = math.max(1, math.min(3, math.floor(tonumber(keysLayout:Get()) or 1)))
        layout = KEY_LAYOUT_FROM_COMBO[combo] or 3
    end)
    local KEYS_W, KEYS_H = keysPanelSize(layout)

    local sw, sh = 1920, 1080
    pcall(function() sw, sh = draw.GetScreenSize() end)

    local x = mfloor(sw * 0.08)
    local y = mfloor(sh * 0.72)
    if KeysPos.x ~= nil and KeysPos.y ~= nil then
        x, y = mfloor(KeysPos.x), mfloor(KeysPos.y)
    end
    if x < 0 then x = 0 elseif x > sw - KEYS_W then x = mmax(0, sw - KEYS_W) end
    if y < 0 then y = 0 elseif y > sh - KEYS_H then y = mmax(0, sh - KEYS_H) end

    local menuOpen = M._open and true or false
    local mx, my, mouseDown = veloMouse()
    local pressed = mouseDown and not Keys._mouseDown
    Keys._mouseDown = mouseDown
    if menuOpen then
        local hov = mx >= x and mx <= x + KEYS_W and my >= y and my <= y + KEYS_H
        if pressed and hov then
            Keys._drag = { dx = mx - x, dy = my - y }
        end
        if Keys._drag then
            if mouseDown then
                x = mx - Keys._drag.dx
                y = my - Keys._drag.dy
                if x < 0 then x = 0 elseif x > sw - KEYS_W then x = mmax(0, sw - KEYS_W) end
                if y < 0 then y = 0 elseif y > sh - KEYS_H then y = mmax(0, sh - KEYS_H) end
                KeysPos.x, KeysPos.y = x, y
            else
                Keys._drag = nil
            end
        end
    else
        Keys._drag = nil
    end

    local accent = keysColor(DEFAULT_ACCENT)
    local bg = keysColor(DEFAULT_BG)
    local bg2 = keysColor(DEFAULT_BG2)
    pcall(function()
        local c = uiAccent:Get()
        if type(c) == "table" and c[1] then accent = keysColor(c) end
    end)
    pcall(function()
        local c = uiBg:Get()
        if type(c) == "table" and c[1] then bg = keysColor(c) end
    end)
    pcall(function()
        local c = uiBg2:Get()
        if type(c) == "table" and c[1] then bg2 = keysColor(c) end
    end)

    local showBg = true
    pcall(function() showBg = keysBackground:Get() and true or false end)
    if showBg then
        local borderA = (Keys._drag and 220) or (menuOpen and 90) or 18
        veloRect(x, y, KEYS_W, KEYS_H, bg, 214)
        veloRect(x, y, KEYS_W, 2, accent, 235)
        veloRect(x, y + KEYS_H - 1, KEYS_W, 1, { 0, 0, 0 }, 150)
        veloRect(x, y + 2, 1, KEYS_H - 3, { 255, 255, 255 }, borderA)
        veloRect(x + KEYS_W - 1, y + 2, 1, KEYS_H - 3, { 255, 255, 255 }, borderA)
        if menuOpen then
            veloRect(x, y + 2, KEYS_W, 1, { 255, 255, 255 }, 28)
            veloRect(x, y + KEYS_H - 2, KEYS_W, 1, { 255, 255, 255 }, 28)
        end
    end

    local originX = x + KEY_PAD
    local originY = y + KEY_PAD

    for i = 1, #KEY_DEFS do
        local k = KEY_DEFS[i]
        local code = (k.id == "jump") and jumpCode or k.code
        local down = keysDown(code)
        local cur = Keys.amount[k.id] or 0
        cur = cur + ((down and 1 or 0) - cur) * 0.38
        if cur < 0.001 then cur = 0 end
        if cur > 0.999 then cur = 1 end
        Keys.amount[k.id] = cur

        local kx, ky, kw, kh = keysKeyRect(layout, k.id, originX, originY, KEYS_W)
        local font = (kw > KEY_SIZE) and Keys.fWide or Keys.fLabel
        keysDrawKey(kx, ky, kw, kh, k.label, cur, bg2, accent, font)
    end
end

return stepUpdate, stepDraw, trailUpdate, trailDraw, deathFxUpdate, veloDraw, keysDraw
end)()

;(function(R)
    local CATALOG_URL = "https://raw.githubusercontent.com/MurkyYT/cs2-map-icons/main/data/available.json"
    local CATALOG_URL_ALT = "https://cdn.jsdelivr.net/gh/MurkyYT/cs2-map-icons@main/data/available.json"
    local CACHE_PATHS = {
        "assets/radar/manifest.txt",
        "Lua/assets/radar/manifest.txt",
        "assets/daizml_radar_manifest.txt",
        "Lua/assets/daizml_radar_manifest.txt",
        "DaizML_radar_manifest.txt",
        "Lua/DaizML_radar_manifest.txt",
    }
    local FP_PREFIX = "#daizml_radar_fp="

    local function log(msg)
        pcall(function() print("[DaizML][Radar] " .. tostring(msg)) end)
    end

    local function setStatus(s)
        R.status = tostring(s or "idle")
        log(R.status)
    end

    local function fingerprint(body)
        if type(body) ~= "string" then return "0:0" end
        local h = 0
        local n = #body
        for i = 1, n do
            h = (h * 31 + body:byte(i)) % 1000000007
        end
        return string.format("%d:%d", n, h)
    end

    local function looksLikeCatalog(body)
        return type(body) == "string"
            and #body > 80
            and body:find('"maps"', 1, true) ~= nil
            and body:find('"count"', 1, true) ~= nil
    end

    local function splitManifest(raw)
        if type(raw) ~= "string" or raw == "" then return nil, nil end
        local fp, rest = raw:match("^#daizml_radar_fp=([^\r\n]+)\r?\n(.*)$")
        if fp and looksLikeCatalog(rest) then
            return fp, rest
        end
        if looksLikeCatalog(raw) then
            return fingerprint(raw), raw
        end
        return nil, nil
    end

    local function writeBytes(path, data)
        if type(data) ~= "string" or data == "" then return false, "empty data" end
        local f
        local openOk, openErr = pcall(function()
            if file and file.Open then f = file.Open(path, "w") end
        end)
        if openOk and f then
            local chunk = 4096
            local n = #data
            local failed = false
            for i = 1, n, chunk do
                local piece = data:sub(i, math.min(n, i + chunk - 1))
                local wok, werr = pcall(function() f:Write(piece) end)
                if not wok then
                    failed = true
                    log("chunk write fail " .. path .. ": " .. tostring(werr))
                    break
                end
            end
            pcall(function() f:Close() end)
            if not failed then
                local check = fileRead(path)
                if type(check) == "string" and #check == n then
                    return true, nil
                end
                local _, body = splitManifest(check)
                if body and looksLikeCatalog(body) then
                    return true, nil
                end
                log("verify mismatch " .. path .. " wrote=" .. tostring(n) .. " read=" .. tostring(check and #check))
            end
        elseif not openOk then
            log("open fail " .. path .. ": " .. tostring(openErr))
        end

        if type(file) == "table" and type(file.Write) == "function" then
            local ok, res = pcall(file.Write, path, data)
            if ok and res ~= false then
                local check = fileRead(path)
                if type(check) == "string" and (#check == #data or select(2, splitManifest(check))) then
                    return true, nil
                end
            else
                log("file.Write fail " .. path .. ": " .. tostring(res))
            end
        end

        if fileWrite(path, data) then
            local check = fileRead(path)
            if type(check) == "string" and #check > 0 then
                return true, nil
            end
        end
        return false, "all write methods failed"
    end

    local function readCacheManifest()
        for i = 1, #CACHE_PATHS do
            local raw = fileRead(CACHE_PATHS[i])
            local fp, body = splitManifest(raw)
            if fp and body then
                return fp, body, CACHE_PATHS[i]
            end
        end
        return nil, nil, nil
    end

    local function writeCache(body, fp)
        local payload = FP_PREFIX .. tostring(fp) .. "\n" .. body
        for i = 1, #CACHE_PATHS do
            local ok, err = writeBytes(CACHE_PATHS[i], payload)
            if ok then
                log("manifest saved -> " .. CACHE_PATHS[i] .. " (" .. tostring(#body) .. " bytes, fp=" .. tostring(fp) .. ")")
                return true
            end
            log("manifest write skip " .. CACHE_PATHS[i] .. ": " .. tostring(err))
        end
        return false
    end

    local function httpGet(url)
        if type(http) ~= "table" or type(http.Get) ~= "function" then
            return nil, "missing http"
        end
        local body
        local ok, err = pcall(function() body = http.Get(url) end)
        if not ok then return nil, tostring(err) end
        if type(body) == "string" and #body > 0 then return body, nil end
        return nil, "empty"
    end

    local function applyRemoteBody(body)
        if not looksLikeCatalog(body) then
            return false, "invalid catalog body"
        end
        body = body .. ""
        local fp = fingerprint(body)
        local cachedFp, cachedBody, cachedPath = readCacheManifest()

        if cachedFp and cachedFp == fp and cachedBody then
            R.needsAssetSync = false
            R.catalogBody = cachedBody
            if cachedPath ~= CACHE_PATHS[1] and cachedPath ~= CACHE_PATHS[2] then
                if writeCache(cachedBody, fp) then
                    setStatus("up to date (moved to assets/radar)")
                    if R.syncAssets then R.syncAssets(false) end
                    return true, "up to date"
                end
            end
            setStatus("up to date")
            if R.syncAssets then R.syncAssets(false) end
            return true, "up to date"
        end

        local wrote = writeCache(body, fp)
        R.catalogBody = body
        R.needsAssetSync = true
        if not wrote then
            setStatus("updated (cache write failed)")
            return false, "write failed"
        end
        if cachedBody then
            setStatus("updated")
        else
            setStatus("updated (first cache)")
        end
        if R.syncAssets then R.syncAssets(false) end
        return true, "updated"
    end

    local ASSET_BASE = "https://raw.githubusercontent.com/MurkyYT/cs2-map-icons/main/"
    local ASSET_BASE_ALT = "https://cdn.jsdelivr.net/gh/MurkyYT/cs2-map-icons@main/"
    local PER_TICK = 1
    local MISSING_PATHS = {
        "assets/radar/missing.txt",
        "Lua/assets/radar/missing.txt",
    }
    local KNOWN_MISSING = {
        "de_ancient_v1/info",
        "de_sugarcane/info",
        "de_dust/main",
        "de_poseidon/main",
        "cs_shelter/main",
        "de_boulder/main",
        "de_debris/main",
        "de_eldorado/main",
        "de_fachwerk/main",
    }

    local function nowRt()
        local t
        pcall(function() t = globals.RealTime() end)
        if type(t) ~= "number" then pcall(function() t = globals.CurTime() end) end
        return tonumber(t) or 0
    end

    local function isPng(data)
        return type(data) == "string" and #data >= 8
            and data:byte(1) == 0x89
            and data:byte(2) == 0x50
            and data:byte(3) == 0x4E
            and data:byte(4) == 0x47
    end

    local function isRadarInfoTxt(data)
        if type(data) ~= "string" or #data < 8 then return false end
        local low = data:lower()
        return low:find("pos_x", 1, true) ~= nil
            or low:find("pos_y", 1, true) ~= nil
            or low:find("\"scale\"", 1, true) ~= nil
            or low:find("scale", 1, true) ~= nil
    end

    local function assetLocalPaths(map, kind)
        local name
        if kind == "main" then
            name = map .. "_radar_psd.png"
        elseif kind == "lower" then
            name = map .. "_lower_radar_psd.png"
        else
            name = map .. ".txt"
        end
        return {
            "assets/radar/" .. name,
            "Lua/assets/radar/" .. name,
        }
    end

    local function assetRemoteUrl(map, kind, alt)
        local base = alt and ASSET_BASE_ALT or ASSET_BASE
        if kind == "main" then
            return base .. "images/radars/" .. map .. "_radar_psd.png"
        elseif kind == "lower" then
            return base .. "images/radars/" .. map .. "_lower_radar_psd.png"
        end
        return base .. "data/radar_info/" .. map .. ".txt"
    end

    local function assetPresent(map, kind)
        local paths = assetLocalPaths(map, kind)
        for i = 1, #paths do
            local data = fileRead(paths[i])
            if kind == "info" then
                if isRadarInfoTxt(data) then return true end
            else
                if isPng(data) then return true end
            end
        end
        return false
    end

    local function missingKey(map, kind)
        return tostring(map) .. "/" .. tostring(kind)
    end

    local function loadMissing()
        if R.missing then return R.missing end
        local set = {}
        for i = 1, #MISSING_PATHS do
            local raw = fileRead(MISSING_PATHS[i])
            if type(raw) == "string" then
                for line in raw:gmatch("[^\r\n]+") do
                    line = line:gsub("^%s+", ""):gsub("%s+$", "")
                    if line ~= "" and line:sub(1, 1) ~= "#" then
                        set[line] = true
                    end
                end
            end
        end
        R.missing = set
        return set
    end

    local function saveMissing()
        local set = R.missing or {}
        local lines = { "# map/kind assets missing upstream — skip until Sync/force or manifest change" }
        local keys = {}
        for k, _ in pairs(set) do keys[#keys + 1] = k end
        table.sort(keys)
        for i = 1, #keys do lines[#lines + 1] = keys[i] end
        local body = table.concat(lines, "\n") .. "\n"
        for i = 1, #MISSING_PATHS do
            if writeBytes(MISSING_PATHS[i], body) then
                log("missing list saved -> " .. MISSING_PATHS[i] .. " (" .. tostring(#keys) .. ")")
                return true
            end
        end
        return false
    end

    local function clearMissing()
        R.missing = {}
        local body = "# cleared\n"
        for i = 1, #MISSING_PATHS do
            pcall(function() writeBytes(MISSING_PATHS[i], body) end)
        end
    end

    local function isMissing(map, kind)
        local set = loadMissing()
        return set[missingKey(map, kind)] == true
    end

    local function markMissing(map, kind)
        local set = loadMissing()
        local key = missingKey(map, kind)
        if not set[key] then
            set[key] = true
            saveMissing()
            log("marked missing " .. key)
        end
    end

    local function writeAssetFile(path, data, kind)
        if type(data) ~= "string" or data == "" then return false end
        local f
        pcall(function()
            if file and file.Open then f = file.Open(path, "w") end
        end)
        if f then
            local chunk = 8192
            local n = #data
            local failed = false
            for i = 1, n, chunk do
                local piece = data:sub(i, math.min(n, i + chunk - 1))
                local wok = pcall(function() f:Write(piece) end)
                if not wok then failed = true; break end
            end
            pcall(function() f:Close() end)
            if not failed then
                local check = fileRead(path)
                if kind == "info" then
                    if isRadarInfoTxt(check) then return true end
                else
                    if isPng(check) then return true end
                end
            end
        end
        if type(file) == "table" and type(file.Write) == "function" then
            local ok, res = pcall(file.Write, path, data)
            if ok and res ~= false then
                local check = fileRead(path)
                if kind == "info" and isRadarInfoTxt(check) then return true end
                if kind ~= "info" and isPng(check) then return true end
            end
        end
        if fileWrite(path, data) then
            local check = fileRead(path)
            if kind == "info" and isRadarInfoTxt(check) then return true end
            if kind ~= "info" and isPng(check) then return true end
            if type(check) == "string" and #check > 0 then return true end
        end
        return false
    end

    local function listRadarMaps(catalog)
        local maps, byName = {}, {}
        if type(catalog) ~= "string" then return maps end

        local function ensure(map, lower)
            if type(map) ~= "string" or map == "" then return end
            if map:sub(-6) == "_lower" then return end
            local e = byName[map]
            if not e then
                e = { name = map, lower = false }
                byName[map] = e
                maps[#maps + 1] = e
            end
            if lower then e.lower = true end
        end

        for map in catalog:gmatch("images/radars/([%w_]+)_lower_radar_psd%.png") do
            ensure(map, true)
        end
        for map in catalog:gmatch("images/radars/([%w_]+)_radar_psd%.png") do
            ensure(map, false)
        end
        for map in catalog:gmatch("data/radar_info/([%w_]+)%.txt") do
            ensure(map, false)
        end

        log("listRadarMaps: " .. tostring(#maps) .. " maps with radar assets")
        return maps
    end

    function R.syncAssets(forceAll)
        if LiveStatsPos._avatarHttpBusy or LiveStatsPos._skinHttpBusy then
            R.pendingSync = true
            if forceAll then R.pendingForce = true end
            setStatus("assets waiting for avatar/skins…")
            return
        end
        if not LiveStatsPos._steamAvatarSettled then
            R.pendingSync = true
            if forceAll then R.pendingForce = true end
            setStatus("assets waiting for avatar…")
            return
        end
        R.pendingSync = false
        if R.pendingForce then forceAll = true; R.pendingForce = false end

        if R.syncing and R.queue and R.qIndex and R.qIndex <= #R.queue then
            setStatus("assets sync already running…")
            return
        end
        local catalog = R.catalogBody
        if not looksLikeCatalog(catalog) then
            local _, body = readCacheManifest()
            catalog = body
            R.catalogBody = body
        end
        if not looksLikeCatalog(catalog) then
            setStatus("assets: no manifest")
            return
        end
        if type(http) ~= "table" or type(http.Get) ~= "function" then
            setStatus("assets: missing http")
            return
        end
        if forceAll then
            clearMissing()
        end

        local maps = listRadarMaps(catalog)
        local queue = {}
        local skippedMissing = 0
        for i = 1, #maps do
            local m = maps[i]
            local kinds = { "main", "info" }
            if m.lower then kinds[#kinds + 1] = "lower" end
            for k = 1, #kinds do
                local kind = kinds[k]
                if (not forceAll) and isMissing(m.name, kind) then
                    skippedMissing = skippedMissing + 1
                elseif forceAll or not assetPresent(m.name, kind) then
                    queue[#queue + 1] = { map = m.name, kind = kind }
                end
            end
        end

        R.queue = queue
        R.qIndex = 1
        R.okCount = 0
        R.failCount = 0
        R.skipCount = skippedMissing
        R.syncing = true
        R.totalJobs = #queue
        if #queue == 0 then
            R.syncing = false
            R.needsAssetSync = false
            if skippedMissing > 0 then
                setStatus(string.format("assets ready (skipped %d missing)", skippedMissing))
            elseif #maps == 0 then
                setStatus("assets ready (no maps parsed)")
            else
                setStatus("assets ready (nothing to download)")
            end
            return
        end
        setStatus(string.format("assets 0/%d…", #queue))
        log(string.format(
            "asset sync queued %d files across %d maps (force=%s, skipped_missing=%d)",
            #queue, #maps, tostring(forceAll and true or false), skippedMissing
        ))
    end

    local function finishJob(job, ok, detail)
        if ok then
            R.okCount = (R.okCount or 0) + 1
        else
            R.failCount = (R.failCount or 0) + 1
            if detail then log("asset fail " .. job.map .. "/" .. job.kind .. ": " .. tostring(detail)) end
            if detail == "bad download" then
                markMissing(job.map, job.kind)
            end
        end
        local done = (R.qIndex or 1)
        local total = R.totalJobs or 0
        setStatus(string.format("assets %d/%d…", done, total))
    end

    local function jobBodyOk(job, body)
        if job.kind == "info" then return isRadarInfoTxt(body) end
        return isPng(body)
    end

    local function completeJobBody(job, body)
        if not jobBodyOk(job, body) then
            finishJob(job, false, "bad download")
            return
        end
        body = body .. ""
        local paths = assetLocalPaths(job.map, job.kind)
        local saved = false
        for p = 1, #paths do
            if writeAssetFile(paths[p], body, job.kind) then
                saved = true
                break
            end
        end
        finishJob(job, saved, saved and nil or "write failed")
    end

    local function beginJob(job)
        R.httpBusy = true
        local urlPrimary = assetRemoteUrl(job.map, job.kind, false)
        local urlAlt = assetRemoteUrl(job.map, job.kind, true)
        local function onBody(body)
            if jobBodyOk(job, body) then
                completeJobBody(job, body)
                R.httpBusy = false
                return
            end
            local okAlt = pcall(function()
                http.Get(urlAlt, function(body2)
                    completeJobBody(job, body2)
                    R.httpBusy = false
                end)
            end)
            if not okAlt then
                finishJob(job, false, "bad download")
                R.httpBusy = false
            end
        end
        local ok = pcall(function()
            http.Get(urlPrimary, onBody)
        end)
        if not ok then
            finishJob(job, false, "bad download")
            R.httpBusy = false
        end
    end

    function R.tick()
        if LiveStatsPos._avatarHttpBusy or LiveStatsPos._skinHttpBusy then
            return
        end

        if not LiveStatsPos._steamAvatarSettled then
            if not R.bootRt then R.bootRt = nowRt() end
            if (nowRt() - (R.bootRt or 0)) < 8 then
                return
            end
            LiveStatsPos._steamAvatarSettled = true
        end

        if R.pendingCatalog then
            R.pendingCatalog = false
            pcall(function() R.checkCatalog(false) end)
            return
        end

        if R.pendingSync then
            local force = R.pendingForce and true or false
            R.pendingSync = false
            R.pendingForce = false
            pcall(function() R.syncAssets(force) end)
        end

        if not R.syncing or not R.queue then
            return
        end
        local idx = R.qIndex or 1
        if idx > #R.queue then
            R.syncing = false
            R.needsAssetSync = false
            R.httpBusy = false
            setStatus(string.format(
                "assets ready (%d ok, %d fail, %d skipped)",
                R.okCount or 0,
                R.failCount or 0,
                R.skipCount or 0
            ))
            return
        end

        if R.httpBusy or LiveStatsPos._avatarHttpBusy or LiveStatsPos._skinHttpBusy then
            return
        end

        local job = R.queue[idx]
        R.qIndex = idx + 1
        beginJob(job)
    end

    function R.checkCatalog(force)
        if R.fetching then
            setStatus("fetching…")
            return
        end
        if (LiveStatsPos._avatarHttpBusy or LiveStatsPos._skinHttpBusy) and not force then
            R.pendingCatalog = true
            setStatus("waiting for avatar/skins…")
            return
        end
        if not LiveStatsPos._steamAvatarSettled and not force then
            R.pendingCatalog = true
            setStatus("waiting for avatar…")
            return
        end
        if type(http) ~= "table" or type(http.Get) ~= "function" then
            local _, cached = readCacheManifest()
            if cached then
                R.catalogBody = cached
                R.needsAssetSync = false
                setStatus("offline (using cache) — no http")
                if R.syncAssets then R.syncAssets(false) end
            else
                setStatus("failed — missing http")
            end
            return
        end

        R.fetching = true
        setStatus("fetching…")

        local function onCatalog(body, err)
            if looksLikeCatalog(body) then
                applyRemoteBody(body)
                R.fetching = false
                return
            end
            local _, cached = readCacheManifest()
            if cached then
                R.catalogBody = cached
                R.needsAssetSync = false
                setStatus("offline (using cache)")
                if R.syncAssets then R.syncAssets(false) end
            else
                R.lastError = err or "fetch failed"
                setStatus("failed")
            end
            R.fetching = false
        end

        local got = false
        local ok = pcall(function()
            http.Get(CATALOG_URL, function(body)
                if got then return end
                if looksLikeCatalog(body) then
                    got = true
                    onCatalog(body, nil)
                    return
                end
                pcall(function()
                    http.Get(CATALOG_URL_ALT, function(body2)
                        if got then return end
                        got = true
                        onCatalog(body2, "empty")
                    end)
                end)
            end)
        end)
        if not ok then
            R.fetching = false
            onCatalog(nil, "http.Get failed")
        end
    end

    function R.hasCache()
        local _, body = readCacheManifest()
        return body ~= nil
    end
    do
        local set = loadMissing()
        local dirty = false
        for i = 1, #KNOWN_MISSING do
            local k = KNOWN_MISSING[i]
            if not set[k] then
                set[k] = true
                dirty = true
            end
        end
        if dirty then saveMissing() end
        local _, body = readCacheManifest()
        if body then
            R.catalogBody = body
            setStatus("cached (waiting for avatar)")
        else
            setStatus("no cache (waiting for avatar)")
        end
        R.pendingCatalog = true
        R.pendingSync = false
    end

    R.size = R.size or 200
    R.x = R.x or nil
    R.y = R.y or nil
    R.texCache = R.texCache or {}  
    R.infoCache = R.infoCache or {} 

    local COL_LOCAL = { 255, 220, 90 }
    local COL_TEAM = { 90, 170, 255 }
    local COL_ENEMY = { 255, 85, 85 }
    local DOT_R = 3
    local DOT_LOCAL_R = 4

    local function normalizeMapName(raw)
        if type(raw) ~= "string" then return "" end
        local map = raw:gsub("%.bsp$", ""):gsub("%.vpk$", ""):gsub("^maps/", "")
        map = map:gsub("\\", "/"):match("([^/]+)$") or map
        map = map:lower():gsub("^%s+", ""):gsub("%s+$", "")
        if map == "" or map == "<empty>" or map == "unknown" then return "" end
        if map:find("lobby", 1, true) then return "" end
        return map
    end

    local function currentMapName()
        local map
        pcall(function()
            if engine and engine.GetMapName then map = engine.GetMapName() end
        end)
        return normalizeMapName(map)
    end

    local function radarInMatch()
        local map = currentMapName()
        if map == "" then return false, "" end
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        if lp == nil then return false, map end
        return true, map, lp
    end

    local function ensureRadarTex(map, level)
        if type(map) ~= "string" or map == "" then return nil end
        level = (level == "lower") and "lower" or "main"
        local key = map .. "/" .. level

        if R.gpu and R.gpu.key == key and R.gpu.tex then
            return R.gpu
        end

        local missKey = "miss:" .. key
        if R.texCache[missKey] then return nil end

        local paths = assetLocalPaths(map, level)
        local data = nil
        for i = 1, #paths do
            local raw = fileRead(paths[i])
            if isPng(raw) then
                data = raw
                break
            end
        end
        if not data then
            R.texCache[missKey] = true
            return nil
        end

        local rgba, w, h
        local ok = pcall(function()
            if common and common.DecodePNG then
                rgba, w, h = common.DecodePNG(data)
            end
        end)
        if not (ok and rgba and tonumber(w) and tonumber(h) and w > 0 and h > 0) then
            R.texCache[missKey] = true
            log("DecodePNG fail for " .. key)
            return nil
        end

        local tex
        ok = pcall(function()
            tex = draw.CreateTexture(rgba, w, h)
        end)
        if not (ok and tex) then
            R.texCache[missKey] = true
            log("CreateTexture fail for " .. key)
            return nil
        end

        local replacing = R.gpu and R.gpu.tex and R.gpu.key ~= key
        R.gpu = { key = key, tex = tex, w = w, h = h }
        if replacing and LiveStatsPos._steamAvatarSettled then
            LiveStatsPos._forceAvatarRefetch = true
        end
        log("radar tex ready " .. key .. " " .. tostring(w) .. "x" .. tostring(h))
        return R.gpu
    end

    local function parseRadarInfo(text)
        if type(text) ~= "string" or text == "" then return nil end
        local pos_x = tonumber(text:match('"pos_x"%s+"([%-%d%.]+)"'))
        local pos_y = tonumber(text:match('"pos_y"%s+"([%-%d%.]+)"'))
        local scale = tonumber(text:match('"scale"%s+"([%-%d%.]+)"'))
        if not (pos_x and pos_y and scale) or scale == 0 then return nil end
        local info = { pos_x = pos_x, pos_y = pos_y, scale = scale }

        local function sectionBlock(name)
            return text:match('"' .. name .. '"[^{]-%{(.-)%}')
        end

        local lowerBlock = sectionBlock("lower")
        if lowerBlock then
            info.lowerMax = tonumber(lowerBlock:match('"AltitudeMax"%s+"([%-%d%.]+)"'))
            info.lowerMin = tonumber(lowerBlock:match('"AltitudeMin"%s+"([%-%d%.]+)"'))
        end
        local defaultBlock = sectionBlock("default")
        if defaultBlock then
            info.splitZ = tonumber(defaultBlock:match('"AltitudeMin"%s+"([%-%d%.]+)"'))
        end
        if not info.splitZ and info.lowerMax then
            info.splitZ = info.lowerMax
        end
        return info
    end

    local function ensureRadarInfo(map)
        if type(map) ~= "string" or map == "" then return nil end
        local cached = R.infoCache[map]
        if cached == false then return nil end
        if type(cached) == "table" then return cached end

        local paths = assetLocalPaths(map, "info")
        local text = nil
        for i = 1, #paths do
            local raw = fileRead(paths[i])
            if isRadarInfoTxt(raw) then
                text = raw
                break
            end
        end
        local info = parseRadarInfo(text)
        if not info then
            R.infoCache[map] = false
            return nil
        end
        R.infoCache[map] = info
        if info.splitZ or info.lowerMax then
            log(string.format(
                "radar info %s splitZ=%s lowerMax=%s lowerMin=%s",
                map,
                tostring(info.splitZ),
                tostring(info.lowerMax),
                tostring(info.lowerMin)
            ))
        end
        return info
    end

    local function pickFloor(map, z, info)
        if type(z) ~= "number" or not info then
            return "main"
        end
        local onLower = false
        if info.splitZ then
            onLower = z < info.splitZ
        elseif info.lowerMax and info.lowerMin then
            onLower = z <= info.lowerMax and z >= info.lowerMin
        end
        if onLower and ensureRadarTex(map, "lower") then
            return "lower"
        end
        return "main"
    end

    local function worldToMapPx(wx, wy, info)
        local scale = info.scale
        if not scale or scale == 0 then return nil end
        return (wx - info.pos_x) / scale, (info.pos_y - wy) / scale
    end

    local function entOrigin(ent)
        if type(stepOrigin) == "function" then
            local ox, oy, oz = stepOrigin(ent)
            if type(ox) == "number" and type(oy) == "number" then
                return ox, oy, oz
            end
        end
        local ox, oy, oz
        pcall(function()
            local o = ent:GetAbsOrigin()
            if o then
                ox = o.x or o[1]
                oy = o.y or o[2]
                oz = o.z or o[3]
            end
        end)
        if type(ox) == "number" and type(oy) == "number" then
            return ox, oy, oz
        end
        local v
        pcall(function() v = ent:GetPropVector("m_vOldOrigin") end)
        if not v then pcall(function() v = ent:GetPropVector("m_vecAbsOrigin") end) end
        if v then
            return v.x or v[1], v.y or v[2], v.z or v[3]
        end
        return nil
    end

    local function entAlive(ent)
        local alive = false
        pcall(function() alive = ent:IsAlive() end)
        if alive then return true end
        local hp
        pcall(function() hp = ent:GetHealth() end)
        if type(hp) ~= "number" then
            pcall(function() hp = ent:GetPropInt("m_iHealth") end)
        end
        return type(hp) == "number" and hp > 0
    end

    local function entTeam(ent)
        local t
        pcall(function() t = ent:GetTeamNumber() end)
        if type(t) ~= "number" then
            pcall(function() t = ent:GetPropInt("m_iTeamNum") end)
        end
        return tonumber(t)
    end

    local function entYaw(ent)
        local yaw
        pcall(function()
            local a = ent:GetPropVector("m_angEyeAngles")
            if a then yaw = a.y or a[2] end
        end)
        if type(yaw) ~= "number" then
            pcall(function()
                local a = ent:GetPropFloat("m_angEyeAngles[1]")
                if type(a) == "number" then yaw = a end
            end)
        end
        if type(yaw) ~= "number" then
            pcall(function()
                if ent.GetEyeAngles then
                    local v = ent:GetEyeAngles()
                    if type(v) == "number" then
                        yaw = v
                    elseif v then
                        yaw = v.y or v[2]
                    end
                end
            end)
        end
        return tonumber(yaw) or 0
    end

    local function optOn(widget, defaultOn)
        if not (widget and widget.Get) then return defaultOn and true or false end
        return widget:Get() and true or false
    end

    local function readDotRadius()
        local d = 4
        if R.dotSize and R.dotSize.Get then
            d = tonumber(R.dotSize:Get()) or 4
        end
        if d < 2 then d = 2 end
        if d > 12 then d = 12 end
        return d
    end

    local function drawDot(cx, cy, r, col, a)
        cx, cy = tonumber(cx), tonumber(cy)
        r = math.floor((tonumber(r) or 3) + 0.5)
        if not (cx and cy) or r < 1 then return end
        a = tonumber(a) or 255
        local ok = false
        pcall(function()
            draw.Color(col[1], col[2], col[3], a)
            if draw.FilledCircle then
                draw.FilledCircle(math.floor(cx), math.floor(cy), r)
                ok = true
            elseif draw.CircleFilled then
                draw.CircleFilled(math.floor(cx), math.floor(cy), r)
                ok = true
            end
        end)
        if not ok then
            for dy = -r, r do
                local w = math.floor(math.sqrt(math.max(0, r * r - dy * dy)) + 0.5)
                if w > 0 then
                    pcall(function()
                        draw.Color(col[1], col[2], col[3], a)
                        draw.FilledRect(
                            math.floor(cx - w), math.floor(cy + dy),
                            math.floor(cx + w + 1), math.floor(cy + dy + 1)
                        )
                    end)
                end
            end
        end
        pcall(function()
            draw.Color(0, 0, 0, math.floor(a * 0.75))
            if draw.Circle then
                draw.Circle(math.floor(cx), math.floor(cy), r + 1)
            end
        end)
    end

    local function radarMouse()
        if type(veloMouse) == "function" then
            return veloMouse()
        end
        local mx, my, down = 0, 0, false
        pcall(function()
            local x, y = input.GetMousePos()
            if type(x) == "number" and type(y) == "number" then mx, my = x, y end
        end)
        pcall(function() down = input.IsButtonDown(0x01) and true or false end)
        return mx, my, down
    end

    local function readZoom()
        local z = 100
        if R.zoomSlider and R.zoomSlider.Get then
            z = tonumber(R.zoomSlider:Get()) or 100
        end
        if z < 100 then z = 100 end
        if z > 250 then z = 250 end
        return z / 100
    end

    local HANDLE = 14

    local function handleLayout(x, y, size)
        return x + size - HANDLE, y + size - HANDLE, HANDLE, HANDLE
    end

    local function applyDragResize(sw, sh)
        local size = tonumber(R.size) or 200
        if size < 80 then size = 80 end
        if size > 512 then size = 512 end

        local x = tonumber(R.x)
        local y = tonumber(R.y)
        if not x then x = 20 end
        if not y then y = math.floor((sh or 1080) * 0.5 - size * 0.5) end

        local menuOpen = M._open and true or false
        local mx, my, mouseDown = radarMouse()
        local pressed = mouseDown and not R._mouseDown
        R._mouseDown = mouseDown

        if not menuOpen then
            R._drag = nil
            R._resize = nil
        else
            local hx, hy, hw, hh = handleLayout(x, y, size)
            local onHandle = mx >= hx and mx <= hx + hw and my >= hy and my <= hy + hh
            local onBody = mx >= x and mx <= x + size and my >= y and my <= y + size

            if pressed and onHandle then
                R._resize = { ox = mx, oy = my, size = size, x = x, y = y }
                R._drag = nil
            elseif pressed and onBody and not onHandle then
                R._drag = { dx = mx - x, dy = my - y }
                R._resize = nil
            end

            if R._resize then
                if mouseDown then
                    local dx = mx - R._resize.ox
                    local dy = my - R._resize.oy
                    local delta = (dx + dy) * 0.5
                    size = math.floor(R._resize.size + delta + 0.5)
                    if size < 80 then size = 80 end
                    if size > 512 then size = 512 end
                    R.size = size
                else
                    R._resize = nil
                end
            elseif R._drag then
                if mouseDown then
                    x = mx - R._drag.dx
                    y = my - R._drag.dy
                    R.x, R.y = x, y
                else
                    R._drag = nil
                end
            end
        end

        size = tonumber(R.size) or size
        if size < 80 then size = 80 end
        if size > 512 then size = 512 end
        R.size = size

        x = tonumber(R.x) or x
        y = tonumber(R.y) or y
        if x < 0 then x = 0 end
        if y < 0 then y = 0 end
        if x + size > sw then x = math.max(0, sw - size) end
        if y + size > sh then y = math.max(0, sh - size) end
        if menuOpen and (R._drag or R._resize) then
            R.x, R.y = x, y
        end
        return x, y, size, menuOpen
    end

    local function projectPoint(mx, my, ref, mapX, mapY, mapSize)
        local sx = mapX + (mx / ref) * mapSize
        local sy = mapY + (my / ref) * mapSize
        return sx, sy
    end

    local function drawDots(info, texInfo, hudX, hudY, hudSize, mapX, mapY, mapSize, lp, opts)
        if not (info and lp) then return end
        local localTeam = entTeam(lp)
        local localIdx
        pcall(function() localIdx = lp:GetIndex() end)
        local showTeam = opts.showTeam
        local cx = hudX + hudSize * 0.5
        local cy = hudY + hudSize * 0.5
        local rad = opts.dotR or 4
        local circle = opts.circle
        local rClip = hudSize * 0.5 - 2
        local rClip2 = rClip * rClip
        local refW = (texInfo and texInfo.w) or 1024

        local list
        pcall(function() list = entities.FindByClass("C_CSPlayerPawn") end)
        if not list then return end

        for i = 1, #list do
            local pawn = list[i]
            if pawn and entAlive(pawn) then
                local team = entTeam(pawn)
                if type(team) == "number" and team > 1 then
                    local idx
                    pcall(function() idx = pawn:GetIndex() end)
                    local isLocal = localIdx and idx and localIdx == idx
                    local isTeam = localTeam and team == localTeam
                    if isLocal or (isTeam and showTeam) or (not isTeam) then
                        local wx, wy = entOrigin(pawn)
                        if wx and wy then
                            local mx, my = worldToMapPx(wx, wy, info)
                            if mx and my then
                                local sx, sy = projectPoint(mx, my, refW, mapX, mapY, mapSize)
                                local onHud = sx >= hudX - 2 and sy >= hudY - 2
                                    and sx <= hudX + hudSize + 2 and sy <= hudY + hudSize + 2
                                if circle and onHud then
                                    local dx, dy = sx - cx, sy - cy
                                    onHud = (dx * dx + dy * dy) <= rClip2
                                end
                                if onHud then
                                    local col = COL_ENEMY
                                    if isLocal then
                                        col = COL_LOCAL
                                    elseif isTeam then
                                        col = COL_TEAM
                                    end
                                    local rr = isLocal and (rad + 1) or rad
                                    drawDot(sx, sy, rr, col, 245)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    function R.draw()
        if not (R.enabled and R.enabled.Get and R.enabled:Get()) then
            return
        end
        local okMatch, map, lp = radarInMatch()
        if not okMatch then return end

        local mapInfo = ensureRadarInfo(map)
        if not mapInfo then return end
        local lwx, lwy, lz = entOrigin(lp)
        local floor = pickFloor(map, lz, mapInfo)
        local texInfo = ensureRadarTex(map, floor)
        if not (texInfo and texInfo.tex) then
            if floor == "lower" then
                texInfo = ensureRadarTex(map, "main")
            end
        end
        if not (texInfo and texInfo.tex) then
            return
        end

        local sw, sh = 1920, 1080
        pcall(function() sw, sh = draw.GetScreenSize() end)
        sw, sh = tonumber(sw) or 1920, tonumber(sh) or 1080

        local x, y, size, menuOpen = applyDragResize(sw, sh)
        local zoom = readZoom()
        local follow = optOn(R.follow, true)
        local circle = optOn(R.circleMap, false)
        local showTeam = optOn(R.showTeam, true)
        local dotR = readDotRadius()

        local refW = texInfo.w or 1024
        local mapSize = size * zoom
        local cx = x + size * 0.5
        local cy = y + size * 0.5
        local mapX, mapY
        if follow and lwx and lwy then
            local lmx, lmy = worldToMapPx(lwx, lwy, mapInfo)
            if lmx and lmy then
                mapX = cx - (lmx / refW) * mapSize
                mapY = cy - (lmy / refW) * mapSize
            end
        end
        if not mapX then
            mapX = x - (mapSize - size) * 0.5
            mapY = y - (mapSize - size) * 0.5
        end

        local hidePanel = optOn(R.hidePanel, true)
        local rad = size * 0.5 - 1
        if not hidePanel then
            pcall(function()
                draw.Color(8, 10, 14, 200)
                if circle then
                    if draw.FilledCircle then
                        draw.FilledCircle(math.floor(cx), math.floor(cy), math.floor(rad))
                    elseif draw.CircleFilled then
                        draw.CircleFilled(math.floor(cx), math.floor(cy), math.floor(rad))
                    else
                        local r2 = rad * rad
                        for row = 0, size - 1 do
                            local dy = (row + 0.5) - (size * 0.5)
                            local dy2 = dy * dy
                            if dy2 <= r2 then
                                local half = math.sqrt(r2 - dy2)
                                draw.FilledRect(
                                    math.floor(cx - half),
                                    math.floor(y + row),
                                    math.floor(cx + half + 1),
                                    math.floor(y + row + 1)
                                )
                            end
                        end
                    end
                else
                    draw.FilledRect(math.floor(x - 2), math.floor(y - 2), math.floor(x + size + 2), math.floor(y + size + 2))
                end
            end)
        end

        do
            pcall(function()
                draw.Color(255, 255, 255, 235)
                draw.SetTexture(texInfo.tex)
                local mx0 = math.floor(mapX)
                local my0 = math.floor(mapY)
                local mx1 = math.floor(mapX + mapSize)
                local my1 = math.floor(mapY + mapSize)
                if circle then
                    local r2 = rad * rad
                    for row = 0, size - 1 do
                        local dy = (row + 0.5) - (size * 0.5)
                        local dy2 = dy * dy
                        if dy2 <= r2 then
                            local half = math.sqrt(r2 - dy2)
                            local left = cx - half
                            local right = cx + half
                            local rw = right - left
                            if rw >= 1 then
                                draw.SetScissorRect(math.floor(left), math.floor(y + row), math.floor(rw), 1)
                                draw.FilledRect(mx0, my0, mx1, my1)
                            end
                        end
                    end
                else
                    draw.SetScissorRect(math.floor(x), math.floor(y), math.floor(size), math.floor(size))
                    draw.FilledRect(mx0, my0, mx1, my1)
                end
                draw.SetTexture(nil)
            end)
            pcall(function()
                draw.SetScissorRect(0, 0, math.floor(sw), math.floor(sh))
            end)
            pcall(function() draw.SetTexture(nil) end)
        end

        if optOn(R.gridlines, true) then
            pcall(function()
                draw.Color(0, 0, 0, 170)
                local midX = math.floor(cx)
                local midY = math.floor(cy)
                local x0, x1, y0, y1
                if circle then
                    x0, x1 = math.floor(cx - rad), math.floor(cx + rad)
                    y0, y1 = math.floor(cy - rad), math.floor(cy + rad)
                else
                    x0, x1 = math.floor(x), math.floor(x + size)
                    y0, y1 = math.floor(y), math.floor(y + size)
                end
                if draw.Line then
                    draw.Line(x0, midY, x1, midY)
                    draw.Line(midX, y0, midX, y1)
                else
                    draw.FilledRect(x0, midY, x1, midY + 1)
                    draw.FilledRect(midX, y0, midX + 1, y1)
                end
            end)
        end

        if not hidePanel then
            if circle then
                pcall(function()
                    draw.Color(255, 255, 255, 70)
                    if draw.Circle then
                        draw.Circle(math.floor(cx), math.floor(cy), math.floor(rad))
                    end
                end)
            else
                local borderA = (R._drag or R._resize) and 200 or (menuOpen and 90) or 40
                pcall(function()
                    draw.Color(255, 255, 255, borderA)
                    draw.OutlinedRect(math.floor(x), math.floor(y), math.floor(x + size), math.floor(y + size))
                end)
            end
        end

        drawDots(mapInfo, texInfo, x, y, size, mapX, mapY, mapSize, lp, {
            showTeam = showTeam,
            dotR = dotR,
            circle = circle,
        })

        if menuOpen then
            local hx, hy, hw, hh = handleLayout(x, y, size)
            local ha = R._resize and 220 or 120
            pcall(function()
                draw.Color(255, 255, 255, ha)
                draw.FilledRect(math.floor(hx), math.floor(hy), math.floor(hx + hw), math.floor(hy + hh))
                draw.Color(20, 22, 28, 200)
                draw.OutlinedRect(math.floor(hx), math.floor(hy), math.floor(hx + hw), math.floor(hy + hh))
            end)
        end
    end
end)(LiveStatsPos.RadarHud)

local liveStatsDraw, liveStatsEventId
liveStatsDraw, LiveStatsReset, liveStatsEventId = (function()
    local EVENT_ID = "daizml_ls_" .. (tostring({}):gsub("%W", "")):sub(-8)
    local LISTEN = {
        "player_death",
        "player_hurt",
        "round_start",
        "bomb_planted",
        "bomb_defused",
        "player_sound",
    }

    local S = {
        kills = 0,
        deaths = 0,
        assists = 0,
        headshots = 0,
        damage = 0,
        utilDamage = 0,
        armorDamage = 0,
        enemiesFlashed = 0,
        ace = 0,
        quad = 0,
        triple = 0,
        knifeKills = 0,
        taserKills = 0,
        liveTime = 0,
        objective = 0,
        mvps = 0,
        roundKills = 0,
        roundDamage = 0,
        score = 0,
        rounds = 0,
        adr = 0,
        events = 0,
        lastEvent = "—",
        lastWeapon = "—",
        lastDetail = "—",
        map = nil,
        localUid = nil,
        localCtrl = nil,
        listenersOk = false,
        registerOk = false,
        mode = "waiting",
        fieldKills = "—",
        fieldHS = "—",
        fieldDmg = "—",
        fieldAts = "—",
        fieldMatch = "—",
        rawAttacker = "—",
        rawVictim = "—",
    }

    local Poll = {
        seeded = false,
        roundKills = 0,
        roundHS = 0,
        roundDmg = 0,
        alive = true,
        allowNext = 0,
    }

    local RoundTrack = {
        seeded = false,
        completed = 0,
        prevRK = 0,
        prevRD = 0,
    }

    local Spark = { buf = {}, head = 0, count = 0, max = 20 }

    local EnemyDeath = { state = {}, session = 0 }

    local UTIL = {
        hegrenade = true,
        flashbang = true,
        smokegrenade = true,
        molotov = true,
        inferno = true,
        incgrenade = true,
        decoy = true,
    }

    local UI = {
        fonts = false,
        fTitle = nil,
        fName = nil,
        fElo = nil,
        fMetric = nil,
        fLabel = nil,
        fBanVal = nil,
        fBanLab = nil,
        fBody = nil,
        _mouseDown = false,
        _drag = nil,
    }

    local Avatar = {
        steam64 = nil,
        tex = nil,
        tw = 0,
        th = 0,
        status = "idle", 
        nextTry = 0,
        detail = nil,
        tick = 0,
        reqId = 0,
        pendingFrame = 0,
        pendingSince = 0,
        imgUrl = nil,
        failCount = 0,
    }

    local Banner = {
        page = 0,
        holdLeft = 4.0,
        fadeFrom = nil,
        fadeT = nil,
        lastNow = nil,
    }
    local BANNER_HOLD = 4.0
    local BANNER_FADE = 0.32
    local BANNER_PAGES = 4

    local function reset(reason)
        S.kills = 0
        S.deaths = 0
        S.assists = 0
        S.headshots = 0
        S.damage = 0
        S.utilDamage = 0
        S.armorDamage = 0
        S.enemiesFlashed = 0
        S.ace = 0
        S.quad = 0
        S.triple = 0
        S.knifeKills = 0
        S.taserKills = 0
        S.liveTime = 0
        S.objective = 0
        S.mvps = 0
        S.roundKills = 0
        S.roundDamage = 0
        S.score = 0
        S.rounds = 0
        S.adr = 0
        S.events = 0
        S.lastEvent = reason and ("reset:" .. tostring(reason)) or "reset"
        S.lastWeapon = "—"
        S.lastDetail = "—"
        S.mode = "waiting"
        S.rawAttacker = "—"
        S.rawVictim = "—"
        Poll.seeded = false
        RoundTrack.seeded = false
        RoundTrack.completed = 0
        RoundTrack.prevRK = 0
        RoundTrack.prevRD = 0
        Spark.buf = {}
        Spark.head = 0
        Spark.count = 0
        EnemyDeath.state = {}
        EnemyDeath.session = 0
        Banner.page = 0
        Banner.holdLeft = BANNER_HOLD
        Banner.fadeFrom = nil
        Banner.fadeT = nil
        Banner.lastNow = nil
    end

    local function mapName()
        local map
        pcall(function()
            if engine and engine.GetMapName then map = engine.GetMapName() end
        end)
        if type(map) ~= "string" or map == "" then return nil end
        map = map:gsub("%.bsp$", ""):gsub("%.vpk$", ""):lower()
        map = map:gsub("^maps/", "")
        return map
    end

    local function allowListeners()
        local okAll = true
        for i = 1, #LISTEN do
            local ok = pcall(function() client.AllowListener(LISTEN[i]) end)
            if not ok then okAll = false end
        end
        S.listenersOk = okAll
        return okAll
    end

    local function localController()
        local ctrl
        pcall(function()
            if entities.GetLocalPlayerController then
                ctrl = entities.GetLocalPlayerController()
            end
        end)
        if ctrl then return ctrl end
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        if not lp then return nil end
        pcall(function() ctrl = lp:GetFieldEntity("m_hController") end)
        if not ctrl then pcall(function() ctrl = lp:GetPropEntity("m_hController") end) end
        return ctrl
    end

    local function entIndex(e)
        if not e then return nil end
        local idx
        pcall(function() idx = e:GetIndex() end)
        return type(idx) == "number" and idx or nil
    end

    local function entClass(e)
        if not e then return nil end
        local cls
        pcall(function() cls = e:GetClass() end)
        return cls
    end

    local function controllerFromEventId(raw)
        if type(raw) ~= "number" then return nil end
        local candidates = { raw + 1, raw, raw - 1 }
        for i = 1, #candidates do
            local ent
            pcall(function() ent = entities.GetByIndex(candidates[i]) end)
            if ent and entClass(ent) == "CCSPlayerController" then
                return ent
            end
        end
        local ent
        pcall(function() ent = entities.GetByUserID(raw) end)
        if ent then
            local cls = entClass(ent)
            if cls == "CCSPlayerController" then return ent end
            if cls and tostring(cls):find("Pawn", 1, true) then
                local ctrl
                pcall(function() ctrl = ent:GetFieldEntity("m_hController") end)
                if not ctrl then pcall(function() ctrl = ent:GetPropEntity("m_hController") end) end
                if ctrl then return ctrl end
            end
        end
        return nil
    end

    local function isLocalEventId(raw)
        if type(raw) ~= "number" then return false end
        local me = localController()
        local meIdx = entIndex(me)
        S.localCtrl = meIdx
        if meIdx then
            if raw == meIdx or raw + 1 == meIdx or raw == meIdx - 1 then
                return true
            end
        end
        local ctrl = controllerFromEventId(raw)
        if ctrl and me and entIndex(ctrl) == meIdx then
            return true
        end
        local pidx, localIdx
        pcall(function() pidx = client.GetPlayerIndexByUserID(raw) end)
        pcall(function() localIdx = client.GetLocalPlayerIndex() end)
        if type(pidx) == "number" and type(localIdx) == "number" and pidx == localIdx then
            return true
        end
        return false
    end

    local function refreshLocalIds()
        local me = localController()
        S.localCtrl = entIndex(me)
        local idx
        pcall(function() idx = client.GetLocalPlayerIndex() end)
        if type(idx) ~= "number" then return end
        local info
        pcall(function() info = client.GetPlayerInfo(idx) end)
        if type(info) ~= "table" then return end
        local uid = info.UserID or info.userid or info.userId or info.UserId
        uid = tonumber(uid) or uid
        if type(uid) == "number" then S.localUid = uid end
    end

    local function evInt(ev, key)
        local v
        pcall(function() v = ev:GetInt(key) end)
        return tonumber(v)
    end

    local function evFloat(ev, key)
        local v
        pcall(function() v = ev:GetFloat(key) end)
        return tonumber(v)
    end

    local function evStr(ev, key)
        local v
        pcall(function() v = ev:GetString(key) end)
        if type(v) == "string" and v ~= "" then return v end
        return nil
    end

    local function isUtil(weapon)
        if type(weapon) ~= "string" then return false end
        local w = weapon:lower()
        if UTIL[w] then return true end
        if w:find("hegrenade", 1, true) or w:find("flashbang", 1, true)
            or w:find("smoke", 1, true) or w:find("molotov", 1, true)
            or w:find("inferno", 1, true) or w:find("incgrenade", 1, true)
            or w:find("decoy", 1, true) then
            return true
        end
        return false
    end

    local FfiStats = {
        ready = false,
        status = "init",
        clientBase = nil,
        dwLPC = nil,
        offAts = 0x820,      
        offMatch = 0xA8,      
        offRoundKills = 0x128,
        offRoundHS = 0x12C,
        offRoundDmg = 0x130,
        offKills = 0x30,     
        offDeaths = 0x34,
        offAssists = 0x38,
        offDamage = 0x3C,
        offHS = 0x50,
        offLiveTime = 0x4C,
        offObjective = 0x54,
        offCash = 0x58,
        offUtil = 0x5C,
        offFlash = 0x60,
        off5k = 0x68,         
        off4k = 0x6C,
        off3k = 0x70,
        offKnife = 0x74,
        offTaser = 0x78,
        offMvps = 0x958,      
        offSteam = 1920,      
        offRankType = 2192,   
        offRanking = 2184,    
        offRankWin = 2196,   
        offRankLoss = 2200,   
        offRankTie = 2204,  
        nextFetch = 0,
    }

    local function ffiValid(p)
        return type(p) == "number" and p > 0x10000 and p < 0x7FFFFFFFFFFF
    end

    local function ffiRPtr(a)
        local v
        pcall(function() v = tonumber(ffi.cast("uintptr_t*", a)[0]) end)
        return ffiValid(v) and v or nil
    end

    local function ffiRI32(a)
        local v
        pcall(function() v = ffi.cast("int32_t*", a)[0] end)
        return type(v) == "number" and v or nil
    end

    local function ffiRF32(a)
        local v
        pcall(function() v = ffi.cast("float*", a)[0] end)
        return type(v) == "number" and v or nil
    end

    local function ffiPullOffset(json, name, afterClass)
        if type(json) ~= "string" then return nil end
        local hay = json
        if afterClass then
            local s, e = json:find('"' .. afterClass .. '"%s*:%s*{')
            if not s then return nil end
            local depth, i, n = 1, e + 1, #json
            while i <= n and depth > 0 do
                local c = json:sub(i, i)
                if c == "{" then depth = depth + 1
                elseif c == "}" then depth = depth - 1 end
                i = i + 1
            end
            hay = json:sub(e, i - 1)
        end
        local v = hay:match('"' .. name .. '"%s*:%s*(%d+)')
        v = v and tonumber(v) or nil
        if v and (v < 0 or v > 0x20000) then return nil end
        return v
    end

    local function ffiSigRva(modBase, mod, pattern, instrLen)
        if not modBase or type(mem) ~= "table" or not mem.FindPattern then return nil end
        local a
        pcall(function() a = mem.FindPattern(mod, pattern) end)
        if not a or a == 0 then return nil end
        a = tonumber(a)
        local rel
        pcall(function() rel = ffi.cast("int32_t*", a + 3)[0] end)
        if type(rel) ~= "number" then return nil end
        return (a + instrLen + rel) - modBase
    end

    local function ffiEnsure()
        if FfiStats.ready and FfiStats.clientBase and FfiStats.dwLPC then
            return true
        end
        if type(ffi) ~= "table" or type(mem) ~= "table" then
            FfiStats.status = "no-ffi"
            return false
        end

        local base
        pcall(function() base = tonumber(mem.GetModuleBase("client.dll")) end)
        if not ffiValid(base) then
            FfiStats.status = "no-client"
            return false
        end
        FfiStats.clientBase = base

        local dw = FfiStats.dwLPC
        if not dw then
            dw = ffiSigRva(base, "client.dll", "48 8B 05 ?? ?? ?? ?? 41 89 BE", 7)
        end
        if not dw and type(http) == "table" and http.Get then
            local json
            pcall(function()
                json = http.Get("https://raw.githubusercontent.com/a2x/cs2-dumper/main/output/offsets.json")
            end)
            if type(json) == "string" then
                dw = ffiPullOffset(json, "dwLocalPlayerController") or dw
            end
        end
        if not dw then
            FfiStats.status = "no-lpc"
            return false
        end
        FfiStats.dwLPC = dw

        local now
        pcall(function() now = globals.RealTime() end)
        now = type(now) == "number" and now or 0
        if now >= (FfiStats.nextFetch or 0) and type(http) == "table" and http.Get then
            FfiStats.nextFetch = now + 300
            local json
            pcall(function()
                json = http.Get("https://raw.githubusercontent.com/a2x/cs2-dumper/main/output/client_dll.json")
            end)
            if type(json) == "string" and #json > 1000 then
                local v
                v = ffiPullOffset(json, "m_pActionTrackingServices", "CCSPlayerController")
                if v then FfiStats.offAts = v end
                v = ffiPullOffset(json, "m_matchStats", "CCSPlayerController_ActionTrackingServices")
                if v then FfiStats.offMatch = v end
                v = ffiPullOffset(json, "m_iNumRoundKills", "CCSPlayerController_ActionTrackingServices")
                if v then FfiStats.offRoundKills = v end
                v = ffiPullOffset(json, "m_iNumRoundKillsHeadshots", "CCSPlayerController_ActionTrackingServices")
                if v then FfiStats.offRoundHS = v end
                v = ffiPullOffset(json, "m_flTotalRoundDamageDealt", "CCSPlayerController_ActionTrackingServices")
                if v then FfiStats.offRoundDmg = v end
                v = ffiPullOffset(json, "m_iKills", "CSPerRoundStats_t")
                if v then FfiStats.offKills = v end
                v = ffiPullOffset(json, "m_iDeaths", "CSPerRoundStats_t")
                if v then FfiStats.offDeaths = v end
                v = ffiPullOffset(json, "m_iAssists", "CSPerRoundStats_t")
                if v then FfiStats.offAssists = v end
                v = ffiPullOffset(json, "m_iDamage", "CSPerRoundStats_t")
                if v then FfiStats.offDamage = v end
                v = ffiPullOffset(json, "m_iHeadShotKills", "CSPerRoundStats_t")
                if v then FfiStats.offHS = v end
                v = ffiPullOffset(json, "m_iLiveTime", "CSPerRoundStats_t")
                if v then FfiStats.offLiveTime = v end
                v = ffiPullOffset(json, "m_iObjective", "CSPerRoundStats_t")
                if v then FfiStats.offObjective = v end
                v = ffiPullOffset(json, "m_iCashEarned", "CSPerRoundStats_t")
                if v then FfiStats.offCash = v end
                v = ffiPullOffset(json, "m_iUtilityDamage", "CSPerRoundStats_t")
                if v then FfiStats.offUtil = v end
                v = ffiPullOffset(json, "m_iEnemiesFlashed", "CSPerRoundStats_t")
                if v then FfiStats.offFlash = v end
                v = ffiPullOffset(json, "m_iEnemy5Ks", "CSMatchStats_t")
                if v then FfiStats.off5k = v end
                v = ffiPullOffset(json, "m_iEnemy4Ks", "CSMatchStats_t")
                if v then FfiStats.off4k = v end
                v = ffiPullOffset(json, "m_iEnemy3Ks", "CSMatchStats_t")
                if v then FfiStats.off3k = v end
                v = ffiPullOffset(json, "m_iEnemyKnifeKills", "CSMatchStats_t")
                if v then FfiStats.offKnife = v end
                v = ffiPullOffset(json, "m_iEnemyTaserKills", "CSMatchStats_t")
                if v then FfiStats.offTaser = v end
                v = ffiPullOffset(json, "m_iMVPs", "CCSPlayerController")
                if v then FfiStats.offMvps = v end
                v = ffiPullOffset(json, "m_steamID", "CBasePlayerController")
                if v then FfiStats.offSteam = v end
                v = ffiPullOffset(json, "m_iCompetitiveRankType", "CCSPlayerController")
                if v then FfiStats.offRankType = v end
                v = ffiPullOffset(json, "m_iCompetitiveRanking", "CCSPlayerController")
                if v then FfiStats.offRanking = v end
                v = ffiPullOffset(json, "m_iCompetitiveRankingPredicted_Win", "CCSPlayerController")
                if v then FfiStats.offRankWin = v end
                v = ffiPullOffset(json, "m_iCompetitiveRankingPredicted_Loss", "CCSPlayerController")
                if v then FfiStats.offRankLoss = v end
                v = ffiPullOffset(json, "m_iCompetitiveRankingPredicted_Tie", "CCSPlayerController")
                if v then FfiStats.offRankTie = v end
            end
        end

        FfiStats.ready = true
        FfiStats.status = string.format("ok ats=0x%X match=0x%X", FfiStats.offAts, FfiStats.offMatch)
        return true
    end

    local function ffiReadPremier()
        if not ffiEnsure() then return nil end
        local ctrl = ffiRPtr(FfiStats.clientBase + FfiStats.dwLPC)
        if not ctrl then return nil end
        local rankType = ffiRI32(ctrl + FfiStats.offRankType)
        if rankType ~= 11 then return nil end
        local elo = ffiRI32(ctrl + FfiStats.offRanking) or 0
        if elo <= 0 then return nil end
        local winPred = ffiRI32(ctrl + FfiStats.offRankWin) or 0
        local lossPred = ffiRI32(ctrl + FfiStats.offRankLoss) or 0
        local winDelta = winPred - elo
        local lossDelta = lossPred - elo
        if winDelta == 0 and lossDelta == 0 then return nil end
        return {
            elo = elo,
            win = winDelta,
            loss = lossDelta,
        }
    end

    local function ffiReadLocalAccountId()
        if not ffiEnsure() then return 0 end
        local ctrl = ffiRPtr(FfiStats.clientBase + FfiStats.dwLPC)
        if not ctrl then return 0 end
        local steamOff = FfiStats.offSteam
        if type(off) == "table" and type(off.m_steamID) == "number" and off.m_steamID > 0 then
            steamOff = off.m_steamID
        end
        local lo, hi = 0, 0
        pcall(function()
            lo = tonumber(ffi.cast("uint32_t*", ctrl + steamOff)[0]) or 0
            hi = tonumber(ffi.cast("uint32_t*", ctrl + steamOff + 4)[0]) or 0
        end)
        if lo > 0 and (hi == 0x01100001 or hi == 0) then
            return lo
        end
        return 0
    end

    local function ffiReadMatchStats()
        if not ffiEnsure() then return nil end
        local ctrl = ffiRPtr(FfiStats.clientBase + FfiStats.dwLPC)
        if not ctrl then
            FfiStats.status = "lpc-nil"
            return nil
        end
        local ats = ffiRPtr(ctrl + FfiStats.offAts)
        if not ats then
            FfiStats.status = "ats-nil"
            return nil
        end
        local match = ats + FfiStats.offMatch
        local out = {
            kills = ffiRI32(match + FfiStats.offKills),
            deaths = ffiRI32(match + FfiStats.offDeaths),
            assists = ffiRI32(match + FfiStats.offAssists),
            damage = ffiRI32(match + FfiStats.offDamage),
            headshots = ffiRI32(match + FfiStats.offHS),
            liveTime = ffiRI32(match + FfiStats.offLiveTime),
            objective = ffiRI32(match + FfiStats.offObjective),
            cashEarned = ffiRI32(match + FfiStats.offCash),
            utilDamage = ffiRI32(match + FfiStats.offUtil),
            enemiesFlashed = ffiRI32(match + FfiStats.offFlash),
            ace = ffiRI32(match + FfiStats.off5k),
            quad = ffiRI32(match + FfiStats.off4k),
            triple = ffiRI32(match + FfiStats.off3k),
            knifeKills = ffiRI32(match + FfiStats.offKnife),
            taserKills = ffiRI32(match + FfiStats.offTaser),
            roundKills = ffiRI32(ats + FfiStats.offRoundKills),
            roundHS = ffiRI32(ats + FfiStats.offRoundHS),
            roundDamage = ffiRF32(ats + FfiStats.offRoundDmg),
            mvps = ffiRI32(ctrl + FfiStats.offMvps),
        }
        FfiStats.status = string.format("ffi ats=0x%X", ats)
        return out
    end

    local function readInt(e, ...)
        if not e then return nil end
        local path = { ... }
        if #path == 0 then return nil end
        local v
        pcall(function() v = e:GetFieldInt(unpack(path)) end)
        if type(v) ~= "number" then
            pcall(function() v = e:GetPropInt(unpack(path)) end)
        end
        if type(v) ~= "number" and #path == 1 then
            pcall(function() v = e:GetField(path[1]) end)
            if type(v) ~= "number" then pcall(function() v = e:GetProp(path[1]) end) end
        end
        return type(v) == "number" and v or nil
    end

    local function readFloat(e, ...)
        if not e then return nil end
        local path = { ... }
        if #path == 0 then return nil end
        local v
        pcall(function() v = e:GetFieldFloat(unpack(path)) end)
        if type(v) ~= "number" then
            pcall(function() v = e:GetPropFloat(unpack(path)) end)
        end
        if type(v) ~= "number" then
            v = readInt(e, unpack(path))
        end
        return type(v) == "number" and v or nil
    end

    local function pawnAlive(pawn)
        if not pawn then return false end
        local alive = false
        pcall(function() alive = pawn:IsAlive() end)
        if alive then return true end
        local hp
        pcall(function() hp = pawn:GetHealth() end)
        if type(hp) ~= "number" then hp = readInt(pawn, "m_iHealth") end
        return type(hp) == "number" and hp > 0
    end

    local function resolveATS(ctrl)
        if not ctrl then return nil, "no-ctrl" end
        local ats
        pcall(function() ats = ctrl:GetFieldEntity("m_pActionTrackingServices") end)
        if ats == nil then pcall(function() ats = ctrl:GetPropEntity("m_pActionTrackingServices") end) end
        if ats ~= nil and type(ats) ~= "number" and type(ats) ~= "boolean" then
            return ats, (entClass(ats) or type(ats)) .. "@m_pActionTrackingServices"
        end
        return nil, "ats-nil"
    end

    local function sparkPush(v)
        v = tonumber(v) or 0
        if v < 0 then v = 0 end
        Spark.head = Spark.head % Spark.max + 1
        Spark.buf[Spark.head] = v
        if Spark.count < Spark.max then Spark.count = Spark.count + 1 end
    end

    local function updateRoundTrack(lp, ffiStats)
        local rk = tonumber(ffiStats.roundKills) or 0
        local rd = tonumber(ffiStats.roundDamage) or 0
        if type(rd) == "number" then rd = math.floor(rd + 0.5) end

        if not RoundTrack.seeded then
            RoundTrack.seeded = true
            RoundTrack.prevRK = rk
            RoundTrack.prevRD = rd
        else
            local resetRound = (rk < RoundTrack.prevRK)
                or (RoundTrack.prevRD > 10 and rd + 5 < RoundTrack.prevRD)
            if resetRound then
                sparkPush(RoundTrack.prevRD)
                RoundTrack.completed = RoundTrack.completed + 1
            end
            RoundTrack.prevRK = rk
            RoundTrack.prevRD = rd
        end

        S.rounds = math.max(1, RoundTrack.completed)
        S.adr = (S.damage or 0) / S.rounds
    end

    local function pollEnemyDeaths(lp)
        if not lp then
            S.fieldMatch = tostring(S.fieldMatch or "n/a") .. " enemyD=" .. tostring(EnemyDeath.session)
            return
        end
        local list
        pcall(function() list = entities.FindByClass("C_CSPlayerPawn") end)
        if type(list) ~= "table" then
            S.fieldMatch = tostring(S.fieldMatch or "n/a") .. " enemyD=" .. tostring(EnemyDeath.session) .. " pawns=nil"
            return
        end
        local seen, pawnN = {}, 0
        for i = 1, #list do
            local pawn = list[i]
            if pawn then
                local idx = entIndex(pawn)
                local isLocal = false
                pcall(function()
                    if lp.GetIndex and pawn.GetIndex and lp:GetIndex() == pawn:GetIndex() then
                        isLocal = true
                    end
                end)
                if idx and not isLocal then
                    pawnN = pawnN + 1
                    seen[idx] = true
                    local alive = pawnAlive(pawn)
                    local st = EnemyDeath.state[idx]
                    if st == nil then
                        EnemyDeath.state[idx] = alive
                    elseif st and not alive then
                        EnemyDeath.state[idx] = false
                        EnemyDeath.session = EnemyDeath.session + 1
                    elseif alive then
                        EnemyDeath.state[idx] = true
                    end
                end
            end
        end
        for k in pairs(EnemyDeath.state) do
            if not seen[k] then EnemyDeath.state[k] = nil end
        end
        S.fieldMatch = string.format("%s enemyD=%d pawns=%d",
            tostring(S.fieldMatch or "n/a"), EnemyDeath.session, pawnN)
    end

    local function pollFields()
        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        local ctrl = localController()
        refreshLocalIds()

        local ats, atsTag = resolveATS(ctrl)
        S.fieldAts = atsTag or "—"

        local score = nil
        local ffiStats = ffiReadMatchStats()
        if ffiStats then
            S.mode = "ffi"
            if ffiStats.kills ~= nil then S.kills = ffiStats.kills end
            if ffiStats.deaths ~= nil then S.deaths = ffiStats.deaths end
            if ffiStats.assists ~= nil then S.assists = ffiStats.assists end
            if ffiStats.headshots ~= nil then S.headshots = ffiStats.headshots end
            if ffiStats.damage ~= nil then S.damage = ffiStats.damage end
            if ffiStats.utilDamage ~= nil then S.utilDamage = ffiStats.utilDamage end
            if ffiStats.enemiesFlashed ~= nil then S.enemiesFlashed = ffiStats.enemiesFlashed end
            if ffiStats.ace ~= nil then S.ace = ffiStats.ace end
            if ffiStats.quad ~= nil then S.quad = ffiStats.quad end
            if ffiStats.triple ~= nil then S.triple = ffiStats.triple end
            if ffiStats.knifeKills ~= nil then S.knifeKills = ffiStats.knifeKills end
            if ffiStats.taserKills ~= nil then S.taserKills = ffiStats.taserKills end
            if ffiStats.liveTime ~= nil then S.liveTime = ffiStats.liveTime end
            if ffiStats.objective ~= nil then S.objective = ffiStats.objective end
            if ffiStats.mvps ~= nil then S.mvps = ffiStats.mvps end
            if ffiStats.roundKills ~= nil then S.roundKills = ffiStats.roundKills end
            if ffiStats.roundDamage ~= nil then S.roundDamage = math.floor(ffiStats.roundDamage + 0.5) end
            S.score = score
            updateRoundTrack(lp, ffiStats)

            S.fieldKills = tostring(ffiStats.roundKills or ffiStats.kills or "?")
            S.fieldHS = tostring(ffiStats.roundHS or ffiStats.headshots or "?")
            S.fieldDmg = tostring(ffiStats.roundDamage and math.floor(ffiStats.roundDamage + 0.5) or ffiStats.damage or "?")
            S.fieldMatch = string.format("K%d/D%d/A%d HS%d dmg%d util%d flash%d sc%s",
                ffiStats.kills or -1, ffiStats.deaths or -1, ffiStats.assists or -1,
                ffiStats.headshots or -1, ffiStats.damage or -1,
                ffiStats.utilDamage or -1, ffiStats.enemiesFlashed or -1,
                tostring(score or "?"))
            S.lastEvent = "ffi:matchStats"
            S.lastDetail = FfiStats.status
            pollEnemyDeaths(lp)
            return
        end

        S.mode = "fields"
        S.fieldKills = "n/a"
        S.fieldHS = "n/a"
        S.fieldDmg = "n/a"
        S.score = score
        S.fieldMatch = "n/a sc" .. tostring(score or "?")
        S.lastDetail = "ffi fail: " .. tostring(FfiStats.status)

        if Poll.seeded and Poll.alive and lp and not pawnAlive(lp) then
        end
        if lp then
            local alive = pawnAlive(lp)
            if Poll.seeded and Poll.alive and not alive then
            end
            Poll.alive = alive
            Poll.seeded = true
        end
        pollEnemyDeaths(lp)
    end

    local function onEvent(ev)
        if not ev then return end

        S.events = S.events + 1
        S.mode = "events"

        local name
        pcall(function() name = ev:GetName() end)
        if type(name) ~= "string" then
            S.lastEvent = "unnamed"
            return
        end
        S.lastEvent = name

        local map = mapName()
        if map and map ~= S.map then
            S.map = map
            reset("map")
            S.events = 1
            S.lastEvent = name
            S.mode = "events"
        elseif not S.map and map then
            S.map = map
        end

        refreshLocalIds()

        if name == "player_sound" then
            S.lastDetail = "canary player_sound"
            return
        end

        if name == "round_start" then
            S.roundKills = 0
            S.roundDamage = 0
            Poll.seeded = false
            S.lastDetail = "round_start"
            return
        end

        if name == "player_death" then
            local victim = evInt(ev, "userid")
            local attacker = evInt(ev, "attacker")
            local assister = evInt(ev, "assister")
            local hs = evInt(ev, "headshot")
            local weapon = evStr(ev, "weapon") or "—"
            S.rawVictim = tostring(victim)
            S.rawAttacker = tostring(attacker)
            S.lastWeapon = weapon
            local meAtk = isLocalEventId(attacker)
            local meVic = isLocalEventId(victim)
            local meAst = isLocalEventId(assister)
            if meAtk and not meVic then
                S.kills = S.kills + 1
                S.roundKills = S.roundKills + 1
                if hs and hs ~= 0 then S.headshots = S.headshots + 1 end
                S.lastDetail = string.format("kill %s%s", weapon, (hs and hs ~= 0) and " HS" or "")
            elseif meVic then
                S.deaths = S.deaths + 1
                S.lastDetail = "death"
            elseif meAst and not meAtk and not meVic then
                S.assists = S.assists + 1
                S.lastDetail = "assist"
            else
                S.lastDetail = string.format("death raw a=%s v=%s", tostring(attacker), tostring(victim))
            end
            return
        end

        if name == "player_hurt" then
            local victim = evInt(ev, "userid")
            local attacker = evInt(ev, "attacker")
            S.rawVictim = tostring(victim)
            S.rawAttacker = tostring(attacker)
            if not (isLocalEventId(attacker) and not isLocalEventId(victim)) then return end
            local dmg = evInt(ev, "dmg_health") or 0
            local admg = evInt(ev, "dmg_armor") or 0
            local weapon = evStr(ev, "weapon") or "—"
            local hitgroup = evInt(ev, "hitgroup")
            S.damage = S.damage + dmg
            S.roundDamage = S.roundDamage + dmg
            S.armorDamage = S.armorDamage + admg
            if isUtil(weapon) then S.utilDamage = S.utilDamage + dmg end
            S.lastWeapon = weapon
            S.lastDetail = string.format("hurt %d (%s hg=%s)", dmg, weapon, tostring(hitgroup or "?"))
            return
        end

        if name == "bomb_planted" then
            if isLocalEventId(evInt(ev, "userid")) then
                S.plants = S.plants + 1
                S.lastDetail = "bomb planted"
            end
            return
        end

        if name == "bomb_defused" then
            if isLocalEventId(evInt(ev, "userid")) then
                S.defuses = S.defuses + 1
                S.lastDetail = "bomb defused"
            end
            return
        end
    end

    do
        allowListeners()
        pcall(function() callbacks.Unregister("FireGameEvent", "daizml_live_stats") end)
        pcall(function() callbacks.Unregister("FireGameEvent", EVENT_ID) end)
        local ok = pcall(function()
            callbacks.Register("FireGameEvent", EVENT_ID, onEvent)
        end)
        S.registerOk = ok and true or false
        if not ok then
            ok = pcall(function()
                callbacks.Register("FireGameEvent", onEvent)
            end)
            S.registerOk = ok and true or false
            if ok then EVENT_ID = "FireGameEvent(anon)" end
        end
    end

    local function lsMouse()
        local mx, my = 0, 0
        pcall(function() mx, my = input.GetMousePos() end)
        local down = false
        pcall(function() down = input.IsButtonDown(1) end)
        return mx or 0, my or 0, down and true or false
    end

    local function lsRect(rx, ry, rw, rh, c, a)
        if rw <= 0 or rh <= 0 then return end
        draw.Color(c[1], c[2], c[3], a or 255)
        draw.FilledRect(math.floor(rx), math.floor(ry), math.floor(rx + rw), math.floor(ry + rh))
    end

    local function lsText(font, x, y, str, c, a)
        if font then draw.SetFont(font) end
        draw.Color(c[1], c[2], c[3], a or 255)
        draw.Text(math.floor(x), math.floor(y), tostring(str))
    end

    local function lsTextSize(font, str)
        local w, h = 0, 0
        pcall(function()
            if font then draw.SetFont(font) end
            w, h = draw.GetTextSize(tostring(str))
        end)
        return w or 0, h or 0
    end

    local function ensureFonts()
        if not UI.fonts or UI._hudTypeV ~= 8 then
            UI.fonts = true
            UI._hudTypeV = 8
            pcall(function()
                UI.fTitle = draw.CreateFont("Segoe UI", 13, 600)
                UI.fName = draw.CreateFont("Segoe UI", 15, 700)
                UI.fElo = draw.CreateFont("Segoe UI", 14, 700)
                UI.fEloDelta = draw.CreateFont("Segoe UI", 10, 600)
                UI.fMetric = draw.CreateFont("Segoe UI", 14, 700)
                UI.fLabel = draw.CreateFont("Segoe UI", 8, 700)
                UI.fBanVal = draw.CreateFont("Segoe UI", 12, 700)
                UI.fBanLab = draw.CreateFont("Segoe UI", 9, 500)
                UI.fBody = draw.CreateFont("Segoe UI", 13, 500)
            end)
        end
        if not UI.fEloDelta then
            pcall(function() UI.fEloDelta = draw.CreateFont("Segoe UI", 10, 600) end)
            UI.fEloDelta = UI.fEloDelta or UI.fBanLab or UI.fLabel
        end
    end

    local function updateSession()
        local now
        pcall(function() now = globals.RealTime() end)
        now = type(now) == "number" and now or 0
        if now >= (Poll.allowNext or 0) then
            allowListeners()
            Poll.allowNext = now + 2.0
        end

        local map = mapName()
        if map and map ~= S.map then
            S.map = map
            reset("map")
        elseif not S.map and map then
            S.map = map
        end

        refreshLocalIds()
        pollFields()
    end

    local function lsTheme()
        local accent = { DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3], DEFAULT_ACCENT[4] or 255 }
        local text = { DEFAULT_TEXT[1], DEFAULT_TEXT[2], DEFAULT_TEXT[3], DEFAULT_TEXT[4] or 255 }
        pcall(function()
            local c = uiAccent:Get()
            if type(c) == "table" and c[1] then accent = { c[1], c[2], c[3], c[4] or 255 } end
        end)
        pcall(function()
            local c = uiText:Get()
            if type(c) == "table" and c[1] then text = { c[1], c[2], c[3], c[4] or 255 } end
        end)
        local bg = { 9, 11, 16 }
        local bg2 = { 12, 14, 20 }
        local dim = {
            math.max(90, math.floor((text[1] or 205) * 0.62)),
            math.max(95, math.floor((text[2] or 213) * 0.62)),
            math.max(105, math.floor((text[3] or 225) * 0.62)),
            255,
        }
        local hi = {
            math.min(255, math.floor((text[1] or 205) * 1.12)),
            math.min(255, math.floor((text[2] or 213) * 1.12)),
            math.min(255, math.floor((text[3] or 225) * 1.12)),
            255,
        }
        return accent, bg, bg2, text, dim, hi
    end

    local function lsAccent()
        local accent = lsTheme()
        return accent
    end

    local function lsFilledCircle(cx, cy, r, c, a)
        cx, cy, r = tonumber(cx), tonumber(cy), tonumber(r)
        if not (cx and cy and r) or r < 1 then return end
        local ok = false
        pcall(function()
            draw.Color(c[1], c[2], c[3], a or 255)
            if draw.FilledCircle then
                draw.FilledCircle(math.floor(cx), math.floor(cy), math.floor(r))
                ok = true
            elseif draw.CircleFilled then
                draw.CircleFilled(math.floor(cx), math.floor(cy), math.floor(r))
                ok = true
            end
        end)
        if ok then return end
        local rr = math.floor(r + 0.5)
        for dy = -rr, rr do
            local w = math.floor(math.sqrt(math.max(0, rr * rr - dy * dy)) + 0.5)
            if w > 0 then lsRect(cx - w, cy + dy, w * 2, 1, c, a) end
        end
    end

    local function lsCircleRing(cx, cy, r, c, a, thick)
        thick = tonumber(thick) or 2
        local outer = tonumber(r) or 1
        for t = 0, math.max(0, thick - 1) do
            local rr = outer - t
            if rr < 1 then break end
            local ok = false
            pcall(function()
                draw.Color(c[1], c[2], c[3], a or 255)
                if draw.Circle then
                    draw.Circle(math.floor(cx), math.floor(cy), math.floor(rr))
                    ok = true
                end
            end)
            if not ok then
                local rri = math.floor(rr + 0.5)
                for dy = -rri, rri do
                    local outerW = math.floor(math.sqrt(math.max(0, rri * rri - dy * dy)) + 0.5)
                    local innerR = rri - 1
                    local innerW = (innerR > 0) and math.floor(math.sqrt(math.max(0, innerR * innerR - dy * dy)) + 0.5) or 0
                    if outerW > innerW then
                        lsRect(cx - outerW, cy + dy, outerW - innerW, 1, c, a)
                        lsRect(cx + innerW, cy + dy, outerW - innerW, 1, c, a)
                    end
                end
            end
        end
    end

    local function lsRoundInset(row, h, rad)
        if row < rad then
            local k = rad - 1 - row
            return rad - math.floor(math.sqrt(math.max(0, rad * rad - k * k)) + 0.5)
        elseif row >= h - rad then
            local k = row - (h - rad)
            return rad - math.floor(math.sqrt(math.max(0, rad * rad - k * k)) + 0.5)
        end
        return 0
    end

    local function lsRoundedRect(x, y, w, h, rad, c, a)
        w, h = math.floor(w), math.floor(h)
        if w < 2 or h < 2 then return end
        rad = math.floor(math.min(rad or 12, math.floor(w * 0.5), math.floor(h * 0.5)))
        if rad < 1 then
            lsRect(x, y, w, h, c, a)
            return
        end
        x, y = math.floor(x), math.floor(y)
        for row = 0, h - 1 do
            local inset = lsRoundInset(row, h, rad)
            local rw = w - inset * 2
            if rw > 0 then
                lsRect(x + inset, y + row, rw, 1, c, a)
            end
        end
    end

    local function lsRoundedBand(x, y, w, h, rad, c, a, row0, row1)
        w, h = math.floor(w), math.floor(h)
        if w < 2 or h < 2 then return end
        rad = math.floor(math.min(rad or 12, math.floor(w * 0.5), math.floor(h * 0.5)))
        x, y = math.floor(x), math.floor(y)
        row0 = math.max(0, math.floor(row0 or 0))
        row1 = math.min(h, math.floor(row1 or h))
        for row = row0, row1 - 1 do
            local inset = (rad < 1) and 0 or lsRoundInset(row, h, rad)
            local rw = w - inset * 2
            if rw > 0 then
                lsRect(x + inset, y + row, rw, 1, c, a)
            end
        end
    end

    local function accountToSteam64(account_id)
        account_id = tonumber(account_id)
        if not account_id or account_id <= 0 then return nil end
        local s
        pcall(function()
            local base = ffi.cast("uint64_t", 0x01100001) * ffi.cast("uint64_t", 0x100000000)
            local id = base + ffi.cast("uint64_t", account_id)
            s = tostring(id):match("^(%d+)")
        end)
        return s
    end

    local function steamIdToSteam64(steam)
        if type(steam) ~= "string" or steam == "" then return nil end
        steam = steam:gsub("^%s+", ""):gsub("%s+$", "")
        if steam:match("^7656%d+$") then return steam end
        local y, z = steam:match("^STEAM_[0-5]:([01]):(%d+)$")
        if y and z then
            return accountToSteam64(tonumber(z) * 2 + tonumber(y))
        end
        local acc = steam:match("^%[U:1:(%d+)%]$") or steam:match("^u:1:(%d+)$")
        if acc then return accountToSteam64(tonumber(acc)) end
        return nil
    end

    local function resolveLocalSteam64()
        Avatar.detail = nil
        local acc = ffiReadLocalAccountId()
        local s64 = accountToSteam64(acc)
        if s64 then
            Avatar.detail = "ffi"
            return s64
        end

        acc = 0
        pcall(function() acc = localAccountId() end)
        s64 = accountToSteam64(acc)
        if s64 then
            Avatar.detail = "skin"
            return s64
        end

        local idx
        pcall(function() idx = client.GetLocalPlayerIndex() end)
        if type(idx) == "number" then
            local info
            pcall(function() info = client.GetPlayerInfo(idx) end)
            if type(info) == "table" then
                local prefer = {
                    info.SteamID64, info.steamID64, info.Steamid64,
                    info.SteamID, info.steamID, info.SteamId, info.steamid,
                }
                for i = 1, #prefer do
                    local v = prefer[i]
                    if type(v) == "string" then
                        s64 = steamIdToSteam64(v)
                    elseif type(v) == "number" and v > 0 then
                        if v < 0x100000000 then
                            s64 = accountToSteam64(v)
                        else
                            s64 = steamIdToSteam64(tostring(v):match("^(%d+)") or "")
                        end
                    end
                    if s64 then
                        Avatar.detail = "info"
                        return s64
                    end
                end
                for _, v in pairs(info) do
                    if type(v) == "string" then
                        s64 = steamIdToSteam64(v)
                        if s64 then
                            Avatar.detail = "info-scan"
                            return s64
                        end
                    end
                end
            end
        end

        local ctrl = localController()
        if ctrl then
            local raw
            pcall(function() raw = ctrl:GetPropInt("m_steamID") end)
            if type(raw) ~= "number" or raw == 0 then
                pcall(function() raw = ctrl:GetField("m_steamID") end)
            end
            if type(raw) == "number" and raw > 0 then
                s64 = accountToSteam64(raw % 0x100000000)
                if s64 then
                    Avatar.detail = "prop"
                    return s64
                end
            end
            pcall(function()
                if ctrl.GetSteamID then
                    local t = ctrl:GetSteamID()
                    if type(t) == "table" and t.low then
                        s64 = accountToSteam64(tonumber(t.low))
                    elseif type(t) == "string" then
                        s64 = steamIdToSteam64(t)
                    elseif type(t) == "number" then
                        s64 = accountToSteam64(t % 0x100000000)
                    end
                end
            end)
            if s64 then
                Avatar.detail = "getsteam"
                return s64
            end
            pcall(function()
                if ctrl.GetStringSteamID then
                    s64 = steamIdToSteam64(ctrl:GetStringSteamID())
                end
            end)
            if s64 then
                Avatar.detail = "strsteam"
                return s64
            end
        end

        Avatar.detail = "none"
        return nil
    end

    local function isBadPlayerName(n)
        if type(n) ~= "string" then return true end
        n = n:gsub("^%s+", ""):gsub("%s+$", "")
        if n == "" then return true end
        local lower = n:lower()
        if lower == "unknown" or lower == "unconnected" or lower == "invalid" then return true end
        if n:find("CCSPlayer", 1, true) or n:find("C_CSPlayer", 1, true) then return true end
        if n:find("PlayerController", 1, true) or n:find("PlayerPawn", 1, true) then return true end
        return false
    end

    local function localPlayerName()
        local idx
        pcall(function() idx = client.GetLocalPlayerIndex() end)

        if type(idx) == "number" then
            local n
            pcall(function() n = client.GetPlayerNameByIndex(idx) end)
            if not isBadPlayerName(n) then return n end

            local info
            pcall(function() info = client.GetPlayerInfo(idx) end)
            if type(info) == "table" then
                n = info.Name or info.name or info.szName or info.PlayerName
                if not isBadPlayerName(n) then return n end
            end
        end

        local ctrl = localController()
        if ctrl then
            local keys = {
                "m_sSanitizedPlayerName",
                "m_iszPlayerName",
                "m_szPlayerName",
            }
            for i = 1, #keys do
                local n
                pcall(function() n = ctrl:GetPropString(keys[i]) end)
                if isBadPlayerName(n) then pcall(function() n = ctrl:GetField(keys[i]) end) end
                if type(n) == "userdata" then pcall(function() n = tostring(n) end) end
                if not isBadPlayerName(n) then return n end
            end
            local n
            pcall(function() n = ctrl:GetName() end)
            if not isBadPlayerName(n) then return n end
        end

        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        if lp then
            local n
            pcall(function() n = lp:GetName() end)
            if not isBadPlayerName(n) then return n end
            local i2
            pcall(function() i2 = lp:GetIndex() end)
            if type(i2) == "number" then
                pcall(function() n = client.GetPlayerNameByIndex(i2) end)
                if not isBadPlayerName(n) then return n end
            end
        end

        return "Player"
    end

    local function circleMaskRgba(rgba, w, h)
        w, h = tonumber(w), tonumber(h)
        if not (rgba and w and h and w > 1 and h > 1) then return rgba end
        local n = w * h * 4
        local buf
        local ok = pcall(function()
            buf = ffi.new("uint8_t[?]", n)
            if type(rgba) == "string" then
                if #rgba < n then error("short") end
                ffi.copy(buf, rgba, n)
            else
                ffi.copy(buf, rgba, n)
            end
        end)
        if not ok or not buf then return rgba end

        local cx = (w - 1) * 0.5
        local cy = (h - 1) * 0.5
        local r = math.min(w, h) * 0.5
        local r2 = r * r
        local soft = 1.25
        local rIn = math.max(0, r - soft)
        local rIn2 = rIn * rIn

        for y = 0, h - 1 do
            local dy = y - cy
            local dy2 = dy * dy
            for x = 0, w - 1 do
                local dx = x - cx
                local d2 = dx * dx + dy2
                local ai = (y * w + x) * 4 + 3
                if d2 >= r2 then
                    buf[ai] = 0
                elseif d2 > rIn2 then
                    local d = math.sqrt(d2)
                    local t = (r - d) / soft
                    if t < 0 then t = 0 elseif t > 1 then t = 1 end
                    buf[ai] = math.floor(255 * t + 0.5)
                else
                    buf[ai] = 255
                end
            end
        end

        local out = rgba
        pcall(function() out = ffi.string(buf, n) end)
        return out
    end

    local function decodeAvatarImage(body)
        if type(body) ~= "string" or #body < 32 then return nil end
        local rgba, w, h
        pcall(function()
            if common.DecodeJPEG then
                rgba, w, h = common.DecodeJPEG(body)
            end
        end)
        if not (rgba and w and h and w > 0) then
            rgba, w, h = nil, nil, nil
            pcall(function()
                if common.DecodePNG then
                    rgba, w, h = common.DecodePNG(body)
                end
            end)
        end
        if not (rgba and w and h and w > 0 and h > 0) then return nil end
        rgba = circleMaskRgba(rgba, w, h)
        local tex
        pcall(function() tex = draw.CreateTexture(rgba, w, h) end)
        if not tex then return nil end
        return tex, w, h
    end

    local function nowTime()
        local t
        pcall(function() t = globals.RealTime() end)
        if type(t) ~= "number" then pcall(function() t = common.Time() end) end
        return type(t) == "number" and t or 0
    end

    local function avatarMarkFail(delay)
        LiveStatsPos._avatarHttpBusy = false
        Avatar.status = "fail"
        Avatar.nextTry = nowTime() + (tonumber(delay) or 3)
        Avatar.failCount = (Avatar.failCount or 0) + 1
        if (Avatar.failCount or 0) >= 3 then
            LiveStatsPos._steamAvatarSettled = true
        end
    end

    local function avatarPendingTimedOut()
        local frames = (Avatar.tick or 0) - (Avatar.pendingFrame or 0)
        if frames >= 300 then return true end
        local now = nowTime()
        local since = tonumber(Avatar.pendingSince) or 0
        if now > 1 and since > 0 and now > since + 8 then
            return true
        end
        return false
    end

    local function avatarApplyTex(tex, w, h)
        if not tex then return false end
        Avatar.tex, Avatar.tw, Avatar.th = tex, w, h
        Avatar.status = "ok"
        Avatar.failCount = 0
        LiveStatsPos._avatarHttpBusy = false
        LiveStatsPos._steamAvatarSettled = true
        M._avatarTex = tex
        M._avatarTw, M._avatarTh = w, h
        return true
    end

    local function avatarFetchImage(url, reqId)
        if type(url) ~= "string" or url == "" then
            avatarMarkFail(4)
            return
        end
        Avatar.imgUrl = url
        Avatar.status = "img"
        Avatar.pendingSince = nowTime()
        Avatar.pendingFrame = Avatar.tick or 0
        LiveStatsPos._avatarHttpBusy = true

        local function finish(body)
            if reqId ~= Avatar.reqId then return end 
            LiveStatsPos._avatarHttpBusy = false
            local tex, w, h = decodeAvatarImage(body)
            if avatarApplyTex(tex, w, h) then
                return
            end
            avatarMarkFail(4)
        end

        local ok = pcall(function()
            http.Get(url, finish)
        end)
        if not ok then
            local body
            pcall(function() body = http.Get(url) end)
            finish(body)
        end
    end

    local function avatarStartXml(s64)
        Avatar.reqId = (Avatar.reqId or 0) + 1
        local reqId = Avatar.reqId
        Avatar.steam64 = s64
        Avatar.status = "xml"
        Avatar.pendingSince = nowTime()
        Avatar.pendingFrame = Avatar.tick or 0
        LiveStatsPos._avatarHttpBusy = true

        local xmlUrl = "https://steamcommunity.com/profiles/" .. s64 .. "/?xml=1"
        local function onXml(body)
            if reqId ~= Avatar.reqId then return end
            if type(body) ~= "string" then
                avatarMarkFail(4)
                return
            end
            local url = body:match("<avatarFull><!%[CDATA%[(.-)%]%]>")
                or body:match("<avatarMedium><!%[CDATA%[(.-)%]%]>")
                or body:match("<avatarIcon><!%[CDATA%[(.-)%]%]>")
                or body:match("<avatarFull>(.-)</avatarFull>")
            if type(url) == "string" then
                url = url:gsub("^%s+", ""):gsub("%s+$", "")
            end
            if not url or url == "" then
                avatarMarkFail(4)
                return
            end
            avatarFetchImage(url, reqId)
        end

        local ok = pcall(function() http.Get(xmlUrl, onXml) end)
        if not ok then
            local body
            pcall(function() body = http.Get(xmlUrl) end)
            onXml(body)
            return
        end
    end

    local function avatarSyncRescue()
        local s64 = Avatar.steam64
        if type(s64) ~= "string" and type(s64) ~= "number" then
            s64 = resolveLocalSteam64()
        end
        s64 = s64 and tostring(s64) or nil
        if not s64 then return false end

        local body
        if Avatar.status == "img" and type(Avatar.imgUrl) == "string" then
            pcall(function() body = http.Get(Avatar.imgUrl) end)
            local tex, w, h = decodeAvatarImage(body)
            return avatarApplyTex(tex, w, h)
        end

        local xmlUrl = "https://steamcommunity.com/profiles/" .. s64 .. "/?xml=1"
        pcall(function() body = http.Get(xmlUrl) end)
        if type(body) ~= "string" then return false end
        local url = body:match("<avatarFull><!%[CDATA%[(.-)%]%]>")
            or body:match("<avatarMedium><!%[CDATA%[(.-)%]%]>")
            or body:match("<avatarIcon><!%[CDATA%[(.-)%]%]>")
            or body:match("<avatarFull>(.-)</avatarFull>")
        if type(url) == "string" then
            url = url:gsub("^%s+", ""):gsub("%s+$", "")
        end
        if not url or url == "" then return false end
        Avatar.imgUrl = url
        local img
        pcall(function() img = http.Get(url) end)
        local tex, w, h = decodeAvatarImage(img)
        return avatarApplyTex(tex, w, h)
    end

    local function avatarEnsure()
        Avatar.tick = (Avatar.tick or 0) + 1
        local now = nowTime()
        if LiveStatsPos._forceAvatarRefetch then
            LiveStatsPos._forceAvatarRefetch = false
            if not LiveStatsPos._avatarHttpBusy then
                Avatar.reqId = (Avatar.reqId or 0) + 1 
                Avatar.status = "idle"
                Avatar.tex, Avatar.tw, Avatar.th = nil, 0, 0
                LiveStatsPos._steamAvatarSettled = false
            end
        end
        if Avatar.status == "ok" and not Avatar.tex then
            Avatar.status = "idle"
            LiveStatsPos._steamAvatarSettled = false
        end
        if Avatar.status == "xml" or Avatar.status == "img" then
            if avatarPendingTimedOut() then
                LiveStatsPos._avatarHttpBusy = false
                Avatar.reqId = (Avatar.reqId or 0) + 1
                if avatarSyncRescue() then
                    return
                end
                Avatar.status = "idle"
                Avatar.failCount = (Avatar.failCount or 0) + 1
                if (Avatar.failCount or 0) >= 3 then
                    LiveStatsPos._steamAvatarSettled = true
                end
            else
                LiveStatsPos._avatarHttpBusy = true
                return
            end
        end

        if Avatar.status == "ok" then
            LiveStatsPos._avatarHttpBusy = false
            LiveStatsPos._steamAvatarSettled = true
            return
        end

        if Avatar.status == "fail" and now > 0 and now < (Avatar.nextTry or 0) then
            return
        end
        if Avatar.status == "fail" and now <= 0 then
            if ((Avatar.tick or 0) % 90) ~= 0 then return end
        end

        if type(http) ~= "table" or type(http.Get) ~= "function" then
            Avatar.status = "fail"
            Avatar.nextTry = now + 8
            return
        end
        local s64 = resolveLocalSteam64()
        if not s64 then
            Avatar.status = "fail"
            Avatar.nextTry = (now > 0) and (now + 1.5) or 0
            Avatar.failCount = (Avatar.failCount or 0) + 1
            LiveStatsPos._avatarHttpBusy = false
            if (Avatar.failCount or 0) >= 2 then
                LiveStatsPos._steamAvatarSettled = true
            end
            return
        end

        do
            local R = LiveStatsPos.RadarHud
            if R and R.httpBusy then
                return
            end
            if R and R.fetching then
                return
            end
        end
        if Avatar.steam64 and Avatar.steam64 ~= s64 then
            Avatar.tex, Avatar.tw, Avatar.th = nil, 0, 0
        end
        avatarStartXml(tostring(s64))
    end

    local function bannerDt(now)
        local dt = 1 / 60
        pcall(function()
            local aft = globals.AbsoluteFrameTime()
            if type(aft) == "number" and aft > 0.0005 and aft < 0.5 then
                dt = aft
            end
        end)
        if type(now) == "number" and Banner.lastNow and now > Banner.lastNow then
            local raw = now - Banner.lastNow
            if raw > 0 and raw < 0.5 then
                dt = raw
            end
        end
        Banner.lastNow = now
        if dt > 0.1 then dt = 0.1 end
        if dt < 0 then dt = 1 / 60 end
        return dt
    end

    local function bannerTick(now)
        local dt = bannerDt(now)
        if Banner.fadeFrom ~= nil then
            Banner.fadeT = (Banner.fadeT or 0) + dt / BANNER_FADE
            if Banner.fadeT >= 1 then
                Banner.fadeFrom = nil
                Banner.fadeT = nil
                Banner.holdLeft = BANNER_HOLD
            end
            return
        end
        Banner.holdLeft = (Banner.holdLeft or BANNER_HOLD) - dt
        if Banner.holdLeft <= 0 then
            Banner.fadeFrom = Banner.page
            Banner.fadeT = 0
            Banner.page = (Banner.page + 1) % BANNER_PAGES
            Banner.holdLeft = BANNER_HOLD
        end
    end

    local function bannerPageData(page, kills, deaths, assists, hsPct)
        if page == 0 then
            return {
                { tostring(kills), "K" },
                { tostring(deaths), "D" },
                { tostring(assists), "A" },
            }
        elseif page == 1 then
            return {
                { string.format("%.0f", hsPct), "HS%" },
                { string.format("%.0f", S.adr), "ADR" },
                { tostring(S.damage), "DMG" },
            }
        elseif page == 2 then
            return {
                { tostring(S.utilDamage), "UD" },
                { tostring(S.enemiesFlashed), "EF" },
                { tostring(S.mvps), "MVPs" },
            }
        else
            return {
                { tostring(S.ace), "5k" },
                { tostring(S.quad), "4k" },
                { tostring(S.triple), "3k" },
            }
        end
    end

    local function drawBannerPage(x, y, w, h, items, textCol, dimCol, alpha)
        if alpha < 8 then return end
        local n = #items
        if n < 1 then return end
        local colW = w / n
        for i = 1, n do
            local it = items[i]
            if it then
                local cx = x + (i - 1) * colW + colW * 0.5
                local vw = lsTextSize(UI.fBanVal, it[1])
                lsText(UI.fBanVal, cx - vw * 0.5, y + 2, it[1], textCol, alpha)
                local lw = lsTextSize(UI.fBanLab, it[2])
                lsText(UI.fBanLab, cx - lw * 0.5, y + 15, it[2], dimCol, math.floor(alpha * 0.85))
            end
        end
    end

    local function drawAvatar(cx, cy, size, accent)
        local r = size * 0.5
        lsFilledCircle(cx, cy, r + 1, { 18, 18, 22 }, 220)
        if Avatar.tex then
            local s = size - 2
            local ax = math.floor(cx - s * 0.5)
            local ay = math.floor(cy - s * 0.5)
            pcall(function()
                draw.Color(255, 255, 255, 255)
                draw.SetTexture(Avatar.tex)
                draw.FilledRect(ax, ay, ax + s, ay + s)
            end)
            pcall(function() draw.SetTexture(nil) end)
        else
            lsFilledCircle(cx, cy, r - 2, { 32, 34, 40 }, 255)
            local initials = "?"
            local nm = localPlayerName()
            if type(nm) == "string" and #nm > 0 then
                initials = nm:sub(1, 1):upper()
            end
            local iw = lsTextSize(UI.fName, initials)
            lsText(UI.fName, cx - iw * 0.5, cy - 8, initials, { 220, 224, 232 }, 230)
        end
        lsCircleRing(cx, cy, r + 1, accent, 255, 2)
        M._avatarTex = Avatar.tex
        M._avatarTw, M._avatarTh = Avatar.tw, Avatar.th
    end
    M._ensureSteamAvatar = function()
        avatarEnsure()
        M._avatarTex = Avatar.tex
        M._avatarTw, M._avatarTh = Avatar.tw, Avatar.th
    end

    local BrandLogo = {
        status = "idle",
        tex = nil,
        busy = false,
        nextTry = 0,
        failCount = 0,
        urlIndex = 1,
        usedFallback = false,
    }
    local BRAND_LOGO_PATH = "assets/brand/lua_logo.svg"
    local BRAND_LOGO_URLS = {
        "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/lua/lua-original.svg",
        "https://cdn.jsdelivr.net/npm/simple-icons@11.15.0/icons/lua.svg",
        "https://upload.wikimedia.org/wikipedia/commons/c/cf/Lua-Logo.svg",
    }
    local BRAND_LOGO_FALLBACK = [[<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128"><ellipse cx="64" cy="64" rx="54" ry="22" fill="none" stroke="#7EC8E3" stroke-width="10" transform="rotate(-40 64 64)"/><circle cx="64" cy="64" r="36" fill="#000080"/><circle cx="98" cy="34" r="14" fill="#7EC8E3"/></svg>]]

    local function brandLogoEnsureDirs()
        pcall(function()
            if file and file.CreateDirectory then
                file.CreateDirectory("assets")
                file.CreateDirectory("assets/brand")
            end
        end)
    end

    local function brandLogoIsSvg(data)
        return type(data) == "string" and #data > 40
            and (data:find("<svg", 1, true) or data:find("<SVG", 1, true))
    end

    local function brandLogoRasterize(data)
        if not brandLogoIsSvg(data) then return nil end
        if type(common) ~= "table" or type(common.RasterizeSVG) ~= "function" then return nil end
        local scales = { 1.5, 1.0, 2.0, 0.75, 0.5 }
        for i = 1, #scales do
            local rgba, w, h
            local ok = pcall(function()
                rgba, w, h = common.RasterizeSVG(data, scales[i])
            end)
            if ok and rgba and type(w) == "number" and type(h) == "number" and w >= 12 and h >= 12 and w <= 512 and h <= 512 then
                local tex
                local okTex = pcall(function() tex = draw.CreateTexture(rgba, w, h) end)
                if okTex and tex then
                    return tex, w, h
                end
            end
        end
        return nil
    end

    local function brandLogoApply(data, saveDisk, source)
        local tex, w, h = brandLogoRasterize(data)
        if not tex then return false end
        if BrandLogo.tex and BrandLogo.tex ~= tex then
            pcall(function()
                if draw.DeleteTexture then draw.DeleteTexture(BrandLogo.tex) end
            end)
        end
        BrandLogo.tex = tex
        BrandLogo.tw, BrandLogo.th = w, h
        BrandLogo.status = "ok"
        BrandLogo.failCount = 0
        BrandLogo.busy = false
        BrandLogo.source = source or (saveDisk and "net" or "disk")
        M._brandLogoTex = tex
        M._brandLogoTw, M._brandLogoTh = w, h
        if saveDisk and brandLogoIsSvg(data) then
            brandLogoEnsureDirs()
            pcall(fileWrite, BRAND_LOGO_PATH, data)
            BrandLogo.source = "net"
        end
        return true
    end

    local function brandLogoTryFallback()
        if BrandLogo.tex and BrandLogo.source and BrandLogo.source ~= "fallback" then
            return true
        end
        if BrandLogo.usedFallback and BrandLogo.tex then return true end
        BrandLogo.usedFallback = true
        return brandLogoApply(BRAND_LOGO_FALLBACK, false, "fallback")
    end

    local function brandLogoFetchNext()
        if BrandLogo.busy then return end
        if BrandLogo.source == "disk" or BrandLogo.source == "net" then return end
        if type(http) ~= "table" or type(http.Get) ~= "function" then
            brandLogoTryFallback()
            BrandLogo.status = BrandLogo.tex and "ok" or "fail"
            return
        end
        local idx = BrandLogo.urlIndex or 1
        if idx > #BRAND_LOGO_URLS then
            brandLogoTryFallback()
            BrandLogo.status = BrandLogo.tex and "ok" or "fail"
            BrandLogo.nextTry = nowTime() + 45
            BrandLogo.urlIndex = 1
            return
        end
        local url = BRAND_LOGO_URLS[idx]
        BrandLogo.busy = true
        BrandLogo.status = "fetch"
        BrandLogo.urlIndex = idx + 1

        local function finish(body)
            BrandLogo.busy = false
            if brandLogoIsSvg(body) and brandLogoApply(body, true, "net") then
                return
            end
            BrandLogo.failCount = (BrandLogo.failCount or 0) + 1
            brandLogoFetchNext()
        end

        local ok = pcall(function()
            http.Get(url, finish)
        end)
        if not ok then
            local body
            pcall(function() body = http.Get(url) end)
            finish(body)
        end
    end

    local function brandLogoEnsure()
        if BrandLogo.tex then
            M._brandLogoTex = BrandLogo.tex
            if BrandLogo.source == "disk" or BrandLogo.source == "net" then
                return
            end
        elseif not BrandLogo.busy then
            local cached = fileRead(BRAND_LOGO_PATH)
            if brandLogoIsSvg(cached) and brandLogoApply(cached, false, "disk") then
                return
            end
            brandLogoTryFallback()
        else
            brandLogoTryFallback()
            return
        end

        if BrandLogo.busy then return end
        if BrandLogo.source == "disk" or BrandLogo.source == "net" then return end

        local now = nowTime()
        if now < (tonumber(BrandLogo.nextTry) or 0) then return end
        BrandLogo.nextTry = now + 8
        if (BrandLogo.urlIndex or 1) > #BRAND_LOGO_URLS then
            BrandLogo.urlIndex = 1
        end
        brandLogoFetchNext()
    end

    M._ensureBrandLogo = brandLogoEnsure
    brandLogoEnsure()

    local function drawThemedCard(x, y, w, h, bannerH, rad, accent, bg, bg2)
        lsRoundedRect(x + 2, y + 4, w, h, rad, { 0, 0, 0 }, 90)
        lsRoundedRect(x, y, w, h, rad, bg, 214)
        local upperH = h - bannerH
        lsRoundedBand(x, y, w, h, rad, bg2, 70, 0, upperH)
        local ban = {
            math.max(0, math.floor((bg[1] or 9) * 0.65)),
            math.max(0, math.floor((bg[2] or 11) * 0.65)),
            math.max(0, math.floor((bg[3] or 16) * 0.65)),
        }
        lsRoundedBand(x, y, w, h, rad, ban, 140, upperH, h)
        lsRect(x + rad, y, w - rad * 2, 2, accent, 235)
        lsRect(x + rad, y + h - 1, w - rad * 2, 1, { 0, 0, 0 }, 150)
        lsRect(x + 18, y + upperH, w - 36, 1, { 255, 255, 255 }, 22)
    end

    local function drawDashboard()
        ensureFonts()
        avatarEnsure()

        local accent, bg, bg2, text, dim, hi = lsTheme()
        local green = { 90, 210, 120 }

        local kills = S.kills
        local deaths = S.deaths
        local assists = S.assists
        local hs = S.headshots
        local hsPct = (kills > 0) and ((hs / kills) * 100) or 0
        local kd = (deaths > 0) and (kills / deaths) or kills
        local pad = 12
        local METRICS_LAYOUT_W = 280
        local W, H = 250, 78
        local bannerH = 28
        local rad = 12
        local sw, sh = 1920, 1080
        pcall(function() sw, sh = draw.GetScreenSize() end)

        local x = 18
        local y = math.floor(sh * 0.22)
        if LiveStatsPos.x ~= nil and LiveStatsPos.y ~= nil then
            x, y = math.floor(LiveStatsPos.x), math.floor(LiveStatsPos.y)
        end
        if x < 0 then x = 0 elseif x > sw - W then x = math.max(0, sw - W) end
        if y < 0 then y = 0 elseif y > sh - H then y = math.max(0, sh - H) end

        local menuOpen = M._open and true or false
        local mx, my, mouseDown = lsMouse()
        local pressed = mouseDown and not UI._mouseDown
        UI._mouseDown = mouseDown
        if menuOpen then
            local hov = mx >= x and mx <= x + W and my >= y and my <= y + H
            if pressed and hov then
                UI._drag = { dx = mx - x, dy = my - y }
            end
            if UI._drag then
                if mouseDown then
                    x = mx - UI._drag.dx
                    y = my - UI._drag.dy
                    if x < 0 then x = 0 elseif x > sw - W then x = math.max(0, sw - W) end
                    if y < 0 then y = 0 elseif y > sh - H then y = math.max(0, sh - H) end
                    LiveStatsPos.x, LiveStatsPos.y = x, y
                else
                    UI._drag = nil
                end
            end
        else
            UI._drag = nil
        end

        drawThemedCard(x, y, W, H, bannerH, rad, accent, bg, bg2)

        if menuOpen then
            local borderA = UI._drag and 160 or 50
            lsRect(x + rad, y + 2, W - rad * 2, 1, { 255, 255, 255 }, borderA)
        end

        local upperH = H - bannerH
        local avSize = 36
        local avCx = x + pad + avSize * 0.5
        local avCy = y + math.floor((upperH - avSize) * 0.5) + avSize * 0.5
        drawAvatar(avCx, avCy, avSize, accent)

        local nameX = x + pad + avSize + 8
        local nameY = y + 8
        local pname = localPlayerName()

        local function formatKd(v)
            if v >= 100 then return string.format("%.0f", v) end
            if v >= 10 then return string.format("%.1f", v) end
            return string.format("%.2f", v)
        end

        local metrics = {
            { tostring(kills), "KILLS" },
            { string.format("%.0f", hsPct), "HS%" },
            { formatKd(kd), "K/D" },
        }
        local metricsOx, metricsOy = -32, 5
        local metricsRight = x + METRICS_LAYOUT_W - pad + metricsOx
        local colGap = 12
        local colW = {}
        local metricsSpan = 0
        for i = 1, 3 do
            local vw = lsTextSize(UI.fMetric, metrics[i][1])
            local lw = lsTextSize(UI.fLabel, metrics[i][2])
            colW[i] = math.max(22, vw, lw)
            metricsSpan = metricsSpan + colW[i] + (i > 1 and colGap or 0)
        end
        local metricsLeft = metricsRight - metricsSpan

        local maxNameW = math.max(28, metricsLeft - nameX - 8)
        local showName = pname
        local ell = "..."
        local ellW = lsTextSize(UI.fName, ell)
        while #showName > 1 and lsTextSize(UI.fName, showName) > maxNameW do
            showName = showName:sub(1, #showName - 1)
        end
        if showName ~= pname then
            while #showName > 1 and lsTextSize(UI.fName, showName .. ell) > maxNameW do
                showName = showName:sub(1, #showName - 1)
            end
            showName = showName .. ell
            if lsTextSize(UI.fName, showName) > maxNameW and ellW <= maxNameW then
                showName = ell
            end
        end
        lsText(UI.fName, nameX, nameY, showName, hi, 255)

        local eloY = nameY + 16
        local premier
        pcall(function() premier = ffiReadPremier() end)

        local function formatElo(n)
            local s = tostring(math.floor(n + 0.5))
            local k
            while true do
                s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
            end
            return s
        end

        if premier and premier.elo and premier.elo > 0 then
            lsText(UI.fElo, nameX, eloY, formatElo(premier.elo), accent, 240)
        else
            lsText(UI.fElo, nameX, eloY, "—", accent, 240)
        end

        local metricValY = nameY + metricsOy
        local metricLabY = nameY + 15 + metricsOy
        local cursor = metricsRight
        for i = 3, 1, -1 do
            local m = metrics[i]
            local cw = colW[i]
            local colLeft = cursor - cw
            local vw = lsTextSize(UI.fMetric, m[1])
            local lw = lsTextSize(UI.fLabel, m[2])
            lsText(UI.fMetric, colLeft + math.floor((cw - vw) * 0.5), metricValY, m[1], hi, 255)
            lsText(UI.fLabel, colLeft + math.floor((cw - lw) * 0.5), metricLabY, m[2], dim, 210)
            cursor = cursor - cw - colGap
        end

        local now = nowTime()
        bannerTick(now)
        local bx = x + pad
        local by = y + upperH + 1
        local bw = W - pad * 2
        local bh = bannerH - 3

        local alphaCur = 255
        local alphaOld = 0
        if Banner.fadeFrom ~= nil then
            local t = Banner.fadeT or 0
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            alphaCur = math.floor(255 * t)
            alphaOld = math.floor(255 * (1 - t))
        end

        if Banner.fadeFrom ~= nil and alphaOld > 0 then
            drawBannerPage(bx, by, bw, bh, bannerPageData(Banner.fadeFrom, kills, deaths, assists, hsPct), text, dim, alphaOld)
        end
        drawBannerPage(bx, by, bw, bh, bannerPageData(Banner.page, kills, deaths, assists, hsPct), text, dim, alphaCur)
    end

    local function lsInGame()
        local map
        pcall(function()
            if engine and engine.GetMapName then map = engine.GetMapName() end
        end)
        if type(map) ~= "string" then map = "" end
        map = map:gsub("%.bsp$", ""):gsub("%.vpk$", ""):gsub("^maps/", ""):lower()
        if map == "" or map == "<empty>" or map == "unknown" or map:find("lobby", 1, true) then
            return false
        end

        local lp
        pcall(function() lp = entities.GetLocalPlayer() end)
        return lp ~= nil
    end

    local function drawOverlay()
        if not (liveStats and liveStats:Get()) then return end
        if not lsInGame() then return end
        pcall(function() draw.SetTexture(nil) end)
        updateSession()
        drawDashboard()
    end

    return drawOverlay, reset, EVENT_ID
end)()

;(function()
    local uid = (tostring({}):gsub("%W", "")):sub(-8)
    local DRAW_ID = "DaizML_D_" .. uid
    local MOVE_ID = "DaizML_M_" .. uid
    local PRE_ID = "DaizML_Pre_" .. uid
    local POST_ID = "DaizML_Post_" .. uid
    local UNLOAD_ID = "DaizML_U_" .. uid
    local tick = M._tick
    local inputFn = M._input
    local keyWasDown = false

    local function keyDown(code)
        local down = false
        if not code or code == 0 then return false end
        pcall(function() down = input.IsButtonDown(code) end)
        return down and true or false
    end

    local function hostDraw()
        pcall(function()
            if followAimware and followAimware.Get then
                M._followAimwareMenu = followAimware:Get() and true or false
            end
            if menuKey and menuKey.Get then
                M._menuToggleKey = tonumber(menuKey:Get()) or 0
            end

            local slot = selectedSlotIndex()
            if slot ~= lastConfigSlot then
                lastConfigSlot = slot
                syncNameFromSlot()
                local cfgSlot = Config.slots[slot]
                if cfgSlot then
                    applyValues(cfgSlot)
                end
            end

            local ap = appearanceFingerprint()
            if ap ~= lastAppearance then
                lastAppearance = ap
                applyAppearanceFromWidgets()
            end

            local wmFp = watermarkFingerprint()
            if wmFp ~= lastWatermark then
                lastWatermark = wmFp
                applyWatermarkFromWidgets()
            end

            local seFp = stepEspFingerprint()
            if seFp ~= lastStepEsp then
                lastStepEsp = seFp
                applyStepEspFromWidgets()
            end

            local trFp = coachTrailFingerprint()
            if trFp ~= lastCoachTrail then
                lastCoachTrail = trFp
                applyCoachTrailFromWidgets()
            end

            pcall(DeathUI.pollWarn)
        end)

        if not M._followAimwareMenu and not M._keybox then
            local code = tonumber(M._menuToggleKey) or 0
            local down = keyDown(code)
            if down and not keyWasDown then
                M._menuVisible = not M._menuVisible
            end
            keyWasDown = down
        else
            keyWasDown = false
        end

        pcall(stepUpdate)
        pcall(stepDraw)
        pcall(trailUpdate)
        pcall(trailDraw)
        pcall(deathFxUpdate)
        pcall(veloDraw)
        pcall(keysDraw)
        pcall(function()
            if type(M._ensureSteamAvatar) == "function" then M._ensureSteamAvatar() end
        end)
        pcall(liveStatsDraw)
        pcall(function()
            local R = LiveStatsPos.RadarHud
            if R and R.tick then R.tick() end
            if R and R.draw then R.draw() end
            draw.SetTexture(nil)
        end)
        if type(GH.draw) == "function" then pcall(GH.draw) end

        if type(tick) == "function" then
            local ok, err = pcall(tick)
            if not ok then print("[DaizML] tick error: " .. tostring(err)) end
        end

    end

    pcall(function()
        callbacks.Register("Draw", DRAW_ID, hostDraw)
    end)
    pcall(function()
        callbacks.Register("CreateMove", MOVE_ID, function(cmd)
            pcall(leftKnifeUpdate)
            pcall(sniperQsUpdate, cmd)
            pcall(deagleQsUpdate, cmd)
            if type(GH.onCreateMove) == "function" then pcall(GH.onCreateMove, cmd) end
            if type(inputFn) == "function" then pcall(inputFn, cmd) end
        end)
    end)
    pcall(function()
        callbacks.Register("PreMove", PRE_ID, function(cmd)
            if type(GH.onPreMove) == "function" then pcall(GH.onPreMove, cmd) end
        end)
    end)
    pcall(function()
        callbacks.Register("PostMove", POST_ID, function(cmd)
            if type(GH.onPostMove) == "function" then pcall(GH.onPostMove, cmd) end
        end)
    end)
    pcall(function()
        callbacks.Register("Unload", UNLOAD_ID, function()
            CoachTrail.particle_idx = nil
            CoachTrail.particle_live = {}
            CoachTrail.points = {}
            if type(ParticleAPI.invalidateSession) == "function" then
                pcall(ParticleAPI.invalidateSession, "unload")
            end
            pcall(leftKnifeReset)
            if VM.wasEnabled then pcall(VM.restore) end
            if VM.fovApplied then pcall(VM.restoreFov) end
            pcall(callbacks.Unregister, "Draw", DRAW_ID)
            pcall(callbacks.Unregister, "CreateMove", MOVE_ID)
            pcall(callbacks.Unregister, "PreMove", PRE_ID)
            pcall(callbacks.Unregister, "PostMove", POST_ID)
            pcall(callbacks.Unregister, "FireGameEvent", "daizml_death_fx")
            pcall(callbacks.Unregister, "FireGameEvent", "daizml_trail_round")
            pcall(callbacks.Unregister, "FireGameEvent", "daizml_live_stats")
            if liveStatsEventId then
                pcall(callbacks.Unregister, "FireGameEvent", liveStatsEventId)
            end
        end)
    end)
end)()


print("[DaizML] ready " .. DAIZML_VERSION)
