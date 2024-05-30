require("string")
require(test_dir.."tools")


iterations = 0
test_table = {
    -- pattern, line, expected result
    {"test", "dies ein test ist", true},
    {"test", "hier gibt es nix zu sehen", false},
    -- the search string is clipped => will not be found
    {"test", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut ist es ein test", false},
    -- search string is at end
    {"test", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschauttest", true},
    -- search string is at beginning
    {"test", "test: hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut", true},
    {"egal78986", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut ist es ein test", false},
    {"test1234", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinsctest1234", true},
    -- line longer than search string
    {"test1234", "test", false},
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
    local ctr = 0
    for i = 1, #str do
        local c = str:sub(i,i)
        write_byte(addr_search + ctr, string.byte(c))
        ctr = ctr + 1
    end
    write_byte(addr_search + buf_len, #str)

    local str2 = test_table[iterations][2]
    ctr = 0
    for i = 1, #str2 do
        local c = str2:sub(i,i)
        write_byte(addr_line + ctr, string.byte(c))
        ctr = ctr + 1
    end
    write_byte(addr_line + buf_len, #str2)    
end

function assert()
    local carry_state = contains_flag("C")

    if test_table[iterations][3] ~= carry_state then 
        return false, string.format("Problem searching '%s' in '%s'", test_table[iterations][1], test_table[iterations][2])
    end

    return true, ""
end
