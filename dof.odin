package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:unicode"

// Number of directories and files removed
number_files       : int = 0
number_directories : int = 0

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
	for fi in fil {
		os.file_info_delete(fi)
	}
	if err == 20 {
		return false, 0
	} else if err != 0 {
		return false, err
	}
	defer delete(fil)

	return true, 0
}

remove_old_files :: proc(directory: string, t: time.Time) -> (os.Errno) {
	current_file : string
	path : string

	d, derr := os.open(directory)
	if derr != 0 {
		return derr
	}
	defer os.close(d)

	fil, err := os.read_dir(d, -1)
	if err != 0 {
		return err
	}
	defer delete(fil)

	for fi in fil {
		current_file = fmt.tprintf("%s/%s", directory, fi.name)
		if diff := time.diff(fi.modification_time, t); diff > 0 {
			path = fmt.tprintf("%s/%s", directory, fi.name)
			if fi.is_dir {
				err = remove_old_files(fmt.tprintf("%s/%s", directory, fi.name), t)
				if err != 0 {
					return err
				}
				err = os.remove_directory(current_file)
				if err == 0 {
					number_directories+=1
				} else {
					fmt.fprintln(os.stderr, "Failed to remove directory:", current_file)
					return err
				}
			} else {
				err = os.remove(current_file)
				if err == 0 {
					number_files+=1
				} else {
					fmt.fprintln(os.stderr, "Failed to remove file:", current_file)
					return err
				}
			}
		}
		os.file_info_delete(fi)
	}

	return 0
}

/*
Arguments:
1. the time
2. the folder
*/
main :: proc() {
	stpwtch: time.Stopwatch
	time.stopwatch_start(&stpwtch)
	if len(os.args) == 3 {
		number := ""
		nanoseconds : f64 = 0
		duration : time.Duration = 0
		folder : string = os.args[2]
		time_argument : string = os.args[1]

		if is_dir, err := is_dir(folder); err == os.EPERM || err == os.ENOENT {
			fmt.fprintln(os.stderr, "dof: don't have permission to the folder or file, or the file or folder doesn't exist")
			os.exit(int(err))
		} else if err != 0 {
			fmt.fprintln(os.stderr, "dof: got an error, whilst checking if the file or folder exists: ", os.Errno(err))
			os.exit(-1)
		} else if !is_dir {
			fmt.println("Have a file, exiting for now...")
			os.exit(0)
		}

		for ch, index in time_argument {
			if ok := unicode.is_digit(ch); ok {
				number = fmt.tprintf("{}{}", number, strconv._digit_value(ch))
			}
			switch ch {
			case '.':
				number = fmt.tprintf("{}.", number)
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

		// This needs to be determined before we delete any files
		// otherwise we will change the modification time of the
		// directory when we are deleting files
		remove_root_directory : bool = false
		if fi, err := os.lstat(folder); err == 0 {
			if diff := time.diff(fi.modification_time, anything_modified_earlier_than_this); diff >= 0 {
				remove_root_directory = true
			}
		}

		remove_old_files_err := remove_old_files(folder, anything_modified_earlier_than_this)
		if remove_old_files_err != 0 {
			fmt.fprintln(os.stderr, "dof: failed with error:", OS_Error(remove_old_files_err))
			os.exit(int(remove_old_files_err))
		}

		if remove_root_directory {
			if err := os.remove_directory(folder); err == 0 {
				number_directories+=1
			} else {
				fmt.fprintln(os.stderr, "dof: failed to delete directory:", folder)
			}
		}

		time.stopwatch_stop(&stpwtch)
		fmt.println("Deleted directories", number_directories, "and", number_files, "files in", time.stopwatch_duration(stpwtch))
	} else if len(os.args) > 3 {
		fmt.fprintln(os.stderr, "Too many arguments passed to dof")
	} else {
		fmt.fprintln(os.stderr, "Not enough arguments passed to dof")
	}
}
