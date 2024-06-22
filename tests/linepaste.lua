require (test_dir.."tools")

iterations = 0
test_table = {
    -- string, insertPos, clip contents, res string
    {"1234567", 2, "ab", "12ab34567"},
    {"", 0, "ab", "ab"},
    {"1234567", 7, "ab", "1234567ab"},
    {"1234567", 0, "ab", "ab1234567"},
    {"0123456789012345678901234567890123456789012345678901234567890123456789012345678", 79, "a", "0123456789012345678901234567890123456789012345678901234567890123456789012345678a"},
    {"0123456789012345678901234567890123456789012345678901234567890123456789012345678", 5, "a", "01234a56789012345678901234567890123456789012345678901234567890123456789012345678"},
    {"", 0, "a", "a"},
    {"1", 0, "a", "a1"},
    {"1", 1, "a", "1a"},
    {"12", 1, "dies ist ein doller test", "1dies ist ein doller test2"}
}


function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    local test_string = test_table[iterations][1]
    local test_clip = test_table[iterations][3]

    copy_string(test_string, load_address + 3)
    copy_string(test_clip, load_address + 93)
    write_byte(load_address + 83, #test_string)
    write_byte(load_address + 92, #test_clip)
    write_byte(load_address + 84, test_table[iterations][2])
end


function assert()
    local carry_set = contains_flag("C")

    if carry_set then
        return false, "Carry is set: An error occurred"
    end

    local res_len = read_byte(load_address + 88)
    local res_string = read_string(de_ref(load_address + 86), res_len)

    local h = parse_allocated_block(read_byte(load_address + 89), read_byte(load_address + 90), read_byte(load_address + 91))
    --print_whole_list(h)

    if res_string ~= test_table[iterations][4] then 
        return false, string.format("Wrong paste result: %s", res_string)
    end

    return true, ""
end