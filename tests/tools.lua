require("math")
require("table")

PAGE_WINDOW = 0xA000
PAGE_SIZE = 8192
BLOCK_SIZE = 32
BLOCKS_PER_PAGE = PAGE_SIZE / BLOCK_SIZE
BYTES_PER_PAGE_IN_MAP = BLOCKS_PER_PAGE / 8
FREE_MEM_START = 0x028000

-- block numbers of 8K blocks which should be managed by memory.asm. Currently these represent
-- 384 K of base memory (beginning at $10000, but leaving a 64 K hole starting with $28000) and optionally 256K of 
-- expanded memory
reference_pages = {
    8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 
    38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 
    60, 61, 62, 63, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 
    142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159
}

mask_bits = {
    1, 2, 4, 8, 16, 32, 64, 128
}

MAX_PAGES = #reference_pages
MAX_BLOCK_POS = MAX_PAGES * 256

-- copy the string given in str to the address addr in the simulator's
-- memory
function copy_string(str, addr)
    local ctr = 0
    local i
    for i = 1, #str do
        local c = str:sub(i,i)
        write_byte(addr + ctr, string.byte(c))
        ctr = ctr + 1
    end
end

function read_string(addr, len)
    local i
    local s = ""

    for i = addr, addr + len - 1, 1 do
        s = s .. string.char(read_byte(i))
    end

    return s
end

function read_string_long(addr, len)
    local i
    local res

    res = ""

    for i = addr, addr + len - 1, 1 do
        res = res .. string.format("%02x", read_byte_long(i))
    end

    return res
end

-- read word stored at the given address
function de_ref(ptr_addr)
    local hi_addr = read_byte(ptr_addr + 1)
    local lo_addr = read_byte(ptr_addr)
    
    return hi_addr * 256 + lo_addr
end

-- read word stored at the given address
function read_word(ptr_addr)
    local hi_addr = read_byte(ptr_addr + 1)
    local lo_addr = read_byte(ptr_addr)
    
    return hi_addr * 256 + lo_addr
end


-- set word at the given address
function set_word_at(addr, w)
    local hi = math.floor(w / 256)
    local lo = math.fmod(w, 256)

    write_byte(addr, lo)
    write_byte(addr+1, hi)
end

-- calculate the address and the bit mask index which represent the block identified by page_nr and
-- block_nr. map_start contains the start address of the block/page map
function pos_to_map_bit(map_start, page_nr, block_nr)
    local ref_map_addr = map_start + (BYTES_PER_PAGE_IN_MAP * page_nr) + math.floor(block_nr / 8)
    local ref_mask = math.fmod(block_nr, 8)

    return ref_map_addr, ref_mask
end


function contains_flag(f)
    return string.find(get_flags(), f, 0, true) ~= nil
end


function get_long_addr(start)
    local offset = (read_byte(start) + 1 * 256 + read_byte(start)) - PAGE_WINDOW
    return (read_byte(start+ 2) * PAGE_SIZE) + offset

end

function seg_2_linear(lo, hi, page)
    local offset = (hi * 256 + lo) - PAGE_WINDOW
    return (page * PAGE_SIZE) + offset
end


function to_addr(a)
    return to_addr_flat(a[1], a[2], a[3])
end


function to_addr_flat(lo, hi, page)
    if page == 0 then
        return "nil"
    else 
        return string.format("%02x:%04x", page, (lo + hi * 256) - PAGE_WINDOW)
    end
end


function block_to_string(a, len)
    local s = ""
    local addr = seg_2_linear(a[1], a[2], a[3])

    for i = addr, addr + len - 1, 1 do
        s = s .. string.char(read_byte_long(i))
    end

    return s
end


function print_allocated_block(b)
    print(to_addr(b["addr"]))
    print("    ", to_addr(b["next"]))
    print("    ", to_addr(b["prev"]))
    print("    ", b["len"])
    print("    ", b["numBlocks"])
    print("    ", b["flags"])
    print("    ", b["data"])
end

function iterate_whole_list(b, iter)
    done = false

    while not done do
        iter(b)
        done = (b.flags == 2) or (b.flags == 3)
        if not done then
            b = parse_allocated_block(b.next[1], b.next[2], b.next[3])        
        end
    end
end


function print_whole_list(b)
    iterate_whole_list(b, print_allocated_block)
end


function parse_allocated_block(lo, hi, page)
    local d = read_allocated_block(lo, hi, page)
    local res = {}
    local len = d[7]
    local num_blocks = d[8]

    local s = ""

    local full_blocks = math.floor(len / BLOCK_SIZE)
    local last_block = math.fmod(len, BLOCK_SIZE)

    res["next"] = {d[1], d[2], d[3]}
    res["prev"] = {d[4], d[5], d[6]}
    res["len"] = len 
    res["numBlocks"] = num_blocks
    res["flags"] = d[9]
    res["block1"] = {d[12], d[13], d[14]}
    res["block2"] = {d[15], d[16], d[17]}
    res["block3"] = {d[18], d[19], d[20]}
    res["block4"] = {d[21], d[22], d[23]}
    res["block5"] = {d[24], d[25], d[26]}
    res["block6"] = {d[27], d[28], d[29]}
    res["block7"] = {d[30], d[31], d[32]}
    res["addr"] =  {lo, hi, page}

    for i = 1, full_blocks, 1 do
        local index = string.format("block%d", i)
        s = s .. block_to_string(res[index], BLOCK_SIZE)
    end
    
    if  last_block ~= 0 then
        local index = string.format("block%d", num_blocks)
        s = s .. block_to_string(res[index], last_block)
    end

    res["data"] = s

    return res
end


function read_allocated_block(lo, hi, page)
    local res = {}
    local long_addr = seg_2_linear(lo, hi, page)

    for i = long_addr, long_addr + BLOCK_SIZE - 1, 1 do
        local d = read_byte_long(i) 
        table.insert(res, d)
    end

    return res
end


-- Parses memory.MEM_STATE into a table
function get_mem_state(addr) 
    local page_window = de_ref(addr)
    addr = addr + 2
    local num_pages = read_byte(addr)
    addr = addr + 1
    local page_map_len = de_ref(addr)
    addr = addr + 2
    local free_blocks = de_ref(addr)
    addr = addr + 2
    local num_blocks = de_ref(addr)
    addr = addr + 2
    local max_block_pos = de_ref(addr)
    addr = addr + 2
    local curr_block_pos = de_ref(addr)
    addr = addr + 2
    local ram_exp_found = read_byte(addr)
    addr = addr + 1
    local map_addr = de_ref(addr)
    addr = addr + 2
    local map_bit = read_byte(addr)
    addr = addr + 1

    local page_list = {}

    for i = addr, addr + MAX_PAGES - 1, 1 do
        table.insert(page_list, read_byte(i))
    end

    addr = addr + MAX_PAGES

    local page_map = {}

    for i = addr, addr + page_map_len - 1, 1 do
        table.insert(page_map, read_byte(i))
    end

    res = {}
    res["addrPageMap"] = page_window
    res["numPages"] = num_pages
    res["pageMapLen"] = page_map_len
    res["numFreeBlocks"] = free_blocks
    res["numBlocks"] = num_blocks
    res["maxBlockPos"] = max_block_pos
    res["blockPos"] = curr_block_pos
    res["ramExpFound"] = (ram_exp_found ~= 0)
    res["mapPos.address"] = map_addr
    res["mapPos.mask"] = map_bit
    res["pages"] = page_list
    res["pageMap"] = page_map

    return res
end