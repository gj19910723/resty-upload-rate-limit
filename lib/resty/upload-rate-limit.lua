local ngx_req = ngx.req
local req_socket = ngx.req.socket
local ngx_now = ngx.now
local ngx_sleep = ngx.sleep
local _M = { version = '0.0.1' }

local CHUNK_SIZE = 4096
local BUFFER_SIZE = 128 * 1024

local mt = {
    __index = _M
}

local function limit_upload_rate(rate, after, buffer_size, chunk_size)
    if rate then
        local sock = req_socket()
        local start = ngx_now()

        local rate_in_bytes = rate * 1024
        local body_size = 0

        ngx_req.init_body(buf_size)
        while true do
            local chunk, err = sock:receive(chunk_size)
            if not chunk then
                if err == "closed" then
                    break
                else
                    ngx.log(ngx.ERR, "fail to read request body, err: " .. err)
                    return false, "fail to read body"
                end
            else
                ngx_req.append_body(chunk)
                body_size = body_size + #chunk
                local delay = ngx_now() - start
                local expected = body_size / rate_in_bytes
                local interval = expected - delay
                if interval > 0 then
                    ngx_sleep(interval)
                end
            end
        end
        ngx_req.finish_body()
        return true, ""
    else
        ngx_req.read_body()
        return true, ""
    end
end

function _M.new(rate, after, buf_size, chunk_size)
    return setmetatable({
        rate = rate or 0,
        after = after or 0,
        buf_size = buf_size or BUFFER_SIZE,
        chunk_size = chunk_size or CHUNK_SIZE
    }, mt)
end

function _M.upload(self)
    return limit_upload_rate(self.rate, self.after, self.buf_size, self.chunk_size)
end



return _M