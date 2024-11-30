require (test_dir.."tools")

-- This is a test for the subroutine list.split which splits a list into two pieces. The piece
-- that is cut from the document list can then be found in clip.CLIP. In each iteration the
-- test driver creates a list of seven lines which is then split as defined in test_table. After the
-- call it is verified that the cut list segement has the expected length and that the used memory 
-- matches the value given in the 3rd element of the test table.

used_blocks = 19
iterations = 0
do_print = true
no_print = false

test_table = {
    -- start pos, offset to end of cut, blocks expected overall after cut, expected carry set, print, expected length of clip after call
    {2, 2, used_blocks, false, no_print, 3},
    {6, 0, used_blocks, false, no_print, 1},
    {0, 0, used_blocks, false, no_print, 1}, 
    {1, 0, used_blocks, false, no_print, 1},
    {0, 6, used_blocks, true, no_print, -1000},
    --  -6
    {6, 0xFFFA, used_blocks, true, no_print, -1000},
    --  -2
    {2, 0xFFFE, used_blocks, false, no_print, 3},
    {1, 4, used_blocks, false, no_print, 5}
}

function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    set_word_at(load_address + 11, test_table[iterations][1])
    set_word_at(load_address + 3, test_table[iterations][2])
end


function assert()
    local addr_clip_head = de_ref(load_address + 5)
    local addr_mem_state = de_ref(load_address + 7)
    local addr_org_list = de_ref(load_address + 9)

    local carry_set = contains_flag("C")    

    if test_table[iterations][4] then
        if not carry_set then
            return false, "Carry should have been set"
        end

        return true, ""
    else
        if carry_set then
            return false, "An error occurred"
        end
    end

    -- get list heads for the document and the clipboard
    local h = parse_allocated_block(read_byte(addr_clip_head), read_byte(addr_clip_head+1), read_byte(addr_clip_head+2))
    local o = parse_allocated_block(read_byte(addr_org_list), read_byte(addr_org_list+1), read_byte(addr_org_list+2))

    if test_table[iterations][5] then
        print_whole_list(o)
        print("###################################")
        print_whole_list(h)
        print("==============================================================")
    end

    -- parse whole memory.MEM_STATE struct
    local state = get_mem_state(addr_mem_state)
    local used_blocks_overall = test_table[iterations][3]

    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - used_blocks_overall) then
        return false, string.format("Unexpected number of used blocks: %d instead of %d", state["numBlocks"] - state["numFreeBlocks"] , used_blocks_overall)
    end

    -- check length of clipboard data
    local clip_len = read_word(load_address + 13)
    if clip_len ~=  test_table[iterations][6] then
        return false, string.format("Wrong clipboard length: %d", clip_len)
    end

    return true, ""
end
