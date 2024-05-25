require (test_dir.."tools")

function arrange()

end

function assert()
    if read_byte(load_address + 3) ~= 1 then
        return false, string.format("Wrong value. Expected %d, got %d", 1, read_byte(load_address + 3))
    end

    if read_byte(load_address + 4) ~= 1 then
        return false, string.format("Wrong value. Expected %d, got %d", 1, read_byte(load_address + 4))
    end

    if read_byte(load_address + 5) ~= 0 then
        return false, string.format("Wrong value. Expected %d, got %d", 0, read_byte(load_address + 5))
    end

    if read_byte(load_address + 6) ~= 0 then
        return false, string.format("Wrong value. Expected %d, got %d", 0, read_byte(load_address + 6))
    end

    if read_byte(load_address + 7) ~= 1 then
        return false, string.format("Wrong value. Expected %d, got %d", 1, read_byte(load_address + 7))
    end

    return true, ""
end