module ch05_21_visibility::api;

use ch05_21_visibility::helper;

public fun exposed(): u64 {
    helper::package_only()
}
