require("string")
require (test_dir.."tools")

function arrange()

end

function assert()
    local state_addr = de_ref(load_address + 3)
    local state = get_mem_state(state_addr)

    if state["addrPageMap"] ~= 0xA000 then
        return false, string.format("Wrong window address: %x", state["addrPageMap"])
    end

    if state["numPages"] ~= MAX_PAGES then
        return false, string.format("Wrong number of pages: %d", state["numPages"])
    end

    local page_map_len_ref = state["numPages"] * BYTES_PER_PAGE_IN_MAP

    if state["pageMapLen"] ~= page_map_len_ref then
        return false, string.format("Wrong pageMap length: %d", state["pageMapLen"])
    end

    if state["numFreeBlocks"] ~= state["numPages"] * BLOCKS_PER_PAGE then
        return false, string.format("Wrong number of free blocks: %d", state["numFreeBlocks"])
    end

    if state["numBlocks"] ~= state["numPages"] * BLOCKS_PER_PAGE then
        return false, string.format("Wrong number of overall blocks: %d", state["numBlocks"])
    end

    if state["maxBlockPos"] ~= MAX_BLOCK_POS then
        return false, string.format("Wrong maximum block pos: %d", state["maxBlockPos"])
    end

    if state["blockPos"] ~= 0 then
        return false, string.format("Wrong block pos: %d", state["blockPos"])
    end

    if not state["ramExpFound"] then
        return false, "No RAM expansion found"
    end

    if state["mapPos.mask"] ~= 0 then
        return false, string.format("Wrong mask value: %d", state["mapPos.mask"])
    end

    local ref_addr = state_addr + 17 + MAX_PAGES

    if state["mapPos.address"] ~= ref_addr then
        return false, string.format("Wrong block pos: %d (%d)", state["mapPos.address"], ref_addr)
    end

    if #state["pages"] ~= MAX_PAGES then
        return false, string.format("Wrong length for page list: %d", #state["pages"])
    end

    for i, v in ipairs(state["pages"]) do
        if v ~= reference_pages[i] then
           return false, string.format("page list incorrect at index %d: %d should be %d", i, v, reference_pages[i])
        end
    end


    if #state["pageMap"] ~= MAX_PAGES * BYTES_PER_PAGE_IN_MAP then
        return false, string.format("Wrong length for page map: %d", #state["pageMap"])
    end

    for i, v in ipairs(state["pageMap"]) do
        if v ~= 0 then
            return false, string.format("page map not cleared at index %d (%d)", i, v)
        end
    end

    return true, ""
end