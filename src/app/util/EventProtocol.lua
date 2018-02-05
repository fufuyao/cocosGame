
local EventProtocol = {}
--multi obj listener event
function EventProtocol.extend(object)

    object.listeners_ = {}
    object.events_ = {}
    -- eventName    obj  class   method class:method
    function object:addEventListener(eventName, obj, method)
        local listener = handler(obj,method)

        eventName = string.upper(eventName)
        if object.listeners_[eventName] == nil then
            object.listeners_[eventName] = {}
        end
        if object.events_[obj]== nil then
            object.events_[obj]={}
        end

        object.listeners_[eventName][obj] = listener
        object.events_[obj][eventName] = eventName
        return listener
    end
    -- target has reg event
    function object:hasEventListener(eventName,obj)
        eventName = string.upper(eventName)
        if object.events_[obj] and object.events_[obj][eventName] then 
            return true
        end
        return false
    end

    -- dispatch event to all targets
    function object:dispatchEvent(event)
        event.name = string.upper(event.name)
        local eventName = event.name
    
        if object.listeners_[eventName] == nil then return end
        event.target = object
        local map = object.listeners_[eventName]
        for obj, listener in pairs(map) do
            listener(event)
        end
    end

    --remove all events for target has reg
    function object:revmoveTargetEvents( obj )
        local map = object.events_[obj]
        if map ==nil then 
            return 
        end

        for event,eventName in pairs(map) do
            object.listeners_[eventName][obj] = nil
        end
        object.events_[obj]=nil
    end

    --remove event for target has reg
    function object:removeEventListener(eventName, obj)
        eventName = string.upper(eventName)

        if object.listeners_[eventName] == nil then return end

        object.listeners_[eventName][obj] = nil
        object.events_[obj][eventName]=nil
    end

    --remove all targets reg events
    function object:removeAllEventListeners()
        object.listeners_ = {}
        object.events_ = {}
    end

    return object
end

return EventProtocol
