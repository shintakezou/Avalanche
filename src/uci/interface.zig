const std = @import("std");
const Position = @import("../board/position.zig");
const Search = @import("../search/search.zig");
const Uci = @import("./uci.zig");
const Perft = @import("./perft.zig");
const Encode = @import("../move/encode.zig");
const HCE = @import("../evaluation/hce.zig");

pub const UciInterface = struct {
    position: Position.Position,

    pub fn new() UciInterface {
        return UciInterface{
            .position = Position.new_position_by_fen(Position.STARTPOS),
        };
    }

    pub fn main_loop(self: *UciInterface) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();
        var command_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer command_arena.deinit();

        var searcher = Search.Searcher.new_searcher();

        _ = try stdout.writeAll("Avalanche 0.0 by SnowballSH\n");

        self.position = Position.new_position_by_fen(Position.STARTPOS);
        defer self.position.deinit();

        out: while (true) {
            // The command will probably be less than 1024 characters
            var line = try stdin.readUntilDelimiterOrEofAlloc(command_arena.allocator(), '\n', 1024);
            if (line == null) {
                break;
            }
            defer command_arena.allocator().free(line.?);

            var tokens = std.mem.split(u8, line.?, " ");
            var token = tokens.next();
            if (token == null) {
                break;
            }

            if (std.mem.eql(u8, token.?, "quit")) {
                break :out;
            } else if (std.mem.eql(u8, token.?, "uci")) {
                _ = try stdout.write("id name Avalanche 0.0\n");
                _ = try stdout.write("id author SnowballSH\n");
                _ = try stdout.writeAll("uciok\n");
            } else if (std.mem.eql(u8, token.?, "isready")) {
                _ = try stdout.writeAll("readyok\n");
            } else if (std.mem.eql(u8, token.?, "d")) {
                self.position.display();
            } else if (std.mem.eql(u8, token.?, "eval")) {
                token = tokens.next();
                if (token != null) {
                    var depth = std.fmt.parseUnsigned(u8, token.?, 10) catch 1;
                    depth = std.math.max(depth, 1);
                    searcher.max_nano = null;
                    searcher.nodes = 0;
                    var score = searcher.negamax(&self.position, -Search.INF, Search.INF, depth);
                    var ev = HCE.evaluate(&self.position);
                    if (@intCast(i16, @enumToInt(self.position.turn)) == 1) {
                        score = -score;
                        ev = -ev;
                    }

                    if (score >= Search.INF - 200 or std.math.absInt(ev - score) catch 0 > 400) {
                        try stdout.print("{}\n", .{ev});
                    } else {
                        try stdout.print("{}\n", .{score});
                    }
                } else {
                    try stdout.print("{}\n", .{HCE.evaluate(&self.position)});
                }
            } else if (std.mem.eql(u8, token.?, "perft")) {
                var depth: usize = 1;
                token = tokens.next();
                if (token != null) {
                    depth = std.fmt.parseUnsigned(usize, token.?, 10) catch 1;
                }

                depth = std.math.max(depth, 1);

                _ = Perft.perft_root(&self.position, depth) catch unreachable;
            } else if (std.mem.eql(u8, token.?, "go")) {
                var movetime: ?u64 = 10 * std.time.ns_per_s;
                while (true) {
                    token = tokens.next();
                    if (token == null) {
                        break;
                    }
                    if (std.mem.eql(u8, token.?, "movetime")) {
                        token = tokens.next();
                        if (token == null) {
                            break;
                        }

                        movetime = std.fmt.parseUnsigned(u64, token.?, 10) catch 10 * std.time.ms_per_s;
                        movetime.? *= std.time.ns_per_ms;
                    }
                }
                searcher.iterative_deepening(&self.position, movetime.?);
            } else if (std.mem.eql(u8, token.?, "position")) {
                token = tokens.next();
                if (token != null) {
                    if (std.mem.eql(u8, token.?, "startpos")) {
                        self.position.deinit();
                        self.position = Position.new_position_by_fen(Position.STARTPOS);

                        token = tokens.next();
                        if (token != null) {
                            if (std.mem.eql(u8, token.?, "moves")) {
                                while (true) {
                                    token = tokens.next();
                                    if (token == null) {
                                        break;
                                    }

                                    var move = Uci.uci_to_move(token.?, &self.position);

                                    if (move == null) {
                                        std.debug.print("Invalid move!\n", .{});
                                        break;
                                    }

                                    self.position.make_move(move.?);
                                    if (Encode.capture(move.?) != 0 or Encode.pt(move.?) % 6 == 0) {
                                        searcher.halfmoves = 0;
                                    } else {
                                        searcher.halfmoves += 1;
                                    }

                                    searcher.hash_history.append(self.position.hash) catch {};
                                }
                            }
                        }
                    } else if (std.mem.eql(u8, token.?, "fen")) {
                        self.position.deinit();
                        tokens = std.mem.split(u8, tokens.rest(), " moves ");
                        var fen = tokens.next();
                        if (fen != null) {
                            self.position = Position.new_position_by_fen(fen.?);

                            var afterfen = tokens.next();
                            if (afterfen != null) {
                                tokens = std.mem.split(u8, afterfen.?, " ");
                                while (true) {
                                    token = tokens.next();
                                    if (token == null) {
                                        break;
                                    }

                                    var move = Uci.uci_to_move(token.?, &self.position);

                                    if (move == null) {
                                        std.debug.print("Invalid move!\n", .{});
                                        break;
                                    }

                                    self.position.make_move(move.?);
                                    if (Encode.capture(move.?) != 0 or Encode.pt(move.?) % 6 == 0) {
                                        searcher.halfmoves = 0;
                                    } else {
                                        searcher.halfmoves += 1;
                                    }

                                    searcher.hash_history.append(self.position.hash) catch {};
                                }
                            }
                        }
                    }
                }
            }
        }
    }
};
