require("string")
require (test_dir.."tools")

-- This code tests the subroutine memory.markCurrentBlockUsed. The asm test driver
-- receives three values. At first an address and a mask index for a block in the
-- block map. This information is used to initialize memory.MEM_STATE.mapPos.address
-- and mask. The third value determines if this block is to be marked as free or
-- allocated before calling the routine under test. Finally memory.markCurrentBlockUsed 
-- is called and afterwards it is  verified that the block was marked as allocated and
-- whether the value of memory.MEM_STATE.numFreeBlocks is correct.

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

    -- read start address of block map from asm side
    local map_start = de_ref(load_address + 3)
    
    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]
    
    -- determine reference value for mapPos.address and mask
    local ref_map_addr, ref_mask = pos_to_map_bit(map_start, page_nr, block_nr)
    -- set value for switch which causes the block to be marked free or allocated 
    local is_free = test_table[iterations][3]
    local bit_val = 0

    -- set value for mapPos.address
    set_word_at(load_address + 5, ref_map_addr)
    -- set value for mapPos.mask
    write_byte(load_address + 7, ref_mask)

    if not is_free then 
        bit_val = 1
    end

    -- set value for switch
    write_byte(load_address + 8, bit_val)
end


function assert()
    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 9
    local state = get_mem_state(de_ref(load_address + 9))

    local block_nr = test_table[iterations][1]
    local page_nr = test_table[iterations][2]
    
    -- determine reference value for offset and mask in state["pageMap"]
    local ref_map_addr, ref_mask = pos_to_map_bit(0, page_nr, block_nr)

    -- check if the block is allocated after the call. This has to be true independent of whether the
    -- block was marked free or allocated before markCurrentBlockUsed was called.
    if (state["pageMap"][1 + ref_map_addr] - mask_bits[1 + ref_mask]) ~= 0 then
        return false, "Block is free, but was expected to be allocated"
    end

    local is_free = test_table[iterations][3]
    
    -- Check if number of free blocks is correct
    if is_free then
        return state["numFreeBlocks"] == (state["numBlocks"] - 1), "Number of free blocks was not decremented (but should have)" 
    else
        return state["numFreeBlocks"] == state["numBlocks"], "Number of free blocks was decremented (but should have not)" 
    end
end