require (test_dir.."tools")

addr_clip_len = de_ref(load_address + 3)
addr_clip_head = de_ref(load_address + 5)
addr_mem_state = de_ref(load_address + 7)


function arrange()
end


function assert()
    -- parse whole memory.MEM_STATE struct
    local state = get_mem_state(addr_mem_state)
    local used_blocks = 19

    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - used_blocks) then
        return false, string.format("Unexpected number of used blocks: %d instead of %d", state["numBlocks"] - state["numFreeBlocks"] , used_blocks)
    end

    local len_before_clear = read_word(load_address + 9)
    if len_before_clear ~= 3 then 
        return false, string.format("Wrong clipboard length before clear: %d", len_before_clear)
    end    

    local clip_len = read_word(addr_clip_len)
    if clip_len ~= 0 then
        return false, string.format("Wrong clipboard length: %d", clip_len)
    end

    return true, ""
end
