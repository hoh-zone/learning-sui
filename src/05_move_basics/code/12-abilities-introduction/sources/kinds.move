module ch05_12_abilities_intro::kinds;

public struct OnlyCopy has copy {}

public struct CopyDrop has copy, drop {}

public struct WithStore has store, drop {
    flag: bool,
}
