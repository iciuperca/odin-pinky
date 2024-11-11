package pinky

import "core:strings"
import "core:fmt"

Token_Kind :: enum {
    // Single-character tokens
    LPAREN, RPAREN, LCURLY, RCURLY, LSQUARE, RSQUARE, COMMA, DOT, MINUS, PLUS, STAR, SLASH, CARET, MOD, COLON, SEMICOLON, QUESTION, NOT, GT, LT,
    //  Two-character tokens
    GE, LE, NE, EQ, ASSIGN, GTGT, LTLT,
    // Literals
    IDENTIFIER, STRING, INTEGER, FLOAT,
    // Keywords
    IF, THEN, ELSE, TRUE, FALSE, AND, OR, WHILE, DO, FOR, FUNC, NULL, END, PRINT, PRINTLN, RET,
}

Token :: struct {
    kind: Token_Kind,
    lexme: []u8,
    line: int,
}

token_to_string :: proc(token: Token, allocator := context.allocator) -> string {

    builder : strings.Builder
    strings.builder_init(&builder, allocator)
    // defer strings.builder_destroy(&builder)

    return fmt.sbprintf(&builder, "token %v '%s' at line %d", token.kind, token.lexme, token.line)
}

// token_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
//     t := cast(^Token)(arg.data)
//     switch verb {
//     case 'v', 's':
//         fmt.fmt_enum(fi, t.kind, 'v')
//         fmt.fmt_string(fi, string(t.lexme), 's')
//         fmt.fmt_int(fi, u64(t.line), true, size_of(int), 'd')
//     case:
//         return false
//     }

//     return true
// }
