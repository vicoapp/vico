#import "Nu/Nu.h"
#import "ViScope.h"

#define ViMapSetsDot		1ULL
#define ViMapNeedMotion		2ULL
#define ViMapIsMotion		4ULL
#define ViMapLineMode		8ULL
#define ViMapNeedArgument	16ULL

@interface ViMapping : NSObject
{
	NSArray *keySequence;
	NSString *keyString;
	NSString *scopeSelector;

	SEL action;
	NSUInteger flags;
	id parameter;

	BOOL recursive;
	NSString *macro;
	NuBlock *expression;
}

@property (nonatomic, readonly) NSString *scopeSelector;
@property (nonatomic, readonly) NSString *keyString;
@property (nonatomic, readonly) NSArray *keySequence;
@property (nonatomic, readonly) SEL action;
@property (nonatomic, readonly) NSUInteger flags;
@property (nonatomic, readonly) BOOL recursive;
@property (nonatomic, readonly) NSString *macro;
@property (nonatomic, readonly) NuBlock *expression;
@property (nonatomic, readonly) id parameter;

+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
			       action:(SEL)anAction
				flags:(NSUInteger)flags
			    parameter:(id)param
				scope:(NSString *)aSelector;
+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
				macro:(NSString *)aMacro
			    recursive:(BOOL)recursiveFlag
				scope:(NSString *)aSelector;
+ (ViMapping *)mappingWithKeySequence:(NSArray *)aKeySequence
			   expression:(NuBlock *)expr
				scope:(NSString *)aSelector;

- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			    action:(SEL)anAction
			     flags:(NSUInteger)flags
			 parameter:(id)param
			     scope:(NSString *)aSelector;
- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			     macro:(NSString *)aMacro
			 recursive:(BOOL)recursiveFlag
			     scope:(NSString *)aSelector;

- (ViMapping *)initWithKeySequence:(NSArray *)aKeySequence
			expression:(NuBlock *)anExpression
			     scope:(NSString *)aSelector;

- (BOOL)isAction;
- (BOOL)isMacro;
- (BOOL)isExpression;
- (BOOL)isOperator;
- (BOOL)isMotion;
- (BOOL)isLineMode;
- (BOOL)needsArgument;
- (BOOL)wantsKeys;

@end

@interface ViMap : NSObject
{
	NSString *name;
	NSMutableArray *actions;
	NSMutableSet *includes;
	ViMap *operatorMap;
	SEL defaultAction;
	BOOL acceptsCounts; /* Default is YES. Disabled for insertMap. */
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray *actions;
@property (nonatomic, readwrite, assign) ViMap *operatorMap;
@property (nonatomic, readwrite) BOOL acceptsCounts;
@property (nonatomic, readwrite) SEL defaultAction;

+ (void)clearAll;
+ (NSArray *)allMaps;
+ (ViMap *)mapWithName:(NSString *)mapName;
+ (ViMap *)insertMap;
+ (ViMap *)normalMap;
+ (ViMap *)operatorMap;
+ (ViMap *)visualMap;
+ (ViMap *)explorerMap;
+ (ViMap *)symbolMap;
+ (ViMap *)completionMap;

- (BOOL)includesMap:(ViMap *)aMap;

- (ViMapping *)lookupKeySequence:(NSArray *)keySequence
                       withScope:(ViScope *)scope
                     allowMacros:(BOOL)allowMacros
                      excessKeys:(NSArray **)excessKeys
                         timeout:(BOOL *)timeoutPtr
                           error:(NSError **)outError;

- (void)map:(NSString *)keySequence
         to:(NSString *)macro
recursively:(BOOL)recursiveFlag
      scope:(NSString *)scopeSelector;
- (void)map:(NSString *)keySequence
         to:(NSString *)macro
      scope:(NSString *)scopeSelector;
- (void)map:(NSString *)keySequence
         to:(NSString *)macro;

- (void)unmap:(NSString *)keySequence
        scope:(NSString *)scopeSelector;
- (void)unmap:(NSString *)keySequence;

- (void)map:(NSString *)keySequence toExpression:(id)expr scope:(NSString *)scopeSelector;
- (void)map:(NSString *)keySequence toExpression:(id)expr;

- (void)setKey:(NSString *)keyDescription
      toAction:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;
- (void)setKey:(NSString *)keyDescription
      toAction:(SEL)selector;

- (void)setKey:(NSString *)keyDescription
      toMotion:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;
- (void)setKey:(NSString *)keyDescription
      toMotion:(SEL)selector;

- (void)setKey:(NSString *)keyDescription
  toEditAction:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;
- (void)setKey:(NSString *)keyDescription
  toEditAction:(SEL)selector;

- (void)setKey:(NSString *)keyDescription
    toOperator:(SEL)selector
         flags:(NSUInteger)flags
     parameter:(id)param
         scope:(NSString *)scopeSelector;
- (void)setKey:(NSString *)keyDescription
    toOperator:(SEL)selector;

@end
