# Here-doc which currently breaks (Revision: 1416)
# submitted by Michael Irwin
$sql .= <<SQL if ( $type eq 'cnd' or $type eq 'mul' );
LEFT JOIN features AS d6 ON a.Style = d6.UID
SQL
