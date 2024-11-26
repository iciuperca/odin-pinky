package pinky

import "core:fmt"
import "core:strings"

Token_Kind :: enum {
    // Single-character tokens
    LPAREN,
    RPAREN,
    LCURLY,
    RCURLY,
    LSQUARE,
    RSQUARE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    STAR,
    SLASH,
    CARET,
    MOD,
    COLON,
    SEMICOLON,
    QUESTION,
    NOT,
    GT,
    LT,
    EQEQ,
    //  Two-character tokens
    GE,
    LE,
    NE,
    EQ,
    ASSIGN,
    GTGT,
    LTLT,
    // Literals
    IDENTIFIER,
    STRING,
    INTEGER,
    FLOAT,
    // Keywords
    IF,
    THEN,
    ELSE,
    TRUE,
    FALSE,
    AND,
    OR,
    WHILE,
    DO,
    FOR,
    FUNC,
    NULL,
    END,
    PRINT,
    PRINTLN,
    RET,
}

Token :: struct {
    kind:  Token_Kind,
    lexme: string,
    line:  int,
    column: int,
}

token_to_string :: proc(token: Token, allocator := context.allocator) -> string {

    builder: strings.Builder
    strings.builder_init(&builder, allocator)
    // defer strings.builder_destroy(&builder)

    return fmt.sbprintf(&builder, "token %v '%s' at line %d, column: %d", token.kind, token.lexme, token.line, token.column)
}

