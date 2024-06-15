require("string")
require(test_dir.."tools")

function arrange()
	-- remember to call set_pc(load_address) if you use test iteration
end

function assert()
    local s = ""
    local addr = load_address + 3

    s = read_string(addr, 80)

    if s ~= "0123467890123456789012345678901234567890123456789012345678901234567890123456789 " then 
        return false, string.format("Wrong result: %s", s)
    end

    return true, ""
end
