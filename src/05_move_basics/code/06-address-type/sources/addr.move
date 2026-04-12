module ch05_06_address::addr;

const ROOT: address = @0x0;

public fun zero_addr(): address {
    ROOT
}

public fun literal(): address {
    @0x42
}
