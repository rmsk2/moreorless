require (test_dir.."tools")

-- This code tests whether list.insertAfter and list.setCurrentLine work as expected. For this a new list
-- with two elements is created by calling list.insertAfter. The assembly test driver then exports 
-- "far pointers" to both elments, the list length as a word and the memory management data structures. 
-- The assembly part also tests whether the new end of the list is correctly signalled when calling list.next.
-- The Lua side then tests whether the memory usage corresponds to the expeted values and checks whether
-- the list elements contain the expected values.

function arrange()

end

function assert()
    -- check if allocation failed
    if contains_flag("C") then
        return false, "Error: Carry was set"
    end

    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    -- verify number of freee blocks
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 4) then
        return false, string.format("Unexpected number of blocks: %d of %d", state["numFreeBlocks"], state["numBlocks"])
    end

    -- verify length of list
    local list_len = de_ref(load_address + 11)

    if list_len ~= 2 then
        return false , string.format("Wrong length: %d", list_len)
    end

    -- look at length field in the first allocated block, which is at offset 6 + 1.
    local elem = read_allocated_block(read_byte(load_address + 5), read_byte(load_address + 6), read_byte(load_address + 7))
    local l = elem[7]
    if l ~= 14 then
        return false, string.format("Line 1 length wrong: %d", l)
    end

    -- look at length field in the second allocated block, which is at offset 6 + 1.
    local elem = read_allocated_block(read_byte(load_address + 8), read_byte(load_address + 9), read_byte(load_address + 10))
    local l = elem[7]
    if l ~= 23 then
        return false, string.format("Line 1 length wrong: %d", l)
    end    

    return true, ""
end