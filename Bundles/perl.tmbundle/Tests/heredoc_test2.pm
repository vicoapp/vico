# another heredoc that breaks (rev 2556)

$Q->{foo1} ||= $DBH->prepare(<<EOQ);
pretend this is SQL
EOQ


$Q->{foo2} ||= $DBH->prepare(<<EOQ);
The next heredoc
EOQ