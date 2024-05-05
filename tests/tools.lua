require("math")
require("table")

PAGE_SIZE = 8192
BLOCK_SIZE = 32
BLOCKS_PER_PAGE = PAGE_SIZE / BLOCK_SIZE
BYTES_PER_PAGE_IN_MAP = BLOCKS_PER_PAGE / 8

reference_pages = {
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 
    38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 
    60, 61, 62, 63, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 
    142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159
}

MAX_PAGES = #reference_pages
MAX_BLOCK_POS = MAX_PAGES * 256

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
        table.insert(page_list, read_byte(i))
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