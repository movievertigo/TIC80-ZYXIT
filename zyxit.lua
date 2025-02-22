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
local autoRepeatDelay = 20
local autoRepeatTime = 4
local textRegionHeight = 7
local scrollMargin = 25

local screenWidth = 240
local screenHeight = 136
local halfScreenWidth = screenWidth/2
local halfScreenHeight = screenHeight/2

local examples = {
    "sin(t-hypot(x-7.5,y-7.5,z-7.5))",
    "max(0,5+4*sin(t)-hypot(x-7.5,y-7.5,z-7.5))",
    "-.5/(hypot(x-t%10,y-t%8,z-t%12)-t%2*16)",
    "sin(max(0,8-hypot(sin(t+z)+x-7.5,sin(t+x)+y-7.5,sin(t+y)+z-7.5))^2)",
    ".025/sin(t+(x~y~z|t//1))",
    "sin(z/8+3*atan2(y-7.5,x-7.5)+t)",
    "min(0,hypot(x-8+sin(t),y-16+abs(sin(t*2))*9,z-3*abs(t*7%10-5))-3)",
    "min(0,((hypot(x-7.5,y-7.5)-5)^2+(z-8)^2)-5+sin(t*2)*5)",
    "max(-0.05,1.5-abs(sin(x+t*4)+cos(y+t*4)+7.5-z))",
    "sin(x+y+t+sin(z+t*4))",
    "sin(x/5.1)+sin(y/5.1)+sin(z/5.1)-sin(t*2)*2-1",
    "min(0,y-0.2-tan(tan(sin(x/5)*sin(z/5)*sin(y/5-t*1.5))))",
    "max(0,-y+0.2+tan(tan(sin(x/2.5)*sin(z/2.5)*sin(z/5+y/5-t*1.5))))",
    "max(0,1-(x~y~min(z,sin(t*2)*8+8)//1))",
    "0.4/atan(x+y+z-22.5-sin(t)*24)",
    "hypot(x-7.5,y-7.5,z-7.5)-sin(t*1.1+x)+sin(t*1.2+y)+sin(t*1.3+z)-8",
    "x%5*y%5*z%5*sin(t*sign(x%10-5)*sign(y%10-5)*sign(z%10-5)+.8)",
    "tan(t/40+x*y*z+i)/999",
    "tan(t/4+(x~y~z))/99",
    "-.2/(hypot((x-7.5)*sin(t),(y-7.5)*sin(t),z-7.5)-8)",
    "max(0,1-abs(hypot(x-7,y-7,z-7)-7))/9/sin(atan2(x-7,y-7)+sin(t)*4)",
    "max(0,1-abs(hypot(x-7,y-7)-7))*.2/(z-7.5)/sin(atan2(x-7,y-7)+t*4)",
    "(x~y~z<1 and 1or x~y~z>14 and -1or 0)*sin(t*2+hypot(x-7,y-7,z-7))",
}

local sin, cos, sqrt = math.sin, math.cos, math.sqrt

function math.hypot(...)
    local sum = 0
    for i=1, select('#', ...) do
        local v = select(i, ...)
        sum = sum + v * v
    end
    return sqrt(sum)
end

function math.sign(x)
    return x > 0 and 1 or (x < 0 and -1 or 0)
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
    local sign = math.sign
    local sin = math.sin
    local sinh = math.sinh
    local sqrt = math.sqrt
    local tan = math.tan
    local tanh = math.tanh
    local hypot = math.hypot
]]

local exampleIndex = 1
local input = examples[exampleIndex]
local cursorIndex = #input
local selectIndex = cursorIndex
local cursorX = -1
local textX = 0
local textDirty = true
local flashTime = 0
local modifiedTime = 0
local buttonWasDown = false
local startedOnText = false
local keyTable = {}
local clipboard = ""
local history = {}
local historyIndex = 0

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
    if left and not startedOnText then
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

local function updateTextBox()
    local mouseX, mouseY, leftButton = mouse()
    local modified = false
    local historyOp = false
    vbank(0)
    if leftButton and not buttonWasDown then
        startedOnText = mouseY >= screenHeight - textRegionHeight
    end
    if leftButton then
        if startedOnText then
            local oldDistance = 1e308
            for i = 0, #input do
                local distance = textX + print(input:sub(1, i), 0, -8, 0, false, 1, true) - mouseX
                if distance > 0 then
                    if distance <= oldDistance then
                        cursorIndex = i
                    else
                        cursorIndex = i - 1
                    end
                    textDirty = true
                    break
                elseif i == #input then
                    cursorIndex = i
                    textDirty = true
                else 
                    oldDistance = -distance
                end
            end
            if not buttonWasDown then selectIndex = cursorIndex end
        end
        buttonWasDown = true
    else
        buttonWasDown = false
    end    
    if key() and not (leftButton and startedOnText) then
        local oldState = {input, cursorIndex, selectIndex}
        for i = 1, #keyTable do
            if not key(63) and keyTable[i][1] < 128 ~= key(64) and keyp(keyTable[i][1]%128, autoRepeatDelay, autoRepeatTime) then
                local posA = cursorIndex < selectIndex and cursorIndex or selectIndex
                local posB = cursorIndex > selectIndex and cursorIndex or selectIndex
                input = input:sub(1, posA)..keyTable[i][2]..input:sub(posB+1, #input)
                cursorIndex = posA + 1
                modified = true
            end
        end

        if key(63) then
            local posA = cursorIndex < selectIndex and cursorIndex or selectIndex
            local posB = cursorIndex > selectIndex and cursorIndex or selectIndex
            if keyp(22, autoRepeatDelay, autoRepeatTime) then
                input = input:sub(1, posA)..clipboard..input:sub(posB+1, #input)
                cursorIndex = posA + #clipboard
                modified = true
            elseif cursorIndex ~= selectIndex and keyp(3, autoRepeatDelay, autoRepeatTime) then
                clipboard = input:sub(posA+1, posB)
            end
        end

        if cursorIndex ~= selectIndex and (keyp(51, autoRepeatDelay, autoRepeatTime) or keyp(52, autoRepeatDelay, autoRepeatTime) or (key(63) and keyp(24, autoRepeatDelay, autoRepeatTime))) then
            local posA = cursorIndex < selectIndex and cursorIndex or selectIndex
            local posB = cursorIndex > selectIndex and cursorIndex or selectIndex
            if key(63) and keyp(24, autoRepeatDelay, autoRepeatTime) then clipboard = input:sub(posA+1, posB) end
            input = input:sub(1, posA)..input:sub(posB+1, #input)
            cursorIndex = posA
            modified = true
        else
            if keyp(51, autoRepeatDelay, autoRepeatTime) and cursorIndex > 0 then input = input:sub(1, cursorIndex-1)..input:sub(cursorIndex+1, #input); cursorIndex = cursorIndex - 1; modified = true end
            if keyp(52, autoRepeatDelay, autoRepeatTime) and cursorIndex < #input then input = input:sub(1, cursorIndex)..input:sub(cursorIndex+2, #input); modified = true end
        end

        if keyp(56, autoRepeatDelay, autoRepeatTime) then cursorIndex = 0; textDirty = true end
        if keyp(57, autoRepeatDelay, autoRepeatTime) then cursorIndex = #input; textDirty = true end
        if not key(64) and not modified and not textDirty and cursorIndex ~= selectIndex then
            if keyp(60, autoRepeatDelay, autoRepeatTime) then cursorIndex = cursorIndex < selectIndex and cursorIndex or selectIndex; textDirty = true end
            if keyp(61, autoRepeatDelay, autoRepeatTime) then cursorIndex = cursorIndex > selectIndex and cursorIndex or selectIndex; textDirty = true end
        else
            if keyp(60, autoRepeatDelay, autoRepeatTime) then cursorIndex = cursorIndex - 1; textDirty = true end
            if keyp(61, autoRepeatDelay, autoRepeatTime) then cursorIndex = cursorIndex + 1; textDirty = true end
        end

        if cursorIndex < 0 then cursorIndex = 0 end
        if cursorIndex > #input then cursorIndex = #input end

        if modified or (textDirty and not key(64)) then selectIndex = cursorIndex end

        if key(63) then
            if keyp(1, autoRepeatDelay, autoRepeatTime) then cursorIndex = 0; selectIndex = #input; textDirty = true end

            if not key(64) and keyp(26, autoRepeatDelay, autoRepeatTime) then
                if historyIndex > 1 then
                    historyIndex = historyIndex - 1
                    input, cursorIndex, selectIndex = history[historyIndex][1], history[historyIndex][2], history[historyIndex][3]
                    modified = true; historyOp = true
                end
            end

            if (key(64) and keyp(26, autoRepeatDelay, autoRepeatTime)) or keyp(25, autoRepeatDelay, autoRepeatTime) then
                if historyIndex < #history then
                    historyIndex = historyIndex + 1
                    input, cursorIndex, selectIndex = history[historyIndex][1], history[historyIndex][2], history[historyIndex][3]
                    modified = true; historyOp = true
                end
            end
        end

        if keyp(55, autoRepeatDelay, autoRepeatTime) or keyp(59, autoRepeatDelay, autoRepeatTime) then
            exampleIndex = (exampleIndex % #examples) + 1
            input = examples[exampleIndex]; cursorIndex = #input; selectIndex = cursorIndex
            modified = true; historyOp = true; history = {}; historyIndex = 0
        end
        if keyp(54, autoRepeatDelay, autoRepeatTime) or keyp(58, autoRepeatDelay, autoRepeatTime) then
            exampleIndex = (exampleIndex - 2) % #examples + 1
            input = examples[exampleIndex]; cursorIndex = #input; selectIndex = cursorIndex
            modified = true; historyOp = true; history = {}; historyIndex = 0
        end

        if modified and not historyOp then
            if historyIndex < #history then for i = historyIndex+1, #history do table.remove(history) end end
            if #history == 0 then
                history[#history+1] = oldState
            end
            history[#history][2], history[#history][3] = oldState[2], oldState[3]
            history[#history+1] = {input, cursorIndex, selectIndex}
            historyIndex = #history
        end
    end
    if textDirty or modified then
        cls(0)
        local textWidth = print(input, 0, -8, 0, false, 1, true) + 1
        local cursorDistance = print(input:sub(1, cursorIndex), 0, -8, 0, false, 1, true)
        local selectDistance = print(input:sub(1, selectIndex), 0, -8, 0, false, 1, true)
        if textWidth < screenWidth then
            textX = halfScreenWidth - textWidth/2
        else
            cursorX = textX + cursorDistance
            if cursorX > screenWidth - scrollMargin and (not leftButton or cursorIndex ~= selectIndex) then textX = textX - cursorX + screenWidth - scrollMargin end
            if cursorX < scrollMargin and (not leftButton or cursorIndex ~= selectIndex) then textX = textX - cursorX + scrollMargin end
            if textX > 0 then textX = 0 end
            if textX+textWidth < screenWidth then textX = screenWidth - textWidth end
        end
        cursorX = textX + cursorDistance
        print(input, textX+1, screenHeight-6, 3, false, 1, true)
        flashTime = time()
        textDirty = false
        if selectIndex ~= cursorIndex then
            if selectIndex < cursorIndex then
                clip(textX+selectDistance, screenHeight-7, 1+cursorDistance-selectDistance, 7)
            elseif selectIndex > cursorIndex then
                clip(cursorX, screenHeight-7, 1+selectDistance-cursorDistance, 7)
            end
            cls(3)
            print(input, textX+1, screenHeight-6, 0, false, 1, true)
            clip()
        end
    end
    if selectIndex == cursorIndex then line(cursorX, screenHeight-7, cursorX, screenHeight, ((time()-flashTime)//500)%2 == 0 and 3 or 0) end
    vbank(1)

    return modified
end

local function testNewFunc()
    local total = 0
    local i = 0
    for z = 0, 15 do
        for y = 0, 15 do
            for x = 0, 15 do
                if newFunc(z,y,x,i,i*0.1) > 0 then total = total + 1 end
                i = i + 1
            end
        end
    end
end

local function createKeyTable()
    keyTable = {
        {128+27,")"},{128+28,"!"},{128+32,"%"},{128+33,"^"},{128+34,"&"},{128+35,"*"},{128+36,"("},{37,"-"},{38,"="},
        {128+38,"+"},{128+41,"|"},{42,";"},{128+44,"~"},{45,","},{128+45,"<"},{46,"."},{128+46,">"},{47,"/"},{47+128,"?"},{48," "},
        {89,"+"},{90,"-"},{91,"*"},{92,"/"},{94,"."}
    }
    for i = 1, 26 do keyTable[#keyTable+1] = {i, string.char(96+i)}; keyTable[#keyTable+1] = {128+i, string.char(96+i)} end
    for i = 27, 36 do keyTable[#keyTable+1] = {i, string.char(21+i)} end
    for i = 79, 88 do keyTable[#keyTable+1] = {i, string.char(i-31)} end
end

function BOOT()
    cls(0)
    vbank(1)
    cls(0)
    createKeyTable()
end

function TIC()
    local newTime = time()
    local deltaTime = newTime - oldTime
    oldTime = newTime

    cls(0)

    if updateTextBox() then
        modifiedTime = newTime
        newFunc = compileFunc(input)
        if not pcall(testNewFunc) then newFunc = compileFunc("0") end
    end

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

    local t = (newTime-modifiedTime)/1000
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
    trace((math.floor(1000*(time() - newTime))/1000).."ms ", 0, 0)
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
-- 000:000000111111222222333333444444555555666666777777888888999999aaaaaabbbbbbccccccddddddeeeeeeffffff
-- 001:0000007500008c0000a30000ba0000d10000e80000ff00000000007575758c8c8ca3a3a3bababad1d1d1e8e8e8ffffff
-- </PALETTE>

