local fio = require('fio')
local errno = require('errno')
local yaml = require('yaml')
local log = require('log')
local client = require('http.client').new({ max_connections = 5 })


local function read_file(path)
    local file = fio.open(path)
    if file == nil then
        return nil, string.format('Failed to open file %s: %s', path, errno.strerror())
    end
    local buf = {}
    while true do
        local val = file:read(1024)
        if val == nil then
            return nil, string.format('Failed to read from file %s: %s', path, errno.strerror())
        elseif val == '' then
            break
        end
        table.insert(buf, val)
    end
    file:close()
    return table.concat(buf, '')
end

local function processConfig(fileName)
    local raw, err = read_file(fileName)
    if err ~= nil then
        return nil, err
    end
    return yaml.decode(raw)
end

local function getURL(host, port, resource)
    return host .. ':' .. port .. resource
end

local function getProxyHandler(config)
    local host = config.proxy.bypass.host
    local port = config.proxy.bypass.port

    local function proxyHandler(req)
        local resp = client:request(req:method(), getURL(host, port, req:path()), req.body, {
            verify_host = false,
            verify_peer = false,
            accept_encoding = true
        })
        return resp
    end

    return proxyHandler
end

local router = require('http.router').new()

local config, err = processConfig('../config.yml')
if err ~= nil then
    log.error(err)
    os.exit()
end

local proxyHandler = getProxyHandler(config)

router:route({ method = 'GET', path = '/.*' }, proxyHandler)
router:route({ method = 'GET', path = '/' }, proxyHandler)

local server = require('http.server').new('localhost', tonumber(config.proxy.port))

server:set_router(router)

server:start()
