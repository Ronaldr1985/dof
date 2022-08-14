package main

import "core:os"

when ODIN_OS == .Linux {
	OS_Error :: enum os.Errno {
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
}
