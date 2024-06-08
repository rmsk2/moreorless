require("string")

function arrange()
	-- remember to call set_pc(load_address) if you use test iteration
end

function assert()
    local s = ""
    local addr = load_address + 3

    for i = addr, addr + 79, 1 do
        s = s .. string.char(read_byte_long(i))
    end

    if s ~= " 0123456789012345678901234567890123456789012345678901234567890123456789012345678" then 
        return false, string.format("Wrong result: %s", s)
    end

    return true, ""
end
