--
-- Author: Chen
-- Date: 2017-10-23 12:03:40
-- Brief: 
--
local UpdateScene = class("UpdateScene", cc.load("mvc").ViewBase)


function UpdateScene:onCreate()

    local layer = display.newLayer()
    self:addChild(layer)
	
    local label1 = cc.Label:create()
	label1:setString("正在热更 请耐心等待.....")
    label1:setPosition( cc.p(display.cx,display.cy-300) )
    label1:setAnchorPoint( cc.p(0.5, 0.5) )
    layer:addChild(label1)

    local onDownload = nil
    onDownload = function(evtCode, data)
        if evtCode == 1 then
            print("<=== evtCode = 1")
            local percent = math.floor(data.percent)
            print("<==== percent = " ..percent .."%")
        elseif evtCode == 2 then
            print("<=== 下载完成")
			local writablePath = cc.FileUtils:getInstance():getWritablePath()
			local storagePath = writablePath .. "Update"
			--将下载目录的src和res作为优先级最高的搜索目录，这样才能保证下载的能覆盖原来的代码
			cc.FileUtils:getInstance():addSearchPath(storagePath.."/src/",true)
			cc.FileUtils:getInstance():addSearchPath(storagePath.."/res/",true)			
			myApp:enterScene("MainScene")
        elseif evtCode == 0 then
            print("<=== 发生错误")

            label1:setString("热更发生错误" ..data.eventCode)
        else
            print("<=== evtCode = " ..evtCode)
        end
    end

    local assertsMgr = require("app.util.AssetsManagerExController"):create()
    assertsMgr:startDownload(onDownload)
end

function UpdateScene:onExit()
	print("UpdateScene:onExit")
    --logger.trace("UpdateScene:onExit")
    --UpdateScene.loadConfig()
    --UpdateScene.super.onExit(self)
end

return UpdateScene
