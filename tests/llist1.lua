require (test_dir.."tools")

-- In this test the asm test driver allocates a new line and fills it with data_len "A"s. After that
-- the line is shortened to 32 and then lengthened to 33 "A" characters. The Lua part then verifies
-- that the number of free blocks (here numBlocks - 3) is and the data length (here 33) is correct. 
-- Finally the Lua part checks whether the line buffer was filled correctly. 

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

    local list_len = de_ref(load_address + 13)

    if list_len ~= 1 then
        return false , string.format("Wrong length: %d", list_len)
    end

    -- parse whole memory.MEM_STATE struct at the address stored at load_address + 3
    local state = get_mem_state(de_ref(load_address + 3))
    
    if state["numFreeBlocks"] ~= (state["numBlocks"] - 3) then
        return false, string.format("Unexpected number of blocks: %d of %d", state["numFreeBlocks"], state["numBlocks"])
    end

    -- look at length field in the allocated block, which is at offset 6 + 1.
    local elem = read_allocated_block(read_byte(load_address + 10), read_byte(load_address + 11), read_byte(load_address + 12))
    local l = elem[7]
    if l ~= 33 then
        return false, string.format("Wrong length: %d", l)
    end

    -- check whether the length of the line buffer was set correctly
    local out_len = read_byte(de_ref(load_address + 7))
    if out_len ~= 33 then
        return false, string.format("Wrong length: %d", out_len)
    end

    local data_addr = de_ref(load_address + 5)

    -- Test whether the line buffer contains 33 As
    for i = data_addr, data_addr + out_len - 1, 1 do
        local b = read_byte(i)
        if b ~= 65 then
            return false, string.format("Unexpected byte %d at 0x%x", b, i)
        end
    end

    return true, ""
end