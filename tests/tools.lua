require("math")
require("table")

MAX_PAGES = 80
PAGE_SIZE = 8192
BLOCK_SIZE = 32
BLOCKS_PER_PAGE = PAGE_SIZE / BLOCK_SIZE
BYTES_PER_PAGE_IN_MAP = BLOCKS_PER_PAGE / 8

MAX_BLOCK_POS = MAX_PAGES * 256

reference_pages = {}

function de_ref(ptr_addr)
    local hi_addr = read_byte(ptr_addr + 1)
    local lo_addr = read_byte(ptr_addr)
    
    return hi_addr * 256 + lo_addr
end

function set_word_at(addr, w)
    local hi = math.floor(w / 256)
    local lo = math.fmod(w, 256)

    write_byte(addr, lo)
    write_byte(addr+1, hi)
end

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
        table.insert(page_list, read_byte(addr))
    end

    addr = addr + MAX_PAGES

    local page_map = {}

    for i = addr, addr + page_map_len - 1, 1 do
        table.insert(page_map, read_byte(addr))
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