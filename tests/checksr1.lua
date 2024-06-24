require("string")
require(test_dir.."tools")


iterations = 0
test_table = {
    -- pattern, line, expected result, pos
    {"test", "dies ein test1 test2 ist", true, 9},
    {"test", "hier gibt es nix zu sehen", false, 0},
    -- the search string is clipped => will not be found
    {"test", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut ist es ein test", false, 5},
    -- search string is at end
    {"test", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschauttest", true, 76},
    -- search string is at beginning
    {"test", "test: hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut", true, 0},
    {"egal78986", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut ist es ein test", false, 7},
    {"test1234", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinsctest1234", true, 72},
    -- line longer than search string
    {"test1234", "test", false, 0},
}

addr_search = de_ref(load_address + 3)
addr_line = de_ref(load_address + 5)
buf_len = read_byte(load_address + 7)

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
    
    set_accu(test_table[iterations][4])
end

function assert()
    local carry_state = contains_flag("C")

    if test_table[iterations][3] ~= carry_state then 
        return false, string.format("Problem searching '%s' in '%s'", test_table[iterations][1], test_table[iterations][2])
    end

    return true, ""
end
