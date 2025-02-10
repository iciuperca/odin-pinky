package pinky

import "core:mem"
import "core:strings"


FORMAT_PADDING :: "  "

Node_Id :: distinct u64

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
	left:  Node_Id,
	op:    Token,
	right: Node_Id,
}

Un_Op :: struct {
	op:      Token,
	operand: Node_Id,
}

// Example: ( expr )
Grouping :: struct {
	expression: Node_Id,
}

Expr :: union {
	Integer,
	Float,
	String,
	Un_Op,
	Bin_Op,
	Grouping,
}

While_Stmt :: struct {
	condition: Node_Id,
	body:      Node_Id,
}

Assigment_Stmt :: struct {
	name:  Token,
	value: Node_Id,
}

If_Stmt :: struct {
	condition:   Node_Id,
	then_branch: Node_Id,
	else_branch: Node_Id,
}

For_Stmt :: struct {
	initialization: Node_Id,
	condition:      Node_Id,
	increment:      Node_Id,
	body:           Node_Id,
}

// Statements perform actions
Stmt :: union {
	While_Stmt,
	Assigment_Stmt,
	If_Stmt,
	For_Stmt,
}

Node_Variant :: union {
	Expr,
	Stmt,
}

Node :: struct {
	id:      Node_Id,
	lineno:  int,
	variant: Node_Variant,
}

Node_Pool :: struct {
	nodes:     map[Node_Id]Node,
	allocator: mem.Allocator,
}

node_get_next_id :: proc "contextless" () -> Node_Id {
	@(static) next_id: Node_Id

	next_id += 1

	return next_id
}

@(require_results)
get_node :: proc(node_pool: Node_Pool, node_id: Node_Id) -> (node: Node, node_found: bool) #optional_ok {
	return node_pool.nodes[node_id]
}

@(require_results)
new_expr_integer :: proc(node_pool: ^Node_Pool, value, lineno: int) -> Node_Id {
	int_expr := Integer {
		value = value,
	}
	expr: Expr = int_expr

	id := node_get_next_id()
	node_pool.nodes[id] = Node {
		id      = id,
		lineno  = lineno,
		variant = expr,
	}

	return id
}

@(require_results)
new_expr_float :: proc(node_pool: ^Node_Pool, value: f64, lineno: int) -> Node_Id {
	float_expr := Float {
		value = value,
	}
	expr: Expr = float_expr

	id := node_get_next_id()
	node_pool.nodes[id] = Node {
		id      = id,
		lineno  = lineno,
		variant = expr,
	}

	return id
}

@(require_results)
new_expr_string :: proc(node_pool: ^Node_Pool, value: string, type: String_Type, lineno: int) -> Node_Id {
	string_expr := String {
		value = value,
		type  = type,
	}
	expr: Expr = string_expr

	id := node_get_next_id()
	node_pool.nodes[id] = Node {
		id      = id,
		lineno  = lineno,
		variant = expr,
	}

	return id
}

@(require_results)
new_expr_un_op :: proc(node_pool: ^Node_Pool, op: Token, operand_id: Node_Id, lineno: int) -> Node_Id {
	un_op_expr := Un_Op {
		op      = op,
		operand = operand_id,
	}
	expr: Expr = un_op_expr

	id := node_get_next_id()
	node_pool.nodes[id] = Node {
		id      = id,
		variant = expr,
	}

	return id
}


@(require_results)
new_expr_bin_op :: proc(node_pool: ^Node_Pool, left_id: Node_Id, op: Token, right_id: Node_Id, lineno: int) -> Node_Id {
	bin_op_expr := Bin_Op {
		left  = left_id,
		op    = op,
		right = right_id,
	}
	expr: Expr = bin_op_expr

	id := node_get_next_id()
	node_pool.nodes[id] = Node {
		id      = id,
		variant = expr,
	}

	return id
}


@(require_results)
new_expr_grouping :: proc(node_pool: ^Node_Pool, expression_id: Node_Id, lineno: int) -> Node_Id {
	grouping_expr := Grouping {
		expression = expression_id,
	}
	expr: Expr = grouping_expr

	id := node_get_next_id()
	node_pool.nodes[id] = Node {
		id      = id,
		variant = expr,
	}

	return id
}

@(require_results)
node_pool_create :: proc(allocator := context.allocator) -> Node_Pool {
	return Node_Pool{nodes = make(map[Node_Id]Node, allocator), allocator = allocator}
}

destroy_node_pool :: proc(node_pool: ^Node_Pool) {
	delete(node_pool.nodes)
}

@(require_results)
node_to_string :: proc(node_pool: Node_Pool, node_id: Node_Id, level: int = 0) -> string {
	builder := strings.builder_make_none(node_pool.allocator)

	padding := strings.repeat(FORMAT_PADDING, level, node_pool.allocator)
	defer delete(padding)

	node := node_pool.nodes[node_id]

	switch node_type in node.variant {
	case Expr:
		switch e in node_type {
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
			operand_string := node_to_string(node_pool, e.operand, next_level)
			defer delete(operand_string)
			strings.write_string(&builder, operand_string)
			format_end_of_block(&builder, padding)
		case Bin_Op:
			next_level := level + 1

			strings.write_string(&builder, "Bin_Op{")
			format_newline(&builder, padding)
			strings.write_string(&builder, "left: ")
			left_string := node_to_string(node_pool, e.left, next_level)
			defer delete(left_string)
			strings.write_string(&builder, left_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "op: ")
			strings.write_string(&builder, e.op.lexme)
			format_newline(&builder, padding)
			strings.write_string(&builder, "right: ")
			right_string := node_to_string(node_pool, e.right, next_level)
			defer delete(right_string)
			strings.write_string(&builder, right_string)
			format_end_of_block(&builder, padding)

		case Grouping:
			next_level := level + 1
			strings.write_string(&builder, "Grouping{")
			format_newline(&builder, padding)
			strings.write_string(&builder, "expression: ")
			expression_string := node_to_string(node_pool, e.expression, next_level)
			defer delete(expression_string)
			strings.write_string(&builder, expression_string)
			format_end_of_block(&builder, padding)
		}
	case Stmt:
		switch s in node_type {
		case While_Stmt:
			next_level := level + 1
			strings.write_string(&builder, "While_Stmt{")
			format_newline(&builder, padding)
			strings.write_string(&builder, "condition: ")
			condition_string := node_to_string(node_pool, s.condition, next_level)
			defer delete(condition_string)
			strings.write_string(&builder, condition_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "body: ")
			body_string := node_to_string(node_pool, s.body, next_level)
			defer delete(body_string)
			strings.write_string(&builder, body_string)
			format_end_of_block(&builder, padding)
		case Assigment_Stmt:
			next_level := level + 1
			strings.write_string(&builder, "Assigment_Stmt{")
			format_newline(&builder, padding)
			strings.write_string(&builder, "name: ")
			strings.write_string(&builder, s.name.lexme)
			format_newline(&builder, padding)
			strings.write_string(&builder, "value: ")
			value_string := node_to_string(node_pool, s.value, next_level)
			defer delete(value_string)
			strings.write_string(&builder, value_string)
			format_end_of_block(&builder, padding)
		case If_Stmt:
			next_level := level + 1
			strings.write_string(&builder, "If_Stmt{")
			format_newline(&builder, padding)
			strings.write_string(&builder, "condition: ")
			condition_string := node_to_string(node_pool, s.condition, next_level)
			defer delete(condition_string)
			strings.write_string(&builder, condition_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "then_branch: ")
			then_branch_string := node_to_string(node_pool, s.then_branch, next_level)
			defer delete(then_branch_string)
			strings.write_string(&builder, then_branch_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "else_branch: ")
			else_branch_string := node_to_string(node_pool, s.else_branch, next_level)
			defer delete(else_branch_string)
			strings.write_string(&builder, else_branch_string)
			format_end_of_block(&builder, padding)
		case For_Stmt:
			next_level := level + 1
			strings.write_string(&builder, "For_Stmt{")
			format_newline(&builder, padding)
			strings.write_string(&builder, "initialization: ")
			initialization_string := node_to_string(node_pool, s.initialization, next_level)
			defer delete(initialization_string)
			strings.write_string(&builder, initialization_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "condition: ")
			condition_string := node_to_string(node_pool, s.condition, next_level)
			defer delete(condition_string)
			strings.write_string(&builder, condition_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "increment: ")
			increment_string := node_to_string(node_pool, s.increment, next_level)
			defer delete(increment_string)
			strings.write_string(&builder, increment_string)
			format_newline(&builder, padding)
			strings.write_string(&builder, "body: ")
			body_string := node_to_string(node_pool, s.body, next_level)
			defer delete(body_string)
			strings.write_string(&builder, body_string)
			format_end_of_block(&builder, padding)
		}
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
