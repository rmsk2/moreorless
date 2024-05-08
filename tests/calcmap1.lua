require("string")
require (test_dir.."tools")

-- The asm test driver receives a block and a page number, then uses memory.blockPosToFarPtr
-- to generate a far ptr. The routine under test is memory.farPtrToMapBit which maps this 
-- far pointer to an address in the page/block map and a mask index which identifies the bit
-- that represents the block with the given page and block number. It is verified that
-- the values memory.farPtrToMapBit returns match the expected values.

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

    -- tell asm test driver page and block number
    write_byte(load_address + 3, test_table[iterations][1])
    write_byte(load_address + 4, test_table[iterations][2])
end


function assert()
    -- read address of memory.FREE_POS from asm side
    local free_pos = de_ref(load_address + 5)
    -- read calculation result from the asm side
    local map_addr = de_ref(free_pos)
    local mask = read_byte(free_pos + 2)
    
    -- read start address of block map from asm side
    local map_start = de_ref(load_address + 7)
    -- read reference values for page and block number
    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]

    -- calculate correct reference values
    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)

    -- verify that address in block map is correct
    if ref_map_addr ~= map_addr then
        return false, string.format("Wrong address: %x", map_addr)
    end

    -- verify that mask index is correct.
    if ref_mask ~= mask then
        return false, string.format("Wrong mask: %x", mask)
    end

    return true, ""
end