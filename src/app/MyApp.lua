
local MyApp = class("MyApp", cc.load("mvc").AppBase)

function MyApp:onCreate()
    math.randomseed(os.time())
	--后台切换监听
	local listener1 = cc.EventListenerCustom:create("APP_ENTER_BACKGROUND", handler(self,self.applicationDidEnterBackground))
	cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listener1, 1)
	
	local listener2 = cc.EventListenerCustom:create("APP_EXIT_BACKGROUND", handler(self,self.applicationWillEnterForeground))
	cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listener2, 1)
	
    Socket_TCP = require("network.client")

    if GameTCP == nil then
		GameTCP = Socket_TCP.create()
    end
	GameTCP:addEventListener(Socket_TCP.EVENT_CONNECTED,self,self.onServerState)
    GameTCP:addEventListener(Socket_TCP.EVENT_CLOSED,self,self.onServerState)
    GameTCP:addEventListener(Socket_TCP.EVENT_CONNECT_FAILURE,self,self.onServerState)	
	GameTCP:connect(SERVER_IP,SERVER_PORT)
end

-- 服务器链接状态
function MyApp:onServerState(eventSockct)
	if not Socket_TCP then
		return
	end
	if eventSockct.name == Socket_TCP.EVENT_CONNECTED then
		CCLog.trace("服务器连接成功")
		GameTCP:sendRPC("login.login",{account = "123", passwd = "123"},self,self.login)
	elseif eventSockct.name == Socket_TCP.EVENT_CLOSED  then
		CCLog.trace("网络无法连接")
	elseif eventSockct.name == Socket_TCP.EVENT_CONNECT_FAILURE  then
		CCLog.trace("服务器连接失败")
	end
end

function MyApp:login(resp)
	CCLog.info(resp)
end

--切换到后台暂停
function MyApp:applicationDidEnterBackground()
	print("applicationDidEnterBackground")
end

--后台切换回来
function MyApp:applicationWillEnterForeground()
	 print("applicationWillEnterForeground")
end

return MyApp
