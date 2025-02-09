package pinky

import "core:fmt"
import "core:os"
import "core:strings"

KEYWORD_IF :: "if"
KEYWORD_THEN :: "then"
KEYWORD_ELSE :: "else"
KEYWORD_TRUE :: "true"
KEYWORD_FALSE :: "false"
KEYWORD_AND :: "and"
KEYWORD_OR :: "or"
KEYWORD_WHILE :: "while"
KEYWORD_DO :: "do"
KEYWORD_FOR :: "for"
KEYWORD_FUNC :: "func"
KEYWORD_NULL :: "null"
KEYWORD_END :: "end"
KEYWORD_PRINT :: "print"
KEYWORD_PRINTLN :: "println"
KEYWORD_RET :: "ret"


Lexer_Unexpected_Character_Error :: struct {
	unexpected: u8,
	line:       int,
	column:     int,
	file:       string,
}

Lexer_Error :: union {
	Lexer_Unexpected_Character_Error,
}

lexer_error_to_string :: proc(err: Lexer_Error, allocator := context.allocator) -> string {
	builder := strings.builder_make_none(allocator)
	switch e in err {
	case Lexer_Unexpected_Character_Error:
		if e.file != "" {
			strings.write_string(&builder, e.file)
			strings.write_string(&builder, ":")
		}
		strings.write_string(&builder, "(")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, ",")
		strings.write_int(&builder, e.column, 10)
		strings.write_string(&builder, ") ")
		strings.write_string(&builder, "Lexer error: ")
		strings.write_string(&builder, "Unexpected character '")
		strings.write_byte(&builder, e.unexpected)
		strings.write_string(&builder, "'")
	}

	return strings.to_string(builder)
}

Lexer :: struct {
	file:      string,
	source:    string,
	start:     int,
	current:   int,
	line:      int,
	column:    int,
	tokens:    [dynamic]Token,
	_keywords: map[string]Token_Kind,
}

quit_with_message :: proc(message: string, line: int) {
	fmt.eprintfln("[line %v] Error: %v", line, message)
	os.exit(EXIT_CODE_DATAERR)
}

@(private = "file", require_results)
is_digit :: proc "contextless" (ch: u8) -> bool {
	return ch >= '0' && ch <= '9'
}

@(private = "file", require_results)
is_lower :: proc "contextless" (ch: u8) -> bool {
	return ch >= 'a' && ch <= 'z'
}

@(private = "file", require_results)
is_upper :: proc "contextless" (ch: u8) -> bool {
	return ch >= 'A' && ch <= 'Z'
}

@(private = "file", require_results)
is_alpha :: proc "contextless" (ch: u8) -> bool {
	return is_lower(ch) || is_upper(ch) || ch == '_'
}

@(private = "file", require_results)
is_alphanumeric :: proc "contextless" (ch: u8) -> bool {
	return is_alpha(ch) || is_digit(ch)
}

lexer_create :: proc(file, source: string, allocator := context.allocator) -> (result: Lexer) {
	result.source = source
	result.start = 0
	result.current = 0
	result.line = 1
	result.column = 1
	result.tokens = make([dynamic]Token, 0, 0, allocator)
	result.file = file

	lexer_init_keywords(&result, allocator)

	return result
}

@(private = "file")
lexer_init_keywords :: proc(lexer: ^Lexer, allocator := context.allocator) {
	lexer._keywords = make(map[string]Token_Kind, 32, allocator)
	lexer._keywords[KEYWORD_IF] = .IF
	lexer._keywords[KEYWORD_THEN] = .THEN
	lexer._keywords[KEYWORD_ELSE] = .ELSE
	lexer._keywords[KEYWORD_TRUE] = .TRUE
	lexer._keywords[KEYWORD_FALSE] = .FALSE
	lexer._keywords[KEYWORD_AND] = .AND
	lexer._keywords[KEYWORD_OR] = .OR
	lexer._keywords[KEYWORD_WHILE] = .WHILE
	lexer._keywords[KEYWORD_DO] = .DO
	lexer._keywords[KEYWORD_FOR] = .FOR
	lexer._keywords[KEYWORD_FUNC] = .FUNC
	lexer._keywords[KEYWORD_NULL] = .NULL
	lexer._keywords[KEYWORD_END] = .END
	lexer._keywords[KEYWORD_PRINT] = .PRINT
	lexer._keywords[KEYWORD_PRINTLN] = .PRINTLN
	lexer._keywords[KEYWORD_RET] = .RET
}

lexer_destroy :: proc(lexer: ^Lexer) {
	delete(lexer.tokens)
	delete(lexer._keywords)
}

@(private = "file")
lexer_add_token :: proc(lexer: ^Lexer, kind: Token_Kind) {
	lexme, _ := strings.substring(lexer.source, lexer.start, lexer.current)
	token := Token {
		kind   = kind,
		lexme  = lexme,
		line   = lexer.line,
		column = lexer.column - len(lexme),
		file   = lexer.file,
	}
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

@(private = "file")
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

@(private = "file")
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

@(private = "file")
lexer_handle_identifier :: proc(lexer: ^Lexer) {
	for is_alphanumeric(lexer_peek(lexer)) {
		lexer_advance(lexer)
	}

	lexme := lexer.source[lexer.start:lexer.current]
	kind := lexer._keywords[lexme] or_else .IDENTIFIER

	lexer_add_token(lexer, kind)
}

@(private = "file")
lexer_handle_comment :: proc(lexer: ^Lexer) {
	for lexer_peek(lexer) != '\n' && lexer_peek(lexer) != 0 {
		lexer_advance(lexer)
	}
}

@(private = "file")
lexer_scan_token :: proc(lexer: ^Lexer) -> Lexer_Error {

	switch ch := lexer_advance(lexer); ch {
	case '\n':
		lexer.line += 1
		lexer.column = 1
	case ' ', '\r', '\t': // Ignore whitespace
	case '(':
		lexer_add_token(lexer, .LPAREN)
	case ')':
		lexer_add_token(lexer, .RPAREN)
	case '{':
		lexer_add_token(lexer, .LCURLY)
	case '}':
		lexer_add_token(lexer, .RCURLY)
	case '[':
		lexer_add_token(lexer, .LSQUARE)
	case ']':
		lexer_add_token(lexer, .RSQUARE)
	case '.':
		lexer_add_token(lexer, .DOT)
	case ',':
		lexer_add_token(lexer, .COMMA)
	case '+':
		lexer_add_token(lexer, .PLUS)
	case '-':
		if lexer_match(lexer, '-') {
			lexer_handle_comment(lexer)
		} else {
			lexer_add_token(lexer, .MINUS)
		}
	case '*':
		lexer_add_token(lexer, .STAR)
	case '^':
		lexer_add_token(lexer, .CARET)
	case '/':
		lexer_add_token(lexer, .SLASH)
	case ';':
		lexer_add_token(lexer, .SEMICOLON)
	case '?':
		lexer_add_token(lexer, .QUESTION)
	case '%':
		lexer_add_token(lexer, .MOD)
	case '=':
		if lexer_match(lexer, '=') {
			lexer_add_token(lexer, .EQEQ)
		} else {
			lexer_add_token(lexer, .EQ)
		}
	case '~':
		if lexer_match(lexer, '=') {
			lexer_add_token(lexer, .NE)
		} else {
			lexer_add_token(lexer, .NOT)
		}
	case '>':
		if lexer_match(lexer, '=') {
			lexer_add_token(lexer, .GE)
		} else {
			lexer_add_token(lexer, .GT)
		}
	case '<':
		if lexer_match(lexer, '=') {
			lexer_add_token(lexer, .LE)
		} else {
			lexer_add_token(lexer, .LT)
		}
	case ':':
		if lexer_match(lexer, '=') {
			lexer_add_token(lexer, .ASSIGN)
		} else {
			lexer_add_token(lexer, .COLON)
		}
	case:
		if is_digit(ch) {
			lexer_handle_number(lexer)
		} else if ch == '"' || ch == '\'' {
			lexer_handle_string(lexer, ch)
		} else if is_alpha(ch) {
			lexer_handle_identifier(lexer)
		} else {
			return Lexer_Unexpected_Character_Error{unexpected = ch, file = lexer.file, line = lexer.line, column = lexer.column}
		}
	}

	return nil
}

lexer_tokenize :: proc(lexer: ^Lexer) -> (tokens: []Token, lexer_scan_token_error: Lexer_Error) {
	for lexer.current < len(lexer.source) {
		lexer.start = lexer.current
		lexer_scan_token(lexer) or_return
	}

	return lexer.tokens[:], nil
}
