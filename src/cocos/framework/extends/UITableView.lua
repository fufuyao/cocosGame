
--[[

Copyright (c) 2011-2014 chukong-inc.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

local TableView = cc.TableView

--create
function TableView:createView( tableSize,direction )
    direction = direction or cc.SCROLLVIEW_DIRECTION_VERTICAL
    local tableView = cc.TableView:create(tableSize)
    tableView:setDirection(direction)
    tableView:setVerticalFillOrder(cc.TABLEVIEW_FILL_TOPDOWN)
    tableView:setDelegate()
    -- tableView:reloadData() 
    return tableView
end

--scroll item
function TableView:onScrollViewDidScroll(callback)
    self:registerScriptHandler(function ( table )
        callback(table)
    end,cc.SCROLLVIEW_SCRIPT_SCROLL)
end

function TableView:onScrollViewDidZoom(callback)
    self:registerScriptHandler(function ( table )
        callback(table)
    end,cc.SCROLLVIEW_SCRIPT_ZOOM)
end

--item touch
function TableView:onTableCellTouched(callback)
    self:registerScriptHandler(function ( table,cell )
        callback(table,cell)
    end,cc.TABLECELL_TOUCHED)
end

--set item size
function TableView:onCellSizeForTable(callback)
    self:registerScriptHandler(function ( table)
        return callback(table)
    end,cc.TABLECELL_SIZE_FOR_INDEX)
end

--set item content
function TableView:onTableCellAtIndex(callback)
    self:registerScriptHandler(function ( table,index)
        return callback(table,index)
    end,cc.TABLECELL_SIZE_AT_INDEX)
end

--set item Num
function TableView:onNumberOfCellsInTableView(callback)
    self:registerScriptHandler(function ( table)
        return callback(table)
    end,cc.NUMBER_OF_CELLS_IN_TABLEVIEW)
end

--jump to  top 
--@param animated  If true, the view will scroll to the new offset.
function TableView:JumpToTop( animated )
    self:setContentOffset(self:minContainerOffset(), animated)
end

--jump to  bottom 
--@param animated  If true, the view will scroll to the new offset.
function TableView:JumpToBottom( animated )
    local point = self:getContentOffset()
    if point.y < 0 then 
        self:setContentOffset(self:maxContainerOffset(), animated)
    end
end

--jump to  cell 
function TableView:scrollToCell( numberOfCells,index,cellSize,animated )
    local point = self:getContentOffset()
    local size = cellSize--self:getCellSize()
    local direction = self:getDirection()
    if direction == cc.SCROLLVIEW_DIRECTION_HORIZONTAL then
        point.x = -((index - 1) * size.width)
    else
        index = numberOfCells - index + 1
        point.y = -((index - 1) * size.height)
    end
    self:setContentOffset(point, animated)
end