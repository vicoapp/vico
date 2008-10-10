#import <Cocoa/Cocoa.h>
#import </usr/include/objc/objc-class.h>
#import </usr/include/objc/Protocol.h>
#import <getopt.h>
#import <fcntl.h>
#import <stdio.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <errno.h>
#import <sys/stat.h>

/*
    gcc -Wmost -arch ppc -arch i386 -mdynamic-no-pic -dead_strip -isysroot /Developer/SDKs/MacOSX10.4u.sdk -Os "$TM_FILEPATH" -o "$TM_SUPPORT_PATH/bin/inspectClass" -framework Foundation


*/
enum {
			kClassMethods,
			kInstanceMethods
		};

void DeconstructClass(Class aClass, unsigned methodType)
{
	struct objc_class *class = aClass;
    //const char *name = class->name;
    int k;
	//struct objc_method *method;
    void *iterator = 0;
    struct objc_method_list *mlist;
    if (methodType == kClassMethods){
		aClass = aClass->isa;	// set aClass to its isa to get class methods
	}
	
    mlist = class_nextMethodList(aClass, &iterator);
    if (mlist == nil)
       // NSLog(@"%s has no methods", name);
		;
    else do
        {
            for (k = 0; k < mlist->method_count; k++)
            {				
               	printf("%s\n", [NSStringFromSelector(mlist->method_list[k].method_name) UTF8String]);
            }
        }
        while ( mlist = class_nextMethodList(aClass, &iterator) );

    if (class->super_class != nil){
		DeconstructClass(class->super_class, methodType);
    }
}


void usage ()
{
	fprintf(stderr, 
		"Usage: inspectClass -[ci] -n class_name\n"
		"-c, --classmethods 		list class methods\n"
		"-i, --instancemethods		list instance methods\n"
		"-i, --classname			name of class to inspect\n"
		"-f, --framework			name of framework to inspect\n"
		"\n"
		"");
}




int main (int argc, char* argv[])
{
	
	unsigned methodType = kInstanceMethods;
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	extern int optind;
	extern char* optarg;
	static struct option longopts[] = {	
		{ "classmethods",		no_argument,		0,		'c'	},
		{ "instancemethods",	no_argument,		0,		'i'	},
		{ "classname",			required_argument,	0,		'n'	},
		{ "framework", 			required_argument,	0,		'f'	},
		{ 0,						0,				0,		0	}
	};
	
	char const* token = NULL;
	char const* framework = NULL;
	char ch;
	
	int res = -1;
	
	while((ch = getopt_long(argc, argv, "cin:f:", longopts, NULL)) != -1)
	{
		switch(ch)
		{
			case 'c':	methodType = kClassMethods;		break;
			case 'i':	methodType = kInstanceMethods;	break;
			case 'n':	token = optarg;	res = 0;		break;
			case 'f':	framework = optarg; 			break;
			default:	usage();						break;
		}
	}
	if (framework){
		NSString *aString = [@"/System/Library/Frameworks/" 
							stringByAppendingString:
							[[NSString stringWithUTF8String:framework] stringByAppendingPathExtension:@"framework"]];
		//NSLog(@"%@", aString );
		NSBundle * b1 = [NSBundle bundleWithPath:aString];
		[b1 load];
	}
	// /System/Library/Frameworks/
    if (res == 0){
		Class aClass = NSClassFromString([NSString stringWithUTF8String:token]);
		if(aClass != nil){
			DeconstructClass(aClass, methodType);
		}
	}
	else{
		usage();
	}
	
	[pool release];
	return res;
}