(macro defined? (x)
	`(try
		(,x class)
		t
		(catch (exception)
			NO)))

; JSON serializer for Nu cells
(class NuCell
	(- (id) proxyForJson is (self array)))

