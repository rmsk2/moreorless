require (test_dir.."tools")

iterations = 0
test_table = {
    -- string, startPos, len, res string
    {"1234567", 2, 3, "1267"},
    {"1234567", 0, 1, "234567"},
    {"1234567", 6, 1, "123456"},
    {"1234567", 0, 7, ""},
    {"1", 0, 1, ""},
    {"01234567890123456789012345678901234567890123456789012345678901234567890123456789", 0, 80, ""},
    {"0123456789aaaaaaaaaa012345678901234567890123456789012345678901234567890123456789", 10, 10, "0123456789012345678901234567890123456789012345678901234567890123456789"},
    {"", 0, 0, ""},
}


function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    local test_string = test_table[iterations][1]

    copy_string(test_string, load_address + 3)
    write_byte(load_address+ 83, #test_string)
    write_byte(load_address + 84, test_table[iterations][2])
    write_byte(load_address + 85, test_table[iterations][3])
end


function assert()
    local carry_set = contains_flag("C")

    if carry_set then
        return false, "An error occurred"
    end

    local res_len = read_byte(load_address + 88)
    local res_string = read_string(de_ref(load_address + 86), res_len)

    if res_string ~= test_table[iterations][4] then 
        return false, string.format("Wrong cut result: %s", res_string)
    end

    local h = parse_allocated_block(read_byte(load_address + 89), read_byte(load_address + 90), read_byte(load_address + 91))
    --print_whole_list(h)

    return true, ""
end