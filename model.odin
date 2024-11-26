package pinky

import "core:fmt"
import "core:strings"


FORMAT_PADDING :: "  "

String_Type :: enum {
    STRING_TYPE_SINGLE,
    STRING_TYPE_DOUBLE,
}

Integer :: struct {
    using expr: Expr,
    value:      int,
}

Float :: struct {
    using expr: Expr,
    value:      f64,
}

String :: struct {
    using expr: Expr,
    value:      string,
    type:       String_Type,
}

Bin_Op :: struct {
    using expr: Expr,
    left:       ^Expr,
    op:         Token,
    right:      ^Expr,
}

Un_Op :: struct {
    using expr: Expr,
    op:         Token,
    operand:    ^Expr,
}

// Example: ( expr )
Grouping :: struct {
    using expr: Expr,
    expression: ^Expr,
}

Expr_Variant :: union {
    ^Integer,
    ^Float,
    ^String,
    ^Un_Op,
    ^Bin_Op,
    ^Grouping,
}

// Expressions evaluate to a result x + (y * 2)
Expr :: struct {
    variant: Expr_Variant,
}

@(require_results)
new_expr_generic :: proc($T: typeid, allocator := context.allocator) -> ^T {
    expr := new(T, allocator)
    expr.variant = expr

    return expr
}

@(require_results)
new_expr_integer :: proc(value: int, allocator := context.allocator) -> ^Integer {
    expr := new(Integer, allocator)
    expr.variant = expr
    expr.value = value

    return expr
}

@(require_results)
new_expr_float :: proc(value: f64, allocator := context.allocator) -> ^Float {
    expr := new(Float, allocator)
    expr.variant = expr
    expr.value = value

    return expr
}

@(require_results)
new_expr_string :: proc(value: string, type: String_Type, allocator := context.allocator) -> ^String {
    expr := new(String, allocator)
    expr.variant = expr
    expr.value = value
    expr.type = type

    return expr
}

@(require_results)
new_expr_un_op :: proc(op: Token, operand: ^Expr, allocator := context.allocator) -> ^Un_Op {
    expr := new(Un_Op, allocator)
    expr.variant = expr
    expr.op = op
    expr.operand = operand

    return expr
}

@(require_results)
new_expr_bin_op :: proc(left: ^Expr, op: Token, right: ^Expr, allocator := context.allocator) -> ^Bin_Op {
    expr := new(Bin_Op, allocator)
    expr.variant = expr
    expr.left = left
    expr.op = op
    expr.right = right

    return expr
}

@(require_results)
new_expr_grouping :: proc(expression: ^Expr, allocator := context.allocator) -> ^Grouping {
    expr := new(Grouping, allocator)
    expr.variant = expr
    expr.expression = expression

    return expr
}

free_expr_iterative :: proc(expr: ^Expr, allocator := context.allocator) {
    stack := make([dynamic]^Expr, 0, 16, allocator)
    defer delete(stack)

    append(&stack, expr)

    for len(stack) > 0 {
        top := stack[len(stack) - 1]
        pop(&stack)
        if top == nil {
            fmt.eprint("Top is nil\n")
            continue
        }

        switch e in top.variant {
        case ^Integer, ^Float, ^String:
        // Do nothing
        case ^Un_Op:
            append(&stack, e.operand)
        case ^Bin_Op:
            append(&stack, e.left)
            append(&stack, e.right)
        case ^Grouping:
            append(&stack, e.expression)
        }

        free(top, allocator)
    }
}

While_Stmt :: struct {
    using stmt: Stmt,
    condition:  ^Expr,
    body:       ^Stmt,
}

Assigment_Stmt :: struct {
    using stmt: Stmt,
    name:       Token,
    value:      ^Expr,
}

// Statements perform an action
Stmt :: struct {
    variant: union {
        ^While_Stmt,
        ^Assigment_Stmt,
    },
}

expr_to_string :: proc(expr: ^Expr, level: int = 0, allocator := context.allocator) -> string {
    builder := strings.builder_make_none(allocator)
    //defer strings.builder_destroy(&builder)

    padding := strings.repeat(FORMAT_PADDING, level, allocator)
    defer delete(padding)

    switch e in expr.variant {
    case ^Integer:
        strings.write_string(&builder, "Integer{")
        strings.write_int(&builder, e.value, 10)
        strings.write_string(&builder, "}")
    case ^Float:
        strings.write_string(&builder, "Float{")
        strings.write_f64(&builder, e.value, 'f')
        strings.write_string(&builder, "}")
    case ^String:
        strings.write_string(&builder, "String{")
        strings.write_string(&builder, e.value)
        strings.write_string(&builder, "}")
    case ^Un_Op:
        next_level := level + 1
        strings.write_string(&builder, "Un_Op{")
        format_newline(&builder, padding)
        strings.write_string(&builder, "op: ")
        enum_string, enum_string_ok := fmt.enum_value_to_string(e.op.kind)
        if !enum_string_ok {
            strings.write_string(&builder, "Unknown")
        } else {
            strings.write_string(&builder, enum_string)
        }
        format_newline(&builder, padding)
        strings.write_string(&builder, "operand: ")
        operand_string := expr_to_string(e.operand, next_level, allocator)
        defer delete(operand_string)
        strings.write_string(&builder, operand_string)
        format_end_of_block(&builder, padding)
    case ^Bin_Op:
        next_level := level + 1

        strings.write_string(&builder, "Bin_Op{")
        format_newline(&builder, padding)
        strings.write_string(&builder, "left: ")
        left_string := expr_to_string(e.left, next_level, allocator)
        defer delete(left_string)
        strings.write_string(&builder, left_string)
        format_newline(&builder, padding)
        strings.write_string(&builder, "op: ")
        enum_string, enum_string_ok := fmt.enum_value_to_string(e.op.kind)
        if !enum_string_ok {
            strings.write_string(&builder, "Unknown")
        } else {
            strings.write_string(&builder, enum_string)
        }
        format_newline(&builder, padding)
        strings.write_string(&builder, "right: ")
        right_string := expr_to_string(e.right, next_level, allocator)
        defer delete(right_string)
        strings.write_string(&builder, right_string)
        format_end_of_block(&builder, padding)

    case ^Grouping:
        next_level := level + 1
        strings.write_string(&builder, "Grouping{")
        format_newline(&builder, padding)
        strings.write_string(&builder, "expression: ")
        expression_string := expr_to_string(e.expression, next_level, allocator)
        defer delete(expression_string)
        strings.write_string(&builder, expression_string)
        format_end_of_block(&builder, padding)
    case:
        strings.write_string(&builder, "Unknown/Last resort")
    }

    return strings.to_string(builder)
}

format_newline :: proc(builder: ^strings.Builder, padding: string) {
    strings.write_byte(builder, '\n')
    strings.write_string(builder, padding)
    strings.write_string(builder, FORMAT_PADDING)
}

format_end_of_block :: proc(builder: ^strings.Builder, padding: string) {
    strings.write_byte(builder, '\n')
    strings.write_string(builder, padding)
    strings.write_string(builder, "}")
}
