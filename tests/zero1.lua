require("string")
require (test_dir.."tools")

iterations = 0
test_table = {
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
    set_accu(test_table[iterations][1])    
end

function assert()
    return get_accu() == test_table[iterations][2], string.format("Wrong value: %d", get_accu())
end