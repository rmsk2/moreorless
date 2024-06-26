require("string")
require(test_dir.."tools")


iterations = 0
test_table = {
    -- pattern, line, expected result, expected pos
    {"test", "dies ein test1 test2 ist", true, 15},
    {"test", "hier gibt es nix zu sehen", false, -1},
    -- the search string is clipped => will not be found
    {"test", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut ist es ein test", false, -1},
    -- search string is at end
    {"test", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschauttest", true, 76},
    -- search string is at beginning
    {"test", "test: hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut", true, 0},
    {"egal78986", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinschaut ist es ein test", false, -1},
    {"test1234", "hier gibt es nix zu sehen, koennte man meinen, doch wenn man genau hinsctest1234", true, 72},
    -- line longer than search string
    {"test1234", "test", false, -1},
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

    if test_table[iterations][3] == true then
        if get_xreg() ~= test_table[iterations][4] then
            return false, string.format("Wrong position. Wanted %d got %d", test_table[iterations][4], get_xreg())
        end
    end

    return true, ""
end
