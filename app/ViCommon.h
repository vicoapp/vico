
#define ViSearchOptionBackwards 1

#define ViSmartPairAttributeName @"ViSmartPair"
#define ViAutoIndentAttributeName @"ViAutoIndent"
#define ViAutoNewlineAttributeName @"ViAutoNewline"
#define ViContinuationAttributeName @"ViContinuation"

#define ViDocumentLoadedNotification @"ViDocumentLoadedNotification"
#define ViDocumentAddedNotification @"ViDocumentAddedNotification"
#define ViDocumentRemovedNotification @"ViDocumentRemovedNotification"
#define ViFirstResponderChangedNotification @"ViFirstResponderChangedNotification"
#define ViCaretChangedNotification @"ViCaretChangedNotification"
#define ViDocumentEditedChangedNotification @"ViDocumentEditedChangedNotification "
#define ViURLContentsCachedNotification @"ViURLContentsCachedNotification"
#define ViTextStorageChangedLinesNotification @"ViTextStorageChangedLinesNotification"
#define ViEditPreferenceChangedNotification @"ViEditPreferenceChangedNotification"

#ifdef TRIAL_VERSION
# define ViTrialDaysChangedNotification @"ViMetaChangedNotification"
#endif

#define ViFilterRunLoopMode @"ViFilterRunLoopMode"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

#ifdef IMIN
# undef IMIN
#endif
#define IMIN(a, b)  (((NSInteger)a) < ((NSInteger)b) ? (a) : (b))

typedef enum { ViNormalMode = 1, ViInsertMode = 2, ViVisualMode = 4, ViAnyMode = 0xFF } ViMode;

