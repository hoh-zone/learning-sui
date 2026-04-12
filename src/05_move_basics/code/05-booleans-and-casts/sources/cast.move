module ch05_05_booleans::cast;

public fun flag_to_u8(b: bool): u8 {
    if (b) { 1 } else { 0 }
}
