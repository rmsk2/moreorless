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
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 7) then
        return false, string.format("Unexpected number of blocks: %d of %d", state["numFreeBlocks"], state["numBlocks"])
    end

    -- verify length of list
    local list_len = de_ref(load_address + 11)

    if list_len ~= 3 then
        return false, string.format("Wrong length: %d", list_len)
    end

    -- print()

    -- look at length field in the first allocated block, which is at offset 6 + 1.
    local elem = parse_allocated_block(read_byte(load_address + 5), read_byte(load_address + 6), read_byte(load_address + 7))
    -- print_whole_list(elem)
    local l = elem.len
    if l ~= 14 then
        return false, string.format("Line 1 length wrong: %d", l)
    end
    
    -- look at length field in the second allocated block, which is at offset 6 + 1.
    elem = parse_allocated_block(read_byte(load_address + 8), read_byte(load_address + 9), read_byte(load_address + 10))    
    l = elem.len
    if l ~= 23 then
        return false, string.format("Line 1 length wrong: %d", l)
    end    

    -- look at length field in the second allocated block, which is at offset 6 + 1.
    elem = parse_allocated_block(read_byte(load_address + 13), read_byte(load_address + 14), read_byte(load_address + 15))
    l = elem.len
    if l ~= 51 then
        return false, string.format("Line 1 length wrong: %d", l)
    end  

    return true, ""
end