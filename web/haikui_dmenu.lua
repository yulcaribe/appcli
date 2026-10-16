-- H298A TTN - YulCaribe WiFi Repeater menu extension
-- Reconstructed from the stock haikui_dmenu.lua and extended with one top-level menu.
-- Target: Lua 5.1 / ZTE Haikui web UI

local dmenu_register = dmenuapi.dmenu_register

local function haikui_opdmenu()
    -- Stock H298A additions preserved.
    dmenu_register(
        "smInternetStatus", "smInternetWan", "", "insert",
        {
            "ssmInternet3GStatus",
            {"Internet_InternetStatus_Internet3GStatus_t.lp"},
            0, 0, 0,
            lang["Internet3GStatus_012"],
            lang["Internet3GStatus_013"]
        },
        {
            ["Mobile3GStatus_lua.lua"] = 0,
            ["WAN3GStatus_lua.lua"] = 0
        }
    )

    dmenu_register(
        "smInternetCof", "smInternetEth", "", "insert",
        {
            "smInternet3G",
            {"Internet_Internet3G_t.lp"},
            1, 0, 0,
            lang["Internet3G_001"],
            lang["Internet3G_002"]
        },
        {
            ["Internet_Internet3G_lua.lua"] = 1,
            ["DongleManage_lua.lua"] = 1
        }
    )

    dmenu_register(
        nil, "mmHome", 1, "insert",
        {
            "mmTopo_a",
            {"topo_t.lp"},
            0, 0, 0,
            lang["pro_topo_001"],
            nil
        },
        {
            ["topo_lua.lua"] = 0
        }
    )

    -- YulCaribe: new first-class top menu, next to the stock main menus.
    dmenu_register(
        nil, "mmLocalnet", 1, "insert",
        {
            "mmWifiRepeater",
            {"Internet_STA_t.lp"},
            1, 0, 0,
            "WiFi Repeater",
            "ZTE native repeater controls / YulCaribe"
        },
        {
            ["Internet_Internet_lua.lua"] = 1,
            ["Internet_STA_Switch_lua.lua"] = 1,
            ["Internet_STA_WLANProfile_lua.lua"] = 1
        }
    )
end

haikui_opdmenu()
