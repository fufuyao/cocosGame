local color      = require("debuglog.color")

local LogReadableHelper = {}
LogReadableHelper.COLOR = {red="",green="",normal=""}


local function checkArgType(arg)
    if type(arg) == "table" then
        -- local result = dump(arg, "table_table", 10, 10086)
        -- arg = table.concat(result, "\n")
        arg = json.encode(arg)
    else
        arg = tostring(arg)
    end

    return arg
end

function LogReadableHelper.init(userName)
    LogReadableHelper.userName = userName
end
function LogReadableHelper.colorPrint(funcName,...)

    local colors = {}
    colors["trace"] = color.BLUE
    colors["debug"] = color.CYAN
    colors["info"]  = color.GREEN
    colors["warn"]  = color.YELLOW
    colors["error"] = color.RED
    colors["fatal"] = color.PURPLE
    local intColor = colors[funcName] or color.GREEN
    color.colorPrint(intColor,'['..funcName..']', ...)
end
local function getLogDir()
    local dir = "E:/cocos2d-x/cocos2dx_lua_skynet_client-master/readable_log/"
    if not cc.FileUtils:getInstance():isDirectoryExist(dir) then
         cc.FileUtils:getInstance():createDirectory(dir)
    end

    -- if device.platform == "windows" then
    --     return dir
    -- end
    -- -- print(LogReadableHelper.userName,"LogReadableHelper.userNam")
    dir = dir .. os.date("%Y%m%d/")
    if not cc.FileUtils:getInstance():isDirectoryExist(dir) then
         cc.FileUtils:getInstance():createDirectory(dir)
    end
    return dir
end

local function write2File(loggertype, string)
	local fileName = getLogDir()..LogReadableHelper.userName..'-log.html'
    local file = io.open(fileName, "a")
    if file then
        local content = os.date("%Y-%m-%d %H:%M:%S") ..": " ..string ..'\n'
        content = string.format("<meta charset='utf-8'><font color=%s>%s</font><br/>",loggertype,content)
        file:write(content)
        file:write("\n")
        file:close()
    end

    --// 分文件 每1M
    local fileSize = cc.FileUtils:getInstance():getFileSize(fileName)
    local part = math.floor(fileSize / (1024 * 1024))

    if part < 0 then
        part = 0
    end

    fileName = getLogDir()..LogReadableHelper.userName.."-log-part-" ..part ..'.html'
	local file = io.open(fileName, "a")
	if file then
        local content = os.date("%Y-%m-%d %H:%M:%S") ..": " ..string ..'\n'
        content = string.format("<meta charset='utf-8'><font color=%s>%s</font><br/>",loggertype,content)
		file:write(content)
		file:write("\n")
		file:close()
	end
end
-- 标记
function LogReadableHelper.trace(data)

    if type(data) == "table" then
        local content = json.encode(data)

        local isRequest = data.request
        if isRequest then
            write2File("blue",content)
        else
            write2File("green",content)
        end
    end
    LogReadableHelper.colorPrint("trace", checkArgType(data))
end
-- 普通
function LogReadableHelper.info(data)

    if type(data) ~= "table" then
        data = {data}
    end
    data = data or {}
    local msg = json.encode(data)
    write2File("black",msg)
    LogReadableHelper.colorPrint("info",checkArgType(data))
end
-- 报错
function LogReadableHelper.error(data)

    if type(data) ~= "table" then
        data = {data}
    end
    data = data or {}
    local msg = json.encode(data)
    write2File("red",msg)
    data.error = "erro"
    LogReadableHelper.colorPrint("error",checkArgType(data))
end
--
function LogReadableHelper.debug(info, isWrite2File, dumpName, nesting)
    LogReadableHelper.info({"[debug]",dumpName,info})
    LogReadableHelper.colorPrint("debug",dumpName,info)
end
function LogReadableHelper.warn(info, isWrite2File, dumpName, nesting)
    LogReadableHelper.info({"[warn]",dumpName,info})
    LogReadableHelper.colorPrint("warn",dumpName,info)
end

return LogReadableHelper
