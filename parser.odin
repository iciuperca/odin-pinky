package pinky

import "base:runtime"
import "core:strconv"
import "core:strings"

Parser :: struct {
	node_pool:      Node_Pool,
	tokens:         []Token,
	current:        int,
	current_line:   int,
	current_column: int,
}

Parser_Unexpected_Token_Error :: struct {
	token:    Token,
	line:     int,
	column:   int,
	file:     string,
	location: runtime.Source_Code_Location,
}

@(private, require_results)
parser_unexpected_token_error_create :: proc(token: Token, loc := #caller_location) -> (err: Parser_Unexpected_Token_Error) {
	err.token = token
	err.location = loc
	err.line = token.line
	err.column = token.column
	err.file = token.file

	return err
}

Parser_End_Of_File_Error :: struct {
	line:     int,
	column:   int,
	location: runtime.Source_Code_Location,
}

Parser_Underflow_Error :: struct {
	line:     int,
	column:   int,
	location: runtime.Source_Code_Location,
}

@(private, require_results)
parser_underflow_error_create :: proc(line: int = 0, column: int = 0, loc := #caller_location) -> (err: Parser_Underflow_Error) {
	err.line = line
	err.column = column
	err.location = loc

	return err
}

Parser_Convert_Int_Error :: struct {
	line:     int,
	column:   int,
	location: runtime.Source_Code_Location,
}

@(private, require_results)
parser_convert_int_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_Convert_Int_Error) {
	err.line = line
	err.column = column
	err.location = loc

	return err
}

Parser_Convert_Float_Error :: struct {
	line:     int,
	column:   int,
	location: runtime.Source_Code_Location,
}

@(private, require_results)
parser_convert_float_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_Convert_Float_Error) {
	err.line = line
	err.column = column
	err.location = loc

	return err
}

Parser_Convert_String_Error :: struct {
	line:     int,
	column:   int,
	location: runtime.Source_Code_Location,
}

Parser_Unmatched_Parentheses_Error :: struct {
	line:     int,
	column:   int,
	location: runtime.Source_Code_Location,
}

@(private, require_results)
parser_unmatched_parentheses_error_create :: proc(
	line: int,
	column: int,
	loc := #caller_location,
) -> (
	err: Parser_Unmatched_Parentheses_Error,
) {
	err.line = line
	err.column = column
	err.location = loc

	return err
}

Parser_Create_No_Tokens_Error :: struct {
	location: runtime.Source_Code_Location,
}

@(private, require_results)
parser_create_no_tokens_error_create :: proc(loc := #caller_location) -> (err: Parser_Create_No_Tokens_Error) {
	err.location = loc

	return err
}

Parser_Error :: union {
	Parser_Unexpected_Token_Error,
	Parser_End_Of_File_Error,
	Parser_Underflow_Error,
	Parser_Convert_Int_Error,
	Parser_Convert_Float_Error,
	Parser_Convert_String_Error,
	Parser_Unmatched_Parentheses_Error,
	Parser_Create_No_Tokens_Error,
}

@(require_results)
parser_error_to_string :: proc(error: Parser_Error, allocator := context.allocator) -> string {
	builder := strings.builder_make_none(allocator)

	if error == nil {
		strings.write_string(&builder, "No error")
		return strings.to_string(builder)
	}
	strings.write_string(&builder, "Parser error: ")

	switch e in error {
	case Parser_Unexpected_Token_Error:
		if (e.token.file != "") {
			strings.write_string(&builder, e.token.file)
			strings.write_string(&builder, ":")
		}
		strings.write_string(&builder, "(")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, ",")
		strings.write_int(&builder, e.column, 10)
		strings.write_string(&builder, ") ")

		strings.write_string(&builder, "Unexpected token '")
		strings.write_string(&builder, e.token.lexme)
		strings.write_string(&builder, "'")
	case Parser_End_Of_File_Error:
		strings.write_string(&builder, "End of file at line ")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, " column ")
		strings.write_int(&builder, e.column, 10)
	case Parser_Underflow_Error:
		strings.write_string(&builder, "Underflow at line ")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, " column ")
		strings.write_int(&builder, e.column, 10)
	case Parser_Convert_Int_Error:
		strings.write_string(&builder, "Error converting integer at line ")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, " column ")
		strings.write_int(&builder, e.column, 10)
	case Parser_Convert_Float_Error:
		strings.write_string(&builder, "Error converting float at line ")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, " column ")
		strings.write_int(&builder, e.column, 10)
	case Parser_Convert_String_Error:
		strings.write_string(&builder, "Error converting string at line ")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, " column ")
		strings.write_int(&builder, e.column, 10)
	case Parser_Unmatched_Parentheses_Error:
		strings.write_string(&builder, "Unmatched parentheses at line ")
		strings.write_int(&builder, e.line, 10)
		strings.write_string(&builder, " column ")
		strings.write_int(&builder, e.column, 10)
	case Parser_Create_No_Tokens_Error:
		strings.write_string(&builder, "No tokens provided to parser")
	}

	return strings.to_string(builder)
}

@(require_results)
parser_create :: proc(tokens: []Token) -> (result: Parser, err: Parser_Error) {
	if len(tokens) == 0 {
		return Parser{}, parser_create_no_tokens_error_create()
	}

	parser := Parser {
		node_pool = node_pool_create(),
		tokens    = tokens,
	}

	return parser, nil
}

parser_destroy :: proc(p: ^Parser) {
	//destroy_node_pool(&p.node_pool)
}

@(private, require_results)
parser_previous_token :: proc(p: ^Parser) -> (Token, Parser_Error) {
	if p.current <= 0 {
		return Token{}, parser_underflow_error_create()
	}

	return p.tokens[p.current - 1], nil
}

@(private, require_results)
parser_peek :: proc(p: Parser) -> (token: Token, was_found: bool) {
	if p.current >= len(p.tokens) {
		return Token{}, false
	}

	if p.current < 0 {
		return Token{}, false
	}

	return p.tokens[p.current], true
}

@(private, require_results)
parser_match :: proc(p: ^Parser, token_kind: Token_Kind) -> (result: bool) {
	next_token := parser_peek(p^) or_return

	if next_token.kind != token_kind {
		return false
	}

	p.current += 1

	return true
}

@(private, require_results)
parser_advance_match :: proc(p: ^Parser, token_kind: Token_Kind) -> (result: Token, was_matched: bool) {
	next_token := parser_peek(p^) or_return

	if next_token.kind != token_kind {
		return next_token, false
	}

	p.current += 1

	return next_token, true
}

@(require_results, private)
parser_primary_integer :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	token := parser_previous_token(p) or_return
	n := 0
	lexme_str := token.lexme
	int_from_token, int_from_token_ok := strconv.parse_int(lexme_str, 10, &n)
	if !int_from_token_ok {
		err = parser_convert_int_error_create(token.line, token.column)
	} else {
		result = new_expr_integer(&p.node_pool, int_from_token, token.line)
	}

	return result, err
}

@(require_results, private)
parser_primary_float :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	token := parser_previous_token(p) or_return
	n := 0
	float_from_token, float_from_token_ok := strconv.parse_f64(token.lexme, &n)
	if !float_from_token_ok {
		err = parser_convert_float_error_create(token.line, token.column)
	} else {
		result = new_expr_float(&p.node_pool, float_from_token, token.line)
	}

	return result, err
}

@(private, require_results)
parser_primary :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	if int_was_matched := parser_match(p, .INTEGER); int_was_matched {
		result = parser_primary_integer(p) or_return

		return result, err
	}

	if float_was_matched := parser_match(p, .FLOAT); float_was_matched {
		result = parser_primary_float(p) or_return

		return result, err
	}

	if string_was_matched := parser_match(p, .STRING); string_was_matched {
		token := parser_previous_token(p) or_return

		string_type: String_Type = .STRING_TYPE_SINGLE
		if token.lexme[0] == '"' {
			string_type = .STRING_TYPE_DOUBLE
		}

		string_value, _ := strings.substring(token.lexme, 1, len(token.lexme) - 1)

		result = new_expr_string(&p.node_pool, string_value, string_type, token.line)

		return result, err
	}

	if lparen_token, lparen_was_matched := parser_advance_match(p, .LPAREN); lparen_was_matched {
		expr := parser_expression(p) or_return
		if rparen_was_matched := parser_match(p, .RPAREN); !rparen_was_matched {
			next_token, next_token_found := parser_peek(p^)
			if next_token_found {
				err = parser_unexpected_token_error_create(next_token)
			} else {
				current_token, _ := parser_get_current_token(p^)
				column := current_token.column + len(current_token.lexme)
				err = parser_unmatched_parentheses_error_create(parser_get_current_line(p^), column)
			}
		} else {
			result = new_expr_grouping(&p.node_pool, expr, lparen_token.line)
		}

		return result, err
	}

	err = parser_unexpected_token_error_create(parser_previous_token(p) or_return)

	return result, err
}

@(private, require_results)
parser_unary :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	if parser_match(p, .NOT) || parser_match(p, .MINUS) || parser_match(p, .PLUS) {
		operator := parser_previous_token(p) or_return
		right := parser_unary(p) or_return
		right_token := parser_previous_token(p) or_return
		result = new_expr_un_op(&p.node_pool, operator, right, right_token.line)
	} else {
		result = parser_primary(p) or_return
	}

	return result, err
}

// <multiplication>  ::= <unary> ( ('*'|'/') <unary> )*
@(private, require_results)
parser_multiplication :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	expr := parser_unary(p) or_return

	for parser_match(p, .STAR) || parser_match(p, .SLASH) {
		operator := parser_previous_token(p) or_return
		right := parser_unary(p) or_return
		right_token := parser_previous_token(p) or_return
		expr = new_expr_bin_op(&p.node_pool, expr, operator, right, right_token.line)
	}

	return expr, nil
}

// <addition>  ::= <multiplication> ( ('+'|'-') <multiplication> )*
@(private, require_results)
parser_addition :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	expr := parser_multiplication(p) or_return

	for parser_match(p, .PLUS) || parser_match(p, .MINUS) {
		operator := parser_previous_token(p) or_return
		right := parser_multiplication(p) or_return
		right_token := parser_previous_token(p) or_return
		expr = new_expr_bin_op(&p.node_pool, expr, operator, right, right_token.line)
	}

	return expr, err
}

@(private, require_results)
parser_expression :: proc(p: ^Parser) -> (result: Node_Id, err: Parser_Error) {
	return parser_addition(p)
}

@(require_results)
parser_parse :: proc(p: ^Parser) -> (result: Node_Id, nodes: Node_Pool, err: Parser_Error) {
	expression := parser_expression(p) or_return

	return expression, p.node_pool, nil
}

@(private, require_results)
parser_get_current_token :: proc(p: Parser) -> (token: Token, was_found: bool) {
	if p.current <= 0 {
		return p.tokens[0], false
	}

	if p.current >= len(p.tokens) {
		return p.tokens[len(p.tokens) - 1], false
	}

	return p.tokens[p.current], true
}

@(private, require_results)
parser_get_current_line :: proc(p: Parser) -> int {
	token, _ := parser_get_current_token(p)


	return token.line
}
