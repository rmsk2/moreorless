require("string")
require (test_dir.."tools")

-- This code tests whether allocPtr finds a new block after 256 failures.

function arrange()
    
end


function assert()
    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    -- Check whether allocation worked at all
    if contains_flag("C") then
        return false, string.format("An error occurred in iteration %d", get_xreg())
    end

    -- check that an additional block has been allocated
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 513) then
        return false, string.format("There should have been 513 blocks allocated but there are %d", state["numFreeBlocks"])
    end

    -- check whether the first block on page 3 was allocated
    if state["pageMap"][65] ~= 0x01 then
        return false, string.format("Block map incorrect: %d", state["pageMap"][1])
    end

    -- check whether the number of trials has wrapped around to zero
    if read_byte(0xA2) ~= 0 then
        return false, string.format("Trial counter is not zero: %d", read_byte(0xA2))
    end

    return true, ""
end