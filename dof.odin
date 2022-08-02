package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:unicode"

write_help :: proc() {
	fmt.println("Need to write a help message")
}

write_version :: proc() {
	fmt.println("dof 0.1")
	fmt.println("License BSD-2-Clause\n")
	fmt.println("Written by Ronald 1985.")
	os.exit(0)
}

is_dir :: proc(path: string) -> (bool, os.Errno) {
	d, derr := os.open(path)
	if derr != 0 {
		return false, derr
	}
	defer os.close(d)

	fil, err := os.read_dir(d, -1)
	if err == 20 {
		return false, 0
	} else if err != 0 {
		return false, err
	}
	defer delete(fil)

	return true, 0

}

get_old_files :: proc(directory: string, t: time.Time) -> ([dynamic]string, os.Errno) {
	files : [dynamic]string = nil
	relative_path : string

	d, derr := os.open(directory)
	if derr != 0 {
		return nil, derr
	}
	defer os.close(d)

	fil, err := os.read_dir(d, -1)
	if err != 0 {
		return nil, err
	}
	defer delete(fil)

	for fi in fil {
		if fi.is_dir {
			// FIXME: Determine what needs to change if we find a folder
		}
		// relative_path = fmt.tprintf("%s/%s", directory, fi.name)
		if diff := time.diff(fi.modification_time, t); diff > 0 {
			append(&files, relative_path)
		}
	}

	return files, 0
}

main :: proc() {
	folder : string = os.args[2]
	if is_dir, err := is_dir(folder); err == os.EPERM || err == os.ENOENT {
		fmt.fprintln(os.stderr, "Don't have permission to the folder or file, or the file or folder doesn't exist")
		os.exit(int(err))
	} else if err != 0 {
		fmt.fprintln(os.stderr, "Got an error, whilst checking if the file or folder exists: ", os.Errno(err))
		os.exit(-1)
	} else if is_dir {
		fmt.println("is_dir: ", is_dir)
	} else if !is_dir {
		fmt.println("Have a file, exiting for now...")
		os.exit(0)
	}
	if len(os.args) == 3 {
		/*
		Arguments:
			1. the time
			2. the folder
		*/
		time_argument : string = os.args[1]
		number : string = ""
		nanoseconds : f64 = 0
		duration : time.Duration = 0

		for ch, index in time_argument {
			if ok := unicode.is_digit(ch); ok {
				number = fmt.tprintf("{}{}", number, strconv._digit_value(ch))
				fmt.println("current number: ", number)
			}
			switch ch {
			case '.':
				number = fmt.aprintf("{}.", number)
			case 's':
				nanoseconds += strconv.atof(number)
				number = ""
			case 'm':
				nanoseconds += strconv.atof(number) * 60
				number = ""
			case 'h':
				nanoseconds += strconv.atof(number) * 60 * 60
			case 'd':
				nanoseconds += strconv.atof(number) * 60 * 60 * 24
			case:
				if ok := unicode.is_digit(ch); !ok {
					fmt.fprintf(os.stderr, "dof: invalid time interval '%c'\nTry 'dof --help' for more information.", ch)
					os.exit(1)
				}
				if len(time_argument) == index {
					nanoseconds += strconv.atof(number)
				}
			}
		}

		duration = time.Duration(nanoseconds * 1e9)
		anything_modified_earlier_than_this := time.time_add(time.now(), -duration)

		files, get_old_files_err := get_old_files(folder, anything_modified_earlier_than_this)
		if get_old_files_err != 0 {
			fmt.fprintln(os.stderr, "Failed to get old files with the following error: ", get_old_files_err)
		}
		defer delete(files)

		fmt.println("Amount of files found to be delete: ", len(files))
		for file in files {
			fmt.println("Current file to be deleted: ", file)
		}
	} else {
		fmt.fprintln(os.stderr, "Too many arguments passed to dof")
	}
}