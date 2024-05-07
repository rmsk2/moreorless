require("string")
require (test_dir.."tools")


iterations = 0
test_table = {
    -- block nr, page nr, free: true/false
    {0 , 0, true},
    {15, 3, false},
    {255,79, true},   -- adapt when block size increases
}


function num_iterations()
    return #test_table
end


function arrange()
    iterations = iterations + 1
    set_pc(load_address)

    local map_start = de_ref(load_address + 3)
    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]
    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)
    local is_free = test_table[iterations][3]
    local bit_val = 0

    set_word_at(load_address + 5, ref_map_addr)
    write_byte(load_address + 7, ref_mask)

    if not is_free then 
        bit_val = 1
    end

    write_byte(load_address + 8, bit_val)
end


function assert()
    local flags = get_flags()
    local is_free = test_table[iterations][3]

    if is_free then
        return contains_flag("C"), "Carry is not set: Block is not free"
    else
        return not contains_flag("C"), "Carry is set: Block is free"
    end
end