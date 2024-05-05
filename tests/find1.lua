require("string")
require (test_dir.."tools")

iterations = 0
test_table = {
    {0   , 0xFE, 0, 0,  , 0},  -- first block
    {2559, 0x7F, 7, 0xFF, 79}, -- last block
    {1283, 255-16, 4, 28, 40}, -- somewhere in the middle
}

function num_iterations()
    return #test_table
end

function arrange()
    iterations = iterations + 1
    set_pc(load_address)

    local addr_of_page_map = de_ref(load_address + 3)
    local offset_of_free_block = test_table[iterations][1]
    local mask_of_free_block = test_table[iterations][2]

    local address_of_freeblock = addr_of_page_map + offset_of_free_block
    set_word_at(load_address + 5, address_of_freeblock)
    write_byte(load_address + 7, mask_of_free_block)
end

function assert()
    local state_addr = de_ref(load_address + 8)
    local state = get_mem_state(state_addr)

    local addr_of_page_map = de_ref(load_address + 3)
    local offset_of_free_block = test_table[iterations][1]
    local address_of_freeblock = addr_of_page_map + offset_of_free_block

    if state["mapPos.address"] ~= address_of_freeblock then
        return false, string.format("Wrong block address found: %x", state["mapPos.address"])
    end

    if state["mapPos.mask"] ~= test_table[iterations][3] then
        return false, string.format("Wrong mask found: %x", state["mapPos.mask"])
    end

    local expected_block_pos = test_table[iterations][4] + 256 * test_table[iterations][5]
    if state["blockPos"] ~= expected_block_pos then
        return false, string.format("Wrong block pos found: %x (%x)", state["blockPos"], expected_block_pos)
    end

    return true, ""
end