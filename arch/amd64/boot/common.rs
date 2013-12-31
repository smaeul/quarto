#[link(name = "quarto", vers = "0.0", license = "MIT")];
#[crate_type = "lib"];
#[no_std];

#[no_mangle]
pub unsafe fn common() {
    loop {}
}
