require("string")
require (test_dir.."tools")

-- In this test the assembler test driver simply as many block as are defined in 
-- blocks_to_reserve and frees four of them again. It is then verified that the number of free 
-- blocks has been decremented to the expxted value and that the block map has the expected state, 
-- i.e. here that four bits in the first byte are set, which indicates that these four blocks are 
-- still marked as allocated.

blocks_to_reserve = 8

function arrange()
    write_byte(load_address + 5, blocks_to_reserve)
end


function assert()
    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    -- check if allocation failed
    if contains_flag("C") then
        return false, string.format("An error occurred in iteration %d", get_xreg())
    end

    -- check whether the correct number of blocks has been freed
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 4) then
        return false, string.format("There should have been 4 blocks allocated but there are %d", state["numFreeBlocks"])
    end

    -- check whether block map looks as expected
    if state["pageMap"][1] ~= (1 + 4 + 16 + 64) then
        print()
        for i = 1, #state["pageMap"], 1 do
            if state["pageMap"][i] ~= 0 then
                print(i, state["pageMap"][i])
            end
        end

        return false, string.format("Block map incorrect: %d", state["pageMap"][1])
    end

    return true, ""
end