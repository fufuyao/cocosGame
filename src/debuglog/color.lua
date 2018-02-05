--[[
    设置打印日志颜色，仅windows控制台生效
]]

local bor = bit.bor
local __g = _G

local setColor = function(c) end
----------------------------------------------------------------------------
local platform = cc.Application:getInstance():getTargetPlatform()

if platform == cc.PLATFORM_OS_WINDOWS then
    -- 调用windows api设置控制台文本颜色
    local STD_INPUT_HANDLE  = -10
    local STD_OUTPUT_HANDLE = -11
    local STD_ERROR_HANDLE  = -12

    local ffi = require('ffi')
    ffi.cdef[[
        typedef unsigned short      WORD;
        typedef unsigned long       DWORD;
        typedef unsigned int        UINT;
        typedef UINT                HWND;
        typedef void*               HANDLE;
        typedef int                 BOOL;

        HANDLE GetStdHandle(DWORD nStdHandle);
        BOOL SetConsoleTextAttribute(HANDLE hConsoleOutput, WORD wAttributes);
    ]]

    local kernel32 = ffi.load('Kernel32.dll')
    local stdout = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
    setColor = function(c) kernel32.SetConsoleTextAttribute(stdout, c) end
end

----------------------------------------------------------------------------
local color = {}

setfenv(1, color)

FOREGROUND_BLACK     = 0x00
FOREGROUND_BLUE      = 0x01 -- text color contains blue.
FOREGROUND_GREEN     = 0x02 -- text color contains green.
FOREGROUND_RED       = 0x04 -- text color contains red.
FOREGROUND_INTENSITY = 0x08 -- text color is intensified.

BACKGROUND_BLUE      = 0x10 -- background color contains blue.
BACKGROUND_GREEN     = 0x20 -- background color contains green.
BACKGROUND_RED       = 0x40 -- background color contains red.
BACKGROUND_INTENSITY = 0x80 -- background color is intensified.

RED     = bor(FOREGROUND_RED, FOREGROUND_INTENSITY)
BLUE    = bor(FOREGROUND_BLUE, FOREGROUND_INTENSITY)
GREEN   = bor(FOREGROUND_GREEN, FOREGROUND_INTENSITY)
PURPLE  = bor(FOREGROUND_RED, FOREGROUND_BLUE, FOREGROUND_INTENSITY)
YELLOW  = bor(FOREGROUND_RED, FOREGROUND_GREEN, FOREGROUND_INTENSITY)
DEFAULT = bor(FOREGROUND_RED, FOREGROUND_GREEN, FOREGROUND_BLUE)
CYAN    = bor(FOREGROUND_BLUE, FOREGROUND_GREEN)

function colorPrint(c, ...)
    setColor(c);
    __g.print(...);
    setColor(DEFAULT)
end

return color