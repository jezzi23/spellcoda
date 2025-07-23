#!/bin/bash

OUTPUT_FILE="locale/default.lua"

TEMP_FILE=".localstrstmp"

#  L["..."] patterns in .lua files
grep -rhoP 'L\["\K[^"]+(?="\])' . --include="*.lua" | sort -u > "$TEMP_FILE"

# write the default english localization, serving as the exhaustive list of strings to be localized
{
    echo "-- GENERATED FROM .lua FILES. NOT TO BE MODIFIED"
    echo "local _, sc                    = ...;"
    echo "local L = {};"
    echo "for _, v in ipairs({"
    awk '{ print "  \"" $0 "\"," }' "$TEMP_FILE"
    echo "}) do"
    echo "  L[v] = v;"
    echo "end"
    echo "sc.localizable_strings = L"
    echo ""
} > "$OUTPUT_FILE"

rm "$TEMP_FILE"
