local string = string
local print = print
local table = table
require "lpeg"
local P = lpeg.P
local C = lpeg.C
local Ct =  lpeg.Ct
local M = lpeg.match
local randCardinal = 1000000
local illegal_ascii = {[1]=34,[2]=35,[3]=36,[4]=37,[5]=38,[6]=39,[7]=42,[8]=43,[9]=44,[10]=45,[11]=46,[12]=47,[13]=92,[14]=124,[15]=32,[16]=40,[17]=41}

function setRandCardinal()
	if randCardinal > 2000000 then
		randCardinal = 1000000
	end
	randCardinal = randCardinal+1
end

function math.rand(num1,num2, randseed)
	setRandCardinal()
	if randseed then
		math.randomseed(randseed)
	else
		math.randomseed(os.time()+randCardinal)
	end
	if num1 and num2 then
		return math.random(num1,num2)
	elseif num1 then
		return math.random(num1)
	else
		return math.random()
	end
end

-- 从一个数字列表中 随机多个不同的数
function randMulNumber(numTab, count, randseed)
	setRandCardinal()
	local arg = numTab
	local selected={}
	math.random(0,#arg)
	if randseed then
		math.randomseed(randseed)
	else
		math.randomseed(os.time()+randCardinal)
	end
	-- if #arg<=count then return unpack(arg) end
	if count <= 0 then return selected end
	if #arg<=count then return arg end
	while #selected < count do
		math.random(#arg)
		table.insert(selected,table.remove(arg,math.random(#arg)))
	end
	-- return unpack(selected)
	return selected
end

function string.formatNum(num)
	if not num then
		num = 0
	end
	local str = tostring(num)
	local count = 0
	local result = ""
	for i=#str, 1, -1  do
		count = count + 1
		local s = string.sub(str, i,i)
		result = s..result
		if count == 3 and i ~= 1 then
			result = ","..result
			count = 0
		end
	end
	return result
end

function string.split (s, sep)
  sep = P(sep)
  local elem = C((1 - sep)^0)
  local p = lpeg.Ct(elem * (sep * elem)^0)   -- make a table capture
  return M(p, s)
end

function handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

function string.formatIndex( s,... )
    local arg = {...}
    local count
    for i,v in ipairs(arg) do
       s ,count = string.gsub(s,"%b{"..i.."}",v)
       -- assert(count==0,"format string at "..i.." not find "..s)
    end
    return s
end


function string.formatIndexExt(strText,Tab)
	local count
    for key,value in pairs(Tab) do
       strText,count = string.gsub(strText,"%b{".. key .."}",value)
    end
    return strText
end

function string.formatIndexAddSuffix(strText,Tab, Add)
	local count
    for key,value in pairs(Tab) do
       strText,count = string.gsub(strText,"%b{".. key .."}",value .."[#00ff00]+" .. Add[key] .. "[end]")
    end
    return strText
end

-- function string.split(input, delimiter)
--     input = tostring(input)
--     delimiter = tostring(delimiter)
--     if (delimiter=='') then return false end
--     local pos,arr = 0, {}
--     -- for each divider found
--     for st,sp in function() return string.find(input, delimiter, pos, true) end do
--         table.insert(arr, string.sub(input, pos, st - 1))
--         pos = sp + 1
--     end
--     table.insert(arr, string.sub(input, pos))
--     return arr
-- end

function string.trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end

function string.strLen(input)
	local num1, num2 = input:gsub('[\128-\255]','')
	return #num1+num2/3*2
end

function RGB(t)
    local r = tonumber("0x" .. string.sub(t, 1, 2))
    local g = tonumber("0x" .. string.sub(t, 3, 4))
    local b = tonumber("0x" .. string.sub(t, 5, 6))
    return cc.c3b(r, g, b)
end

function ARGB(t)
    local r = tonumber("0x" .. string.sub(t, 3, 4))
    local g = tonumber("0x" .. string.sub(t, 5, 6))
    local b = tonumber("0x" .. string.sub(t, 7, 8))
    local a = tonumber("0x" .. string.sub(t, 1, 2))
    return cc.c4b(r, g, b,a)
end

function trace(...)
    if Debug ==0 then 
        return 
    end
    if not s_moduleNames or table.nums(s_moduleNames) == 0 then
       print(...)
    else
        for modelename,line in string.gmatch(debug.traceback(),"/([^/]-)%.lua\"%]:(%d+):") do
            if  modelename and line and  (modelename ~= "functions") then
                local lowerName = string.lower(modelename)
                if (s_moduleNames["All"] and s_moduleNames[lowerName] ~=false) or s_moduleNames[lowerName] then
                    print("["..modelename..":"..line.."]",...)
                end
                return
            end
        end
    end
end

function stringToChars(str)
	-- 主要用了Unicode(UTF-8)编码的原理分隔字符串
	-- 简单来说就是每个字符的第一位定义了该字符占据了多少字节
	-- UTF-8的编码：它是一种变长的编码方式
	-- 对于单字节的符号，字节的第一位设为0，后面7位为这个符号的unicode码。因此对于英语字母，UTF-8编码和ASCII码是相同的。
	-- 对于n字节的符号（n>1），第一个字节的前n位都设为1，第n+1位设为0，后面字节的前两位一律设为10。
	-- 剩下的没有提及的二进制位，全部为这个符号的unicode码。
    local list = {}
    local len = string.len(str)
    local i = 1 
	local count = 0
    while i <= len do
        local c = string.byte(str, i)
        local shift = 1
        if c > 0 and c <= 127 then
            shift = 1
        elseif (c >= 192 and c <= 223) then
            shift = 2
        elseif (c >= 224 and c <= 239) then
            shift = 3
        elseif (c >= 240 and c <= 247) then
            shift = 4
        end
        local char = string.sub(str, i, i+shift-1)
        i = i + shift
        table.insert(list, char)
		count = count+1
    end
	return list, len, count
end

function stringToChars2(str)
	-- 主要用了Unicode(UTF-8)编码的原理分隔字符串
	-- 简单来说就是每个字符的第一位定义了该字符占据了多少字节
	-- UTF-8的编码：它是一种变长的编码方式
	-- 对于单字节的符号，字节的第一位设为0，后面7位为这个符号的unicode码。因此对于英语字母，UTF-8编码和ASCII码是相同的。
	-- 对于n字节的符号（n>1），第一个字节的前n位都设为1，第n+1位设为0，后面字节的前两位一律设为10。
	-- 剩下的没有提及的二进制位，全部为这个符号的unicode码。
    local list = {}
    local len = string.len(str)
    local i = 1 
	local count = 0
    while i <= len do
        local c = string.byte(str, i)
        local shift = 1
        if c > 0 and c <= 127 then
            shift = 1
        elseif (c >= 192 and c <= 223) then
            shift = 2
        elseif (c >= 224 and c <= 239) then
            shift = 3
        elseif (c >= 240 and c <= 247) then
            shift = 4
        end
        local char = string.sub(str, i, i+shift-1)
        --过滤字符集
        for i,v in ipairs(illegal_ascii) do
            if c == v then
                char = "*"
            end
        end
        i = i + shift
        if shift <= 3 then  --表情和空格禁止
            table.insert(list, char)
		    count = count+shift
        end    
    end
    local str2 = table.concat( list, "")
	return str2,count
end

function stringToChars3( str )
    local len = string.len(str)
    local i = 1 
    while i <= len do
        local c = string.byte(str, i)
        local shift = 1
        if c > 0 and c <= 127 then
            shift = 1
        elseif (c >= 192 and c <= 223) then
            shift = 2
        elseif (c >= 224 and c <= 239) then
            shift = 3
        elseif (c >= 240 and c <= 247) then
            shift = 4
        end        
        --过滤字符集
        for i,v in ipairs(illegal_ascii) do
            if c == v then
                return false
            end
        end
        i = i +shift
    end
    
	return true
end


function stringToFormat(str,mlen)
	str = str or ""
	local maxLen = mlen or 15
	local list,len = stringToChars(str)
	local suffix = ""
	if len > maxLen then
		maxLen = maxLen - 3
		suffix = "..."
	end
	local totalLen = 0
	local newTab = {}
	for k,v in pairs(list) do
		local cLen = string.len(v)
		totalLen = totalLen+cLen
		if totalLen > maxLen then
			break
		else
			table.insert(newTab, v)
		end
	end
	table.insert(newTab, suffix)
	
	return table.concat(newTab)
end

function stringToSub(str, num)
	local list,len,count = stringToChars(str)
	local num = math.floor(count*num)
	local newTab = {}
	local count = 0
	for k,v in pairs(list) do
		count = count + 1
		if count > num then
			break
		end
		table.insert(newTab, v) 
	end
	table.insert(newTab, "...")
	return table.concat(newTab)
end

--如果label内的文字内容过长,超过width像素长度,则以...显示最后部分
--(label不可为为自定义尺寸)
function stringToFormatEx(label,width)
    if not util.isExistsByNode(label) then
        return
    end
	local str = label:getString()
	local list,max = stringToChars(str)
    local min = 1
    local index = max
    while(true)do
        local strW = label:getContentSize().width
        local newIndex
        if strW<=width then
            newIndex = math.floor((index+max)/2)
            min = index
        else
            newIndex = math.floor((index+min)/2)
            max = index
        end
        if newIndex == index then
            return
        else
            index = newIndex
        end
        label:setString(stringToFormat(str,index))
    end
end

function getnode(root, name)
    local control
    if type(name) ~= "string" then
        control = name
    else
        root:enumerateChildren('//' .. name, function(ret)
            control = ret;
            return false;
        end);
    end
    if control and control:getDescription()=="Button" then 
        control:setPressedActionEnabled(true)
    end
    return control;
end


function clickSelf( root,name,funcheckClick,parameters )
    local node = getnode(root,name)
    if node then
        node:setTouchEnabled(true)
        local touch = function ( cnode ,event )
           local hd = handler(root,funcheckClick)
           hd(parameters)
        end
        node:addClickEventListener(touch)
    else
        trace("util.click not find "..name)
    end
end

function tryRemove(node)
    if not  tolua.isnull(node) and node:getParent() then 
        if debugUI then 
            trace("removed :"..node:getName().."  count:"..node:getParent():getChildrenCount())
        end
        node:removeFromParent()
    end
end


--遍历表格按key顺序排列
function pairsKey(t, f)
    local a = {}    
    for n in pairs(t) do
        table.insert(a, n)
    end    
    table.sort(a, f)
 
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
 
    return iter
end

function list_iter(t)
    -- local i = 0
    -- local a = {}    
    -- for k,v in ipairs(t) do
    --     table.insert(a, v)
    -- end    
    -- local n = #a
    -- return function ()
    --     i=i+1
    --    if i <= n then return a[i] end
    -- end
    local a = {}    
    for n in pairs(t) do
        table.insert(a, n)
    end    
    table.sort(a, f)
 
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return t[a[i]]
        end
    end
 
    return iter
end

function table_count(tab)
	local count = 0
	for k,v in pairs(tab) do
		count = count + 1
	end
	return count
end

function sortByKey(t, key, bool)
    local d = {}    
    for k,v in pairs(t) do
		table.insert(d, v)	
	end
	local sortFun
	if bool then -- 降序 从大到小
		sortFun = function ( a,b )
			return tonumber(a[key])>tonumber(b[key])
		end	
	else -- 升序 从小到大
		sortFun = function ( a,b )
			return tonumber(a[key])<tonumber(b[key])
		end	
	end
    table.sort(d, sortFun)
    return d
end

function sortByKey2(tab, key1, key2)
	local sortFun = function ( a,b )
		if a[key1] > b[key1] then
			return true
		elseif a[key1] == b[key1] then
			return tonumber(a[key2])<tonumber(b[key2])
		else
			return false
		end
	end
	table.sort(tab, sortFun)
end

-- 双键排序
function sortByDoubleKey(tab, key1, key2, isDescending)
	local sortFun
	if isDescending then -- 降序排序
		sortFun = function ( a,b )
			if a[key1] > b[key1] then
				return true
			elseif a[key1] == b[key1] then
				return a[key2]>b[key2]
			else
				return false
			end
		end	
	else -- 升序排序
		sortFun = function ( a,b )
			if a[key1] < b[key1] then
				return true
			elseif a[key1] == b[key1] then
				return a[key2] < b[key2]
			else
				return false
			end
		end		
	end
	table.sort(tab, sortFun)
end

function table.nums(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end

function table.find( tab,value )
    for k,v in pairs(tab) do
        if v == value then 
            return k
        end
    end
    return nil
end

--remove old key-v
function table.strucRemove( old,new )
    local t
    for k,v in pairs(new) do
        t = type(v)
        if old[k] and t~="table" then 
            old[k] = nil
        end
        if t=="table" then 
            if old[k] then 
               table.strucRemove(old[k],v)
            end
        end
    end
end

function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

function table.equal(t1,t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return false
    end
    
    if table.nums(t1) ~= table.nums(t2) then
        return false
    end

    for i,j in pairs(t1) do
        if type(t1[i]) ~= "table" then
            if t1[i] ~= t2[i] then
                return false
            end
        else
            if not table.equal(t1[i],t2[i]) then
                return false
            end
        end
    end

    return true
end

if not table.pack then
    function table.pack (...)
        return {n=select('#',...); ...}
    end
end

-- 比较两个浮点数是否相等
function float_equal(x,v)  
    local EPSILON = 0.000001  
    return ((v - EPSILON) < x) and (x <( v + EPSILON))  
end  

function dumphex(data)
    print(string.gsub(data, ".",function(x) return string.format("%02x ", string.byte(x)) end))
end

-- 打印堆栈
function printStack()
	print(debug.traceback("Stack trace"))
end

--打印树形对象
function traceObj(value, desciption, nesting, filterString)
    if Debug == 0 then 
        return 
    end

    if type(nesting) ~= "number" then nesting = 5 end

    local lookupTable = {}
    local result = {}

    local filterString = filterString or false

    local function _v(v)
        if type(v) == "string" then
            v = "\"" .. v .. "\""
        end
        return tostring(v)
    end

    local traceback = string.split(debug.traceback("", 2), "\n")
    trace("dump from: " .. string.trim(traceback[3]))

    local function _dump(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"
        spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - string.len(_v(desciption)))
        end
        if type(value) ~= "table" then
            if filterString == false then
                result[#result +1 ] = string.format("%s%s%s = %s", indent, _v(desciption), spc, _v(value))
            end
        elseif lookupTable[value] then
            result[#result +1 ] = string.format("%s%s%s = *REF*", indent, desciption, spc)
        else
            lookupTable[value] = true
            if nest > nesting then
                result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, desciption)
            else
                result[#result +1 ] = string.format("%s%s = {", indent, _v(desciption))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = _v(k)
                    local vkl = string.len(vk)
                    if vkl > keylen then keylen = vkl end
                    values[k] = v
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                for i, k in ipairs(keys) do
                    _dump(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = string.format("%s}", indent)
            end        end
    end
    _dump(value, desciption, "- ", 1)

    for i, line in ipairs(result) do
        trace(line)
    end
end

--某个时间之后触发一次回调
function Timer( node, delay, callback )  
    local delay = cc.DelayTime:create( delay )  
    local sequence = cc.Squence:create( delay, cc.CallFunc:create( callback ) )  
    node:runAction( sequence )  
end 

--每隔一段时间调用一次回调
function Interval( node, delay, callback )  
    local delay = cc.DelayTime:create( delay )  
    local sequence = cc.Squence:create( delay, cc.CallFunc:create( callback ) )  
    local action = cc.RepeatForever:create( sequence )  
    node:runAction( action )  
end 

--动作执行完成后调用回调
function actionCallBack( node, action, callback )  
    local sequence = cc.Squence:create( action, cc.CallFunc:create( callback ) )  
    node:runAction( sequence )  
end  
