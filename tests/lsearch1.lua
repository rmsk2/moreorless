require (test_dir.."tools")

down = 1
up = 0

iterations = 0

test_table = {
    -- sesarch text, initial pos, search direction, end count, found?
    {"this is the fourth", 0, down, 3, true},
    {"longer than", 6, up, 5, true},
    -- this text is beyond the 80 byte mark => it should not be found
    {"goes on and on", 6, up, 6, false},    
    {"7 this", 2, down, 4, true},
}

addr_search = de_ref(load_address + 10)
buf_len = read_byte(load_address + 16)

function num_iterations()
    return #test_table
end


function arrange()
    set_pc(load_address)
    iterations = iterations + 1

    -- write search string
    local str = test_table[iterations][1]
    local ctr = 0
    for i = 1, #str do
        local c = str:sub(i,i)
        write_byte(addr_search + ctr, string.byte(c))
        ctr = ctr + 1
    end
    write_byte(addr_search + buf_len, #str)    

    -- set search direction
    write_byte(load_address + 15, test_table[iterations][3])

    -- set start offset
    set_word_at(load_address + 13, test_table[iterations][2])
end


function assert()
    local carry_set = contains_flag("C")

    if carry_set then
        return false, "An error occurred"
    end

    -- check number of steps taken
    local steps_required = read_byte(load_address + 12)
    if steps_required ~= test_table[iterations][4] then
        return false, string.format("Wrong number of steps: %d", steps_required)
    end

    -- check whether element was found or not
    local was_found = (read_byte(load_address + 9) ~= 0)
    if was_found ~= test_table[iterations][5] then
        return false, string.format("Unexpected search state: %d", read_byte(load_address + 9))
    end

    -- check current list element after the search
    local start_addr = get_long_addr(load_address + 3)
    local end_addr = get_long_addr(load_address + 6)

    if not test_table[iterations][5] then        
        if start_addr ~= end_addr then
            return false, "Current element not reset to start after unsuccessfull search"
        end
    else
        if start_addr == end_addr then
            return false, "Current element is not different from start position"
        end
    end

    return true, ""
end
