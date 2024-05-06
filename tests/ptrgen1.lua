require("string")
require (test_dir.."tools")


iterations = 0
test_table = {
    -- block nr, page nr
    {15, 3},
    {0 , 0},
    {255,79},
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
    local start_address = reference_pages[test_table[iterations][2]+1] * PAGE_SIZE
    start_address = start_address + test_table[iterations][1] * BLOCK_SIZE

    local counter = 0

    for i = start_address, start_address + BLOCK_SIZE - 1, 1 do
        if read_byte_long(i) ~= counter then
            return false, string.format("Wrong value. Expected %d got %d at %x", counter, read_byte_long(i), i)
        end
    end

    return true, ""
end