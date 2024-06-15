require("string")
require (test_dir.."tools")


iterations = 0
test_table = {
    -- string, insert pos, result string, success expected
    {"dies_ist_ein_test", 0, " dies_ist_ein_test", true},
    {"", 0, " ", true},
    {"dies_ist_ein_test", 17, "dies_ist_ein_test ", true},
    {"01234567890123456789012345678901234567890123456789012345678901234567890123456789", 1, "", false},
    {"0123456789012345678901234567890123456789012345678901234567890123456789012345678", 17, "01234567890123456 78901234567890123456789012345678901234567890123456789012345678", true},
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

    set_xreg(0x20)
    set_yreg(#dat)
    set_accu(test_table[iterations][2])
end

function assert()
    if test_table[iterations][4] then
        if contains_flag("C") then
            return false, "Error: Carry was set"
        end    
    else
        if not contains_flag("C") then
            return false, "Error: Carry was clear"
        end

        return true, ""    
    end

    local new_len = #test_table[iterations][1] + 1
    if new_len > 80 then
        new_len = 80
    end

    if get_accu() ~= new_len then
        return false, string.format("Wrong length: %d", get_accu())
    end 

    local s = read_string(buffer_addr, new_len)
    if s ~= test_table[iterations][3] then
        return false, string.format("Wrong result: %s", s)
    end

    return true, ""
end
