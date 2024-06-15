require("string")
require (test_dir.."tools")

-- This code tests whether memory.insertCharacterDrop works as intended by feeding several inputs
-- to the routine and checking that the input buffer are modified as expected.

iterations = 0
test_table = {
    -- string, result string
    {"dies_ist_ein_test", " dies_ist_ein_tes"},
    {"4", " "},
    {"0123456789012345678901234567890123456789012345678901234567890123456789012345678", " 012345678901234567890123456789012345678901234567890123456789012345678901234567"},
}

buffer_addr = de_ref(load_address + 3)

function num_iterations()
    return #test_table
end

function arrange()
    iterations = iterations + 1
    set_pc(load_address)
    local dat = test_table[iterations][1]
    
    copy_string(dat, buffer_addr)
    -- write a defined value to the byte immediately following the buffer
    write_byte(buffer_addr + #dat, 0)

    -- insert a blank character
    set_xreg(0x20)
    set_yreg(#dat)
end

function assert()
    local len = #test_table[iterations][1]

    local s = read_string(buffer_addr, len)
    if s ~= test_table[iterations][2] then
        return false, string.format("Wrong result: %s", s)
    end

    -- check that no byte beyond the buffer was modified
    if read_byte(buffer_addr + len) ~= 0 then
        return false, "Buffer overrun"
    end

    return true, ""
end
