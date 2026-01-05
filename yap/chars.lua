local Characters = {}

Characters.__index = Characters

function Characters.new()
    local self = setmetatable({}, Characters)
    self.characters = {}
    self.quads = {}
    return self
end

function 

return Characters
