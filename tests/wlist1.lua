require (test_dir.."tools")
require (test_dir.."reformat")

-- This is a text for the subroutine clip.createClipFromMemory. The assembly test driver calls
-- this routine using word list data which is generated in the arrange() function. After the
-- call it is checked whether the correct number of lines has been created by the subroutine. 
-- Additionally for each created line it is verified that its length matches the expected value.

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

function arrange()
	-- remember to call set_pc(load_address) if you use test iteration
    local ref_data = make_reference_data(0, 7, all_lines)
    local i, v

    for i, v in ipairs(ref_data) do 
        write_byte_long(FREE_MEM_START - 1 + i, v)
    end    
end


function assert()
    local clip_len = read_word(load_address + 3)
    local list_head = parse_allocated_block(read_byte(load_address + 5), read_byte(load_address + 6), read_byte(load_address + 7))
    local i, v
    local reformat_len = 0
    local reformatted_lines = {}

    local function check_func(block)
        reformat_len = reformat_len + 1
        table.insert(reformatted_lines, block.len)
        -- print(block.data)
    end        

    iterate_whole_list(list_head, check_func)

    if #reformatted_lines ~= 5 then
        return false, string.format("Unexpected number of reformatted lines %d", #reformatted_lines)
    end

    local ref_lengths = {76, 77, 74, 79, 54}

    for i, v in ipairs(reformatted_lines) do 
        if v ~= ref_lengths[i] then 
            return false, string.format("Unexpected length %d in line %d", v, i)
        end
    end

    return true, ""
end
