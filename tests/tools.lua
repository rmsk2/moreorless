require("math")

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