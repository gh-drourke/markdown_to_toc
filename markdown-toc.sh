#!/usr/bin/env bash
#
# code blocks starting/ending with ``` are excluded from formatting

# Global variables
SRC_FILE_ORIGINAL=${1:?No file was specified as first argument}
SRC_FILE_CLEAN="$(mktemp)"
TOC_FILE="$(mktemp)"
# TOC_LINE_COUNT=0
INDENT_SPACING=''
declare -a LINE_NO_ARY # array to hold line numbers of header in source file
declare -a TOC_ARY     # array to hold "#" headers

# Functions

sum() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: sum <number> <number>"
        exit
        # return 1
    fi
    echo $(($1 + $2))
}

repeat_str() {
    local count=$1
    local str=$2
    for ((i = 0; i < count; i++)); do
        echo -n "${str}"
    done
}

# Given a str $2, echo it count $1 times to global var: indent_spacing
set_indent_spacing() {
    local count=$1
    local str=$2
    INDENT_SPACING=$(repeat_str "$count" "$str")
}

# Count lines in given file
count_lines() {
    local SRC=$1
    local lines
    if [ -f "$SRC" ]; then
        lines=$(wc -l <"$SRC")
        echo "$lines"
    else
        echo 0
    fi
}

count_top_level_headers() {
    # Check if at least one parameter is provided
    # A top level header starts with '# '

    if [ "$#" -lt 1 ]; then
        echo "Usage: count_lines_with_pattern <array>"
        return 1
    fi

    # Extract the array from the parameters
    lines=("$@") # Directly using "$@" to get all array elements

    # Counter for lines starting with '# '
    counter=0

    # Loop through the array and count lines starting with '# '
    for line in "${lines[@]}"; do
        if [[ $line == "# "* ]]; then
            ((counter++))
        fi
    done

    # Return the counter
    echo "$counter"
}

extend_string_with() {
    original_string="$1"
    max_length="$2"
    repeat_pattern="$3"
    local result
    local len

    result=$original_string
    while [ ${#result} -lt "$max_length" ]; do
        len=${#result}
        if [ $((len % 2)) -eq 0 ]; then
            result+=$repeat_pattern
        else
            result+=' '
        fi
    done
    echo "$result"
}

# add_number_to_array() {
#     # Check if at least two parameters are provided
#     if [ "$#" -lt 2 ]; then
#         echo "Usage: add_number_to_array <array> <number>"
#         return 1
#     fi
#
#     # Extract array and number from parameters
#     array=("${!1}") # Using indirect reference to get the array
#     number="$2"
#
#     # Loop through the array and add the number to each element
#     for ((i = 0; i < ${#array[@]}; i++)); do
#         ((array[i] += number))
#     done
# }

# adjust_TOC_line_references() {
#     # count TOC lines to establlish a relative reference to lines following TOC
#     TOC_LINE_COUNT=$(count_lines "$TOC_FILE")
#     echo "TOC line count: $TOC_LINE_COUNT"
#     add_number_to_array TOC "$TOC_LINE_COUNT"
# }

# Remove current toc from file by reading whole file and echoing lines that are not toc
clean_file_of_toc() {
    local SRC=$1    # source file with TOC
    local DST=$2    # destination file cleaned of TOC
    local toc_block # 0=not-in block, 1=in block

    toc_block=0 # Initialize to "not-in block
    while IFS= read -r line; do
        # Handle table of contents - skip over if in previous toc-block
        if [[ "${line}" =~ "!--toc:start-->" ]]; then
            toc_block=1
            continue
        fi

        if [[ "${line}" =~ "!--toc:end-->" ]]; then
            toc_block=0
            continue
        fi

        if [[ $toc_block == 1 ]]; then
            continue # skip line
        elif
            [[ $toc_block == 0 ]]
        then
            echo "${line}" >>"$DST" # copy line to destination file.
            continue
        fi
    done <"$SRC"
}

# Build table of contents from source to $TOC_ARY
# THE $TOC_ARY consiste of lines of headers
# No return results. Side effect - builds TOC_ARY
build_toc_array() {
    local SRC=$1
    local heading_regx='^\#{1,}\ .*$'
    local code_block_regx='^```'
    local code_block_status=0
    #                       0 = not in code block
    #                       1 = in code block
    #                       2 = reached end of code block

    local src_line_no=0 # the line number of the header in the orginal source file

    while IFS= read -r line; do
        ((src_line_no++))

        # Handle code blocks
        if [[ "${line}" =~ $code_block_regx ]]; then
            echo "Begin code block"
            # Ignore lines until we see code block ending
            code_block_status=$((code_block_status + 1))
            if [[ "${code_block_status}" -eq 2 ]]; then # We hit the closing code block
                echo "End code block"
                code_block_status=0
            fi
            continue
        fi

        # Handle normal line
        if [[ "${code_block_status}" == 0 ]]; then
            # If we have a heading, we save it to $TOC map
            if [[ "${line}" =~ ${heading_regx} ]]; then
                TOC_ARY+=("${line}")
                LINE_NO_ARY+=("${src_line_no}")
                # echo "header line num: $src_line_no"
            fi
        fi

    done <"$SRC"
    # echo "TOC_ARY build with size:  ${#TOC_ARY[@]}"
}

# Build toc file from previously populated TOC array
# No return results
# Side effects: populate OUT_FILE
build_toc_file() {
    local OUT_FILE=$1
    local factor=3
    local CHR=" "
    local new_line
    local line_idx=0        # index of line in $TOC
    local line_value        # value at $TOC indexed by 'line_idx'
    local extra_toc_lines=4 # lines written to toc_file in addition to '#' lines
    #               one more line will be added for each main '# ' header line

    echo "=build_toc_file()"
    local TOC_size=${#TOC_ARY[@]}
    echo ".. TOC_size: $TOC_size"
    local TOC_MAIN_HEADERS_COUNT
    TOC_MAIN_HEADERS_COUNT=$(count_top_level_headers "${TOC_ARY[@]}")

    echo ".. Base:  TOC extra lines: $extra_toc_lines"
    echo ".. Add:   TOC main header count: $TOC_MAIN_HEADERS_COUNT"
    extra_toc_lines=$(sum "$extra_toc_lines" "$TOC_MAIN_HEADERS_COUNT")
    echo ".. Total: TOC extra lines: $extra_toc_lines"
    TOC_size=$(sum "$TOC_size" "$extra_toc_lines")
    echo ".. size of TOC: $TOC_size"

    echo -e "<!--toc:start-->" >>"$OUT_FILE"
    echo -e "\`\`\`" >>"$OUT_FILE" # to protect TOC against reformatting
    # echo -e "## Table of Contents\n"

    for line in "${TOC_ARY[@]}"; do
        ((line_idx++))
        line_value=${LINE_NO_ARY[$line_idx - 1]}
        line_value=$(sum "$line_value" "$TOC_size")

        case "${line}" in
        '#######'*) set_indent_spacing $((factor * 6)) "$CHR" ;;
        '######'*) set_indent_spacing $((factor * 5)) "$CHR" ;;
        '#####'*) set_indent_spacing $((factor * 4)) "$CHR" ;;
        '####'*) set_indent_spacing $((factor * 3)) "$CHR" ;;
        '###'*) set_indent_spacing $((factor * 2)) "$CHR" ;;
        '##'*) set_indent_spacing $((factor * 1)) "$CHR" ;;
        # '#'*) set_indent_spacing $((factor * 0)) "$CHR" ;;
        '#'*)
            if [ "$line_idx" -ne 1 ]; then
                echo >>"$OUT_FILE" # echo extra separator line for top-level headers
            fi
            set_indent_spacing $((factor * 0)) "$CHR"
            ;;
        esac
        # Format output line: filter out leading "#"s
        line=$(echo "$line" | sed 's/^#*//')
        line=$INDENT_SPACING$line

        # Format output line: remove blank character between last "#" and first character
        new_line="${line:1}"
        new_line=$(extend_string_with "$new_line" 65 ".")
        # Format output line: complete line by adding line reference
        printf "%-65s  %-d\n" "$new_line" "$line_value" >>"$OUT_FILE"
    done

    echo -e "\`\`\`" >>"$OUT_FILE"
    echo -e "<!--toc:end-->\n" >>"$OUT_FILE"
}

# == Main Script ==
#
# 1. Remove toc from orginal source file -> 'clean file'
# 2. Using 'clean file' as source, build a toc -> 'toc_file'
# 3. Extend 'toc_file' by concatenating 'clean file'
# 4. Write final version of 'toc-file' to original source file (replace contents)
#
main() {
    # remove TOC from current file
    clean_file_of_toc "$SRC_FILE_ORIGINAL" "$SRC_FILE_CLEAN"

    # remove leading blank lines from $CLEAN_FILE
    sed -i '/./,$!d' "$SRC_FILE_CLEAN"

    # build new TOC_ARY from $CLEAN_FILE
    build_toc_array "$SRC_FILE_CLEAN"

    # build TOC_FILE from $TOC_ARY
    build_toc_file "$TOC_FILE" ''

    # TOC_FILE is the final production
    cat "$SRC_FILE_CLEAN" >>"$TOC_FILE"

    # rewrite final production back to orginal source file.
    cat "$TOC_FILE" >"$SRC_FILE_ORIGINAL"
}

main
