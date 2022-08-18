# dof

**dof** is a command line application that Deletes Old Files.

## Usage

To use dof you must pass it a folder and a time duration.

````
dof 10s Downloads
````
The above example will delete any files that are older than 10 seconds in the "Downloads" folder, including the "Downloads" folder if it's modification time is also older than 10 seconds ago and there are no other files in the directory.
