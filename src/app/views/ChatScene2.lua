local ChatScene2 = class('ChatScene2', cc.Layer)

local Max_ShowNum = 10  --最大显示的条数

function ChatScene2:ctor()
    local ui = cc.CSLoader:createNode('ChatScene.csb')
    self:addChild(ui)
    local mainpanel = ui:getChildByName('MainPanel')
    local btn_close = mainpanel:getChildByName("btn_close")


    self.contentStr = nil
    self.ALL_ContentRecords = {}    -- 所有的聊天记录
    self.curr_ContentRecords = {}   -- 当前显示的20条记录表
    self.list_head =1               -- 表头
    self.scroll_height = 0          --列表位置
    self.laoding  = false           --加载中

    self.listView = mainpanel:getChildByName("ListView_1")  
    self:loadChatData()
    --关闭界面
    btn_close:addClickEventListener(function ( ... )
        self:removeSelf()
    end)
    --输入框
    self.editBox = ccui.EditBox:create(cc.size(460,35), "Default/img_blank.png")
    self.editBox:setAnchorPoint(0.5, 0.5)
    self.editBox:setFontName(display.DEFAULT_TTF_FONT)
    self.editBox:setFontColor(cc.c3b(255,255,255))
    self.editBox:setFontSize(30)
    self.editBox:setPlaceHolder("请输入文本")
    self.editBox:setPosition(cc.p(260,60))
    self.editBox:setInputFlag(cc.EDITBOX_INPUT_FLAG_SENSITIVE)
    self:addChild(self.editBox)
    self.editBox:registerScriptEditBoxHandler(function ( event, textField )
        self:EditContent(event, textField )
    end)

    --发送按钮
    local btn_send = mainpanel:getChildByName("panel_send"):getChildByName("btn_send") 
    btn_send:addClickEventListener(function ( ... )
        self:sendContent()
    end)   

    --回到底部
    self.btn_gobottom = mainpanel:getChildByName("btn_gobottom")
    self.btn_gobottom:addClickEventListener(function ( ... )
        self:jumpToDown() 
    end) 
    self.openMenu = false
    self.action = cc.CSLoader:createTimeline("ChatScene.csb")
    ui:runAction(self.action)
    self.action:gotoFrameAndPause(0)
    self.panel_menu =  mainpanel:getChildByName("panel_menu")
    self.btn_menu =self.panel_menu:getChildByName("btn_menu")
    self.btn_menu:addClickEventListener(function ( ... )
        self.btn_menu:setTouchEnabled(false)
        self.action:gotoFrameAndPlay(0,15,false)
        self.openMenu = true
    end)    
    --清理
    local btn_clear = self.panel_menu:getChildByName("bg_menu"):getChildByName("btn_clear")
    btn_clear:addClickEventListener(function ( ... )
        ChatModel:clean()
        self:clean()
    end)  

    --监听消息
    EventListener.addEventListener(self,EVENT_TYPE.CHATMSGNOTIFY,function (event)
        if event.data then
            self:insertNewChat(event.data)
        end
    end)

    --监听消息
    EventListener.addEventListener(self,EVENT_TYPE.CHATSYSMSGNOTIFY,function (event)
        if event.data then
            self:insertNewChat(event.data)
        end
     end)

    --滑动监听
    self.listView:addScrollViewEventListener(function(sender, eventType)
        if eventType == ccui.ScrollviewEventType.scrollToTop then 
            --第一次加载不允许进来
            if self.laoding then 
                return 
            end
            --在计算中
            if self.waiting then
                return 
            end
            self.waiting = true
            print("滑到顶部刷新消息")
            self:loadHistoryData()
            performWithDelay(self,function ( ... )
                self.waiting = false
            end,1)
        elseif eventType == ccui.ScrollviewEventType.scrollToBottom then
            
        elseif eventType == ccui.ScrollviewEventType.scrolling then 
            if self.laoding then 
                return 
            end
            --在计算中
            if self.scrolldowning then
                return
            end                
            --下滑
            if self.scroll_height > self.listView:getInnerContainer():getPositionY() and #self.curr_ContentRecords >0 then 
                local pos = self.curr_ContentRecords[#self.curr_ContentRecords]:convertToWorldSpace(cc.p(0,0))
                --print("尾位置",pos.x,":",pos.y,":")
                if pos.y < 1150 and self.curr_ContentRecords[#self.curr_ContentRecords] ~= self.ALL_ContentRecords[#self.ALL_ContentRecords]   then 
                    --在计算中
                    self.scrolldowning = true
                    --表尾插入新的数据
                    table.insert( self.curr_ContentRecords,self.ALL_ContentRecords[self.list_head+#self.curr_ContentRecords])
                    local item = self:createItem(self.curr_ContentRecords[#self.curr_ContentRecords].data)
                    item:setAnchorPoint(0,0)
                    item:setPosition(cc.p(0,0))
                    self.curr_ContentRecords[#self.curr_ContentRecords]:addChild(item)

                    --表头删除
                    self.curr_ContentRecords[1]:removeAllChildren()
                    table.remove(self.curr_ContentRecords,1)

                    --移动链表头
                    self.list_head = self.list_head + 1
                end

            --上滑
            elseif self.scroll_height < self.listView:getInnerContainer():getPositionY() and #self.curr_ContentRecords >0 then 
                --print(self.list_head)
                local pos = self.curr_ContentRecords[1]:convertToWorldSpace(cc.p(0,0))
                --print("头位置",pos.x,":",pos.y)
                if pos.y > -20 and self.curr_ContentRecords[1] ~= self.ALL_ContentRecords[1]  then
                    --在计算中
                    self.scrolldowning = true

                    --移动链表头
                    self.list_head = self.list_head - 1
                    --表头插入新的数据
                    table.insert(self.curr_ContentRecords,1,self.ALL_ContentRecords[self.list_head])
                        
                    local item = self:createItem(self.curr_ContentRecords[1].data)
                    item:setAnchorPoint(0,0)    
                    item:setPosition(cc.p(0,0))
                    self.curr_ContentRecords[1]:addChild(item)                                                 
                    
                    --删除表尾
                    self.curr_ContentRecords[#self.curr_ContentRecords]:removeAllChildren()
                    table.remove(self.curr_ContentRecords,#self.curr_ContentRecords)

                end
            end
            self.scrolldowning = false

            self.scroll_height = self.listView:getInnerContainer():getPositionY()
        end 
    end)

    ChatModel:setInChatView( true )

	local function onTouchBegan(touch, event)
		return true
	end
    local function onTouchEnded(touch, event)
        local touch2 = touch:getLocation()
        local pos  = self.panel_menu:convertToWorldSpace(cc.p(0,0))
        local size  = self.panel_menu:getContentSize()
        local rect = cc.rect(pos.x,pos.y,size.width,size.height)
        if not cc.rectContainsPoint(rect,touch2) then
            if self.openMenu then 
                self.openMenu = false
                self.btn_menu:setTouchEnabled(true)
                self.action:gotoFrameAndPlay(25,35,false)
            end
        end
	end
	local function onTouchMoved(touch, event)
    end
    local layer = cc.Layer:create()
    self:addChild(layer)
	local eveListener = cc.EventListenerTouchOneByOne:create();
	eveListener:registerScriptHandler(onTouchBegan, cc.Handler.EVENT_TOUCH_BEGAN);
	eveListener:registerScriptHandler(onTouchEnded, cc.Handler.EVENT_TOUCH_ENDED);
	eveListener:registerScriptHandler(onTouchMoved, cc.Handler.EVENT_TOUCH_MOVED);
	local eveDispatch = layer:getEventDispatcher();
	eveDispatch:addEventListenerWithSceneGraphPriority(eveListener, layer);
end

--加载聊天数据
function ChatScene2:loadChatData( ... )
    self.laoding = true
    self.historyData = {}
    for i,v in ipairs(ChatModel:getChatData()) do
        self.historyData[i] = v
    end
    self.list_head = 1
    for i=1,10 do
        if #self.historyData > 0 then 
            local info  = table.remove( self.historyData, #self.historyData )
            local item = self:createItem(info)
            local widget = ccui.Widget:create()
            widget:setContentSize(cc.size(item:getContentSize().width, item:getContentSize().height))
            item:setPosition(cc.p(0,0))
            item:setAnchorPoint(0,0)
            widget.data = info
            self.listView:insertCustomItem(widget,0)

            table.insert(self.ALL_ContentRecords, widget) 

            if i >=self.list_head then 
                widget:addChild(item)
                table.insert(self.curr_ContentRecords, widget)
            end   
        end     
    end
    --测试代码
    -- self.historyData = {}
    -- for i=1,150 do
    --     local data ={userid=111,nickname="yff",viplevel=2,content="芬是否萨芬是的范德萨发斯蒂芬上的"..i}
    --     table.insert( self.historyData,data)
    -- end

    -- self.list_head = 1
    -- for i=1,10 do
    --     if #self.historyData > 0 then 
    --         local info  = table.remove( self.historyData, #self.historyData )
    --         local item = self:createItem(info)
    --         local widget = ccui.Widget:create()
    --         widget:setContentSize(cc.size(item:getContentSize().width, item:getContentSize().height))
    --         item:setPosition(cc.p(0,0))
    --         item:setAnchorPoint(0,0)
    --         widget.data = info
    --         self.listView:insertCustomItem(widget,0)

    --         table.insert(self.ALL_ContentRecords, widget) 

    --         if i >=self.list_head then 
    --             widget:addChild(item)
    --             table.insert(self.curr_ContentRecords, widget)
    --         end   
    --     end     
    -- end

    
    performWithDelay(self,function ( ... )
        self.listView:jumpToBottom()
        self.laoding = false
        self.scroll_height = self.listView:getInnerContainer():getPositionY()
    end,0.1)

end

--加载历史消息
function ChatScene2:loadHistoryData( ... )
    if #self.historyData > 0 then 
        local oldPositionX,oldPositionY = self.listView:getInnerContainer():getPosition()
        local height  = 0
        for i=1,10 do
            if #self.historyData > 0 then 
                local info  = table.remove( self.historyData, #self.historyData )
                local item = self:createItem(info)
                local widget = ccui.Widget:create()
                widget:setContentSize(cc.size(item:getContentSize().width, item:getContentSize().height))
                item:setPosition(cc.p(0,0))
                item:setAnchorPoint(0,0)
                widget.data = info
                self.listView:insertCustomItem(widget,0)
                table.insert(self.ALL_ContentRecords, widget) 

                if i <= 3 then 
                    widget:addChild(item)
                    height = height + item:getContentSize().height
                    --表尾插入新的数据
                    table.insert( self.curr_ContentRecords,widget)
                    --表头删除
                    self.curr_ContentRecords[1]:removeAllChildren()
                    table.remove(self.curr_ContentRecords,1)
                    self.list_head = self.list_head + 1
                end
            end     
        end     
        performWithDelay(self,function ( ... )
            self.listView:getInnerContainer():setPositionY(oldPositionY-300)
        end,0.1)
    end
end

--编辑文本
function ChatScene2:EditContent( textField, event )
    if event == "began" then 
        self.editBox:setText("")
    elseif event == "ended" then 
        local str = textField:getText()
        str = self:checkSensitiveWord( str )
        textField:setText(stringToChars(str,100,true))
    end
end

--检查屏蔽字
function ChatScene2:checkSensitiveWord(content)
    if 'string' ~= type(content) then return '' end
    for i, var in pairs(sensitiveWordList) do
        content = string.gsub(content, var[1], var[2])
    end
    return content
end

--发送消息
function ChatScene2:sendContent( ... )
    if self.clickTime and  os.clock()-self.clickTime <= 2 then 
        PopMsg("发言过于频繁")
        return 
    end
    self.clickTime = os.clock()
    if string.len( self.editBox:getText())==0 then 
        PopMsg("不能发送空文字")
        return
    end
    GameClient:getInstance():send('chat.sendmessage',{userid = MyLogin:getInstance().roleid,content = self.editBox:getText()},
    "chat.sendmessage_resp",handler(self,self.getMessageBack),true) 
end

--回包
function ChatScene2:getMessageBack( params )
    if params.error == 1 then
        self.editBox:setText("")
    end
end

function ChatScene2:createItem( data )
    if data.isSys then 
        return self:createSysChatItem(data)
    else
        return self:createChatItem(data)
    end
end


--创建聊天item
function ChatScene2:createChatItem( data)
    --设置文本
    if data then 
        --设置文本
        local itemNode
        if data.userid == MyLogin:getInstance().roleid then 
            itemNode = cc.CSLoader:createNode("Chatitemme.csb");
        else
            itemNode = cc.CSLoader:createNode("Chatitemother.csb");
        end
        --csb创建
        local mainPanel = itemNode:getChildByName("MainPanel")
        mainPanel:removeFromParent()
        local title = mainPanel:getChildByName("title")
        local nickname = title:getChildByName("nickname")
        nickname:setString(data.nickname)
        local imgTitleBg = title:getChildByName("bg")

        local vipImage = title:getChildByName("img_vip")
        if data.viplevel and data.viplevel > 0 then 
            vipImage:loadTexture("ui/VipForm/vip"..data.viplevel..".png")
            imgTitleBg:setContentSize(cc.size(nickname:getContentSize().width+106,imgTitleBg:getContentSize().height))
        else
            vipImage:hide()
            nickname:setPositionX(5)
            imgTitleBg:setContentSize(cc.size(nickname:getContentSize().width+20,imgTitleBg:getContentSize().height))
        end
        local bg = mainPanel:getChildByName("bg")
        local oldSize = bg:getContentSize()
        local text= mainPanel:getChildByName("txt"):hide()
        text:setString(data.content)
        local contentWidth = text:getContentSize().width > 390 and 390 or text:getContentSize().width
        local content = cc.Label:createWithSystemFont(data.content,"Arail",30,cc.size(contentWidth,0))
        content:setColor(cc.c3b(255,255,255))
        content:setAnchorPoint(cc.p(0,0))
        content:setPosition(26.3,24)
        bg:addChild(content)
        bg:setContentSize(cc.size(content:getContentSize().width+60,content:getContentSize().height+45))
        if data.userid == MyLogin:getInstance().roleid then
            bg:getChildByName("bottom"):setPositionX(bg:getChildByName("bottom"):getPositionX()+(bg:getContentSize().width-oldSize.width))
        end
        local addHight = bg:getContentSize().height - oldSize.height
        mainPanel:setContentSize(cc.size(mainPanel:getContentSize().width,bg:getContentSize().height+39))
        bg:setPositionY(bg:getPositionY()+addHight)
        title:setPositionY(title:getPositionY()+addHight)
        return mainPanel
    end
    return nil
end

--创建系统聊天item
function ChatScene2:createSysChatItem( data)
    --设置文本
    if data then 
        local itemNode = cc.CSLoader:createNode("Chatitemsys.csb");
        local mainPanel = itemNode:getChildByName("MainPanel")
        mainPanel:removeFromParent()
        local bg = mainPanel:getChildByName("bg")
        local title = bg:getChildByName("title")
        local oldSize = bg:getContentSize()
        local text= mainPanel:getChildByName("txt"):hide()
        local addHight = 0
        if string.find(data.content,"<div") then 
            local richLabel = RichLabel.new {
                fontName = "system",
                fontColor = cc.c3b(255,239,15),
                fontSize = 30,
                maxWidth=text:getContentSize().width,
            }
            richLabel:setString(data.content)
            richLabel:setAnchorPoint(cc.p(0,0))
            richLabel:setPosition(34.31,35)
            bg:addChild(richLabel)  
            bg:setContentSize(cc.size(bg:getContentSize().width,richLabel:getSize().height+97))
            addHight = bg:getContentSize().height - oldSize.height     
        else

            local content = cc.Label:createWithSystemFont(data.content,"Arail",30,cc.size(text:getContentSize().width,0))
            content:setColor(cc.c3b(255,239,15))
            content:setAnchorPoint(cc.p(0,0))
            content:setPosition(34.31,35)
            bg:addChild(content)
            bg:setContentSize(cc.size(bg:getContentSize().width,content:getContentSize().height+102))
            addHight = bg:getContentSize().height - oldSize.height
        end        
        mainPanel:setContentSize(cc.size(mainPanel:getContentSize().width,bg:getContentSize().height+5))
        bg:setPositionY(bg:getPositionY()+addHight)
        title:setPositionY(title:getPositionY()+addHight)

        return mainPanel
    end
end

--跳到底部
function ChatScene2:jumpToDown()
    self.laoding = true
    if #self.ALL_ContentRecords > Max_ShowNum and self.curr_ContentRecords[1] ~=  self.ALL_ContentRecords[1] then
        for i,v in ipairs(self.curr_ContentRecords) do
            v:removeAllChildren()
        end
        for i,v in ipairs(self.curr_ContentRecords) do
            self.curr_ContentRecords[i] = self.ALL_ContentRecords[i]
            local item = self:createChatItem(self.curr_ContentRecords[i].data)
            item:setAnchorPoint(0,0)
            item:setPosition(cc.p(0,0))
            self.curr_ContentRecords[i]:addChild(item)
        end 
        self.list_head = 1
        self.scroll_height =self.listView:getInnerContainer():getPositionY()  
    end
    self.listView:jumpToBottom()
    self.laoding = false
end

--插入新消息
function ChatScene2:insertNewChat( data )
    self.laoding = true
    local item =  self:createItem(data)
    local widget = ccui.Widget:create()
    widget:setContentSize(cc.size(item:getContentSize().width, item:getContentSize().height))
    item:setAnchorPoint(0,0)
    item:setPosition(cc.p(0,0))
    widget.data = data
    self.listView:pushBackCustomItem(widget)
    --在中间得到消息
    if self.ALL_ContentRecords[1] ~= self.curr_ContentRecords[1] then
        table.insert(self.ALL_ContentRecords,1,widget)  
        
        if #self.ALL_ContentRecords <= Max_ShowNum then 
            table.insert(self.curr_ContentRecords,1,widget)
        else
            self.list_head = self.list_head  +  1
        end 
        if data.userid == MyLogin:getInstance().roleid then 
            performWithDelay(self,function ( ... )
                self:jumpToDown()
            end,0.1) 
        end
    ---在底部得到消息
    else
        table.insert(self.ALL_ContentRecords,1,widget)   
        --小于最大的条数
        if #self.ALL_ContentRecords <= Max_ShowNum then 
            widget:addChild(item)
            table.insert(self.curr_ContentRecords,1,widget)
            performWithDelay(self,function ( ... )
                self.listView:jumpToBottom()
            end,0.1) 
        elseif #self.ALL_ContentRecords > Max_ShowNum then 
            --移动链表头
            self.list_head = 1
            --表头插入新的数据
            widget:addChild(item)
            table.insert(self.curr_ContentRecords,1,widget)

            --删除表尾
            self.curr_ContentRecords[#self.curr_ContentRecords]:removeAllChildren()
            table.remove(self.curr_ContentRecords,#self.curr_ContentRecords)

            performWithDelay(self,function ( ... )
                self.listView:jumpToBottom()
            end,0.1)                                   
        end                
    end
    self.laoding = false
end


function ChatScene2:clean( ... )
    self.listView:removeAllItems()
    self.ALL_ContentRecords = {}    
    self.curr_ContentRecords = {}
    self.list_head =1              
    self.scroll_height = 0          
    self.listView:jumpToBottom()
end

return ChatScene2