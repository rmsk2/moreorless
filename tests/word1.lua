require("string")
require(test_dir.."tools")


iterations = 0
test_table = {
    -- string, result at 0x028000, byte counter, error
    {"a", "0161", 2, false},
    {" a", "0161", 2, false},
    {"ab    ", "026162", 3, false},
    {"ab", "026162", 3, false},
    {" a b  ", "01610162", 4, false},
    {" a b\t", "01610162", 4, false},
    {"                   a", "0161", 2, false},
    {"a     \t              ", "0161", 2, false},
    {"aaa bbbb    cc", "036161610462626262026363", 12, false},
    {"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab", "4f616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161610162", 82, false},
}

addr_line = de_ref(load_address + 3)
addr_buf_len = de_ref(load_address + 5)
addr_byte_counter = de_ref(load_address + 7)

function num_iterations()
    return #test_table
end

function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    copy_string(test_table[iterations][1], addr_line)
    write_byte(addr_buf_len, #test_table[iterations][1])

    write_byte_long(FREE_MEM_START, 0xDD)
    write_byte_long(FREE_MEM_START+1, 0xD1)
end

function assert()
    local carry_state = contains_flag("C")

    if test_table[iterations][4] ~= carry_state then 
        return false, string.format("Problem splitting '%s' ", test_table[iterations][1])
    end

    local bytes_written = read_word(addr_byte_counter)
    local exptected_len = test_table[iterations][3]

    if bytes_written ~= exptected_len then 
        return false, string.format("Unexpected length '%s' ", bytes_written)
    end

    local mem_dump = read_string_long(FREE_MEM_START, exptected_len)

    if test_table[iterations][2] ~= mem_dump then
        return false, string.format("Unexpected result: %s", mem_dump)
    end

    return true, ""
end
