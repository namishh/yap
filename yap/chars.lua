local Characters = {}

Characters.__index = Characters

function Characters.new()
    local self = setmetatable({}, Characters)
    self.characters = {}
    self.quads = {}
    return self
end

function Characters:register(id, data)
  self.characters[id] = {
      id = id,
      name = data.name or id,
      spritesheet = data.spritesheet
  }

  if data.spritesheet then
    self:makeQuads(id)
  end
end

function Characters:makeQuads(id)
  local char = self.characters[id]
  if not char or not char.spritesheet then
    return
  end

  local sheet = char.spritesheet
  local path = sheet[1]
  local spriteW = sheet[2]
  local spriteH = sheet[3]
  local rows = sheet[4]
  local cols = sheet[5]

  local imageW = spriteW * cols
  local imageH = spriteH * rows

  self.quads[id] = {
    spriteWidth = spriteW,
    spriteHeight = spriteH,
    rows = rows,
    cols = cols,
    imageWidth = imageW,
    imageHeight = imageH,
    path = path,
    grid = {}
  }

  for row = 0, rows - 1 do
    self.quads[id].grid[row] = {}
    for col = 0, cols - 1 do
        self.quads[id].grid[row][col] = {
            x = col * spriteW,
            y = row * spriteH,
            w = spriteW,
            h = spriteH
        }
    end
  end
end

function Characters:getPortraitQuad(id, row, col)
  local quadData = self.quads[id]
  if not quadData then
    return nil
  end
  row = math.max(0, math.min(row, quadData.rows - 1))
  col = math.max(0, math.min(col, quadData.cols - 1))
  local quad = quadData.grid[row] and quadData.grid[row][col]
  if not quad then
      return nil
  end
  return {
    x = quad.x,
    y = quad.y,
    w = quad.w,
    h = quad.h,
    imageWidth = quadData.imageWidth,
    imageHeight = quadData.imageHeight,
    path = quadData.path
  }
end

function Characters:get(id)
  return self.characters[id]
end

function Characters:has(id)
  return self.characters[id] ~= nil
end

function Characters:getAllIds()
  local ids = {}
  for id in pairs(self.characters) do
      table.insert(ids, id)
  end
  return ids
end

function Characters:remove(id)
  self.characters[id] = nil
  self.quads[id] = nil
end

function Characters:clear()
  self.characters = {}
  self.quads = {}
end

-- built in helper function that might come in handy later.
-- this requires the love2d api
function Characters:createLoveQuad(id, row, col)
  local info = self:getPortraitQuad(id, row, col)
  if not info then
      return nil
  end
  if love and love.graphics and love.graphics.newQuad then
    return love.graphics.newQuad(
      info.x, info.y,
      info.w, info.h,
      info.imageWidth, info.imageHeight
    )
  end
  return nil
end

return Characters
