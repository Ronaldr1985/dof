package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:unicode"

LinuxError :: enum os.Errno { //constants copied from os
	ERROR_NONE     = 0,
	EPERM          = 1,
	ENOENT         = 2,
	ESRCH          = 3,
	EINTR          = 4,
	EIO            = 5,
	ENXIO          = 6,
	EBADF          = 9,
	EAGAIN         = 11,
	ENOMEM         = 12,
	EACCES         = 13,
	EFAULT         = 14,
	EEXIST         = 17,
	ENODEV         = 19,
	ENOTDIR        = 20,
	EISDIR         = 21,
	EINVAL         = 22,
	ENFILE         = 23,
	EMFILE         = 24,
	ETXTBSY        = 26,
	EFBIG          = 27,
	ENOSPC         = 28,
	ESPIPE         = 29,
	EROFS          = 30,
	EPIPE          = 32,
	ERANGE         = 34, /* Result too large */
	EDEADLK        = 35, /* Resource deadlock would occur */
	ENAMETOOLONG   = 36, /* File name too long */
	ENOLCK         = 37, /* No record locks available */
	ENOSYS         = 38, /* Invalid system call number */
	ENOTEMPTY      = 39, /* Directory not empty */
	ELOOP          = 40, /* Too many symbolic links encountered */
}

old_file :: struct {
	path: string,
	type: string,
}

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

get_old_files :: proc(directory: string, t: time.Time, old_files: ^[dynamic]old_file) -> (os.Errno) {
	current_directory : string = os.get_current_directory()
	current_file : old_file
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
		if diff := time.diff(fi.modification_time, t); diff > 0 {
			path = fmt.tprintf("%s/%s/%s", current_directory, directory, fi.name)
			current_file.path = path
			if fi.is_dir {
				current_file.type = "directory"
				append(old_files, current_file)
				err = get_old_files(fmt.tprintf("%s/%s", directory, fi.name), t, old_files)
				if err != 0 {
					return err
				}
			} else {
				current_file.type = "file"
			}
			append(old_files, current_file)
		}
		current_file.path = ""
	}

	return 0
}

main :: proc() {
	/*
	Arguments:
		1. the time
		2. the folder
	*/
	if len(os.args) == 3 {
		number : string = ""
		nanoseconds : f64 = 0
		duration : time.Duration = 0
		folder : string = os.args[2]
		time_argument : string = os.args[1]

		if is_dir, err := is_dir(folder); err == os.EPERM || err == os.ENOENT {
			fmt.fprintln(os.stderr, "Don't have permission to the folder or file, or the file or folder doesn't exist")
			os.exit(int(err))
		} else if err != 0 {
			fmt.fprintln(os.stderr, "Got an error, whilst checking if the file or folder exists: ", os.Errno(err))
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

		old_files : [dynamic]old_file
		get_old_files_err := get_old_files(folder, anything_modified_earlier_than_this, &old_files)
		if get_old_files_err != 0 {
			fmt.fprintln(os.stderr, "Failed to get old files with the following error: ", LinuxError(get_old_files_err))
			// os.exit(-1)
		}
		defer delete(old_files)

		fmt.println("Amount of files found to be delete: ", len(old_files))

		err: os.Errno
		for old_file in old_files {
			if old_file.type == "file" {
				err = os.remove(old_file.path)
			} else if old_file.type == "directory" {
				err = os.remove_directory(old_file.path)
			}
			if err != 0 {
				fmt.fprintln(os.stderr, "Failed to delete", old_file.path, "with the error code", LinuxError(err))
			} else {
				fmt.printf("removed %s '%s'\n", old_file.type, old_file.path)
			}
		}
	} else if len(os.args) > 3 {
		fmt.fprintln(os.stderr, "Too many arguments passed to dof")
	} else {
		fmt.fprintln(os.stderr, "Not enough arguments passed to dof")
	}
}
