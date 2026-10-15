-- YulCaribe H298A WiFi Repeater: read-only WLAN object probe.
-- This intentionally does NOT write SSID/password yet.
-- Goal: map ZTE's hidden STA/APCLI profile object without guessing on flash.

local function xesc(v)
    v = tostring(v or "")
    v = string.gsub(v, "&", "&amp;")
    v = string.gsub(v, "<", "&lt;")
    v = string.gsub(v, ">", "&gt;")
    v = string.gsub(v, '"', "&quot;")
    v = string.gsub(v, "'", "&apos;")
    return v
end

local function list_obj(obj, root)
    local ok, ret = pcall(cmapi.querylist, obj, root)
    if not ok then
        return '<Object name="' .. xesc(obj) .. '" error="' .. xesc(ret) .. '" />'
    end
    if type(ret) ~= "table" then
        return '<Object name="' .. xesc(obj) .. '" error="non-table" />'
    end

    local buf = {'<Object name="' .. xesc(obj) .. '" count="' .. tostring(#ret) .. '">'}
    local max = #ret
    if max > 32 then max = 32 end
    for i = 1, max do
        buf[#buf + 1] = '<Inst>' .. xesc(ret[i]) .. '</Inst>'
    end
    buf[#buf + 1] = '</Object>'
    return table.concat(buf)
end

local out = '<?xml version="1.0" encoding="UTF-8"?>' ..
    '<WLANProbe>' ..
    '<IF_ERRORID>0</IF_ERRORID>' ..
    '<IF_ERRORSTR>SUCC</IF_ERRORSTR>' ..
    '<WriteEnabled>0</WriteEnabled>' ..
    '<Note>Read-only probe; no SSID or password is modified.</Note>' ..
    list_obj('OBJ_WLANSETTING_ID', 'IGD') ..
    list_obj('OBJ_WLANAP_ID', 'IGD') ..
    list_obj('OBJ_WLANPSK_ID', 'IGD') ..
    '<FirmwareEvidence>WORK_MODE_REPEATER; workmode_repeater; ApCliSsid; ApCliWPAPSK</FirmwareEvidence>' ..
    '<Build>YulCaribe-H298A-repeater-debug-v0.1</Build>' ..
    '</WLANProbe>'

cgilua.put(out)
