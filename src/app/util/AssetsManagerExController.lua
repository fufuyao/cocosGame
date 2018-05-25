--
-- Author: ChenShao
-- Date: 2016-12-13 14:08:42
--

local AssetsManagerExController = class("AssetsManagerExController", function()
	return cc.Node:create()
end)


function AssetsManagerExController:ctor(args)
    --self:enableNodeEvents()

    self.manifestUrl = "project.manifest"
	if device.platform == "android" or device.platform == "ios" then
    	self.storagePath = cc.FileUtils:getInstance():getWritablePath() .."Update/dafw"
	else
		self.storagePath = cc.FileUtils:getInstance():getWritablePath() .."Update"
	end
end

function AssetsManagerExController:create(args)
    local instance = self.new(args)
    local ret      = instance:init()
    return instance, ret
end

function AssetsManagerExController:init()

    return true
end

--// 0 错误 1 下载百分比 2 下载完成
--// 3 弹出是否下载提示框
function AssetsManagerExController:startDownload(cb, isFriendly)
    
    local amEx
    if isFriendly then
        amEx = cc.AssetsManagerEx:create(self.manifestUrl, self.storagePath, true)
    else
        amEx = cc.AssetsManagerEx:create(self.manifestUrl, self.storagePath)
    end

    amEx:retain()
    self.amEx = amEx

    local function onUpdateEvent(event)
        local eventCode = event:getEventCode()

        local args = {}

        if eventCode == cc.EventAssetsManagerEx.EventCode.ALREADY_UP_TO_DATE or 
        	eventCode == cc.EventAssetsManagerEx.EventCode.UPDATE_FINISHED then
        	--print("<=== 本地已为最新版本")
        	--print("<=== 下载完成")

        	if cb then
        		cb(2, args)
        	end
       	 elseif eventCode == cc.EventAssetsManagerEx.EventCode.UPDATE_PROGRESSION then
            
            print("percent", event:getPercentByFile() .."%")
            if cb then
                args.percent = event:getPercentByFile()
        		cb(1, args)
        	end
        elseif eventCode == cc.EventAssetsManagerEx.EventCode.ERROR_NO_LOCAL_MANIFEST or 
        	eventCode == cc.EventAssetsManagerEx.EventCode.ERROR_DOWNLOAD_MANIFEST or 
        	eventCode == cc.EventAssetsManagerEx.EventCode.ERROR_PARSE_MANIFEST or 
        	eventCode == cc.EventAssetsManagerEx.EventCode.ERROR_UPDATING or 
        	eventCode == cc.EventAssetsManagerEx.EventCode.UPDATE_FAILED or 
        	eventCode == cc.EventAssetsManagerEx.EventCode.ERROR_DECOMPRESS then
        	print("<=== Error eventCode = " ..eventCode)
            args.eventCode = eventCode
       		if cb then
        	 	cb(0, args)
        	end
        elseif eventCode == 11 then
            print("msg = " ..event:getMessage())

            if cb then
                local msg  = event:getMessage()
                local b, e = string.find(msg, ",")
                args.count = string.sub(msg, 1, b - 1) --文件总数量
                args.size  = string.sub(msg, e + 1) --文件总大小

                args.fcop = function(op)
                    if op == "ok" then
                        gg.eventDispatcher:dispatchEvent("EVT_ASSETS_MANAGEREX_START_DOWNLOAD")
                    else
                        cc.Director:getInstance():endToLua()
                        if cc.PLATFORM_OS_IPHONE == cc.Application:getInstance():getTargetPlatform() then  
                            os.exit()
                        end                      
                    end
                end

                cb(3, args)
            end
        else
            cb(4, args)
        	print("<=== other eventCode = " ..eventCode)
        end
    end

     local listenerForUpdate = cc.EventListenerAssetsManagerEx:create(amEx, onUpdateEvent)
    cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listenerForUpdate, 1)
    amEx:update()
end

function AssetsManagerExController:onEnter()

end

function AssetsManagerExController:onExit()
	if self.amEx then
       self.amEx:release()
    end
end

return AssetsManagerExController