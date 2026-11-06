local LED_START = 1
local LED_COUNT = 6

-- "OUT" = centre -> outside
-- "IN" = outside -> centre
-- "SCROLL" = left -> right
local FILL_MODE = "OUT"

-- How bright the LEDs are at zero throttle
local IDLE_GLOW = 25
local MAX_BRIGHTNESS = 255

-- Overall colour strength
-- 1.0 = normal, 1.4 = very colourful
local COLOUR_POWER = 1.35

-- How much the sticks move the colours around
local STICK_COLOUR_AMOUNT = 0.45

-- Set true if you want the stick colours only on the bright/filling LEDs
local STICK_FOLLOWS_FILL = false

local function clamp(x, min, max)
  if x < min then return min end
  if x > max then return max end
  return x
end

local function axis01(name)
  local v = getValue(name) or 0
  return clamp((v + 1024) / 2048, 0, 1)
end

local function axisSigned(name)
  local v = getValue(name) or 0
  return clamp(v / 1024, -1, 1)
end

local function hsvToRgb(h, s, v)
  h = h % 360

  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c

  local r, g, b = 0, 0, 0

  if h < 60 then
    r, g, b = c, x, 0
  elseif h < 120 then
    r, g, b = x, c, 0
  elseif h < 180 then
    r, g, b = 0, c, x
  elseif h < 240 then
    r, g, b = 0, x, c
  elseif h < 300 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end

  return math.floor((r + m) * 255),
         math.floor((g + m) * 255),
         math.floor((b + m) * 255)
end

local function pairPosition(ledIndex)
  if FILL_MODE == "IN" then
    if ledIndex == 1 or ledIndex == 6 then return 0 end
    if ledIndex == 2 or ledIndex == 5 then return 1 end
    return 2
  else
    if ledIndex == 3 or ledIndex == 4 then return 0 end
    if ledIndex == 2 or ledIndex == 5 then return 1 end
    return 2
  end
end

local function getFill(ledIndex, throttle)
  if FILL_MODE == "SCROLL" then
    return clamp((throttle * LED_COUNT) - (ledIndex - 1), 0, 1)
  else
    return clamp((throttle * 3) - pairPosition(ledIndex), 0, 1)
  end
end

local function getColour(ledIndex, throttle, fill)
  local ail = axisSigned("ail")
  local ele = axisSigned("ele")
  local rud = axisSigned("rud")

  local pos = (ledIndex - 1) / (LED_COUNT - 1)
  local centreDist = math.abs(ledIndex - 3.5) / 2.5

  local stickAmount = STICK_COLOUR_AMOUNT
  if STICK_FOLLOWS_FILL then
    stickAmount = stickAmount * fill
  end

  -- Base colourful moving palette.
  -- Throttle moves through the hue range but avoids white.
  local hue =
    200 +
    throttle * 170 +
    pos * 90 +
    ail * 120 * stickAmount +
    rud * centreDist * 140 * stickAmount -
    ele * (1 - centreDist) * 100 * stickAmount

  -- Keep saturation high so mid throttle stays colourful.
  local saturation = clamp(
    0.95 -
    math.abs(ele) * 0.15 +
    math.abs(rud) * 0.10,
    0.75,
    1.0
  )

  -- Value is kept high before final brightness scaling.
  local value = clamp(
    0.85 +
    math.abs(ail) * 0.10 +
    math.abs(ele) * 0.10 +
    math.abs(rud) * 0.10,
    0.75,
    1.0
  )

  local r, g, b = hsvToRgb(hue, saturation, value)

  -- Boost colour contrast a bit
  r = clamp((r - 40) * COLOUR_POWER + 40, 0, 255)
  g = clamp((g - 40) * COLOUR_POWER + 40, 0, 255)
  b = clamp((b - 40) * COLOUR_POWER + 40, 0, 255)

  return math.floor(r), math.floor(g), math.floor(b)
end

local function run()
  local throttle = axis01("thr")

  for i = 1, LED_COUNT do
    local fill = getFill(i, throttle)

    local brightness = IDLE_GLOW + fill * (MAX_BRIGHTNESS - IDLE_GLOW)

    local r, g, b = getColour(i, throttle, fill)

    setRGBLedColor(
      LED_START + i - 1,
      math.floor(r * brightness / 255),
      math.floor(g * brightness / 255),
      math.floor(b * brightness / 255)
    )
  end

  applyRGBLedColors()
end

return { run = run }