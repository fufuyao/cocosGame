local SOCKET_TICK_TIME = 0.1 			-- check socket data interval
local SOCKET_RECONNECT_TIME = 5			-- socket reconnect try interval
local SOCKET_CONNECT_FAIL_TIMEOUT = 5	-- socket failure timeout

local STATUS_CLOSED = "closed"
local STATUS_NOT_CONNECTED = "Socket is not connected"
local STATUS_ALREADY_CONNECTED = "already connected"
local STATUS_ALREADY_IN_PROGRESS = "Operation already in progress"
local STATUS_TIMEOUT = "timeout"

local socket = require "socket"
local bit32 = require "bit32"
local assert = assert
local print = print
local strchar = string.char
local SocketTCP = class("SocketTCP")

local reszlib , zlib = pcall(require,"zlib")


--local LoadingTimer = require("util.LoadingTimer"):getInstance()
--local LoadingManager = require("util.LoadingManager"):getInstance()


SocketTCP.EVENT_DATA = "SOCKET_TCP_DATA"
SocketTCP.EVENT_PING = "SOCKET_TCP_DATA_PING"
SocketTCP.EVENT_CLOSE = "SOCKET_TCP_CLOSE"
SocketTCP.EVENT_CLOSED = "SOCKET_TCP_CLOSED"
SocketTCP.EVENT_CONNECTED = "SOCKET_TCP_CONNECTED"
SocketTCP.EVENT_CONNECT_FAILURE = "SOCKET_TCP_CONNECT_FAILURE"

SocketTCP._VERSION = socket._VERSION
SocketTCP._DEBUG = socket._DEBUG


local printf = function(...)
    print(string.format(...))
end

SocketTCP.host = nil
SocketTCP.request = nil

function SocketTCP.getTime()
	return socket.gettime()
end

function SocketTCP.setHost( __host ,__request)
	SocketTCP.host = __host
	SocketTCP.request =  __request
end

function SocketTCP.create( __host, __port, __retryConnectWhenFailure )
	local s = SocketTCP.new(__host, __port, __retryConnectWhenFailure)
	return s
end

function SocketTCP:ctor(__host, __port, __retryConnectWhenFailure)
	EventProtocol.extend(self)

    self.host = __host
    self.port = __port
	self.tickScheduler = nil			-- timer for data
	self.reconnectScheduler = nil		-- timer for reconnect
	self.connectTimeTickScheduler = nil	-- timer for connect timeout
	self.name = 'SocketTCP'
	self.tcp = nil
	self.isRetryConnect = __retryConnectWhenFailure
	self.isConnected = false

	self.session = 0
	self.rpcMap={}
    self.rpcDataHandlerMap = self.rpcDataHandlerMap or {}
    self.lockSession = nil
    self.lockSessionRPC = {}
    self.sessionTempData = {}

    self.losePacks = {}
end

function SocketTCP:setName( __name )
	self.name = __name
	return self
end

function SocketTCP:setTickTime(__time)
	SOCKET_TICK_TIME = __time
	return self
end

function SocketTCP:setReconnTime(__time)
	SOCKET_RECONNECT_TIME = __time
	return self
end

function SocketTCP:setConnFailTime(__time)
	SOCKET_CONNECT_FAIL_TIMEOUT = __time
	return self
end

function SocketTCP:connect(__host, __port, __retryConnectWhenFailure)
	-- print(debug.traceback())
	if __host then self.host = __host end
	if __port then self.port = __port end
	if __retryConnectWhenFailure ~= nil then self.isRetryConnect = __retryConnectWhenFailure end
	assert(self.host or self.port, "Host and port are necessary!")
	assert(SocketTCP.host, "SocketTCP.host is nil call SocketTCP.setHost(host)")
	printf("%s.connect(%s, %d) time :%s", self.name, self.host, self.port,socket.gettime())
	
	-- ipv6支持
	local isipv6_only = false
	local addrinfo, err = socket.dns.getaddrinfo(self.host)
	for i,v in ipairs(addrinfo) do
		if v.family == "inet6" then
			isipv6_only = true;
			break
		end
	end
	print("isipv6_only", isipv6_only)
	-- dump(addrinfo)
	if isipv6_only then
		self.tcp = socket.tcp6()
	else
		self.tcp = socket.tcp() 
	end
	
	self.tcp:settimeout(0)
	self.last_timeout = 0
	self.last = ""

	local function __checkConnect()
		local __succ = self:_connect()
		if __succ then
			self:_onConnected()
		end
		return __succ
	end

	if not __checkConnect() then
		-- check whether connection is success
		-- the connection is failure if socket isn't connected after SOCKET_CONNECT_FAIL_TIMEOUT seconds
		local __connectTimeTick = function ()
			-- printf("%s.connectTimeTick", self.name)
			if self.isConnected then return end
			self.waitConnect = self.waitConnect or 0
			self.waitConnect = self.waitConnect + SOCKET_TICK_TIME
			if self.waitConnect >= SOCKET_CONNECT_FAIL_TIMEOUT then
				-- print(self.waitConnect,SOCKET_CONNECT_FAIL_TIMEOUT,"ffff")
				self.waitConnect = nil
				self:close()
				self:_connectFailure()
			end
			__checkConnect()
		end
		self.connectTimeTickScheduler = scheduler.scheduleGlobal(__connectTimeTick, SOCKET_TICK_TIME)
	end
end

--发送一个rpc请求
--lockSession  锁定这个回话过程中的收到的其他数据包  直到回话被结束
function SocketTCP:sendRPC(msgname,msdobj,obj,method,lockSession)
	if self.isConnected == false then
		print("SocketTCP has close(),cache pack now send on reconnect",msgname)
	end
    local session = self:sendMsg(msgname,msdobj)
    if msgname ~="handshake" then
		traceObj(msdobj,"Send "..session.." "..msgname.." time:"..socket.gettime())
	end
	-- print("send:"..session,msgname,socket.gettime())
	local handlerID = 0
    if obj and method then
		handlerID = handler(obj, method)
    end
    self:addEventListener(session, self, self.dispatchPRC)
    self.rpcMap[session]= {msgname,handlerID}

    if lockSession then
		self.lockSessionRPC[session] = {}
		self.lockSession = session
    end
	if msdobj then
		msdobj.__send_time = socket.gettime()
	end
    self.sessionTempData[session] = msdobj

    --LoadingTimer:insertDataSign(session, os.clock(), 1, 0, false, msgname)

    return session
end

--当rpc处理数据的时候挂钩子处理对应数据
function SocketTCP:addDataHandler(eventName,obj,method)
    assert(obj~=nil and method~=nil, "SocketTCP:addDataHandler obj or method is nil")
    self.rpcDataHandlerMap[eventName] = handler(obj,method)
end

--移除rpc回调监听
function SocketTCP:removeDataHandler( eventName )
	self.rpcDataHandlerMap[eventName] = nil
end

--转发一个处理结果
function SocketTCP:dispatchPRC(eventSockct)
    if eventSockct.type == "RESPONSE" then
		-- trace("RESPONSE:", eventSockct.name)
        --name 为session
        self:removeEventListener(eventSockct.name,self)
        local map = self.rpcMap[eventSockct.name]
        if map then
            local eventName = map[1]
            local handlerID = map[2]

            if not G_filter_packet[eventName] then
				traceObj(eventSockct.result,"RESPONSE Rev "..eventSockct.name.."  "..eventName.." time:"..socket.gettime())
	        end

	        --锁定的回话结束
	        if self.lockSession == tostring(eventSockct.name) then
				eventSockct.result.session = eventSockct.name
				self.lockSession = nil
	        end

            --处理resquset或者response的数据
            local gHandler = self.rpcDataHandlerMap[eventName]

            if gHandler then
                gHandler(eventSockct.result)
            end
            if handlerID ~= 0 then
				local sessionID = eventSockct.name
				local send_msg = self.sessionTempData[sessionID]
				if send_msg then
					local ping = math.ceil((socket.gettime()-send_msg.__send_time)/2*1000)
					self:dispatchEvent({name=SocketTCP.EVENT_PING,data=ping})
				end
				handlerID(eventSockct.result,send_msg)
				send_msg = nil
				self.sessionTempData[eventSockct.name]=nil
            end
            self.rpcMap[eventSockct.name] = nil
        else
            trace("rpc session is not find"..eventSockct.name.." time:"..socket.gettime())
        end
    elseif eventSockct.type == "REQUEST" then
		-- trace("PUSH:", eventSockct.name,G_filter_packet[eventSockct.name])
        --name 为 事件名称

        --处理resquset或者response的数据
        local gHandler = self.rpcDataHandlerMap[eventSockct.name]
        if gHandler then
	        if self.lockSession then
				-- 如果回话被锁定  回话中间的请求数据包被缓存 直到回话结束才执行
				local temp = self.lockSessionRPC[self.lockSession]
				table.insert(temp,{handler=gHandler,data = eventSockct.result,time =os.time(),name=eventSockct.name})
				-- print("lock ",type(self.lockSession),self.lockSession)
	        else
				for i,v in pairs(self.lockSessionRPC) do
					for m,n in ipairs(v) do
						if n.name == eventSockct.name then
							table.strucRemove(n.data,eventSockct.result)
						end
					end
				end

				if not G_filter_packet[eventSockct.name] then
					traceObj(eventSockct.result,"PUSH Rev==> "..eventSockct.name.."  time "..socket.gettime(),6)
				end
		        gHandler(eventSockct.result)
	        end
	    end
    end
end

--回话结束 执行回话中间的数据包
function SocketTCP:endSession(sessionID)
	local temp = self.lockSessionRPC[sessionID]
	if temp then
		for i,v in ipairs(temp) do
			if v.data then
				v.handler(v.data)
				-- print("send session "..sessionID.."  time "..v.time)
			end
		end
		self.lockSessionRPC[sessionID] = nil
	end
end


function SocketTCP:sendMsg(msgname,msdobj)
	
	self.session = self.session + 1
	-- print("send",self.session,os.date(),msgname,"   last timeout",socket.gettime()- self.last_timeout)
	local str = SocketTCP.request(msgname,msdobj,self.session)
	-- print(socket.gettime(),self.session,"send:",msgname,#str+2)
	self:send(str)
	return tostring(self.session)
end

function SocketTCP:send(pack)
	--assert(self.isConnected, self.name .. " is not connected.")
	local size = #pack
	local package = strchar(bit32.extract(size,8,8)) ..
		strchar(bit32.extract(size,0,8))..pack
	if self.isConnected then
		self.tcp:send(package)
	else
		self.losePacks[#self.losePacks+1] = package
	end
end

function SocketTCP:close( ... )
	printf("%s.close: %s : %s  time:%s", self.name,self.host,self.port,socket.gettime())
	self.tcp:close();
	if self.connectTimeTickScheduler then
		scheduler.unscheduleGlobal(self.connectTimeTickScheduler)
		self.connectTimeTickScheduler = nil
	end
	if self.tickScheduler then
		scheduler.unscheduleGlobal(self.tickScheduler)
		self.tickScheduler = nil
	end
	self:dispatchEvent({name=SocketTCP.EVENT_CLOSE})
end

function SocketTCP:isConnect()
	return self.isConnected
end

-- disconnect on user's own initiative.
function SocketTCP:disconnect()
	self:_disconnect()
	self.isRetryConnect = false -- initiative to disconnect, no reconnect.
end

--------------------
-- private
--------------------

--- When connect a connected socket server, it will return "already connected"
-- @see: http://lua-users.org/lists/lua-l/2009-10/msg00584.html
function SocketTCP:_connect()
	local __succ, __status = self.tcp:connect(self.host, self.port)
	-- printf("SocketTCP._connect:", __succ, __status)
	return __succ == 1 or __status == STATUS_ALREADY_CONNECTED
end

function SocketTCP:_disconnect()
	self.isConnected = false
	self.tcp:shutdown()
	self:dispatchEvent({name=SocketTCP.EVENT_CLOSED})
end

function SocketTCP:_onDisconnect()
	--printf("%s._onDisConnect", self.name);
	self.isConnected = false
	self:dispatchEvent({name=SocketTCP.EVENT_CLOSED})
	self:_reconnect();
end

-- connecte success, cancel the connection timerout timer
function SocketTCP:_onConnected()
	printf("%s.onConnectd: %s : %s time:%s losepack:%s", self.name,self.host,self.port,socket.gettime(),#self.losePacks)
	self.isConnected = true
	self:dispatchEvent({name=SocketTCP.EVENT_CONNECTED})

	for i,v in ipairs(self.losePacks) do
		if v then
			self.tcp:send(v)
		end
	end

	if self.connectTimeTickScheduler then
		scheduler.unscheduleGlobal(self.connectTimeTickScheduler)
		self.connectTimeTickScheduler = nil
	end
	if self.tickScheduler then
		scheduler.unscheduleGlobal(self.tickScheduler)
		self.tickScheduler = nil
	end
	
	local __tick = function()
		local function readTcp(len)
			local r ,__status = self.tcp:receive(len)
			local now_time = socket.gettime()
			if self.last_timeout>0 and now_time- self.last_timeout > 18 then
				self:dispatchEvent({name=SocketTCP.EVENT_PING,data=math.ceil(now_time- self.last_timeout)*1000})
				if now_time- self.last_timeout > 25 then
					-- print(__status,"timeout socket",now_time- self.last_timeout)
					__status = STATUS_CLOSED
				end
			end

			if r then
				-- print("self.last_timeout",self.last_timeout)
				self.last_timeout = now_time
			end
			if __status == STATUS_CLOSED or __status == STATUS_NOT_CONNECTED then
				print("read tcp error,close connect",__status)
				self:close()
				if self.isConnected then
					self:_onDisconnect()
				else
					self:_connectFailure()
				end
				return nil
			end
			return r
		end

		local function readHead()
			local temp = readTcp(2)
			if temp then
				return  temp:byte(1) * 256 + temp:byte(2)
			else
				return nil
			end
		end

		local function recv_package(headSize)
			repeat
				body = readTcp(headSize)
			until body

			if zlib and string.byte(body,1) == 120 and string.byte(body,2) == 156 then
				local unzip = zlib.inflate()
				body = unzip(body,"finish")
			end

			local type, nameOrSession, result, response = SocketTCP.host:dispatch(body)
			local event = {name=nameOrSession,type = type, result=result,response=response}
			-- print(socket.gettime(),nameOrSession,"recv:",#body)
			if type == "RESPONSE" then
				-- self:dispatchEvent(event) 修改为捕获错误，防止加载框没有移除
				local ok ,err = pcall(self.dispatchEvent,self,event)
				if ok == false then
					print("error on TCP dispatchEvent ",nameOrSession,err)
				end
				--LoadingTimer:deleteDataSign(event.name)
			else
				local ok ,err = pcall(self.dispatchPRC,self,event)
				if ok == false then
					print("error on TCP dispatchEvent ",nameOrSession,err)
				end
			end
		end
		local headSize
		repeat
			headSize = readHead()
			if headSize then
				recv_package(headSize)
			end
		until headSize==nil
	end

	-- start to read TCP data
	self.tickScheduler = scheduler.scheduleGlobal(__tick, 0)
end

function SocketTCP:_connectFailure(status)
	-- print(debug.traceback())
	printf("%s.connectFailure:%s : %s  time:%s", self.name,self.host,self.port,socket.gettime())
	self:dispatchEvent({name=SocketTCP.EVENT_CONNECT_FAILURE})
	self:_reconnect();
end

-- if connection is initiative, do not reconnect
function SocketTCP:_reconnect(__immediately)
	if not self.isRetryConnect then return end
	printf("%s.reconnect", self.name)
	if __immediately then self:connect() return end
	if self.reconnectScheduler then scheduler.unscheduleGlobal(self.reconnectScheduler) end
	local __doReConnect = function ()
		self:connect()
	end
	self.reconnectScheduler = scheduler.performWithDelayGlobal(__doReConnect, SOCKET_RECONNECT_TIME)
end

return SocketTCP