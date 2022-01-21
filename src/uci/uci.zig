const std = @import("std");
const Encode = @import("../move/encode.zig");
const Bitboard = @import("../board/bitboard.zig");

pub const alphabets = "abcdefgh";
pub const pieces = "PNBRQKpnbrqk";
pub const pieces_lower = "pnbrqkpnbrqk";
pub const numbers = "12345678";

pub inline fn move_to_uci(move: u24) []u8 {
    const source = Encode.source(move);
    const target = Encode.target(move);
    const promop = Encode.promote(move);
    if (promop != 0) {
        return std.fmt.allocPrint(std.heap.page_allocator, "{c}{c}{c}{c}{c}", .{ alphabets[Bitboard.file_of(source)], numbers[Bitboard.rank_of(source)], alphabets[Bitboard.file_of(target)], numbers[Bitboard.rank_of(target)], pieces_lower[promop] }) catch unreachable;
    } else {
        return std.fmt.allocPrint(std.heap.page_allocator, "{c}{c}{c}{c}", .{ alphabets[Bitboard.file_of(source)], numbers[Bitboard.rank_of(source)], alphabets[Bitboard.file_of(target)], numbers[Bitboard.rank_of(target)] }) catch unreachable;
    }
}
