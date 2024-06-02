require (test_dir.."tools")


function arrange()

end

function assert()
    -- check if allocation failed
    if contains_flag("C") then
        return false, "Error: Carry was set"
    end

    -- look at length field in the current element
    local elem = parse_allocated_block(read_byte(load_address + 3), read_byte(load_address + 4), read_byte(load_address + 5))
    local l = elem.len
    if l ~= read_byte(load_address + 6) then
        return false, string.format("Line length wrong. wanted %d got %d", l, read_byte(load_address + 6))
    end

    return true, ""
end