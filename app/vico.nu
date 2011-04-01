(macro defined? (x)
	`(try
		(,x class)
		t
		(catch (exception)
			NO)))

(function log (msg)
	(NSLog (msg description)))
