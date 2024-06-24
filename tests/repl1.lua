require("string")
require(test_dir.."tools")


iterations = 0
test_table = {
    -- search string, line, replace string, repl pos, expected result
    {"test", "dies ein test1 test2 ist", "tadaa", 9, "dies ein tadaa1 test2 ist"},
    {"test", "dies ein test1 test2 ist", "", 9, "dies ein 1 test2 ist"},
    {"dies", "dies ein test1 test2 ist", "tadaa", 0, "tadaa ein test1 test2 ist"},
    {"ist", "dies ein test1 test2 ist", "tadaa", 21, "dies ein test1 test2 tadaa"},
    {"ist", "dies ein test1 test2 ist", "", 21, "dies ein test1 test2 "},
    {"dies", "dies ein test1 test2 ist", "", 0, " ein test1 test2 ist"},
    {"t", "dies ein test1 test2 ist", "d", 23, "dies ein test1 test2 isd"},
}

addr_search = de_ref(load_address + 3)
addr_line = de_ref(load_address + 5)
buf_len = read_byte(load_address + 7)
addr_repl = de_ref(load_address + 8)
repl_len = read_byte(load_address + 10)

function num_iterations()
    return #test_table
end

function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    local str = test_table[iterations][1]
    copy_string(str, addr_search)
    write_byte(addr_search + buf_len, #str)

    local str2 = test_table[iterations][2]
    copy_string(str2, addr_line)
    write_byte(addr_line + buf_len, #str2)
    
    local str3 = test_table[iterations][3]
    copy_string(str3, addr_repl)
    write_byte(addr_repl + repl_len, #str3)

    set_accu(test_table[iterations][4])
end

function assert()
    local carry_state = contains_flag("C")

    if carry_state then 
        return false, "An error occurred"
    end

    local len = read_byte(addr_line + buf_len)
    local res_str = read_string(addr_line, len)

    if res_str ~= test_table[iterations][5] then
        return false, string.format("Wrong result: %s", res_str)
    end

    return true, ""
end
