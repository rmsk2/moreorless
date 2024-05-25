require (test_dir.."tools")

function arrange()

end

function assert()

    if read_word(load_address + 3) ~= 0 then
        return false, string.format("Wrong value. Expected %d, got %d", 0, read_word(load_address + 3))
    end

    if read_word(load_address + 5) ~= 1 then
        return false, string.format("Wrong value. Expected %d, got %d", 1, read_word(load_address + 5))
    end

    if read_word(load_address + 7) ~= 23 then
        return false, string.format("Wrong value. Expected %d, got %d", 23, read_word(load_address + 7))
    end

    if read_word(load_address + 9) ~= 65525 then
        return false, string.format("Wrong value. Expected %d, got %d", 65525, read_word(load_address + 9))
    end

    if read_word(load_address + 11) ~= 65535 then
        return false, string.format("Wrong value. Expected %d, got %d", 65535, read_word(load_address + 11))
    end

    return true, ""
end