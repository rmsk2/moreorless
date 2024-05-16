require (test_dir.."tools")


function arrange()

end

function assert()
    -- check if allocation failed
    if contains_flag("C") then
        return false, "Error: Carry was set"
    end

    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 6) then
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

    -- print()
    -- look at length field in the first allocated block, which is at offset.
    local elem = parse_allocated_block(read_byte(load_address + 5), read_byte(load_address + 6), read_byte(load_address + 7))
    -- print_whole_list(elem)
    local l = elem.len
    if l ~= 71 then
        return false, string.format("Line 1 length wrong: %d", l)
    end
    
    -- look at length field in the second allocated block, which is at offset.
    elem = parse_allocated_block(read_byte(load_address + 10), read_byte(load_address + 11), read_byte(load_address + 12))    
    l = elem.len
    if l ~= 21 then
        return false, string.format("Line 1 length wrong: %d", l)
    end    

    return true, ""
end