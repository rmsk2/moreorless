require (test_dir.."tools")

line_1 = "1 this is the first line"
line_2 = "2 this is the middle line and it is longer than the others by quite a bit. it still does not stop. it goes on and on and on ..."
line_3 = "3 this is the third line and it should be bigger than 32 bytes"
line_4 = "4 this is the fourth    line and it should be bigger than 32 bytes "
line_5 = "5 this is not the last line"
line_6 = "6 this is also not the last line"
line_7 = "7 this is the  last line"

lines = {
    line_1,
    line_2,
    line_3,
    line_4,
    line_5,
    line_6,
    line_7
}

iterations = 0
test_table = {
    -- start offset, len to copy, error expected
    {6, 1, false},
    {0, 1, false},
    {2, 2, false},
    {1, 5, false},
    {0, 7, false},
}

function simple_split(inputstr)
    local sep = "%s"
    local t = {}

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end

    return t
end

function make_word_list(start_pos, len)
    local word_list = {}
    local i, v

    for i = start_pos + 1, start_pos + len, 1 do
        local w = simple_split(lines[i])
        for _,v in ipairs(w) do 
            table.insert(word_list, v)
        end
    end
        
    return word_list
end

function num_iterations()    
    return #test_table
end


addr_start_pos = load_address + 3
addr_copy_len = load_address + 5

function arrange()
    set_pc(load_address)
    iterations = iterations + 1
    set_word_at(addr_start_pos, test_table[iterations][1])
    set_word_at(addr_copy_len, test_table[iterations][2])
end

function make_reference_data(start_pos, len)
    local word_list = make_word_list(start_pos, len)
    local v, i
    local ref_bytes = {}

    for _,v in ipairs(word_list) do 
        table.insert(ref_bytes, #v)

        for i = 1, #v do
            local c = v:sub(i,i)
            table.insert(ref_bytes, string.byte(c))
        end            
    end

    table.insert(ref_bytes, 0)

    return ref_bytes
end

function assert()
    local carry_set = contains_flag("C")
    local ref_bytes = make_reference_data(test_table[iterations][1], test_table[iterations][2])
    local v, i

    if carry_set ~= test_table[iterations][3] then
        return false, "Error result was unexpected"
    end

    for i, v in ipairs(ref_bytes) do 
        if read_byte_long(FREE_MEM_START - 1 + i) ~= v then
            return false, string.format("Difference to reference data at index %d", i)
        end
    end    

    return true, ""
end
