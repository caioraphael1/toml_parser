#+private
package toml

/*

    This file is for testing. It should be ignored by library users.
 
    For contributors:
    I have integrated these tests:
        https://github.com/toml-lang/toml-test

    To get them please download/build release 1.5.0:
        $ go install github.com/toml-lang/toml-test/cmd/toml-test@v1.5.0 

        To do so with shell: 
            $ export $GOBIN="/tmp"
            $ go install github.com/toml-lang/toml-test/cmd/toml-test@v1.5.0
            $ odin build . 
            $ /tmp/toml-test <the built executable>

    Also, big thanks to tgolsson for suggesting this project
    and arp242 for actually making the tests!

*/

import "core:encoding/json"
import "core:fmt"
import "base:runtime"
import "core:mem"
import "core:os"
import "dates"

// import "core:testing"

exit :: os.exit

main :: proc() {

	// parse_file("testing/current.toml")

    allocator := runtime.heap_allocator()
   
	data := make([]u8, 16 * 1024 * 1024, allocator)
	count, err_read := os.read(os.stdin, data)
	assert(err_read == nil)

	table, err := parse(string(data[:count]), "<stdin>", allocator)

	if err.type != .None {
        print_error(err, allocator)
        os.exit(1)
    }

	idk, ok := marshal(table, allocator)
	if !ok do return
	json, _ := json.marshal(idk, allocator = allocator)
	logln(string(json))

	// for the valid/key/quoted-unicode test
	// for k, v in table^ {
	//     logln(k, "=", v)
	// }

	deep_delete(table, allocator)
	// delete_error(&err)

}

// @test
// memory_test :: proc(t: ^testing.T) {
//     data := `
//     [["valid/key/dotted-4.toml-20".arr]]
//     ["valid/key/dotted-4.toml-20".arr.a]
//     `
//
//     table, err := parse(string(data), "<f>")
//
//     if any_of("--print-errors", ..os.args) && err.type != .None { logln(err); print_error(err) }
//     if err.type != .None do os.exit(1)
//
//     logln(deep_delete(table))
//     delete_error(&err)
// }

// Dunno what to really call this...
TestingType :: struct {
	type:  string,
	value: union {
		map[string]HelpMePlease,
		[]HelpMePlease,
		string,
		bool,
		i64,
		f64,
	},
}

HelpMePlease :: union {
	TestingType,
	map[string]HelpMePlease,
	[]HelpMePlease,
}

marshal :: proc(input: Type, allocator: mem.Allocator) -> (result: HelpMePlease, ok: bool) {
	output: TestingType

	switch value in input {
	case nil:
		assert(false)
	case ^List:
		if value == nil do return result, false
		out := make([]HelpMePlease, len(value), allocator)
		for v, i in value {out[i] = marshal(v, allocator) or_continue}
		return out, true

	case ^Table:
		if value == nil do return result, false
		out := make(map[string]HelpMePlease, allocator)
		for k, v in value {out[k] = marshal(v, allocator) or_continue}
		return out, true

	case string:
		output = {
			type  = "string",
			value = value,
		}
	case bool:
		output = {
			type  = "bool",
			value = fmt.aprint({ value }, allocator = allocator),
		}
	case i64:
		output = {
			type  = "integer",
			value = fmt.aprint({ value }, allocator = allocator),
		}
	case f64:
		output = {
			type  = "float",
			value = fmt.aprint({ value }, allocator = allocator),
		}

	case dates.Date:
		result, err := dates.partial_date_to_string(value, 'T', allocator)
		if err != .NONE do os.exit(1) // I shouldn't do this like that...

		date := value
		if date.is_time_only {
			output.type = "time-local"
		} else if date.is_date_only {
			output.type = "date-local"
		} else if date.is_date_local {
			output.type = "datetime-local"
		} else {
			output.type = "datetime"
		}
		output.value = result
	}

	return output, true
}

