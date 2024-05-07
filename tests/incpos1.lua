require("string")
require (test_dir.."tools")


iterations = 0
test_table = {
    -- block nr, page nr, incr block nr, inc page nr    
    {0 , 0, 1, 0},
    {15, 3, 16, 3},
    {255,79, 0, 0},
    {255, 14, 0, 15},
    {123, 54, 124, 54}
}


function num_iterations()
    return #test_table
end


function arrange()
    iterations = iterations + 1
    set_pc(load_address)
    write_byte(load_address + 3, iterations)

    local map_start = de_ref(load_address + 6)
    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]
    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)
    
    write_byte(load_address + 8, block_nr)
    write_byte(load_address + 9, page_nr)
    set_word_at(load_address + 10, ref_map_addr)
    write_byte(load_address+ 12, ref_mask)
end


function assert()
    local state = get_mem_state(de_ref(load_address + 4))
    local map_start = de_ref(load_address + 6)

    local block_nr = test_table[iterations][3]
    local page_nr = test_table[iterations][4]

    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)

    if (block_nr + 256 * page_nr) ~= state["blockPos"] then
        return false, string.format("Wrong block position: %x", state["blockPos"])
    end

    if state["mapPos.address"] ~= ref_map_addr then
        return false, string.format("Wrong map bit address: %x", state["mapPos.address"])
    end

    if state["mapPos.mask"] ~= ref_mask then
        return false, string.format("Wrong map bit maske: %x", state["mapPos.mask"])
    end    

    return true, ""
end