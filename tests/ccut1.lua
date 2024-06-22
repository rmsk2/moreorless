require (test_dir.."tools")

iterations = 0
test_table = {
    -- start offset, len of cut, len list, len cut, seq
    {6, 1, 1, 6, "123456"},
    {0, 1, 1, 6, "234567"},
    {2, 3, 3, 4, "1267"},
}


function num_iterations()
    return #test_table
end


seq = ""

addr_clip_len = de_ref(load_address + 3)
addr_clip_head = de_ref(load_address + 5)
addr_mem_state = de_ref(load_address + 7)
addr_org_list = de_ref(load_address + 13)
addr_start_pos = load_address + 15
addr_cut_len = load_address + 17

function arrange()
    set_pc(load_address)
    iterations = iterations + 1
    seq = ""
    set_word_at(addr_start_pos, test_table[iterations][1])
    set_word_at(addr_cut_len, test_table[iterations][2])
end


function add_to_seq(b)
    seq = seq .. string.sub(b.data, 1, 1)
end


function assert()
    -- parse whole memory.MEM_STATE struct
    local state = get_mem_state(addr_mem_state)
    local used_blocks = 19

    local carry_set = contains_flag("C")

    if carry_set then
        return false, "An error occurred"
    end

    local h = parse_allocated_block(read_byte(addr_clip_head), read_byte(addr_clip_head+1), read_byte(addr_clip_head+2))
    local o = parse_allocated_block(read_byte(addr_org_list), read_byte(addr_org_list+1), read_byte(addr_org_list+2))

    iterate_whole_list(o, add_to_seq)

    if seq ~= test_table[iterations][5] then
        return false, string.format("Wrong sequence: %s", seq)
    end

    -- print_whole_list(o)
    -- print("###################################")
    -- print_whole_list(h)
    -- print("==============================================================")

    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - used_blocks) then
        return false, string.format("Unexpected number of used blocks: %d instead of %d", state["numBlocks"] - state["numFreeBlocks"] , used_blocks)
    end

    local clip_len = read_word(addr_clip_len)
    if clip_len ~= test_table[iterations][3] then
        return false, string.format("Wrong clipboard length: %d", clip_len)
    end

    local list_len = read_word(load_address + 11)
    if list_len ~= test_table[iterations][4] then
        return false, string.format("Wrong list length: %d", list_len)
    end

    return true, ""
end
