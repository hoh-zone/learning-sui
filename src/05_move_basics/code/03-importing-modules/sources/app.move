module ch05_03_importing::app;

use ch05_03_importing::lib;

public fun doubled(): u64 {
    lib::value() + lib::value()
}
