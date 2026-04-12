module ch06_04_string::str;

use std::string::String;

public fun hello(): String {
    b"hello".to_string()
}
