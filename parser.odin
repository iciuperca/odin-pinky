package pinky

import "core:strconv"
import "base:runtime"
import "core:strings"

Parser :: struct {
    tokens: []Token,
    current: int,
}

Parser_Unexpected_Token_Error :: struct {
    token: Token,
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_unexpected_token_error_create :: proc(token: Token, loc := #caller_location) -> (err: Parser_Unexpected_Token_Error) {
    err.token = token
    err.location = loc
    err.line = token.line
    err.column = token.column

    return err
}

Parser_End_Of_File_Error :: struct {
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_end_of_file_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_End_Of_File_Error) {
    err.line = line
    err.column = column
    err.location = loc

    return err
}

Parser_Underflow_Error :: struct {
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_underflow_error_create :: proc(line: int = 0, column: int = 0, loc := #caller_location) -> (err: Parser_Underflow_Error) {
    err.line = line
    err.column = column
    err.location = loc

    return err
}

Parser_Convert_Int_Error :: struct {
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_convert_int_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_Convert_Int_Error) {
    err.line = line
    err.column = column
    err.location = loc

    return err
}

Parser_Convert_Float_Error :: struct {
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_convert_float_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_Convert_Float_Error) {
    err.line = line
    err.column = column
    err.location = loc

    return err
}

Parser_Convert_String_Error :: struct {
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_convert_string_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_Convert_String_Error) {
    err.line = line
    err.column = column
    err.location = loc

    return err
}

Parser_Unmatched_Parentheses_Error :: struct {
    line: int,
    column: int,
    location: runtime.Source_Code_Location,
}

parser_unmatched_parentheses_error_create :: proc(line: int, column: int, loc := #caller_location) -> (err: Parser_Unmatched_Parentheses_Error) {
    err.line = line
    err.column = column
    err.location = loc

    return err
}

Parser_Create_No_Tokens_Error :: struct {
    location: runtime.Source_Code_Location,
}

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

parser_create :: proc(tokens: []Token) -> (result: Parser, err: Parser_Error) {
    if len(tokens) == 0 {
        return Parser{}, parser_create_no_tokens_error_create()
    }

    return Parser{tokens = tokens, current = 0}, nil
}

parser_previous_token :: proc(p: ^Parser) -> (Token, Parser_Error) {
    if p.current <= 0 {
        return Token{}, parser_underflow_error_create()
    }

    return p.tokens[p.current - 1], nil
}

parser_peek :: proc(p: Parser) -> (token: Token, was_found: bool) {
    if p.current >= len(p.tokens) {
        return Token{}, false
    }

    if p.current < 0 {
        return Token{}, false
    }

    return p.tokens[p.current], true
}

parser_look_ahead :: proc(p: ^Parser, distance: int = 1) -> (token: Token, was_found: bool) {
    index := p.current + distance
    if index < 0 || index >= len(p.tokens) {
        return Token{}, false
    }

    return p.tokens[index], true
}

parser_is_next :: proc(p: ^Parser, token_kind: Token_Kind) -> (result: bool, err: Parser_Error) {
    next_token, next_token_found := parser_peek(p^)
    if !next_token_found {
        return false, nil
    }

    return next_token.kind == token_kind, nil
}

parser_expect :: proc(p: ^Parser, token_kind: Token_Kind) -> (token: Token, err: Parser_Error) {
    next_token, next_token_found := parser_peek(p^)
    if !next_token_found {
        current_token := p.tokens[p.current]
        return Token{}, parser_end_of_file_error_create(current_token.line, current_token.column)
    }

    if next_token.kind != token_kind {
        return Token{}, parser_unexpected_token_error_create(next_token)
    }

    p.current += 1

    return next_token, nil
}

parser_previous :: proc(p: Parser) -> (token: Token, was_found: bool) {
    if p.current <= 0 {
        return Token{}, false
    }

    return p.tokens[p.current - 1], true
}

parser_match :: proc(p: ^Parser, token_kind: Token_Kind) -> (result: bool) {
    next_token := parser_peek(p^) or_return

    if next_token.kind != token_kind {
        return false
    }

    p.current += 1

    return true
}

parser_advance :: proc(p: ^Parser) -> (Token, Parser_Error) {
    token, token_found := parser_peek(p^)
    if !token_found {
        return Token{}, parser_end_of_file_error_create(0, 0)
    }

    p.current += 1

    return token, nil
}

parser_primary_integer :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    token := parser_previous_token(p) or_return
    n := 0
    lexme_str := token.lexme
    int_from_token, int_from_token_ok := strconv.parse_int(lexme_str, 10, &n)
    if !int_from_token_ok {
        err = parser_convert_int_error_create(token.line, token.column)
    } else {
        result = new_expr_integer(int_from_token)
    }

    return result, err
}

parser_primary_float :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    token := parser_previous_token(p) or_return
    n := 0
    float_from_token, float_from_token_ok := strconv.parse_f64(token.lexme, &n)
    if !float_from_token_ok {
        err = parser_convert_float_error_create(token.line, token.column)
    } else {
        result = new_expr_float(float_from_token)
    }

    return result, err
}

parser_primary :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
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

        string_type : String_Type = .STRING_TYPE_SINGLE
        if token.lexme[0] == '"' {
            string_type = .STRING_TYPE_DOUBLE
        }

        string_value, _ := strings.substring(token.lexme, 1, len(token.lexme) - 1)

        result = new_expr_string(string_value, string_type)

        return result, err
    }

    if lparen_was_matched := parser_match(p, .LPAREN); lparen_was_matched {
        expr := parser_expression(p) or_return
        if rparen_was_matched := parser_match(p, .RPAREN); !rparen_was_matched {
            next_token, next_token_found := parser_peek(p^)
            if next_token_found {
                err = parser_unexpected_token_error_create(next_token)
            } else {
                err = parser_unmatched_parentheses_error_create(0, 0)
            }
        } else {
            result = new_expr_grouping(expr)
        }

        return result, err
    }

    err = parser_unexpected_token_error_create(parser_previous_token(p) or_return)

    return result, err
}

parser_unary :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    if parser_match(p, .NOT) || parser_match(p, .MINUS) || parser_match(p, .PLUS) {
        operator := parser_previous_token(p) or_return
        right := parser_unary(p) or_return

        result = new_expr_un_op(operator, right)
    } else {
        result = parser_primary(p) or_return
    }

    return result, err
}

parser_factor :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    return parser_unary(p)
}

//# <term>  ::=  <factor> ( ('*'|'/') <factor> )*
parser_term :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    expr := parser_factor(p) or_return

    for parser_match(p, .STAR) || parser_match(p, .SLASH) {
        operator := parser_previous_token(p) or_return
        right := parser_factor(p) or_return
        expr = new_expr_bin_op(expr, operator, right)
    }

    return expr, nil
}

// <expr>  ::=  <term> ( ('+'|'-') <term> )*
parser_expression :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    expr := parser_term(p) or_return

    for parser_match(p, .PLUS) || parser_match(p, .MINUS) {
        operator := parser_previous_token(p) or_return
        right := parser_term(p) or_return
        expr = new_expr_bin_op(expr, operator, right)
    }

    return expr, err
}

parser_parse :: proc(p: ^Parser) -> (result: ^Expr, err: Parser_Error) {
    return parser_expression(p)
}