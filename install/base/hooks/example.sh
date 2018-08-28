#!/usr/bin/env bash

#
# This example is for fetch_files_post.sh.  It shows how you would remove the
# password from certain files when fetching.
#

# Define which files contain sensitive password.
declare -a  files=("$5/1~settings.local.php");

output=''

# Iterate over files and remove password.
for file in "${files[@]}"; do
    [[ "$output" ]] && echo_green "├── $output"
    test -f $file || (echo_red "File not found: $file" && exit 1)
    sed -i '' "s/^.*password.*$/'password' => '',/g" $file && output="Password removed from: ${file##*/}"
done
echo_green "└── $output"
exit 0
