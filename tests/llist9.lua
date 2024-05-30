require (test_dir.."tools")

-- This test verifies that list.destroy frees all previously allocated memory. For this a list
-- containing three elements is created and then deleted by a call to list.destroy. The Lua
-- part verifies that all memory has been freed.

function arrange()

end

function assert()
    -- check if error occurred
    if contains_flag("C") then
        return false, "Error: Carry was set"
    end

    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))

    -- verify number of freee blocks
    if state.numFreeBlocks ~= (state.numBlocks) then
        return false, string.format("Unexpected number of blocks: %d of %d", state.numFreeBlocks, state.numBlocks)
    end

    return true, ""
end