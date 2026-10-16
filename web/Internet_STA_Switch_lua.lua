-- YulCaribe H298A repeater control v0.3 (experimental, RAM-only)
-- ZTE NetSphere Mode=Master/Slave/auto is NOT the same as WORK_MODE_REPEATER=7.
-- Only fixed, allowlisted shell helper actions are executed.

local function esc(v)
    v = tostring(v or '')
    v = string.gsub(v, '[%z\1-\8\11\12\14-\31]', '')
    v = string.gsub(v, '&', '&amp;')
    v = string.gsub(v, '<', '&lt;')
    v = string.gsub(v, '>', '&gt;')
    v = string.gsub(v, '"', '&quot;')
    v = string.gsub(v, "'", '&apos;')
    return v
end
local function node(k, v) return '<' .. k .. '>' .. esc(v) .. '</' .. k .. '>' end
local function grab(obj, inst)
    if not cmapi or not cmapi.getinst then return {} end
    local ok, data = pcall(cmapi.getinst, obj, inst)
    if ok and type(data) == 'table' then return data end
    return {}
end
local function readfile(path, max)
    local f = io.open(path, 'rb')
    if not f then return '' end
    local content = f:read(max or 20000) or ''
    f:close()
    return content
end
local function make_private_dir()
    if not os or not os.execute then return false, 'os.execute unavailable in this CGI runtime' end
    local rc = os.execute('mkdir -p /tmp/yc_repeater && chmod 700 /tmp/yc_repeater')
    if rc ~= 0 and rc ~= true then return false, 'Unable to create private runtime directory' end
    return true, ''
end
local function private_file(path, data)
    -- Never place credentials in URLs, shell command strings or debug logs.
    local f = io.open(path, 'wb')
    if not f then return false end
    f:write(data, '\n')
    f:close()
    os.execute('chmod 600 ' .. path)
    return true
end
local CMD = {
    Scan2g = 'scan2g', Scan5g = 'scan5g',
    Connect2g = 'connect2g', Connect5g = 'connect5g',
    Publish2g = 'publish2g', Publish5g = 'publish5g',
    APOn2g = 'apon2g', APOff2g = 'apoff2g',
    APOn5g = 'apon5g', APOff5g = 'apoff5g',
    Mode7 = 'mode7', Mode1 = 'mode1', ConfirmMode = 'confirm',
    FullStatus = 'status', ModeLog = 'log'
}
local action = 'Status'
local output = ''
local errmsg = ''
local errcode = '0'
local p = cgilua.POST or {}
local paction = tostring(p.IF_ACTION or '')
local function bad(code, msg)
    errcode = tostring(code)
    errmsg = tostring(msg)
end

if paction ~= '' then
    action = paction
    local verb = CMD[action]
    if not verb then
        bad(400, 'Unknown action')
    else
        local ok, why = make_private_dir()
        if not ok then bad(501, why)
        else
            if action == 'Publish2g' or action == 'Publish5g' or
               action == 'Connect2g' or action == 'Connect5g' then
                local ssid = tostring(p.SSID or '')
                local key = tostring(p.Key or '')
                if #ssid < 1 or #ssid > 32 or string.find(ssid, '[%c]') then
                    bad(422, 'SSID must be 1-32 bytes without control characters')
                elseif #key < 8 or #key > 63 or string.find(key, '[%c]') then
                    bad(422, 'WPA2 password must be 8-63 bytes without control characters')
                else
                    local prefix
                    if action == 'Publish2g' then prefix = '/tmp/yc_repeater/ap_2g'
                    elseif action == 'Publish5g' then prefix = '/tmp/yc_repeater/ap_5g'
                    else prefix = '/tmp/yc_repeater/sta' end
                    if not private_file(prefix .. '_ssid', ssid) or
                       not private_file(prefix .. '_psk', key) then
                        bad(503, 'Cannot write protected temporary profile')
                    end
                end
            end
            if errcode == '0' then
                -- 'verb' is from a hardcoded whitelist. User input never enters a shell command.
                local rc = os.execute('/bin/sh /tmp/yc_repeater.sh ' .. verb ..
                           ' > /tmp/yc_repeater/last_action.log 2>&1')
                output = readfile('/tmp/yc_repeater/last_action.log', 30000)
                if rc ~= 0 and rc ~= true then
                    bad(550, 'Driver/command error (see Output)')
                end
            end
        end
    end
end

local master = grab('OBJ_NETSPHERE_MAP_ID', 'DEV.MULTIAPCFG')
local ap2g = grab('OBJ_WLANAP_ID', 'DEV.WIFI.AP1')
local ap5g = grab('OBJ_WLANAP_ID', 'DEV.WIFI.AP5')
local out = '<?xml version="1.0" encoding="UTF-8"?>' ..
    '<YCRepeater>' ..
    node('IF_ERRORID', errcode) .. node('IF_ERRORSTR', errmsg) ..
    node('Action', action) ..
    node('NetSphereMode', master.Mode or '') ..
    node('NetSphereEnable', master.Enable or '') ..
    '<AP2G>' .. node('ESSID', ap2g.ESSID or '') .. node('Enable', ap2g.Enable or '') .. '</AP2G>' ..
    '<AP5G>' .. node('ESSID', ap5g.ESSID or '') .. node('Enable', ap5g.Enable or '') .. '</AP5G>' ..
    node('Output', output) ..
    node('ModeLog', readfile('/tmp/yc_repeater/mode.log', 4000)) ..
    node('Build', 'YulCaribe-H298A-repeater-v0.3') ..
    '</YCRepeater>'

cgilua.put(out)
