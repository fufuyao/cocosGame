--地图拖动缩放工具
local DragScale = class("DragScale",function ()
    local layer = cc.Layer:create()
    return layer
end)

function DragScale:ctor(home_layer)
    self._scale=1--0.9

    self._dragLayer = home_layer
    self._dragLayer:setScale(self._scale)
    self._touchs = {}

    self._circle_began ={} 
    self._circle ={}

    --第一次点击信息
    self._beginTouch = nil 

    --判断操作是滑动还是缩放
    self._action = 1

    EventProtocol.extend(self)
    self:addDrag()
end

local _beganPos={x=0,y=0}
--点击开始和结束距离判断是否为点击
local CLICK_DIS = 20
local TIME_MOVE = 0.02--产生惯性最小时间
local TIME_JUMP = 1

local MAX_SCALE = 1.2
local MIN_SCALE = 0.8

local MAX_SCALE_M = 1.4
local MIN_SCALE_M = 0.6

local Click_time = true

local socket = require "socket"

--设置触摸圆半径
function DragScale:setCircle( p1,p2,c )
    c._center_point = cc.pMidpoint(p1,p2)
    c._d = cc.pGetDistance(p1,p2)
end

function DragScale:addDrag()
    local function onTouchBegan(touch, event)
        if tolua.isnull(touch) then 
            return
        end
        local isNull = false
        for k,v in pairs(self._touchs) do
            if tolua.isnull(v) then
                isNull = true
                break
            end
        end        
        if isNull or self._touchs[touch:getId()+1] then
            self._touchs = {}
            self._beginTouch = nil
        end
        self._touchs[touch:getId()+1] = touch
        -- print(table_count(self._touchs),"std",touch:getId())
        if  self._beginTouch == nil then 
            self._beginTouch = touch:getLocation()
            self._beginTouch.time = socket.gettime()
        end

        self:updatePosition()
        return true
    end

    local function onTouchMove(touch, event)
        if tolua.isnull(touch) then 
            return
        end
        self._touchs[touch:getId()+1] = touch

        local count = table_count(self._touchs)
        if count == 0 then 
            return 
        end
        if not GameHelper:IsGuideProcessMove() then
            return
        end       
        local touch1 = self._touchs[1] or self._touchs[2] or self._touchs[3] or self._touchs[4] or self._touchs[5]
        local p1 = touch1:getLocation()
        local touch2 = self._touchs[2]
        if count > 1 and touch2 then 
            
            local p2 = touch2:getLocation()

            self:setCircle(p1, p2, self._circle)
            local scale = self._circle._d / self._circle_began._d * self._scale ; 
            scale = self._scale + (scale - self._scale) * 0.45

            if scale < MIN_SCALE_M then 
                scale = MIN_SCALE_M
            elseif scale> MAX_SCALE_M then 
                scale = MAX_SCALE_M
            end

            if scale~=scale then 
                scale = self._scale
            end 
            
            self._dragLayer:setScale(scale)
            self._action = 2
        else
            self:setCircle(p1,p1,self._circle)
            self._action = 1
        end
        --移动过程中不需要再设置锚点位置
        self:resetPosition(self._circle._center_point)
    end

    local function onTouchEnded(touch, event)
        if tolua.isnull(touch) then 
            return
        end
        self._touchs[touch:getId()+1] = nil

        local count = table_count(self._touchs)

        -- if not GameHelper:IsGuideProcessMove() then
        --     self:notifyClick(touch)
        --     return    
        -- end  
        
        self:updatePosition()

        --根据操作类型修正后面的运动轨迹
        if self._action ==1 and count == 0 then 
            -- print("点击结束",self._beginTouch.x,self._beginTouch.y,touch:getLocation().x,touch:getLocation().y)
            local sp = self._beginTouch
            local ep = touch:getLocation()
            local ds = cc.pGetDistance(sp,ep)
            --判断是否为点击事件
            --print("ds < CLICK_DIS", ds , CLICK_DIS)
            if ds < CLICK_DIS then 
                 if Click_time then
                    Click_time = false
                    self:notifyClick(touch)
                    util.setTimeout(function() 
                        Click_time = true
                    end, 0.5)                    
                 end   
            else   
                if not GameHelper:IsGuideProcessMove() then
                    self._beginTouch = nil
                    return    
                end                                  
                --根据滑动速度和时间，继续滑动一段距离
                local st = self._beginTouch.time 
                local et = socket.gettime()
                local ct = et - st
                local epdis = cc.pSub(sp,ep)
                --print("偏移距离:", cc.pGetDistance(sp,ep) ,util.display.width/4)
                if ct<0.5 then 
                    local lp = cc.pSub(cc.p(self._dragLayer:getPosition()),cc.pMul(epdis,1-ct))
                    --print(self._scale,"滑动时间",ct,ds,"\n", sp.x,sp.y,"\n",ep.x,ep.y,"\n",epdis.x,epdis.y,"\n",lp.x,lp.y)
                    self:goPosAction(self._scale,lp,ct+1)

                end
            end
            self._beginTouch = nil
        elseif self._action == 2 and count == 0 then 
             --当超过缩放大小的时候恢复到最大或最小的
            self:scaleFix()
            self._beginTouch = nil
            self._action = 1
            
        end
    end
   
    local listener = cc.EventListenerTouchOneByOne:create()
    listener:registerScriptHandler(onTouchBegan,cc.Handler.EVENT_TOUCH_BEGAN )
    listener:registerScriptHandler(onTouchMove,cc.Handler.EVENT_TOUCH_MOVED )
    listener:registerScriptHandler(onTouchEnded,cc.Handler.EVENT_TOUCH_ENDED )
    self._dragLayer:getEventDispatcher():addEventListenerWithSceneGraphPriority(listener, self._dragLayer)
end

function DragScale:getSafeScale()
    local v= math.min(self._dragLayer:getScaleY(),self._dragLayer:getScaleX())
    return v
end

--当超过缩放大小的时候恢复到最大或最小的
function DragScale:scaleFix()
    local scale = self:getSafeScale()

    if scale < MIN_SCALE then 
        scale = MIN_SCALE
    elseif scale> MAX_SCALE then 
        scale = MAX_SCALE
    end
    self._scale = scale

    self:goPosAction(scale, self:getFixPosition(scale))
end

function DragScale:goPosAction( scale , pos ,t,center)
    self._dragLayer:stopAllActions()
    -- trace("goPosAction",scale,pos.x,pos.y,"\n")
    if center == false then 
       
    else
         pos = self:getFixPosition(scale,pos)
    end
    --[[]]
    local time = t or TIME_JUMP
    local scale_to = cc.ScaleTo:create(time,scale)
    local move_to = cc.MoveTo:create(time,pos)
    local sp = cc.Spawn:create(scale_to,move_to)
    local seq = cc.EaseExponentialOut:create(sp)
    self._dragLayer:runAction(seq)
    --]]
end


--修复位置放置滑动到外面去
function DragScale:getFixPosition(scale, pos)
    local new_point = pos or cc.p(self._dragLayer:getPositionX(),self._dragLayer:getPositionY())
    local size = self._dragLayer:getContentSize()
    size.width = size.width*scale
    size.height = size.height*scale
    local achor_point = self._dragLayer:getAnchorPoint()
    local win_size = cc.Director:getInstance():getWinSize()

    local min_x = win_size.width - size.width * (1 - achor_point.x)
    local max_x = 0 + size.width * achor_point.x
    local min_y = win_size.height - size.height * (1 - achor_point.y) + util.display.offy - 90
    local max_y = 0 + size.height * achor_point.y + util.display.offy + 110

    -- print(min_x,max_x,min_y,max_y,util.display.offy)
    if new_point.x < min_x then 
        new_point.x = min_x
    elseif new_point.x > max_x then 
        new_point.x = max_x
    end
    if new_point.y < min_y then 
        new_point.y = min_y
    elseif new_point.y > max_y then 
        new_point.y = max_y
    end

    return new_point;
end

-- 强制更新位置
function DragScale:fixPosition()
    self._dragLayer:setPosition(self:getFixPosition(self:getSafeScale()))
end


--更新位置 点击开始 和点击结束的时候
function DragScale:updatePosition()
    local count = table_count(self._touchs)
    if count == 0 then 
        return 
    end
    local touch1 = self._touchs[1] or self._touchs[2] or self._touchs[3] or self._touchs[4] or self._touchs[5]
    local p1 = touch1:getLocation()
    local touch2 = self._touchs[2]

    if count > 1 then 
        if touch2 then
            if tolua.isnull(touch2) then -- 在iPad上 5个手指头抓取屏幕 程序会处于伪后台， 此时快速点击拖动 touch2会报错 所以需要加isnull判断  
                return
            end        
            local p2 = touch2:getLocation()

            self:setCircle(p1, p2, self._circle_began)
            self:setCircle(p1, p2, self._circle)
        end
    else
        self:setCircle(p1, p1, self._circle)
    end

    self:resetAnchorPoint(self._circle._center_point)
    self:resetPosition(self._circle._center_point)
    self._scale = self:getSafeScale()
end

--重新设置锚点（p是location的点）位置会发生变化
function DragScale:resetAnchorPoint( p )
    local rp = self._dragLayer:convertToNodeSpace(p)
    local size = self._dragLayer:getContentSize()
    self._dragLayer:setAnchorPoint(cc.p(rp.x/size.width,rp.y/size.height))
    -- print("setAnchorPoint",self._dragLayer:getAnchorPoint().x,self._dragLayer:getAnchorPoint().y)
end

--重新设置位置 (pt是location的点）
function DragScale:resetPosition( pt )
    local p = cc.p(pt.x,pt.y)
    p.y =  p.y + util.display.offy
    self._dragLayer:setPosition(p)
    self:fixPosition()
end

--锚点改变的时候  位置不变化
function DragScale:fixAnchorPoint(rp)
    local size = self._dragLayer:getContentSize()
    local np = cc.p(rp.x/size.width,rp.y/size.height)
    local op = self._dragLayer:getAnchorPoint()
    local diffx = (np.x-op.x)*size.width
    local diffy = (np.y-op.y)*size.height
    self._dragLayer:setPositionX(self._dragLayer:getPositionX()+diffx)
    self._dragLayer:setPositionY(self._dragLayer:getPositionY()+diffy)

    self._dragLayer:setAnchorPoint(np)
end

--------------外包接口--------------
--通知主城点击建筑位置
function DragScale:notifyClick(touch)
    if tolua.isnull(touch) then 
        return
    end
    local pos = self._dragLayer:convertToNodeSpace(touch:getLocation())
    -- print("点击结束 ",math.floor(pos.x),math.floor(pos.y),touch:getLocation().x,touch:getLocation().y)
    self:dispatchEvent({name="touchMap",data = {x=math.floor(pos.x),y=math.floor(pos.y),location=cc.p(touch:getLocation().x,touch:getLocation().y)}})
end

--焦点跳到建筑物去
function DragScale:jumpPosition( new_x, new_y,center, scale )
    -- trace("跳到",socket.gettime(),new_x,new_y,scale,center)
    local p = cc.p(new_x, new_y)
    local op 
    if not center then 
        op = cc.p(util.display.width/4, util.display.height-util.display.height/3-80+ util.display.offy)
    else
        op = cc.p(util.display.width/2, util.display.height/2+ util.display.offy)
    end
    --记录跳转之前的位置
    self._circle.op = self._dragLayer:convertToNodeSpace(cc.p(util.display.width/2, util.display.height/2))
    self._circle.os = self._dragLayer:getScale()

    self:fixAnchorPoint(p)

    scale = scale or self._scale
    self:goPosAction( scale  , op ,nil,center )
end

--跳回焦点前的位置
function DragScale:jumpBack( ... )
    -- trace("跳回",socket.gettime(),self._circle.op.x,self._circle.op.y,self._scale )
    --无动画
    -- self:resetPosition(self._circle._center_point)
    --动画 先恢复之前的位置
    self:fixAnchorPoint(self._circle.op)
    self:goPosAction( self._circle.os , cc.p(util.display.width/2, util.display.height/2+ util.display.offy) )
end

--移动固定点到中间的缩放
function DragScale:doScaleAction( scale ,pos  )
    -- trace("缩放",scale,pos)
    local op = cc.p(util.display.width/2, util.display.height/2+ util.display.offy)
    local p 
    if pos then 
        self:fixAnchorPoint(pos)
    else
        op = cc.p(self._dragLayer:getPosition()) --op --当前位置缩放
    end
    self:goPosAction( scale or self._scale , op )
end

function DragScale:getdragLayer( ... )
    return self._dragLayer
end

return DragScale