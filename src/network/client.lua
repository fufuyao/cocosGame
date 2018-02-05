local SOCKET_TICK_TIME = 0.1 			-- check socket data interval
local SOCKET_CONNECT_FAIL_TIMEOUT = 5	-- socket failure timeout

local STATUS_CLOSED = "closed"
local STATUS_NOT_CONNECTED = "Socket is not connected"
local STATUS_ALREADY_CONNECTED = "already connected"
local STATUS_ALREADY_IN_PROGRESS = "Operation already in progress"
local STATUS_TIMEOUT = "timeout"

local socket = require "socket.core"
local Packer = require "network.packer"
--local scheduler = cc.Director:getInstance():getScheduler()

local SocketTCP = class("SocketTCP")

SocketTCP.EVENT_DATA = "SOCKET_TCP_DATA"
SocketTCP.EVENT_PING = "SOCKET_TCP_DATA_PING"
SocketTCP.EVENT_CLOSE = "SOCKET_TCP_CLOSE"
SocketTCP.EVENT_CLOSED = "SOCKET_TCP_CLOSED"
SocketTCP.EVENT_CONNECTED = "SOCKET_TCP_CONNECTED"
SocketTCP.EVENT_CONNECT_FAILURE = "SOCKET_TCP_CONNECT_FAILURE"

function SocketTCP:ctor()
	EventProtocol.extend(self)
	self.last = ""
	self.pack_list = {}
	self.head = nil
	self.callback_tbl = {}
	self.tcp = nil
	self.isConnected = false
	self.losePacks = {}
	self.name = 'SocketTCP'
end

function SocketTCP:connect(ip, port)
	self.ip = ip
     self.port = port
     -- ipv6支持
     local isipv6_only = false
     local addrinfo, err = socket.dns.getaddrinfo(self.ip)
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

     --local n,e = sock:connect(ip, port)
     self.tcp:settimeout(0)
	self.last_timeout = 0
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

function SocketTCP:_connect()
	local __succ, __status = self.tcp:connect(self.ip, self.port)
	-- printf("SocketTCP._connect:", __succ, __status)
	return __succ == 1 or __status == STATUS_ALREADY_CONNECTED
end

function SocketTCP:_onConnected()
	print("%s.onConnectd: %s : %s time:%s losepack:%s", self.name,self.host,self.port,socket.gettime(),#self.losePacks)
	self.isConnected = true

	self:dispatchEvent({name=SocketTCP.EVENT_CONNECTED})
	
	--重新发出没有发出的包
	for i,v in ipairs(self.losePacks) do
		if v then
			self.tcp:send(v)
		end
	end
	
	--停止定时器
	if self.connectTimeTickScheduler then
		scheduler.unscheduleGlobal(self.connectTimeTickScheduler)
		self.connectTimeTickScheduler = nil
	end
	if self.tickScheduler then
		scheduler.unscheduleGlobal(self.tickScheduler)
		self.tickScheduler = nil
	end
	
	local __tick = function()
		self:recv()
		self:split_pack()	
		self:dispatch_one()
	end
	-- start to read TCP data
	self.tickScheduler = scheduler.scheduleGlobal(__tick, 0)	
	
	-- self:recv()
	-- self:split_pack()
	-- while self:dispatch_one() do
	
	-- end
end

function SocketTCP:recv()
	local reads, writes = socket.select({self.tcp}, {}, 0)
	if #reads == 0 then
		--print("no reads")
		return
	end

	-- 读包头,两字节长度
	if #self.last < 2 then
		local r, __status = self.tcp:receive(2 - #self.last)
		if __status == STATUS_CLOSED or __status == STATUS_NOT_CONNECTED then
			self:close()
			if self.isConnected then
				self:_onDisconnect()
			else
				self:_connectFailure()
			end
			return
		end
			
		if not r then
			return
		end
		
		self.last = self.last .. r
		if #self.last < 2 then
			return
		end
	end
	
	local len = self.last:byte(1) * 256 + self.last:byte(2)
	
	local r, __status = self.tcp:receive(len + 2 - #self.last)
	if __status == STATUS_CLOSED or __status == STATUS_NOT_CONNECTED then
		self:close()
		if self.isConnected then
			self:_onDisconnect()
		else
			self:_connectFailure()
		end
		return
	end
	
	if not r then
		return
	end
	
	self.last = self.last .. r
	if #self.last < 2 then
		return
	end
		
    if not r then
		print("socket empty", s)
        return
    end

    print("recv data", #r)
end

function SocketTCP:split_pack()
	local last = self.last
    local len
    repeat
        if #last < 2 then
            break
        end
        len = last:byte(1) * 256 + last:byte(2)
        if #last < len + 2 then
            break
        end
        table.insert(self.pack_list, last:sub(3, 2 + len))
        last = last:sub(3 + len) or ""
    until(false)
	self.last = last
end

function SocketTCP:dispatch_one()
	if not next(self.pack_list) then
		return
	end
	local data = table.remove(self.pack_list, 1)
	print("split pack",#data)
	local proto_name, params = Packer.unpack(data)
	print("recv msg", proto_name)
	local callback = self.callback_tbl[proto_name]
	--callback.callback(callback.obj, params)
	--回调
	if callback ~= 0 then
		callback(params)
	end
	return
end

function SocketTCP:sendRPC(proto_name, msg,obj, method)
     print("send msg", proto_name)
     local package = Packer.pack(proto_name, msg)
	if obj and method then 
		self:register(proto_name,obj, method)
	end
	if self.isConnected then
		self.tcp:send(package)
	else
		self.losePacks[#self.losePacks+1] = package
	end
end

function SocketTCP:register(name, obj, method)
	self.callback_tbl[name] = handler(obj, method)
end

function SocketTCP:unregister(name)
	self.callback_tbl[name] = nil
end

function SocketTCP:isConnect()
	return self.isConnected
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

function SocketTCP:_disconnect()
	self.isConnected = false
	self.tcp:shutdown()
	self:dispatchEvent({name=SocketTCP.EVENT_CLOSED})
end

function SocketTCP:_onDisconnect()
	--printf("%s._onDisConnect", self.name);
	self.isConnected = false
	self:dispatchEvent({name=SocketTCP.EVENT_CLOSED})
	--self:_reconnect();
end

function SocketTCP:_connectFailure(status)
	-- print(debug.traceback())
	printf("%s.connectFailure:%s : %s  time:%s", self.name,self.host,self.port,socket.gettime())
	self:dispatchEvent({name=SocketTCP.EVENT_CONNECT_FAILURE})
	--self:_reconnect();
end

-- if connection is initiative, do not reconnect
function SocketTCP:_reconnect(__immediately)
	if not self.isRetryConnect then return end
	printInfo("%s._reconnect", self.name)
	if __immediately then self:connect() return end
	if self.reconnectScheduler then scheduler.unscheduleGlobal(self.reconnectScheduler) end
	local __doReConnect = function ()
		self:connect()
	end
	self.reconnectScheduler = scheduler.performWithDelayGlobal(__doReConnect, SOCKET_RECONNECT_TIME)
end

return SocketTCP
