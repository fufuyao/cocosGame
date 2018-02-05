--
-- Author: Your Name
-- Date: 2015-07-13 14:16:38
--
local GameEvent = class("GameEvent")

function GameEvent.create()
	return GameEvent.new()
end

function GameEvent:ctor()
	EventProtocol.extend(self)
	self.newState = {}
end

function GameEvent:notifyView( name ,data,isNew)
	if isNew then 
		self:setState(name)
	end
	self:dispatchEvent({name=name,data=data})
end

--读取状态
function GameEvent:readState( name )
	self.newState[name] = nil
	self:notifyView(name, nil, false)
end

--获取状态
function GameEvent:getState( name )
	return self.newState[name] and self.newState[name] == true
end

--设置状态
function GameEvent:setState( name )
	self.newState[name] = true
end

--[[使用
GameEvent:addEventListener(GameEvent.maintest,self,self.test)
GameEvent:notifyView(GameEvent.maintest,{i=1,s="dsfs"})]]

--界面消息传递事件
GameEvent.maintest = "maintest"

return GameEvent