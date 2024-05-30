require (test_dir.."tools")

-- This code tests the subroutines list.next and list.prev which implement iterating through the list in both
-- directions. For this the assembly test driver creates a list of three elements using list.insertAfter. Then 
-- it moves two elements towards the end of the list using list.next and then calls list.prev three times. It 
-- is expected that after doing this the current element of the list is the first list element and that the 
-- last call to list.prev signals through a set carry bit that the beginning has been reached. The Lua part 
-- verifies that we arrived at the first element and that memory usage conforms to expectations.

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

    -- look at length field in the first allocated block, which is at offset.
    local elem = parse_allocated_block(read_byte(load_address + 5), read_byte(load_address + 6), read_byte(load_address + 7))
    local l = elem.len
    if l ~= 14 then
        return false, string.format("Line 1 length wrong: %d", l)
    end
    
    return true, ""
end