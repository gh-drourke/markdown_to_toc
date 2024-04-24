<!--toc:start-->
```
Purpose .   .   .   .   .   .   .   .   .   .   .   .   .   .   .  13

Usage   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .  19
   Description: .   .   .   .   .   .   .   .   .   .   .   .   .  28
   Notes.   .   .   .   .   .   .   .   .   .   .   .   .   .   .  40

Example .   .   .   .   .   .   .   .   .   .   .   .   .   .   .  48
```
<!--toc:end-->

# Purpose

To prepend a Table of Contents (TOC) to a Markdown file.

Headers are the contents of any line that start with one or more '#' characters.

# Usage

```bash
    $ md_toc [file1 ...] [options]

    Options:
    -h, --help    Show help message.
```

## Description:

Generate a table of contents for Markdown files.

The script takes at least one input file as an argument. Additional files can be provided as well.

Examples:

    $ md_toc file1.md file2.md
    $ md_toc file1.md file2.md file3.md
    $ md_toc *.md

## Notes

1. Each entry in the TOC has the corresponding line number of the line at which the TOC header can be found in the cocument.

2. This makes it easy to jump to the line referenced by the Table of Contents.

3. Each time the file is processed the previous TOC is removed before prepending the new TOC.

# Example

This README.md was processed using

    $md_toc README.md
