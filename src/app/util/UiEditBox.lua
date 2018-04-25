local UiEditBox = class("UiEditBox")


function UiEditBox.create( ... )
	local edit = UiEditBox.new(...)
	return edit
end

--创建
function UiEditBox:ctor(ParentNode,fontsize,maxLen,CallBack,PlaceHoldertext,fontcolor, size)
	if not util.isExistsByNode(ParentNode) then
		return
	end	
	--ccui.Scale9Sprite:create()
	local editBoxSize	
	if size then
		editBoxSize = size
	else
		editBoxSize = cc.size(ParentNode:getContentSize().width, ParentNode:getContentSize().height) 
	end
	self.EditBox = ccui.EditBox:create(editBoxSize, R.getResframe2("frame_10098"))

	self.EditBox:setAnchorPoint(cc.p(0,0))

	self.fontcolor = fontcolor or cc.c4b(0, 0, 0, 255)
    self.EditBox:setFontColor(self.fontcolor)

   	self.EditBox:setPlaceHolder(PlaceHoldertext or "")
    self.EditBox:setPlaceholderFontColor(cc.c3b(255,255,255))
    --ios调用报错
    self.EditBox:setReturnType(ccui.keyboard_returntype.done)

    self.EditBox:setFont(css.fontName,fontsize or 24)	

    self.EditBox:setMaxLength(maxLen)

    if CallBack then
    	self.EditBox:registerScriptEditBoxHandler(CallBack)	
    end	

    self.EditBox:setInputMode(ccui.editbox_input_mode.singleline)

    ParentNode:addChild(self.EditBox)
end

--设置文字
function UiEditBox:setText(text)
	self.EditBox:setText(text)
end	

--获取文字
function UiEditBox:getText()
	return self.EditBox:getText()
end	

function UiEditBox:getEditBox()
	return self.EditBox
end

return UiEditBox
