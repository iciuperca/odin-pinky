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
	kind:   Token_Kind,
	lexme:  string,
	line:   int,
	column: int,
	file:   string,
}

token_to_string :: proc(token: Token, allocator := context.allocator) -> string {

	builder: strings.Builder
	strings.builder_init(&builder, allocator)
	// defer strings.builder_destroy(&builder)

	if (token.file != "") {
		strings.write_string(&builder, token.file)
		strings.write_string(&builder, ",")
	}
	strings.write_string(&builder, "(")
	strings.write_int(&builder, token.line, 10)
	strings.write_string(&builder, ":")
	strings.write_int(&builder, token.column, 10)
	strings.write_string(&builder, ") ")

	strings.write_string(&builder, "token ")
	token_kind_string, token_kind_string_ok := fmt.enum_value_to_string(token.kind)
	if !token_kind_string_ok {
		token_kind_string = "unknown"
	}
	strings.write_string(&builder, token_kind_string)
	strings.write_string(&builder, " '")
	strings.write_string(&builder, token.lexme)
	strings.write_string(&builder, "'")


	return strings.to_string(builder)
}
