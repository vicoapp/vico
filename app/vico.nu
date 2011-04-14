(macro defined? (x)
	`(try
		(,x class)
		t
		(catch (exception)
			NO)))

(function log (msg)
	(NSLog (msg description)))

; JSON serializer for Nu cells
(class NuCell
	(- (id) proxyForJson is (self array)))

