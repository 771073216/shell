#!/usr/bin/env bash
num=$(wc -l < 111.txt)
for ((i = 1; i <= "$num"; i++)); do
  a[$i]=$(sed -n "$i"P < 111.txt | tr '	' '*' | bc)
done
echo "${a[*]}" | tr ' ' '+' | bc
