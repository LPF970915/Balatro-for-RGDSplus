function love.conf(t)
    t.identity = "balatro-dual-installer"
    t.version = "11.5"
    t.console = true
    t.window = false
    t.modules.audio = false
    t.modules.sound = false
    t.modules.physics = false
    if os.getenv("BALATRO_IMPORT_TEST") == "1" then
        t.modules.graphics = false
        t.modules.window = false
    end
end
