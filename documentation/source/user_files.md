# User (non-versioned) files component

Loft Deploy supports up to three directories of non-versioned files as part of the files fetch/pull operation.  This is ample to cover Drupal's concept of _public_ and _private_ directories, with one more directory to spare.

Be sure that the prod and staging directories map to the correct files path to local, e.g. prod:local_files2 maps to local:local_files2 and so on.

## Configuration

| config var | rsync exclusion file |
|----------|----------|
| local_files | files_exclude.txt |
| local_files2 | files2_exclude.txt |
| local_files3 | files3_exclude.txt |

## Excluding certain files using _files_exclude.txt_

You may set Loft Deploy to ignore certain user files by creating a file _.loft_deploy/files_exclude.txt_.  This will be used by the rsync program as an `--exclude-from` argument.  Notice that you will need to use _files2_exclude.txt_ and _files3_exclude.txt_ to target files in those other directories, if necessary.

Some highlights from the `rsync` documentation:

* Blank lines in the file and lines starting with ';' or '#' are ignored.
* If the pattern ends with a / then it will only match a directory, not a file, link, or device.
* A '*' matches any non-empty path component (it stops at slashes).
* Use '**' to match anything, including slashes.
* A '?' matches any character except a slash (/).
* A '[' introduces a character class, such as [a-z] or [[:alpha:]].

## Filenames with special chars

There appears to be a shortcoming with filenames that contain special chars.  The file sync may not work in this case.  Easiest fix is to insure filenames do not have special chars, like accents, etc.

