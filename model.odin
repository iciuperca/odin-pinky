package pinky

import "core:mem"
import "core:strings"


FORMAT_PADDING :: "  "

Expression_Id :: distinct u64

String_Type :: enum {
	STRING_TYPE_SINGLE,
	STRING_TYPE_DOUBLE,
}

Integer :: struct {
	value: int,
}

Float :: struct {
	value: f64,
}

String :: struct {
	value: string,
	type:  String_Type,
}

Bin_Op :: struct {
	left:  Expression_Id,
	op:    Token,
	right: Expression_Id,
}

Un_Op :: struct {
	op:      Token,
	operand: Expression_Id,
}

// Example: ( expr )
Grouping :: struct {
	expression: Expression_Id,
}

Expr_Variant :: union {
	Integer,
	Float,
	String,
	Un_Op,
	Bin_Op,
	Grouping,
}

Expr :: struct {
	id:      Expression_Id,
	variant: Expr_Variant,
}

Expression_Pool :: struct {
	expressions: map[Expression_Id]Expr,
	allocator:   mem.Allocator,
}

expression_get_next_id :: proc "contextless" () -> Expression_Id {
	@(static) next_id: Expression_Id

	next_id += 1

	return next_id
}

@(require_results)
new_expr_integer :: proc(expression_pool: ^Expression_Pool, value: int) -> Expression_Id {
	int_expr := Integer {
		value = value,
	}

	id := expression_get_next_id()
	expression_pool.expressions[id] = Expr {
		id      = id,
		variant = int_expr,
	}

	return id
}

@(require_results)
new_expr_float :: proc(expression_pool: ^Expression_Pool, value: f64) -> Expression_Id {
	float_expr := Float {
		value = value,
	}

	id := expression_get_next_id()
	expression_pool.expressions[id] = Expr {
		id      = id,
		variant = float_expr,
	}

	return id
}

@(require_results)
new_expr_string :: proc(expression_pool: ^Expression_Pool, value: string, type: String_Type) -> Expression_Id {
	string_expr := String {
		value = value,
		type  = type,
	}

	id := expression_get_next_id()
	expression_pool.expressions[id] = Expr {
		id      = id,
		variant = string_expr,
	}

	return id
}

@(require_results)
new_expr_un_op :: proc(expression_pool: ^Expression_Pool, op: Token, operand_id: Expression_Id) -> Expression_Id {
	un_op_expr := Un_Op {
		op      = op,
		operand = operand_id,
	}

	id := expression_get_next_id()
	expression_pool.expressions[id] = Expr {
		id      = id,
		variant = un_op_expr,
	}

	return id
}


@(require_results)
new_expr_bin_op :: proc(expression_pool: ^Expression_Pool, left_id: Expression_Id, op: Token, right_id: Expression_Id) -> Expression_Id {
	bin_op_expr := Bin_Op {
		left  = left_id,
		op    = op,
		right = right_id,
	}

	id := expression_get_next_id()
	expression_pool.expressions[id] = Expr {
		id      = id,
		variant = bin_op_expr,
	}

	return id
}


@(require_results)
new_expr_grouping :: proc(expression_pool: ^Expression_Pool, expression_id: Expression_Id) -> Expression_Id {
	grouping_expr := Grouping {
		expression = expression_id,
	}

	id := expression_get_next_id()
	expression_pool.expressions[id] = Expr {
		id      = id,
		variant = grouping_expr,
	}

	return id
}

destroy_expression_pool :: proc(expression_pool: ^Expression_Pool) {
	delete(expression_pool.expressions)
}

expression_pool_create :: proc(allocator := context.allocator) -> Expression_Pool {
	return Expression_Pool{expressions = make(map[Expression_Id]Expr, allocator), allocator = allocator}
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

expr_to_string :: proc(expression_pool: ^Expression_Pool, expression_id: Expression_Id, level: int = 0) -> string {
	builder := strings.builder_make_none(expression_pool.allocator)

	padding := strings.repeat(FORMAT_PADDING, level, expression_pool.allocator)
	defer delete(padding)

	expr := expression_pool.expressions[expression_id]

	switch e in expr.variant {
	case Integer:
		strings.write_string(&builder, "Integer{")
		strings.write_int(&builder, e.value, 10)
		strings.write_string(&builder, "}")
	case Float:
		strings.write_string(&builder, "Float{")
		strings.write_f64(&builder, e.value, 'f')
		strings.write_string(&builder, "}")
	case String:
		strings.write_string(&builder, "String{")
		strings.write_string(&builder, e.value)
		strings.write_string(&builder, "}")
	case Un_Op:
		next_level := level + 1
		strings.write_string(&builder, "Un_Op{")
		format_newline(&builder, padding)
		strings.write_string(&builder, "op: ")
		strings.write_string(&builder, e.op.lexme)
		format_newline(&builder, padding)
		strings.write_string(&builder, "operand: ")
		operand_string := expr_to_string(expression_pool, e.operand, next_level)
		defer delete(operand_string)
		strings.write_string(&builder, operand_string)
		format_end_of_block(&builder, padding)
	case Bin_Op:
		next_level := level + 1

		strings.write_string(&builder, "Bin_Op{")
		format_newline(&builder, padding)
		strings.write_string(&builder, "left: ")
		left_string := expr_to_string(expression_pool, e.left, next_level)
		defer delete(left_string)
		strings.write_string(&builder, left_string)
		format_newline(&builder, padding)
		strings.write_string(&builder, "op: ")
		strings.write_string(&builder, e.op.lexme)
		format_newline(&builder, padding)
		strings.write_string(&builder, "right: ")
		right_string := expr_to_string(expression_pool, e.right, next_level)
		defer delete(right_string)
		strings.write_string(&builder, right_string)
		format_end_of_block(&builder, padding)

	case Grouping:
		next_level := level + 1
		strings.write_string(&builder, "Grouping{")
		format_newline(&builder, padding)
		strings.write_string(&builder, "expression: ")
		expression_string := expr_to_string(expression_pool, e.expression, next_level)
		defer delete(expression_string)
		strings.write_string(&builder, expression_string)
		format_end_of_block(&builder, padding)
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
