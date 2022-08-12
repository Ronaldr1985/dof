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

// Returns a list of old directories, and removes old files
remove_old_files :: proc(directory: string, t: time.Time) -> (os.Errno) {
	current_working_directory : string = os.get_current_directory()
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
		current_file = fmt.tprintf("%s/%s/%s", current_working_directory, directory, fi.name)
		if diff := time.diff(fi.modification_time, t); diff > 0 {
			path = fmt.tprintf("%s/%s/%s", current_working_directory, directory, fi.name)
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

		// This need to be determined before we delete any files
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
			fmt.fprintln(os.stderr, "dof: failed with error:", LinuxError(remove_old_files_err))
			os.exit(int(remove_old_files_err))
		}

		if remove_root_directory {
			if err := os.remove_directory(folder); err == 0 {
				number_directories+=1
			} else {
				fmt.fprintln(os.stderr, "dof: failed to delete directory:", folder)
			}
		}

		fmt.println("Amount of directories deleted:", number_directories)
		fmt.println("Amount of files deleted:      ", number_files)
	} else if len(os.args) > 3 {
		fmt.fprintln(os.stderr, "Too many arguments passed to dof")
	} else {
		fmt.fprintln(os.stderr, "Not enough arguments passed to dof")
	}
}
