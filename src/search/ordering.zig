const Position = @import("../board/position.zig");
const Piece = @import("../board/piece.zig");
const Encode = @import("../move/encode.zig");
const HCE = @import("../evaluation/hce.zig");
const Search = @import("./search.zig");
const SEE = @import("./see.zig");

const std = @import("std");

pub const OrderInfo = struct {
    pos: *Position.Position,
    searcher: *Search.Searcher,
    old_pv: u24,
};

pub fn order(info: OrderInfo, lhs: u24, rhs: u24) bool {
    return score_move(lhs, info) > score_move(rhs, info);
}

// MVV_LVA[attacker][captured]
const MVV_LVA: [6][6]i16 = .{
    .{ 60, 61, 62, 63, 64, 65 },
    .{ 50, 51, 52, 53, 54, 55 },
    .{ 40, 41, 42, 43, 44, 45 },
    .{ 30, 31, 32, 33, 34, 35 },
    .{ 20, 21, 22, 23, 24, 25 },
    .{ 10, 11, 12, 13, 14, 15 },
};

pub fn score_move(move: u24, info: OrderInfo) i16 {
    var pos = info.pos;

    if (info.old_pv == move) {
        return 16000;
    }

    var score: i16 = 0;
    var bts = Encode.target(move);
    var ts = Position.fen_sq_to_sq(bts);
    var pt = Encode.pt(move);

    if (Encode.capture(move) != 0) {
        // Captures first!
        score += 7000;

        if (Encode.enpassant(move) != 0) {
            return score;
        }

        if (Encode.promote(move) != 0) {
            return score + 2000 + HCE.PieceValues[Encode.promote(move) % 6];
        }

        var captured = @enumToInt(pos.mailbox[ts].?);
        //score += MVV_LVA[pt % 6][captured % 6];

        var attackers = pos.square_attackers(ts, pos.turn.invert());
        var defenders = pos.square_attackers(ts, pos.turn);

        score += SEE.get_see(pt % 6, captured % 6, attackers, defenders);

        return score;
    } else {
        if (info.searcher.killers[0][info.searcher.ply] == move) {
            score += 4000;
        } else if (info.searcher.killers[1][info.searcher.ply] == move) {
            score += 2500;
        } else {
            score += @intCast(i16, info.searcher.history[Encode.source(move)][Encode.target(move)]);
        }

        if (Encode.castling(move) != 0) {
            score += 400;
        }
    }

    if (Encode.promote(move) != 0) {
        score += 9500 + HCE.PieceValues[Encode.promote(move) % 6];
    }

    return score;
}
