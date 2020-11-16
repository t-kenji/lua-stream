---
--  Lua Streaming request handling module.
--
--  @module     stream
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2020-2021 t-kenji

local _M = {
    _VERSION = "Stream 0.2.1",
}

local unix = require('socket.unix')

function table.indexof(t, v)
    for key, val in pairs(t) do
        if val == v then
            return key
        end
    end
end

function table.flatten(t)
    local res = {}

    local function flatten(t)
        for _, v in ipairs(t) do
            if type(v) == 'table' then
                flatten(v)
            else
                table.insert(res, v)
            end
        end
    end

    flatten(t)
    return res
end

local servers = {}
local readers = {}
local writers = {}

local threads = setmetatable({}, {__mode = 'k'})
local streams = setmetatable({}, {__mode = 'k'})

function _M.unix(path)
    os.remove(path)
    local sock = assert(unix.stream())
    assert(sock:bind(path))
    assert(sock:listen())
    assert(sock:settimeout(0)) -- change to non-blocking.
    return sock
end

function _M.new(sock)
    local instance = {
        sock_ = sock,
        onerror_ = function (s, err) print('error: ' .. err) end,
    }

    function instance:onreceive(callback, oneshot)
        -- FIXME: Thread the following, if performance is lacking.
        threads[self.sock_] = assert(coroutine.create(function (s)
            while true do
                table.remove(readers, table.indexof(readers, s))
                table.insert(writers, s)

                coroutine.yield()
                callback(s)

                table.remove(writers, table.indexof(writers, s))
                if oneshot then
                    break
                else
                    table.insert(readers, s)
                    coroutine.yield()
                end
            end
            assert(s:shutdown())
        end))
        table.insert(readers, self.sock_)

        return self
    end

    function instance:onerror(callback)
        if type(callback) == 'function' then
            self.onerror_ = callback
        end

        return self
    end

    streams[sock] = instance
    return instance
end

local vanished = {}

function _M.vanish(co)
    co = co or coroutine.running()
    for i, s in ipairs(writers) do
        if threads[s] == co then
            vanished[co] = s
            table.remove(writers, i)
            break
        end
    end
end

function _M.appear(co)
    co = co or coroutine.running()
    local s = vanished[co]
    if s then
        table.insert(writers, s)
    end
    vanished[co] = nil
end

function _M.onaccept(sock, callback)
    threads[sock] = coroutine.create(function (s)
        while true do
            local c = assert(s:accept())
            assert(c:settimeout(0))

            callback(_M.new(c))

            coroutine.yield()
        end
    end)
    table.insert(servers, sock)
end

function _M.serve()
    local socket = require('socket')

    while true do
        local r, w = socket.select(table.flatten({servers, readers}), writers)

        for _, s in ipairs(table.flatten({r, w})) do
            local ok, err = coroutine.resume(threads[s], s)
            if ok then
                -- TODO: anything to do?
            else
                pcall(streams[s].onerror_, s, err)

                for _, set in pairs({readers, writers}) do
                    local i = table.indexof(set, s)
                    if i then
                        table.remove(set, i)
                    end
                end

                pcall(function ()
                    s:close()
                end)
            end
        end
    end
end

return _M
