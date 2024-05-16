require (test_dir.."tools")


function arrange()

end

function assert()
    local c = 15
    local h = 5
    local e = 10
    -- check if allocation failed
    if contains_flag("C") then
        return false, "Error: Carry was set"
    end

    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 4) then
        return false, string.format("Unexpected number of blocks: %d of %d", state["numFreeBlocks"], state["numBlocks"])
    end

    -- verify length of list before remove
    local list_len = de_ref(load_address + 8)

    if list_len ~= 3 then
        return false, string.format("Wrong length before remove: %d", list_len)
    end

    -- verify length of list after remove
    local list_len = de_ref(load_address + 13)

    if list_len ~= 2 then
        return false, string.format("Wrong length after remove: %d", list_len)
    end

    local addr_current = to_addr_flat(read_byte(load_address + c), read_byte(load_address + c + 1), read_byte(load_address + c + 2))
    local addr_end = to_addr_flat(read_byte(load_address + e), read_byte(load_address + e + 1), read_byte(load_address + e + 2))

    if addr_current ~= addr_end then
        return false, string.format("Current position not at end: %s != %s", addr_current, addr_end)
    end

    -- print()
    local elem = parse_allocated_block(read_byte(load_address + h), read_byte(load_address + h + 1), read_byte(load_address + h + 2))
    -- print_whole_list(elem)
    -- print(to_addr_flat(read_byte(load_address + c), read_byte(load_address + c + 1), read_byte(load_address + c + 2)))
    local l = elem.len
    if l ~= 22 then
        return false, string.format("Line 1 length wrong: %d", l)
    end
    
    elem = parse_allocated_block(read_byte(load_address + c), read_byte(load_address + c + 1), read_byte(load_address + c + 2))    
    l = elem.len
    if l ~= 21 then
        return false, string.format("Line 2 length wrong: %d", l)
    end    

    return true, ""
end