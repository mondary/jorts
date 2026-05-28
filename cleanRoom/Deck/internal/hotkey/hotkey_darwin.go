package hotkey

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Cocoa -framework Carbon

#include <Carbon/Carbon.h>

extern void deckHotkeyCallback();

static EventHandlerUPP deck_handler;
static EventHotKeyRef deck_hotKeyRef;

static OSStatus deckHotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    deckHotkeyCallback();
    return noErr;
}

static void deckRegisterHotkey(int keycode, int modifiers) {
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind  = kEventHotKeyPressed;

    deck_handler = NewEventHandlerUPP(deckHotKeyHandler);
    InstallApplicationEventHandler(deck_handler, 1, &eventType, NULL, NULL);

    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'deck';
    hotKeyID.id = 1;

    RegisterEventHotKey(keycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &deck_hotKeyRef);
}

static void deckUnregisterHotkey() {
    if (deck_hotKeyRef) {
        UnregisterEventHotKey(deck_hotKeyRef);
        deck_hotKeyRef = NULL;
    }
}
*/
import "C"
import "sync"

var callback func()
var mu sync.Mutex

//export deckHotkeyCallback
func deckHotkeyCallback() {
	mu.Lock()
	fn := callback
	mu.Unlock()
	if fn != nil {
		fn()
	}
}

type Hotkey struct {
	keyCode   int
	modifiers int
}

func New(keyCode, modifiers int) *Hotkey {
	return &Hotkey{keyCode: keyCode, modifiers: modifiers}
}

func (h *Hotkey) Register(fn func()) {
	mu.Lock()
	callback = fn
	mu.Unlock()
	C.deckRegisterHotkey(C.int(h.keyCode), C.int(h.modifiers))
}

func (h *Hotkey) Unregister() {
	C.deckUnregisterHotkey()
	mu.Lock()
	callback = nil
	mu.Unlock()
}

const (
	KeyP        = 0x23
	KeyCMD      = 0x0100
	KeyCMDShift = 0x0100 | 0x0200
	KeyCMDOpt   = 0x0100 | 0x0800
)
