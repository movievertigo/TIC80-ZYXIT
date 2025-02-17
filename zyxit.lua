-- title: ZYXIT
-- author: Movie Vertigo
-- desc: 3D mathematical playground
-- script: lua
-- input: mouse
-- saveid: ZYXIT

local dragSpeed = 0.05
local damping = 0.05
local scaleDefault = 100
local scaleMin = 50
local scaleMax = 300
local scaleChange = 0.04
local scaleDamping = 0.1
local distance = 24

local screenWidth = 240
local screenHeight = 136
local halfScreenWidth = screenWidth/2
local halfScreenHeight = screenHeight/2

local sin, cos, sqrt = math.sin, math.cos, math.sqrt

function math.hypot(...)
    local sum = 0
    for i=1, select('#', ...) do
        local v = select(i, ...)
        sum = sum + v * v
    end
    return sqrt(sum)
end

local mathFuncs = [[
    local abs = math.abs
    local acos = math.acos
    local asin = math.asin
    local atan = math.atan
    local atan2 = math.atan2
    local ceil = math.ceil
    local cos = math.cos
    local cosh = math.cosh
    local deg = math.deg
    local exp = math.exp
    local floor = math.floor
    local fmod = math.fmod
    local frexp = math.frexp
    local ldexp = math.ldexp
    local log = math.log
    local log10 = math.log10
    local max = math.max
    local min = math.min
    local modf = math.modf
    local pi = math.pi
    local pow = math.pow
    local rad = math.rad
    local sin = math.sin
    local sinh = math.sinh
    local sqrt = math.sqrt
    local tan = math.tan
    local tanh = math.tanh
    local hypot = math.hypot
]]

local input = "sin(t-hypot(x-7.5,y-7.5,z-7.5))"
--local input = "-.4/(hypot(x-t%10,y-t%8,z-t%12)-t%2*16)"
--local input = "1"

local function compileFunc(str)
    local fn = load(mathFuncs.." return function(z,y,x,i,t) return "..str.." end")
    if fn then
        return fn()
    else
        return function(z,y,x,i,t) return 0 end
    end
end

local newFunc = compileFunc(input)

local identity = { 1,0,0, 0,1,0, 0,0,1 }
local rotation = identity

local function makeRotMat(x, y, z)
    local sx, cx, sy, cy, sz, cz = sin(x), cos(x), sin(y), cos(y), sin(z), cos(z)
    return { cz*cx,cz*sx*sy-sz*cy,cz*sx*cy+sz*sy, sz*cx,sz*sx*sy+cz*cy,sz*sx*cy-cz*sy, -sx,cx*sy,cx*cy }
end

local function mulMatMat(a, b)
    local result = {}
    for i = 0,2 do
        for j = 0,2 do
            local sum = 0
            for k = 0,2 do
                sum = sum + a[i*3+k+1] * b[k*3+j+1]
            end
            result[i*3+j+1] = sum
        end
    end
    return result
end

local oldTime = time()
local oldMouseX, oldMouseY, newMouseX, newMouseY, mouseZ = 0, 0, 0.5/dragSpeed, 0.25/dragSpeed, 0
local dragX, dragY, dragZ = oldMouseX - newMouseX, newMouseY - oldMouseY, mouseZ
local dragging = false
local targetScale = scaleDefault
local scale = targetScale

function controls()
    local x, y, left, middle, right, scrollx, scrolly = mouse()
    if left then
        if x >= 0 and x < screenWidth and y >= 0 and y < screenHeight then
            if not dragging then
                dragging = true
                oldMouseX = x
                oldMouseY = y
            end
            newMouseX = x
            newMouseY = y
        end
    elseif right then
        if x >= 0 and x < screenWidth and y >= 0 and y < screenHeight then
            if not dragging then
                dragging = true
                oldMouseX = x
                oldMouseY = y
                newMouseX = x
                newMouseY = y
            end
            local delta = math.atan2(oldMouseX - halfScreenWidth, oldMouseY - halfScreenHeight) - math.atan2(x - halfScreenWidth, y - halfScreenHeight)
            if delta < -math.pi then
                delta = delta + 2*math.pi
            elseif delta > math.pi then
                delta = delta - 2*math.pi
            end
            mouseZ = mouseZ + screenWidth * delta / (2*math.pi)
            oldMouseX = x
            oldMouseY = y
            newMouseX = x
            newMouseY = y
    end
    else
        if dragging then
            oldMouseX = newMouseX
            oldMouseY = newMouseY
            mouseZ = 0
            dragging = false
        end
    end
    if scrolly > 0 then
        targetScale = targetScale * (1 + scaleChange * scrolly)
        if targetScale > scaleMax then targetScale = scaleMax end
    elseif scrolly < 0 then
        targetScale = targetScale / (1 - scaleChange * scrolly)
        if targetScale < scaleMin then targetScale = scaleMin end
    end
    if middle then
        targetScale = scaleDefault
    end
end

local frames = 0
local totalTime = 0
function TIC()
    local newTime = time()
    local deltaTime = newTime - oldTime
    oldTime = newTime

    cls(0)

    controls()
    dragX = (1-damping) * dragX + damping * (oldMouseX - newMouseX)
    dragY = (1-damping) * dragY + damping * (newMouseY - oldMouseY)
    dragZ = (1-damping) * dragZ + damping * (mouseZ)
    scale = (1-scaleDamping) * scale + scaleDamping * targetScale
    local rotSpeed = dragSpeed * deltaTime * 0.001
    rotation = mulMatMat(makeRotMat(dragX * rotSpeed, dragY * rotSpeed, dragZ * rotSpeed), rotation)

    local r1 = rotation[1]; local r2 = rotation[2]; local r3 = rotation[3]
    local r4 = rotation[4]; local r5 = rotation[5]; local r6 = rotation[6]
    local r7 = rotation[7]; local r8 = rotation[8]; local r9 = rotation[9]
    local rotx = -7.5*r1 -7.5*r2 -7.5*r3
    local roty = -7.5*r4 -7.5*r5 -7.5*r6
    local rotz = -7.5*r7 -7.5*r8 -7.5*r9 + distance
    r3 = r3 - r2*16; r2 = r2 - r1*16
    r6 = r6 - r5*16; r5 = r5 - r4*16
    r9 = r9 - r8*16; r8 = r8 - r7*16

    local t = time()/1000
    local i = 0
    for z = 0, 15 do
        for y = 0, 15 do
            for x = 0, 15 do
                local result = newFunc(z,y,x,i,t)
                if result > 1 then result = 1 elseif result < -1 then result = -1 end
                i = i + 1

                local r = scale/rotz
                local px = halfScreenWidth + rotx * r
                local py = halfScreenHeight + roty * r
                r = r * result * 0.53333333 -- 0.5 * 16/15
                local pxl = px-r
                local pxr = px+r
                local pyt = py-r
                local pyb = py+r

                if result < 0 then
                    ttri(pxl,pyt,pxr,pyt,pxl,pyb,16,0,32,0,16,16,0,0,rotz,rotz,rotz)
                    ttri(pxr,pyb,pxl,pyb,pxr,pyt,32,16,16,16,32,0,0,0,rotz,rotz,rotz)
                else
                    ttri(pxl,pyt,pxr,pyt,pxl,pyb,0,0,16,0,0,16,0,0,rotz,rotz,rotz)
                    ttri(pxr,pyb,pxl,pyb,pxr,pyt,16,16,0,16,16,0,0,0,rotz,rotz,rotz)
                end

                rotx = rotx + r1
                roty = roty + r4
                rotz = rotz + r7
            end
            rotx = rotx + r2
            roty = roty + r5
            rotz = rotz + r8
        end
        rotx = rotx + r3
        roty = roty + r6
        rotz = rotz + r9
    end
    totalTime = totalTime + time() - newTime
    frames = frames + 1
    trace((math.floor(1000*totalTime/frames)/1000).."ms ", 0, 0)
end

-- <TILES>
-- 000:0000099900099aaa0099aabb099abbcc09abbcdd9aabcdde9abcddee9abcdeef
-- 001:99900000aaa99000bbaa9900ccbba990ddcbba90eddcbaa9eeddcba9feedcba9
-- 002:0000011100011222001122330112334401233455122345561234556612345667
-- 003:1110000022211000332211004433211055433210655432216655432176654321
-- 016:9abcdeef9abcddee9aabcdde09abbcdd099abbcc0099aabb00099aaa00000999
-- 017:feedcba9eeddcba9eddcbaa9ddcbba90ccbba990bbaa9900aaa9900099900000
-- 018:1234566712345566122345560123345501123344001122330001122200000111
-- 019:7665432166554321655432215543321044332110332211002221100011100000
-- </TILES>

-- <PALETTE>
-- 000:0000007500008c0000a30000ba0000d10000e80000ff00000000007575758c8c8ca3a3a3bababad1d1d1e8e8e8ffffff
-- </PALETTE>

