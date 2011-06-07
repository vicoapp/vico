
#define ViSearchOptionBackwards 1

#define ViSmartPairAttributeName @"ViSmartPair"
#define ViAutoIndentAttributeName @"ViAutoIndent"
#define ViContinuationAttributeName @"ViContinuation"

#define ViFirstResponderChangedNotification @"ViFirstResponderChangedNotification"
#define ViCaretChangedNotification @"ViCaretChangedNotification"

#define ViURLContentsCachedNotification @"ViURLContentsCachedNotification"

#define ViFilterRunLoopMode @"ViFilterRunLoopMode"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

#ifdef IMIN
# undef IMIN
#endif
#define IMIN(a, b)  (((NSInteger)a) < ((NSInteger)b) ? (a) : (b))

typedef enum { ViCommandMode, ViNormalMode = ViCommandMode, ViInsertMode, ViVisualMode, ViAnyMode } ViMode;

#define ViTextStorageChangedLinesNotification @"ViTextStorageChangedLinesNotification"

