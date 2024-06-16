require (test_dir.."tools")

used_blocks = 19
iterations = 0

test_table = {
    -- start pos, length to copy, blocks expected in clipboard
    {2, 3, 8},
    {0, 5, 15},
    {0, 0, 0},
    {6, 1, 2},
    {0, 1, 2},
    {0, 7, 19},
    {1, 1, 5},
}

addr_clip_len = de_ref(load_address + 3)
addr_clip_head = de_ref(load_address + 5)
addr_mem_state = de_ref(load_address + 7)
addr_org_list = de_ref(load_address + 9)

function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    set_word_at(load_address + 11, test_table[iterations][1])
    set_word_at(load_address + 13, test_table[iterations][2])
end


function assert()
    local carry_set = contains_flag("C")

    if carry_set then
        return false, "An error occurred"
    end

    -- local h = parse_allocated_block(read_byte(addr_clip_head), read_byte(addr_clip_head+1), read_byte(addr_clip_head+2))
    -- local o = parse_allocated_block(read_byte(addr_org_list), read_byte(addr_org_list+1), read_byte(addr_org_list+2))
    -- print_whole_list(o)
    -- print("--------------------------")
    -- print_whole_list(h)

    -- parse whole memory.MEM_STATE struct
    local state = get_mem_state(addr_mem_state)
    local used_blocks_clip = test_table[iterations][3]

    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - (used_blocks  + used_blocks_clip)) then
        return false, string.format("Unexpected number of used blocks: %d instead of %d", state["numBlocks"] - state["numFreeBlocks"] , used_blocks + used_blocks_clip)
    end

    local clip_len = read_word(addr_clip_len)
    if clip_len ~=  test_table[iterations][2] then
        return false, string.format("Wrong clipboard length: %d", clip_len)
    end

    return true, ""
end
