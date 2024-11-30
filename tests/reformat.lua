function simple_split(inputstr)
    local sep = "%s"
    local t = {}

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end

    return t
end

function make_word_list(start_pos, len, text)
    local word_list = {}
    local i, v

    for i = start_pos + 1, start_pos + len, 1 do
        local w = simple_split(text[i])
        for _,v in ipairs(w) do 
            table.insert(word_list, v)
        end
    end
        
    return word_list
end

function make_reference_data(start_pos, len, text)
    local word_list = make_word_list(start_pos, len, text)
    local v, i
    local ref_bytes = {}

    for _,v in ipairs(word_list) do 
        table.insert(ref_bytes, #v)

        for i = 1, #v do
            local c = v:sub(i,i)
            table.insert(ref_bytes, string.byte(c))
        end            
    end

    table.insert(ref_bytes, 0)

    return ref_bytes
end