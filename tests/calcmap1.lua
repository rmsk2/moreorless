require("string")
require (test_dir.."tools")


iterations = 0
test_table = {
    -- block nr, page nr
    {15, 3},
    {0 , 0},
    {255,79}, -- adapt when block size increases
    {123, 54}
}


function num_iterations()
    return #test_table
end


function arrange()
    iterations = iterations + 1
    set_pc(load_address)

    write_byte(load_address + 3, test_table[iterations][1])
    write_byte(load_address + 4, test_table[iterations][2])
end


function assert()
    local free_pos = de_ref(load_address + 5)
    local map_addr = de_ref(free_pos)
    local mask = read_byte(free_pos + 2)
    
    local map_start = de_ref(load_address + 7)
    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]

    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)

    if ref_map_addr ~= map_addr then
        return false, string.format("Wrong address: %x", map_addr)
    end

    if ref_mask ~= mask then
        return false, string.format("Wrong mask: %x", mask)
    end

    return true, ""
end