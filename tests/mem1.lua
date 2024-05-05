require("string")
require (test_dir.."tools")

iterations = 0
test_table = {
    {42, 0xA000, 1, 0x8000},
    {42, 0xA000, 1033, 0x8000},
    {42, 0xA000, 256, 0x8000},
    {42, 0xA000, 255, 0x8000},
    {42, 0xA000, 257, 0x8000},
    {42, 0xA000, 0, 0x8000},
    {42, 0xA000, 8192, 0x6000},
    {42, 0xA000, 8191, 0x8000}
}

function num_iterations()
    return #test_table
end

function arrange()
    iterations = iterations + 1
    set_pc(load_address)
    
    local val = test_table[iterations][1]
    local start = test_table[iterations][2]
    local length = test_table[iterations][3]
    local target = test_table[iterations][4]
    -- clear source memory and add one byte no man's land
    -- at start and end
    for i = start-1, start + length, 1 do
        write_byte(i, 0)
    end

    -- clear source memory and add one byte no man's land
    -- at start and end
    for i = target-1, target + length, 1 do
        write_byte(i, 0)
    end
    
    -- set parameters
    set_word_at(load_address + 3, start)
    set_word_at(load_address + 5, length)
    set_word_at(load_address + 7, target)
    write_byte(load_address + 9, val)
end

function assert()
    local val = test_table[iterations][1]
    local start = test_table[iterations][2]
    local length = test_table[iterations][3]
    local target = test_table[iterations][4]

    -- check if no man's land was left untouched
    local minus_1 = read_byte(target-1)
    local plus_1 = read_byte(target + length)
    if minus_1 ~= 0 then
        return false, "off by one at start"
    end
    
    if plus_1 ~= 0 then
        return false, "off by one at end"
    end
    
    -- Check whether copied memory contains expected values
    for i = target, target + length - 1, 1 do
        if read_byte(i) ~= val then
            return false, string.format("Wrong value %d at %d", read_byte(i), i)
        end
    end    

    return true, ""
end