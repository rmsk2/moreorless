require("string")
require (test_dir.."tools")

-- this code tests the subroutine memory.findFirstZeroBit which
-- gets a mask in the accu and returns the index of the first zero
-- bit of the value in the accu.

iterations = 0
test_table = {
    -- masks with exactly on bit zero, number of the zero bit
    {0xFF - 1, 0},
    {0xFF - 2, 1},
    {0xFF - 4, 2},
    {0xFF - 8, 3},
    {0xFF - 16, 4},
    {0xFF - 32, 5},
    {0xFF - 64, 6},
    {0xFF - 128, 7},
}

function num_iterations()
    return #test_table
end

function arrange()
    iterations = iterations + 1
    set_pc(load_address)
    -- set value to test
    set_accu(test_table[iterations][1])    
end

function assert()
    -- verify whether the accu contains the index of the zero bit
    return get_accu() == test_table[iterations][2], string.format("Wrong value: %d", get_accu())
end