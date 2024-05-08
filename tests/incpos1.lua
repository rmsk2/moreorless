require("string")
require (test_dir.."tools")

-- The asm test driver receives five values which are used to set the current
-- block in blockPos and mapPos. Then memory.incBlockPosCtr is called and
-- it is checked whether the incremented values matches the expected values.

iterations = 0
test_table = {
    -- block nr, page nr, incremented block nr, incremented page nr    
    {0 , 0, 1, 0},
    {15, 3, 16, 3},
    {255,79, 0, 0},   -- adapt when block size increases
    {255, 14, 0, 15}, -- adapt when block size increases
    {123, 54, 124, 54}
}


function num_iterations()
    return #test_table
end


function arrange()
    iterations = iterations + 1
    set_pc(load_address)
    -- set iteration number. This allows the asm side to only call init when
    -- this value is one.
    write_byte(load_address + 3, iterations)

    -- read start address of block map from asm side
    local map_start = de_ref(load_address + 6)

    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]

    -- determine mapPos.address and mapPos.mask for this block
    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)
    
    -- write initial block and page numbers
    write_byte(load_address + 8, block_nr)
    write_byte(load_address + 9, page_nr)
    -- write initial mapPos.address and mapPos.masks
    set_word_at(load_address + 10, ref_map_addr)
    write_byte(load_address + 12, ref_mask)
end


function assert()
    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 4
    local state = get_mem_state(de_ref(load_address + 4))
    -- read start address of block map from asm side
    local map_start = de_ref(load_address + 6)

    -- read reference values for incremented block and page number from test_table
    local block_nr = test_table[iterations][3]
    local page_nr = test_table[iterations][4]

    -- calcuate mapPos.address and mapPos.mask for this block
    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)

    -- check whether blockPos has been calculated correctly
    if (block_nr + 256 * page_nr) ~= state["blockPos"] then
        return false, string.format("Wrong block position: %x", state["blockPos"])
    end

    -- check whether mapPos.address has been calculated correctly
    if state["mapPos.address"] ~= ref_map_addr then
        return false, string.format("Wrong map bit address: %x", state["mapPos.address"])
    end

    -- check whether mapPos.mask has been calculated correctly
    if state["mapPos.mask"] ~= ref_mask then
        return false, string.format("Wrong map bit mask: %x", state["mapPos.mask"])
    end    

    return true, ""
end