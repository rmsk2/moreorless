require (test_dir.."tools")
require (test_dir.."reformat")

-- This is a test for the subroutine clip.copyRegion. In each iteration a document of seven 
-- lines is created in the assembly test driver. Then the clip.copyRegion subroutine is
-- called for a section of this document. Finally it is checked whether the word list
-- genereated by this subroutine matches the reference value as calculated in this script.

line_1 = "1 this is the first line"
line_2 = "2 this is the middle line and it is longer than the others by quite a bit. it still does not stop. it goes on and on and on ..."
line_3 = "3 this is the third line and it should be bigger than 32 bytes"
line_4 = "4 this is the fourth    line and it should be bigger than 32 bytes "
line_5 = "5 this is not the last line"
line_6 = "6 this is also not the last line"
line_7 = "7 this is the  last line"

all_lines = {
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


function assert()
    local carry_set = contains_flag("C")
    local ref_bytes = make_reference_data(test_table[iterations][1], test_table[iterations][2], all_lines)
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
