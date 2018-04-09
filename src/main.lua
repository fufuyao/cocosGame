cc.FileUtils:getInstance():setPopupNotify(false)
cc.FileUtils:getInstance():addSearchPath("src/")
cc.FileUtils:getInstance():addSearchPath("res/")

require "config"
require "cocos.init"
require "app.common.ServerConfig"
require "app.util.init"
require("debugtool.init")

local function main()
	--初始化日志文件
	CCLog.init(os.date("%H-%M-%S"))
	cc.exports.myApp = require("app.MyApp"):create()
	myApp:run()
end

__G__TRACKBACK__ = function(msg)
    -- 覆盖全局的__G__TRACKBACK__才能处理所有的异常
    local msg = debug.traceback(msg, 3)
	 
	--报错打印
    if CCLog and CCLog.error then
        CCLog.error(msg)
    end
    return msg
end

local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
    print(msg)
end
