require (test_dir.."tools")

data_len = 224

function arrange()
    -- fill line buffer
    local addr = de_ref(load_address + 5)
    for i = addr, addr + data_len, 1 do
        write_byte(i, 65)
    end

    -- set line buffer length
    write_byte(de_ref(load_address + 7), data_len)
end

function assert()
    local line_buffer_len = read_byte(load_address + 9)
    if line_buffer_len ~= data_len then
        return false, string.format("Wrong line buffer length: %d", line_buffer_len)
    end

    -- check if allocation failed
    if contains_flag("C") then
        return false, "Error: Carry was set"
    end

    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 3) then
        return false, string.format("Unexpected number of blocks: %d of %d", state["numFreeBlocks"], state["numBlocks"])
    end

    local elem = read_allocated_block(read_byte(load_address + 10), read_byte(load_address + 11), read_byte(load_address + 12))
    local l = elem[7]
    if l ~= 33 then
        return false, string.format("Wrong length: %d", l)
    end

    local out_len = read_byte(de_ref(load_address + 7))
    if out_len ~= 33 then
        return false, string.format("Wrong length: %d", out_len)
    end

    local data_addr = de_ref(load_address + 5)

    for i = data_addr, data_addr + out_len - 1, 1 do
        local b = read_byte(i)
        if b ~= 65 then
            return false, string.format("Unexpected byte %d at 0x%x", b, i)
        end
    end

    return true, ""
end