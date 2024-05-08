require("string")
require (test_dir.."tools")

-- this code tests memory.blockPosToFarPtr. The test driver determines the
-- the memory address of the identified block through this subroutine and writes 
-- the the values 0-31 into the block through the page window in the 16 bit address 
-- space.

iterations = 0
test_table = {
    -- block nr, page nr    
    {0 , 0},
    {15, 3},
    {255,79},
    {123, 54}
}


function num_iterations()
    return #test_table
end


function arrange()
    iterations = iterations + 1
    set_pc(load_address)

    -- set block and page number of block
    write_byte(load_address + 3, test_table[iterations][1])
    write_byte(load_address + 4, test_table[iterations][2])
end


function assert()
    -- calculate address of block in full 24 bit address space
    local start_address = reference_pages[test_table[iterations][2]+1] * PAGE_SIZE
    start_address = start_address + test_table[iterations][1] * BLOCK_SIZE

    local counter = 0

    -- Test whether the test driver has set the data in the block to the correct values 0,1,2, ...., 31 
    for i = start_address, start_address + BLOCK_SIZE - 1, 1 do
        if read_byte_long(i) ~= counter then
            return false, string.format("Wrong value. Expected %d got %d at %x", counter, read_byte_long(i), i)
        end

        counter = counter + 1
    end

    return true, ""
end