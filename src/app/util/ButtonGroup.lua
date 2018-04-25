local ButtonGroup = class("ButtonGroup")


function ButtonGroup.create( ... )
	local bg = ButtonGroup.new(...)
	return bg
end


function ButtonGroup:ctor( buttons,pnls,callbackFuncs,skins,index,resType)
	assert(#buttons>1,"ButtonGroup must 2 button")

	self.buttons = buttons
	self.pnls = pnls or {}
	self.callbackFuncs = callbackFuncs or {}
	self.skins = skins or {}
    self.resType = resType or 1
	for k,v in pairs(self.buttons) do
		v:addClickEventListener(handler(self, self.onItemClick))
	end

	self:select(index or 1)
end

function ButtonGroup:select(index)
	local checkbox = self.buttons[index]
	self:onItemClick(checkbox,index)
end

function ButtonGroup:getValue()
	return self.value
end

function ButtonGroup:onItemClick(sender,value)
	local pnl 
	local cb 
	for k,v in ipairs(self.buttons) do
		pnl = self.pnls[k]
		cb = self.callbackFuncs[k] or self.callbackFuncs[1]
        local skin
		if v == sender then 
			 v:setTouchEnabled(false) --禁止点击2次触发
			if pnl then 
				pnl:setVisible(true)
			end
            if type(self.skins[1]) == "table" and  self.skins[k] and self.skins[k][1] then
                skin = self.skins[k][1]
			elseif self.skins[1] then 
				skin = self.skins[1]
			end

            if self.selectColor then
                v:setTitleColor(self.selectColor)
            end

			self.value =  k
		else
			v:setTouchEnabled(true)
			if type(self.skins[1]) == "table" and  self.skins[k] and self.skins[k][2] then
                skin = self.skins[k][2]
			elseif self.skins[2] then 
				skin = self.skins[2]
			end
			if pnl then 
				pnl:setVisible(false)
			end

            if self.unSelectColor then
                v:setTitleColor(self.unSelectColor)
            end
		end 

        if skin then
            v:loadTextureNormal(skin,self.resType) 
        end

		if v == sender and cb then 
			cb(k)
		end
	end
end

--设置按钮文字颜色，（选中颜色，未选中颜色）
function ButtonGroup:setSelColor(selectColor,unSelectColor)
	self.selectColor = selectColor
	self.unSelectColor = unSelectColor

    for k,v in ipairs(self.buttons) do
        if k == self.value then
            if self.selectColor then
                v:setTitleColor(self.selectColor)
            end
        else
            if self.unSelectColor then
                v:setTitleColor(self.unSelectColor)
            end
        end
    end
end


return ButtonGroup
