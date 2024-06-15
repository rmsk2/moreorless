require (test_dir.."tools")

down = 1
up = 0

iterations = 0

test_table = {
    -- sesarch text, initial pos, search direction, end count, found?
    {"this is the fourth", 0, down, 3, true},
}

addr_clip_len = de_ref(load_address + 3)
addr_clip_head = de_ref(load_address + 5)
addr_mem_state = de_ref(load_address + 7)

function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1
end


function assert()
    local carry_set = contains_flag("C")

    if carry_set then
        return false, "An error occurred"
    end

    local h = parse_allocated_block(read_byte(addr_clip_head), read_byte(addr_clip_head+1), read_byte(addr_clip_head+2))
    --print_whole_list(h)

    -- parse whole memory.MEM_STATE struct
    local state = get_mem_state(addr_mem_state)
    local used_blocks = 19
    local used_blocks_clip = 8

    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - (used_blocks  + used_blocks_clip)) then
        return false, string.format("Unexpected number of used blocks: %d instead of %d", state["numBlocks"] - state["numFreeBlocks"] , used_blocks + used_blocks_clip)
    end

    local clip_len = read_word(addr_clip_len)
    if clip_len ~= 3 then
        return false, string.format("Wrong clipboard length: %d", clip_len)
    end

    return true, ""
end
