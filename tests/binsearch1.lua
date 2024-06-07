require(test_dir.."tools")

iterations = 0
test_table = {
    {17, 20, 32, 544, 794, 1231, 17244, 17245, 17246, 17247, 17248, 17249, 17250, 17251, 17252},
    {1},
    {2, 3},
    {4, 5},
    {17, 20, 32, 544, 794, 1231, 17244},
    {17, 20, 32, 544, 794, 1231, 17244},
    {17},
    {4, 5},
    {17, 1200, 28000}
}

res_table = {
    {17252, 14*4, true},
    {1, 0, true},
    {2, 0, true},
    {5, 4, true},
    {544, 12, true},
    {543, 0, false},
    {5, 0, false},
    {3, 0, false},
    {1200, 4, true},
}

function num_iterations()
    return #test_table
end


function arrange()
    iterations = iterations + 1
    set_pc(load_address)

    write_byte(load_address+3, #test_table[iterations])

    local addr = load_address + 4
    local w = 0
    for i = 1, #test_table[iterations], 1 do
        w = test_table[iterations][i]
        set_word_at(addr, w)
        set_word_at(addr + 2, 0)
        addr = addr + 4
    end

    w = res_table[iterations][1]

    local hi = math.floor(w / 256)
    local lo = math.fmod(w, 256)
    set_accu(lo)
    set_xreg(hi)
end

function assert()
    if res_table[iterations][3] then
        if not contains_flag("C") then
            return false, string.format("Error: Value %d not found", res_table[iterations][1])
        end

        if get_yreg() ~= res_table[iterations][2] then 
            return false, string.format("Element found at wrong index. Wanted %d got %d", res_table[iterations][2], get_yreg())
        end        
    else
        if contains_flag("C") then
            return false, string.format("Error: Value %d should not have been found", res_table[iterations][1])
        end
    end

    return true, ""
end
