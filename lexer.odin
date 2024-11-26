package pinky

import "core:os"
import "core:fmt"
import "core:strings"

@(private="file")
KEYWORDS := map[string]Token_Kind {
    "if" = .IF,
    "then" = .THEN,
    "else" = .ELSE,
    "true" = .TRUE,
    "false" = .FALSE,
    "and" = .AND,
    "or" = .OR,
    "while" = .WHILE,
    "do" = .DO,
    "for" = .FOR,
    "func" = .FUNC,
    "null" = .NULL,
    "end" = .END,
    "print" = .PRINT,
    "println" = .PRINTLN,
    "ret" = .RET,
}

Lexer :: struct {
    source: string,
    start: int,
    current: int,
    line: int,
    column: int,
    tokens: [dynamic]Token,
}

quit_with_message :: proc(message: string, line: int) {
    fmt.eprintfln("[line %v] Error: %v", line, message)
    os.exit(EXIT_CODE_DATAERR)
}

@(private="file")
@(require_results)
is_digit :: proc "contextless" (ch: u8) -> bool {
    return ch >= '0' && ch <= '9'
}

@(private="file")
@(require_results)
is_lower :: proc "contextless" (ch: u8) -> bool {
    return ch >= 'a' && ch <= 'z'
}

@(private="file")
@(require_results)
is_upper :: proc "contextless" (ch: u8) -> bool {
    return ch >= 'A' && ch <= 'Z'
}

@(private="file")
@(require_results)
is_alpha :: proc "contextless" (ch: u8) -> bool {
    return is_lower(ch) || is_upper(ch) || ch == '_'
}

@(private="file")
@(require_results)
is_alphanumeric :: proc "contextless" (ch: u8) -> bool {
    return is_alpha(ch) || is_digit(ch)
}

lexer_create :: proc(source: string, allocator := context.allocator) -> (result: Lexer) {
    result.source = source
    result.start = 0
    result.current = 0
    result.line = 1
    result.column = 1
    result.tokens = make([dynamic]Token, 0, len(source) / 2, allocator)

    return result
}

lexer_destroy :: proc(lexer: ^Lexer) {
    delete(lexer.tokens)
}

@(private="file")
lexer_add_token :: proc(lexer: ^Lexer, kind: Token_Kind) {
    lexme, _ := strings.substring(lexer.source, lexer.start, lexer.current)
    token := Token{kind = kind, lexme = lexme, line = lexer.line, column = lexer.column}
    append(&lexer.tokens, token)
}

lexer_advance :: proc(lexer: ^Lexer) -> u8 {
    assert(lexer.current < len(lexer.source), "Lexer out of bounds")

    ch := lexer.source[lexer.current]
    lexer.current += 1
    lexer.column += 1

    return ch
}

@(require_results)
lexer_peek :: proc(lexer: ^Lexer) -> u8 {
    if lexer.current >= len(lexer.source) {
        return 0
    }

    return lexer.source[lexer.current]
}

@(require_results)
look_ahead :: proc(lexer: ^Lexer, distance: int = 1) -> u8 {
    index := lexer.current + distance
    if index >= len(lexer.source) {
        return 0
    }

    return lexer.source[index]
}

@(require_results)
lexer_match :: proc(lexer: ^Lexer, expected: u8) -> bool {
    if lexer_peek(lexer) != expected {
        return false
    }

    lexer_advance(lexer)

    return true
}

@(private="file")
lexer_handle_number :: proc(lexer: ^Lexer) {
    for is_digit(lexer_peek(lexer)) {
        lexer_advance(lexer)
    }

    if lexer_peek(lexer) == '.' && is_digit(look_ahead(lexer)) {
        lexer_advance(lexer)

        for is_digit(lexer_peek(lexer)) {
            lexer_advance(lexer)
        }
        lexer_add_token(lexer, .FLOAT)
    } else {
        lexer_add_token(lexer, .INTEGER)
    }
}

@(private="file")
lexer_handle_string :: proc(lexer: ^Lexer, delimiter: u8) {
    for lexer_peek(lexer) != delimiter && lexer_peek(lexer) != 0 {
        if lexer_peek(lexer) == '\n' {
            lexer.line += 1
            lexer.column = 1
        }

        lexer_advance(lexer)
    }

    if lexer_peek(lexer) == 0 {
        quit_with_message("Unterminated string", lexer.line)
    }

    lexer_advance(lexer)

    lexer_add_token(lexer, .STRING)
}

@(private="file")
lexer_handle_identifier :: proc(lexer: ^Lexer) {
    for is_alphanumeric(lexer_peek(lexer)) {
        lexer_advance(lexer)
    }

    lexme := lexer.source[lexer.start:lexer.current]
    kind := KEYWORDS[lexme] or_else .IDENTIFIER

    lexer_add_token(lexer, kind)
}

@(private="file")
lexer_handle_comment :: proc(lexer: ^Lexer) {
    for lexer_peek(lexer) != '\n' && lexer_peek(lexer) != 0 {
        lexer_advance(lexer)
    }
}

@(private="file")
lexer_scan_token :: proc(lexer: ^Lexer) {
    
    switch ch := lexer_advance(lexer); ch {
    case '\n': {
        lexer.line += 1
        lexer.column = 1
    }
    case ' ', '\r', '\t': {
        // Ignore whitespace
    }
    case '(': lexer_add_token(lexer, .LPAREN)
    case ')': lexer_add_token(lexer, .RPAREN)
    case '{': lexer_add_token(lexer, .LCURLY)
    case '}': lexer_add_token(lexer, .RCURLY)
    case '[': lexer_add_token(lexer, .LSQUARE)
    case ']': lexer_add_token(lexer, .RSQUARE)
    case '.': lexer_add_token(lexer, .DOT)
    case ',': lexer_add_token(lexer, .COMMA)
    case '+': lexer_add_token(lexer, .PLUS)
    case '-': {
        if lexer_match(lexer, '-') {
            lexer_handle_comment(lexer)
        } else {
            lexer_add_token(lexer, .MINUS)
        }
    }
    case '*': lexer_add_token(lexer, .STAR)
    case '^': lexer_add_token(lexer, .CARET)
    case '/': lexer_add_token(lexer, .SLASH)
    case ';': lexer_add_token(lexer, .SEMICOLON)
    case '?': lexer_add_token(lexer, .QUESTION)
    case '%': lexer_add_token(lexer, .MOD)
    case '=': {
        if lexer_match(lexer, '=') {
            lexer_add_token(lexer, .EQEQ)
        } else {
            lexer_add_token(lexer, .EQ)
        }
    }
    case '~': {
        if lexer_match(lexer, '=') {
            lexer_add_token(lexer, .NE)
        } else {
            lexer_add_token(lexer, .NOT)
        }
    }
    case '>': {
        if lexer_match(lexer, '=') {
            lexer_add_token(lexer, .GE)
        } else {
            lexer_add_token(lexer, .GT)
        }
    }
    case '<': {
        if lexer_match(lexer, '=') {
            lexer_add_token(lexer, .LE)
        } else {
            lexer_add_token(lexer, .LT)
        }
    }
    case ':': {
        if lexer_match(lexer, '=') {
            lexer_add_token(lexer, .ASSIGN)
        } else {
            lexer_add_token(lexer, .COLON)
        }
    }
    case: {
        if is_digit(ch) {
            lexer_handle_number(lexer)
        } else if ch == '"' || ch == '\'' {
            lexer_handle_string(lexer, ch)
        } else if is_alpha(ch) {
            lexer_handle_identifier(lexer)
        } else {
           // quit_with_message("Unexpected character", lexer.line)
        }
    }
    }
}

lexer_tokenize :: proc(lexer: ^Lexer) -> []Token {
    for lexer.current < len(lexer.source) {
        lexer.start = lexer.current
        lexer_scan_token(lexer)
    }

    return lexer.tokens[:]
}