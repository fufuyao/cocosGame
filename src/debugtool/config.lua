
local Config = {
    synclog         = false,                        -- 是否同步print日志到webserver
    logserver       = "https://logdebug.tcy365.org:2505",                -- webserver地址
    gmenable        = true,                         -- 是否连接指令服务器
    gmserver        = "logdebug.tcy365.org",        -- 指令服务器地址
    gmport          = 7777,
    memenable       = false,                        -- 是否一直显示内存信息
}

return Config
