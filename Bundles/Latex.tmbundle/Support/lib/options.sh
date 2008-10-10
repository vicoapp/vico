# parse any %!TEX options in the given file (passed as argument)
# The known options will set the OPTIONS_optname variables
# Only parse the first 20 lines to be consistent with TeXShop
parse_options () {
  OPTIONS=`head -n 20 "$1" | sed -E -e '/^%!TEX ([^ ]+) = *(.*[^ ]) *$/{s//\1=\2/p;};d'`
  old_IFS="$IFS"
  IFS=$'\n'
  for line in $OPTIONS; do
    cmd="${line%%=*}"
    val="${line#*=}"
    case "$cmd" in
      root) OPTIONS_root="$val";;
      TS-program) OPTIONS_program="$val";;
      # I have no idea what to do with the following command. It controls the
      # document encoding TeXShop uses to read/write the file, but we can't do that here
      # Still, record it because it's a known encoding
      encoding) OPTIONS_encoding="$val";;
    esac
  done
  IFS="$old_IFS"
}
