package clipboard

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Cocoa -framework UniformTypeIdentifiers

#import <Cocoa/Cocoa.h>
#include <stdlib.h>

long getChangeCount() {
    return [[NSPasteboard generalPasteboard] changeCount];
}

const char* getStringData() {
    NSString *str = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    if (str) {
        return [str UTF8String];
    }
    return "";
}

const char* getHTMLData() {
    NSData *data = [[NSPasteboard generalPasteboard] dataForType:NSPasteboardTypeHTML];
    if (data) {
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (str) {
            const char *c = [str UTF8String];
            char *copy = strdup(c);
            [str release];
            return copy;
        }
    }
    return "";
}

int hasImageData() {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSArray *types = [pb types];
    for (NSString *type in types) {
        if ([type isEqualToString:@"public.png"] || [type isEqualToString:@"public.tiff"] || [type isEqualToString:@"public.jpeg"]) {
            return 1;
        }
    }
    return 0;
}

void* getImageData(int *outLen) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSData *data = nil;
    NSArray *types = [pb types];
    for (NSString *type in types) {
        if ([type isEqualToString:@"public.png"] || [type isEqualToString:@"public.tiff"] || [type isEqualToString:@"public.jpeg"]) {
            data = [pb dataForType:type];
            break;
        }
    }
    if (data) {
        *outLen = (int)[data length];
        void *buf = malloc(*outLen);
        [data getBytes:buf length:*outLen];
        return buf;
    }
    *outLen = 0;
    return NULL;
}

const char* getFileURLData() {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSURL *url = [NSURL URLFromPasteboard:pb];
    if (url && [url isFileURL]) {
        return [[url absoluteString] UTF8String];
    }
    NSString *str = [pb stringForType:@"public.file-url"];
    if (str) {
        return [str UTF8String];
    }
    return "";
}

const char* getFrontmostApp() {
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (app) {
        return [[app bundleIdentifier] UTF8String];
    }
    return "";
}

const char* getFrontmostAppName() {
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (app) {
        return [[app localizedName] UTF8String];
    }
    return "";
}

const char* getFrontmostAppPath() {
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (app) {
        return [[[app bundleURL] path] UTF8String];
    }
    return "";
}

void writeClipboard(const char* text) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:[NSString stringWithUTF8String:text] forType:NSPasteboardTypeString];
}

void writeClipboardImage(const void* data, int len) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    NSData *nsData = [NSData dataWithBytes:data length:len];
    NSImage *image = [[NSImage alloc] initWithData:nsData];
    [pb writeObjects:@[image]];
    [image release];
}

void simulatePaste() {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
        CGEventRef cmdDown = CGEventCreateKeyboardEvent(source, 0x37, true);
        CGEventRef vDown = CGEventCreateKeyboardEvent(source, 0x09, true);
        CGEventRef vUp = CGEventCreateKeyboardEvent(source, 0x09, false);
        CGEventRef cmdUp = CGEventCreateKeyboardEvent(source, 0x37, false);
        CGEventPost(kCGSessionEventTap, cmdDown);
        CGEventPost(kCGSessionEventTap, vDown);
        CGEventPost(kCGSessionEventTap, vUp);
        CGEventPost(kCGSessionEventTap, cmdUp);
        CFRelease(cmdDown);
        CFRelease(vDown);
        CFRelease(vUp);
        CFRelease(cmdUp);
        CFRelease(source);
    });
}
*/
import "C"
import "unsafe"

func GetChangeCount() int64 {
	return int64(C.getChangeCount())
}

func GetStringData() string {
	cs := C.getStringData()
	if cs == nil {
		return ""
	}
	return C.GoString(cs)
}

func GetHTMLData() string {
	cs := C.getHTMLData()
	if cs == nil {
		return ""
	}
	defer C.free(unsafe.Pointer(cs))
	return C.GoString(cs)
}

func HasImageData() bool {
	return C.hasImageData() == 1
}

func GetImageData() []byte {
	var length C.int
	ptr := C.getImageData(&length)
	if ptr == nil || length == 0 {
		return nil
	}
	defer C.free(ptr)
	return C.GoBytes(ptr, length)
}

func GetFileURLData() string {
	cs := C.getFileURLData()
	if cs == nil {
		return ""
	}
	return C.GoString(cs)
}

func GetFrontmostApp() (bundleID, name, path string) {
	cb := C.getFrontmostApp()
	if cb != nil {
		bundleID = C.GoString(cb)
	}
	cn := C.getFrontmostAppName()
	if cn != nil {
		name = C.GoString(cn)
	}
	cp := C.getFrontmostAppPath()
	if cp != nil {
		path = C.GoString(cp)
	}
	return bundleID, name, path
}

func WriteClipboard(text string) {
	ct := C.CString(text)
	defer C.free(unsafe.Pointer(ct))
	C.writeClipboard(ct)
}

func WriteClipboardImage(data []byte) {
	if len(data) == 0 {
		return
	}
	C.writeClipboardImage(unsafe.Pointer(&data[0]), C.int(len(data)))
}

func SimulatePaste() {
	C.simulatePaste()
}
