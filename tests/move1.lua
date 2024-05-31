require (test_dir.."tools")

-- this code tests list.move in two stages. It initializes a list of seven elements and then executes
-- two moves. At the end it is checked whether we arrived a the expected element as identified by
-- the first charatcer of the list data.

iterations = 0
test_table = {
    -- index_start lo, index_start hi, index_move lo, index_move hi, first character of data, carry set in last list.move
    {0, 0, 5, 0, "6", false},
    -- offset -3
    {6, 0, 0xFD, 0xFF, "4", false},
    -- offset -6
    {6, 0, 0xFA, 0xFF, "1", false},
    -- offset -2
    {4, 0, 0xFE, 0xFF, "3", false},
    -- offset +32767
    {4, 0, 0xFF, 0x7F, "7", true},
    -- start and offset are zero
    {0, 0, 0, 0, "1", false},
}


function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    write_byte(load_address + 3, test_table[iterations][1])
    write_byte(load_address + 4, test_table[iterations][2])
    write_byte(load_address + 5, test_table[iterations][3])
    write_byte(load_address + 6, test_table[iterations][4])
end


function assert()
    local h = parse_allocated_block(read_byte(load_address + 13), read_byte(load_address + 14), read_byte(load_address + 15))
    
    -- check if error occurred
    if contains_flag("C") then
        print()
        print_whole_list(h)
        return false, "Error: Carry was set"
    end

    local len_addr = read_word(load_address + 11)
    local llen = read_byte(len_addr) + read_byte(len_addr + 1) * 256
    if llen ~= 7 then
        return false, string.format("List has wrong length: %d", llen)
    end
    
    local b = parse_allocated_block(read_byte(load_address + 7), read_byte(load_address + 8), read_byte(load_address + 9))    
    if string.sub(b.data, 1, 1) ~= test_table[iterations][5] then
        print_allocated_block(b)
        return false, "Not at correct element"
    end

    if (read_byte(load_address + 10) ~= 0) ~= test_table[iterations][6] then
        return false, string.format("end position not signalled correctly: %d", read_byte(load_address + 10))
    end

    return true, ""
end