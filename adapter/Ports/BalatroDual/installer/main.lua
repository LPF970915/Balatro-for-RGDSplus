local recipe = require("recipe")
local app = assert(os.getenv("BALATRO_RGDS_ROOT"), "Missing application directory")
local testing = os.getenv("BALATRO_IMPORT_TEST") == "1"
local fs = love.filesystem
local build = "builds/" .. recipe.id
local game = build .. "/game"
local progress, title, detail = 0, "Preparing Balatro for RGDSplus", ""
local failed, visible, worker, mounted, archive_data
local heading_font, body_font
local result = {status = "starting", build = recipe.id}

local function hash(data)
    return love.data.encode("string", "hex", love.data.hash("sha256", data))
end

local function safe(path)
    if type(path) ~= "string" or path == "" or path:find("[\\:%c]") or
       path:sub(1, 1) == "/" or path:sub(-1) == "/" or path:find("//", 1, true) then
        return false
    end
    for part in path:gmatch("[^/]+") do
        if part == "." or part == ".." then return false end
    end
    return true
end

local function read(path)
    local value, err = fs.read(path)
    if not value then error("Cannot read " .. path .. ": " .. tostring(err), 0) end
    return value
end

local function write(path, data)
    assert(safe(path), "Unsafe installation path")
    local parent = path:match("^(.*)/[^/]+$")
    if parent then
        local ok, err = fs.createDirectory(parent)
        if not ok then error("Cannot create cache directory: " .. tostring(err), 0) end
    end
    local ok, err = fs.write(path, data)
    if not ok then error("Cannot write cache. Check free space / SD card: " .. tostring(err), 0) end
end

local function show()
    if testing or visible then return end
    local ok, err = love.window.setMode(2048, 768, {
        fullscreen = false, borderless = true, resizable = false, vsync = 1,
    })
    if not ok then error("Cannot open installer display: " .. tostring(err), 0) end
    love.window.setTitle("Balatro for RGDSplus")
    love.window.setPosition(0, 0, 1)
    heading_font = love.graphics.newFont(30)
    body_font = love.graphics.newFont(22)
    visible = true
end

local function step(message, fraction)
    detail, progress = message, fraction or progress
    coroutine.yield()
end

local function validate_recipe()
    assert(recipe.format == 1 and recipe.id:match("^[a-f0-9]+$") and #recipe.id == 64,
           "Invalid patch recipe")
    local seen = {}
    for _, entry in ipairs(recipe.files) do
        assert(safe(entry.path) and not seen[entry.path], "Invalid target path")
        seen[entry.path] = true
        assert(entry.size >= 0 and entry.size < 64 * 1024 * 1024, "Invalid target size")
        if entry.source then
            assert(safe(entry.source) and recipe.sources[entry.source], "Invalid source path")
        end
        if entry.payload then
            assert(safe(entry.payload) and entry.payload:match("^payload/"), "Invalid payload path")
        end
    end
    for name in pairs(recipe.sources) do assert(safe(name), "Invalid source path") end
end

local function check_payloads()
    for _, entry in ipairs(recipe.files) do
        if entry.payload then
            assert(hash(read(entry.payload)) == entry.payload_sha256,
                   "Adapter files are damaged. Extract the adapter ZIP again.")
        end
    end
end

local function existing_valid()
    if not fs.getInfo(build .. "/ready.txt", "file") then return false end
    if read(build .. "/ready.txt") ~= recipe.id .. "\n" then return false end
    for i, entry in ipairs(recipe.files) do
        local path = game .. "/" .. entry.path
        local info = fs.getInfo(path, "file")
        if not info or info.size ~= entry.size or hash(read(path)) ~= entry.sha256 then
            return false
        end
        step("Checking installed files", i / #recipe.files)
    end
    return true
end

local function open_original()
    local path = app .. "/gamedata/Balatro.exe"
    local file = io.open(path, "rb")
    if not file then
        error("Game file not found.\n\nCopy your purchased Balatro.exe to:\n" ..
              "Ports/BalatroDual/gamedata/Balatro.exe\n\nThen start Balatro for RGDSplus again.", 0)
    end
    local size = file:seek("end")
    if not size or size < 1024 or size > 128 * 1024 * 1024 then
        file:close()
        error("Invalid Balatro.exe size. Copy the original game file again.", 0)
    end
    file:seek("set", 0)
    local data = file:read("*a")
    file:close()
    if not data or #data ~= size then error("Could not read Balatro.exe completely.", 0) end
    local digest = hash(data)
    archive_data = fs.newFileData(data, "Balatro.zip")
    data = nil
    local ok, err = fs.mount(archive_data, "purchased", false)
    if not ok then
        error("Cannot open Balatro.exe as a game archive.\nCopy the original Steam file again.\n" ..
              tostring(err), 0)
    end
    mounted = true
    return digest
end

local function validate_original()
    local count, total = 0, 0
    for _ in pairs(recipe.sources) do total = total + 1 end
    for name, expected in pairs(recipe.sources) do
        local path = "purchased/" .. name
        local info = fs.getInfo(path, "file")
        if not info or info.size ~= expected.size or hash(read(path)) ~= expected.sha256 then
            error("Unsupported or modified game file.\nRequired version: " .. recipe.version ..
                  "\nMismatch: " .. name ..
                  "\n\nUse the original supported Balatro.exe. Saves have not been changed.", 0)
        end
        count = count + 1
        step("Verifying purchased game: " .. count .. " / " .. total, count / total * 0.35)
    end
end

local function materialize(entry)
    local source = entry.source and read("purchased/" .. entry.source) or ""
    local payload = entry.payload and read(entry.payload) or ""
    if not entry.ops then return source end
    local chunks, length = {}, 0
    for _, op in ipairs(entry.ops) do
        assert(op[1] == "copy" or op[1] == "insert", "Unknown patch instruction")
        local input = op[1] == "copy" and source or payload
        local offset, size = op[2], op[3]
        assert(offset >= 0 and size > 0 and offset % 1 == 0 and size % 1 == 0 and
               offset + size <= #input, "Invalid patch range")
        length = length + size
        assert(length <= entry.size, "Patch output is too large")
        chunks[#chunks + 1] = input:sub(offset + 1, offset + size)
    end
    return table.concat(chunks)
end

local function install()
    validate_recipe()
    check_payloads()
    -- Validate the cached result before deciding whether the original is needed.
    local cached = existing_valid()
    local original = io.open(app .. "/gamedata/Balatro.exe", "rb")
    if not original and cached then
        result.status = "cached"
        return
    end
    if original then original:close() end
    if not cached then show() end
    step("Reading gamedata/Balatro.exe", 0)
    local source_hash = open_original()
    if cached and fs.getInfo(build .. "/source.sha256", "file") and
       read(build .. "/source.sha256") == source_hash .. "\n" then
        result.status = "cached"
        return
    end
    show()
    validate_original()
    if cached then
        write(build .. "/source.sha256", source_hash .. "\n")
        result.status = "cached"
        return
    end
    title = "Installing Balatro for RGDSplus"
    fs.remove(build .. "/ready.txt")
    for i, entry in ipairs(recipe.files) do
        local data = materialize(entry)
        assert(#data == entry.size and hash(data) == entry.sha256,
               "Patch output mismatch: " .. entry.path)
        local path = game .. "/" .. entry.path
        write(path, data)
        assert(hash(read(path)) == entry.sha256,
               "SD card write verification failed: " .. entry.path)
        step("Installing: " .. i .. " / " .. #recipe.files, 0.35 + i / #recipe.files * 0.65)
        collectgarbage("step", 128)
    end
    write(build .. "/source.sha256", source_hash .. "\n")
    -- Only a fully verified build receives a completion marker.
    write(build .. "/ready.txt", recipe.id .. "\n")
    result.status = "installed"
end

local function report()
    result.game = fs.getSaveDirectory() .. "/" .. game
    print("[importer] status=" .. result.status .. " build=" .. recipe.id)
    if testing then
        local out = assert(io.open(app .. "/import-test-result.txt", "wb"))
        out:write(result.status, "\n", result.game, "\n", detail)
        out:close()
    end
end

local function finish(code)
    if mounted then fs.unmount(archive_data); mounted = false end
    archive_data = nil
    report()
    love.event.quit(code)
end

function love.load()
    worker = coroutine.create(install)
end

function love.update()
    if failed then return end
    local ok, err = coroutine.resume(worker)
    if not ok then
        failed, title, detail = true, "Balatro for RGDSplus - setup stopped", tostring(err)
        result.status = "error"
        print("[importer] " .. detail)
        if testing then finish(2) else show() end
    elseif coroutine.status(worker) == "dead" then
        finish(0)
    end
end

function love.draw()
    if not visible then return end
    love.graphics.clear(0.07, 0.08, 0.09)
    local width, height = love.graphics.getDimensions()
    local panel = width / 2
    for i = 0, 1 do
        local x = i * panel + 64
        local content = panel - 128
        love.graphics.setColor(0.93, 0.94, 0.95)
        love.graphics.setFont(heading_font)
        love.graphics.printf(title, x, 115, content)
        love.graphics.setFont(body_font)
        love.graphics.setColor(0.78, 0.82, 0.84)
        love.graphics.printf(detail, x, 210, content)
        if not failed then
            love.graphics.setColor(0.2, 0.23, 0.25)
            love.graphics.rectangle("fill", x, height - 150, content, 12)
            love.graphics.setColor(0.2, 0.77, 0.53)
            love.graphics.rectangle("fill", x, height - 150, content * progress, 12)
        else
            love.graphics.setColor(0.86, 0.69, 0.35)
            love.graphics.printf("Press a button to return to Ports.", x, height - 125, content)
        end
    end
end

function love.keypressed()
    if failed then finish(2) end
end

function love.joystickpressed()
    if failed then finish(2) end
end

function love.touchpressed()
    if failed then finish(2) end
end

function love.quit()
    if not failed and result.status == "starting" then return true end
end
