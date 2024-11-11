package pinky

import "core:bufio"
import "core:fmt"
import "core:os"
// import "core:io"
import "core:mem"

EXIT_CODE_SUCCESS :: 0
EXIT_CODE_USAGE :: 64
EXIT_CODE_DATAERR :: 65
EXIT_CODE_NOINPUT :: 66
EXIT_CODE_NOUSER :: 67
EXIT_CODE_NOHOST :: 68
EXIT_CODE_UNAVAILABLE :: 69
EXIT_CODE_SOFTWARE :: 70
EXIT_CODE_OSERR :: 71
EXIT_CODE_OSFILE :: 72
EXIT_CODE_CANTCREAT :: 73
EXIT_CODE_IOERR :: 74
EXIT_CODE_TEMPFAIL :: 75
EXIT_CODE_PROTOCOL :: 76
EXIT_CODE_NOPERM :: 77
EXIT_CODE_CONFIG :: 78

g_had_error := false

@(private = "file")
run :: proc(source: []u8, allocator := context.allocator) -> bool {
    lexer := lexer_create(source)
    defer lexer_destroy(&lexer)

    tokens := lexer_tokenize(&lexer)

    for token in tokens {
        token_string := token_to_string(token, allocator)
        defer delete(token_string)
        fmt.println(token_string)
        // fmt.println(token)
    }

    return true
}

@(private = "file")
run_file :: proc(path: string) -> bool {
    file_data, file_data_read_status := os.read_entire_file(path)
    defer delete(file_data)
    if !file_data_read_status {
        fmt.printfln("Error reading file: %v", file_data_read_status)

        os.exit(EXIT_CODE_NOINPUT)
    }

    run(file_data)

    if g_had_error {
        os.exit(EXIT_CODE_DATAERR)
    }

    return true
}

@(private = "file")
run_prompt :: proc() {
    reader: bufio.Reader
    stdin_stream := os.stream_from_handle(os.stdin)
    bufio.reader_init(&reader, stdin_stream)
    defer bufio.reader_destroy(&reader)
    for {
        fmt.print("pinky> ")
        line, read_err := bufio.reader_read_bytes(&reader, '\n')
        if read_err == .EOF {
            fmt.println()
            break
        } else if read_err != .None {
            fmt.printfln("Error reading input: %v", read_err)
            os.exit(EXIT_CODE_IOERR)
        }

        run(line)
        g_had_error = false
    }
}

@(private = "file")
_main :: proc() {
    args := os.args

    if len(args) > 2 {
        fmt.printfln("Usage: %v [script]", args[0])
        os.exit(EXIT_CODE_USAGE)
    } else if len(args) == 2 {
        run_file(args[1])
        if g_had_error {
            os.exit(EXIT_CODE_DATAERR)
        }
    } else {
        run_prompt()
    }
}

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }

            mem.tracking_allocator_destroy(&track)
        }
    }

    // fmt.set_user_formatters(new(map[typeid]fmt.User_Formatter))
    // err := fmt.register_user_formatter(type_info_of(Token).id, token_formatter)
    // assert(err == .None)

    _main()
}
