package pinky

import "core:strings"

Interpreter :: struct {
	node_pool: Node_Pool,
}

Value :: union {
	f64,
	string,
	bool,
}

Interpret_Error_Type :: enum {
	None,
	Unsupported_Operation,
}

// value_destroy :: proc(value: ^Value) {
// 	switch v in value {
// 	case string:
// 		delete(v)
// 	case f64: // Do nothing
// 	}
// }

// value_number_to_string :: proc(a: f64, allocator := context.allocator) -> string {
// 	builder := strings.Builder{}
// 	strings.builder_init_none(&builder, allocator)

// 	strings.write_f64(&builder, a, 'f')

// 	return strings.to_string(builder)
// }

@(require_results, private)
value_plus_string_number :: proc(a: string, b: f64, allocator := context.allocator) -> string {

	builder := strings.Builder{}
	strings.builder_init_none(&builder, allocator)

	strings.write_string(&builder, a)
	strings.write_f64(&builder, b, 'f')

	return strings.to_string(builder)
}

@(require_results, private)
value_plus_number_string :: proc(a: f64, b: string, allocator := context.allocator) -> string {

	builder := strings.Builder{}
	strings.builder_init_none(&builder, allocator)

	strings.write_f64(&builder, a, 'f')
	strings.write_string(&builder, b)

	return strings.to_string(builder)
}

@(require_results, private)
value_plus_string_string :: proc(a, b: string, allocator := context.allocator) -> string {

	builder := strings.Builder{}
	strings.builder_init_none(&builder, allocator)

	strings.write_string(&builder, a)
	strings.write_string(&builder, b)

	return strings.to_string(builder)
}

@(require_results, private)
value_plus_number_number :: #force_inline proc "contextless" (a, b: f64) -> f64 {
	return a + b
}

value_do_plus :: proc {
	value_plus_string_number,
	value_plus_number_string,
	value_plus_string_string,
	value_plus_number_number,
}

@(require_results, private)
bool_to_f64 :: #force_inline proc "contextless" (a: bool) -> f64 {
	return 1.0 if a else 0.0
}

@(require_results, private)
f64_to_bool :: #force_inline proc "contextless" (a: f64) -> bool {
	return a != 0.0
}

@(require_results, private)
bool_to_string :: #force_inline proc "contextless" (a: bool) -> string {
	return "true" if a else "false"
}

@(require_results, private)
string_to_bool :: #force_inline proc "contextless" (a: string) -> bool {
	return a == ""
}

@(require_results, private)
value_plus :: proc(a, b: Value, allocator := context.allocator) -> Value {
	switch a_val in a {
	case f64:
		switch b_val in b {
		case f64:
			return value_plus_number_number(a_val, b_val)
		case string:
			return value_plus_number_string(a_val, b_val, allocator)
		case bool:
			return value_plus_number_number(a_val, bool_to_f64(b_val))
		}
	case string:
		switch b_val in b {
		case f64:
			return value_plus_string_number(a_val, b_val, allocator)
		case string:
			return value_plus_string_string(a_val, b_val, allocator)
		case bool:
			return value_plus_string_string(a_val, bool_to_string(b_val), allocator)
		}
	case bool:
		switch b_val in b {
		case f64:
			return value_plus_number_number(bool_to_f64(a_val), b_val)
		case string:
			return value_plus_string_string(bool_to_string(a_val), b_val, allocator)
		case bool:
			return bool_to_f64(a_val) + bool_to_f64(b_val)
		}
	}

	return Value{}
}

value_minus :: proc(a, b: Value) -> (val: Value) {
	#partial switch a_val in a {
	case f64:
		#partial switch b_val in b {
		case f64:
			val = a_val - b_val
		}
	}

	return val
}

value_mul :: proc(a, b: Value) -> (val: Value) {
	#partial switch a_val in a {
	case f64:
		#partial switch b_val in b {
		case f64:
			val = a_val * b_val
		}
	}

	return val
}

value_div :: proc(a, b: Value) -> (val: Value) {
	#partial switch a_val in a {
	case f64:
		#partial switch b_val in b {
		case f64:
			val = a_val / b_val
		}
	}

	return val
}

interpreter_create :: proc(node_pool: Node_Pool) -> Interpreter {
	return Interpreter{node_pool = node_pool}
}

interpreter_destroy :: proc(interpreter: ^Interpreter) {
	destroy_node_pool(&interpreter.node_pool)
}

interpreter_interpret :: proc(interpreter: Interpreter, node_id: Node_Id) -> (value: Value) {
	node := get_node(interpreter.node_pool, node_id)
	switch node_type in node.variant {
	case Expr:
		switch e in node_type {
		case Integer:
			return f64(e.value)
		case Float:
			return e.value
		case Bool:
			return e.value
		case String:
			return e.value
		case Grouping:
			return interpreter_interpret(interpreter, e.expression)
		case Bin_Op:
			left := interpreter_interpret(interpreter, e.left)
			right := interpreter_interpret(interpreter, e.right)
			if e.op.kind == .PLUS {
				return value_plus(left, right)
			} else if e.op.kind == .MINUS {
				return value_minus(left, right)
			} else if e.op.kind == .STAR {
				return value_mul(left, right)
			} else if e.op.kind == .SLASH {
				return value_div(left, right)
			}
		case Un_Op:
			un_val := interpreter_interpret(interpreter, e.operand)
			switch val in un_val {
			case f64:
				if e.op.kind == .MINUS {
					return -val
				} else if e.op.kind == .PLUS {
					return +val
				} else if e.op.kind == .NOT {
					return !f64_to_bool(val)
				}
			case string:
				if e.op.kind == .NOT {
					return !string_to_bool(val)
				}
			case bool:
				if e.op.kind == .NOT {
					return !val
				}
			}
		}

	case Stmt:
		#partial switch s in node_type {
		}
	}

	return Value{}
}
