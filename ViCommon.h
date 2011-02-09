
#define ViSmartPairAttributeName @"ViSmartPair"
#define ViContinuationAttributeName @"ViContinuation"

#define ViFirstResponderChangedNotification @"ViFirstResponderChangedNotification"
#define ViCaretChangedNotification @"ViCaretChangedNotification"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

#ifdef IMIN
# undef IMIN
#endif
#define IMIN(a, b)  (((NSInteger)a) < ((NSInteger)b) ? (a) : (b))

typedef enum { ViCommandMode, ViNormalMode = ViCommandMode, ViInsertMode, ViVisualMode, ViAnyMode } ViMode;
