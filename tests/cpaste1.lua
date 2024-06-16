require (test_dir.."tools")

addr_clip_len = de_ref(load_address + 3)
addr_clip_head = de_ref(load_address + 5)
addr_mem_state = de_ref(load_address + 7)
addr_org_list = de_ref(load_address + 13)

function arrange()
end


function assert()
    -- parse whole memory.MEM_STATE struct
    local state = get_mem_state(addr_mem_state)
    local used_blocks = 28

    local carry_set = contains_flag("C")

    if carry_set then
        return false, "An error occurred"
    end

    local h = parse_allocated_block(read_byte(addr_clip_head), read_byte(addr_clip_head+1), read_byte(addr_clip_head+2))
    local o = parse_allocated_block(read_byte(addr_org_list), read_byte(addr_org_list+1), read_byte(addr_org_list+2))

    print_whole_list(o)
    print("###################################")
    print_whole_list(h)
    print("==============================================================")

    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - used_blocks) then
        return false, string.format("Unexpected number of used blocks: %d instead of %d", state["numBlocks"] - state["numFreeBlocks"] , used_blocks)
    end

    local clip_len = read_word(addr_clip_len)
    if clip_len ~= 2 then
        return false, string.format("Wrong clipboard length: %d", clip_len)
    end

    local list_len = read_word(load_address + 11)
    if list_len ~= 7 then
        return false, string.format("Wrong list length: %d", list_len)
    end

    return true, ""
end
