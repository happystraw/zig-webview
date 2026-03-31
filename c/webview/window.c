#include "window.h"

/// Window state control functions

#ifdef _WIN32

#include <windows.h> /* _WIN32 */
#include <stdlib.h>

typedef struct webview_win32_fullscreen_state {
    WINDOWPLACEMENT placement;
    DWORD style;
    DWORD ex_style;
} webview_win32_fullscreen_state_t;

static const char *WEBVIEW_WIN32_FULLSCREEN_STATE_PROP = "webview_fullscreen_state";

static webview_win32_fullscreen_state_t *webview_win32_get_fullscreen_state(HWND hwnd)
{
    return (webview_win32_fullscreen_state_t *)GetPropA(
        hwnd, WEBVIEW_WIN32_FULLSCREEN_STATE_PROP);
}

static void webview_win32_clear_fullscreen_state(HWND hwnd)
{
    webview_win32_fullscreen_state_t *state =
        (webview_win32_fullscreen_state_t *)RemovePropA(
            hwnd, WEBVIEW_WIN32_FULLSCREEN_STATE_PROP);
    if (state) {
        free(state);
    }
}

#elif defined(__APPLE__)

#include <objc/objc.h>
#include <objc/runtime.h>
#include <objc/message.h>

// For BOOL type
#ifndef BOOL
#define BOOL signed char
#endif

#ifndef YES
#define YES (BOOL)1
#endif

#ifndef NO
#define NO (BOOL)0
#endif

// For NSUInteger type
#ifndef NSUInteger
#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
typedef unsigned long NSUInteger;
#else
typedef unsigned int NSUInteger;
#endif /* __LP64__ */
#endif

// For NSInteger type
#ifndef NSInteger
#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
typedef long NSInteger;
#else
typedef int NSInteger;
#endif

#endif /* __APPLE__ */

#elif defined(__linux__)

#include <gtk/gtk.h>

#if GTK_MAJOR_VERSION >= 4
#define GTK_WINDOW_MINIMIZE(w) gtk_window_minimize(w)
#define GTK_WINDOW_UNMINIMIZE(w) gtk_window_unminimize(w)
#define GTK_GET_SURFACE(widget) gtk_native_get_surface(gtk_widget_get_native(GTK_WIDGET(widget)))
#define GTK_SURFACE_STATE(surface) gdk_toplevel_get_state(GDK_TOPLEVEL(surface))
#else
#define GTK_WINDOW_MINIMIZE(w) gtk_window_iconify(w)
#define GTK_WINDOW_UNMINIMIZE(w) gtk_window_deiconify(w)
#define GTK_GET_SURFACE(widget) gtk_widget_get_window(GTK_WIDGET(widget))
#define GTK_SURFACE_STATE(surface) gdk_window_get_state(surface)
#endif

#endif /* __LINUX__ */

// Window state control functions
WEBVIEW_API webview_error_t webview_window_maximize(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;
    ShowWindow(hwnd, SW_MAXIMIZE);
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    // Get NSWindow class and zoom: method
    id window = (id)nswindow;
    SEL zoom_sel = sel_registerName("zoom:");
    SEL isZoomed_sel = sel_registerName("isZoomed");

    if (class_respondsToSelector(object_getClass(window), zoom_sel) &&
        class_respondsToSelector(object_getClass(window), isZoomed_sel)) {

        // Only maximize if not already maximized
        BOOL isZoomed = ((BOOL(*)(id, SEL))objc_msgSend)(window, isZoomed_sel);
        if (!isZoomed) {
            ((void(*)(id, SEL, id))objc_msgSend)(window, zoom_sel, window);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    gtk_window_maximize(GTK_WINDOW(gtkwindow));
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_minimize(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;
    ShowWindow(hwnd, SW_MINIMIZE);
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL miniaturize_sel = sel_registerName("miniaturize:");
    if (class_respondsToSelector(object_getClass(window), miniaturize_sel)) {
        ((void(*)(id, SEL, id))objc_msgSend)(window, miniaturize_sel, window);
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    GTK_WINDOW_MINIMIZE(GTK_WINDOW(gtkwindow));
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_unmaximize(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    WINDOWPLACEMENT wp = { sizeof(wp) };
    if (GetWindowPlacement(hwnd, &wp) && wp.showCmd == SW_MAXIMIZE) {
        ShowWindow(hwnd, SW_RESTORE);
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL isZoomed_sel = sel_registerName("isZoomed");
    SEL zoom_sel = sel_registerName("zoom:");

    if (class_respondsToSelector(object_getClass(window), isZoomed_sel) &&
        class_respondsToSelector(object_getClass(window), zoom_sel)) {

        // Check if maximized (zoomed), then unmaximize
        BOOL isZoomed = ((BOOL(*)(id, SEL))objc_msgSend)(window, isZoomed_sel);
        if (isZoomed) {
            ((void(*)(id, SEL, id))objc_msgSend)(window, zoom_sel, window);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    gtk_window_unmaximize(GTK_WINDOW(gtkwindow));
    return WEBVIEW_ERROR_OK;
#endif
}

WEBVIEW_API webview_error_t webview_window_unminimize(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    WINDOWPLACEMENT wp = { sizeof(wp) };
    if (GetWindowPlacement(hwnd, &wp) &&
        (wp.showCmd == SW_MINIMIZE || wp.showCmd == SW_SHOWMINIMIZED)) {
        ShowWindow(hwnd, SW_RESTORE);
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL deminiaturize_sel = sel_registerName("deminiaturize:");
    SEL isMiniaturized_sel = sel_registerName("isMiniaturized");

    if (class_respondsToSelector(object_getClass(window), deminiaturize_sel) &&
        class_respondsToSelector(object_getClass(window), isMiniaturized_sel)) {

        // Check if minimized, then unminimize
        BOOL isMiniaturized = ((BOOL(*)(id, SEL))objc_msgSend)(window, isMiniaturized_sel);
        if (isMiniaturized) {
            ((void(*)(id, SEL, id))objc_msgSend)(window, deminiaturize_sel, window);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    GtkWindow *win = GTK_WINDOW(gtkwindow);
    GTK_WINDOW_UNMINIMIZE(win);
    gtk_window_present(win);
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_fullscreen(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    DWORD style = GetWindowLong(hwnd, GWL_STYLE);
    DWORD ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);

    if (style & WS_OVERLAPPEDWINDOW) {
        webview_win32_fullscreen_state_t *state =
            webview_win32_get_fullscreen_state(hwnd);
        if (!state) {
            state = (webview_win32_fullscreen_state_t *)malloc(sizeof(*state));
            if (!state) return WEBVIEW_ERROR_UNSPECIFIED;

            state->placement.length = sizeof(state->placement);
            if (!GetWindowPlacement(hwnd, &state->placement)) {
                free(state);
                return WEBVIEW_ERROR_INVALID_STATE;
            }

            state->style = style;
            state->ex_style = ex_style;

            if (!SetPropA(hwnd, WEBVIEW_WIN32_FULLSCREEN_STATE_PROP, (HANDLE)state)) {
                free(state);
                return WEBVIEW_ERROR_UNSPECIFIED;
            }
        }

        // Enter fullscreen
        SetWindowLong(hwnd, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
        SetWindowLong(hwnd, GWL_EXSTYLE, ex_style & ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));

        MONITORINFO mi = { sizeof(mi) };
        if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi)) {
            SetWindowPos(hwnd, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top,
                        mi.rcMonitor.right - mi.rcMonitor.left,
                        mi.rcMonitor.bottom - mi.rcMonitor.top,
                        SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL toggleFullScreen_sel = sel_registerName("toggleFullScreen:");
    SEL styleMask_sel = sel_registerName("styleMask");

    if (class_respondsToSelector(object_getClass(window), toggleFullScreen_sel) &&
        class_respondsToSelector(object_getClass(window), styleMask_sel)) {

        // Check if already in fullscreen mode
        // NSWindowStyleMaskFullScreen = 1 << 14 = 16384
        NSUInteger styleMask = ((NSUInteger(*)(id, SEL))objc_msgSend)(window, styleMask_sel);
        BOOL isFullScreen = ((styleMask & (1 << 14)) != 0) ? YES : NO;

        // Only enter fullscreen if not already in fullscreen
        if (!isFullScreen) {
            ((void(*)(id, SEL, id))objc_msgSend)(window, toggleFullScreen_sel, window);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    gtk_window_fullscreen(GTK_WINDOW(gtkwindow));
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_unfullscreen(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    DWORD style = GetWindowLong(hwnd, GWL_STYLE);
    if (!(style & WS_OVERLAPPEDWINDOW)) {
        webview_win32_fullscreen_state_t *state =
            webview_win32_get_fullscreen_state(hwnd);

        if (state) {
            SetWindowLong(hwnd, GWL_STYLE, state->style);
            SetWindowLong(hwnd, GWL_EXSTYLE, state->ex_style);
            SetWindowPlacement(hwnd, &state->placement);
            SetWindowPos(hwnd, NULL, 0, 0, 0, 0,
                        SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                            SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            webview_win32_clear_fullscreen_state(hwnd);
        } else {
            SetWindowLong(hwnd, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
            SetWindowPos(hwnd, NULL, 0, 0, 0, 0,
                        SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                            SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            ShowWindow(hwnd, SW_RESTORE);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL toggleFullScreen_sel = sel_registerName("toggleFullScreen:");
    SEL styleMask_sel = sel_registerName("styleMask");

    if (class_respondsToSelector(object_getClass(window), toggleFullScreen_sel) &&
        class_respondsToSelector(object_getClass(window), styleMask_sel)) {

        // Check if currently in fullscreen mode
        // NSWindowStyleMaskFullScreen = 1 << 14 = 16384
        NSUInteger styleMask = ((NSUInteger(*)(id, SEL))objc_msgSend)(window, styleMask_sel);
        BOOL isFullScreen = ((styleMask & (1 << 14)) != 0) ? YES : NO;

        // Only exit fullscreen if currently in fullscreen
        if (isFullScreen) {
            ((void(*)(id, SEL, id))objc_msgSend)(window, toggleFullScreen_sel, window);
        }
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    gtk_window_unfullscreen(GTK_WINDOW(gtkwindow));
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_hide(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;
    ShowWindow(hwnd, SW_HIDE);
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    // Hide the application (including dock icon)
    // Get shared NSApplication instance
    Class nsAppClass = objc_getClass("NSApplication");
    SEL sharedApp_sel = sel_registerName("sharedApplication");
    id nsApp = ((id(*)(Class, SEL))objc_msgSend)(nsAppClass, sharedApp_sel);
    if (nsApp) {
        // Set activation policy to Accessory to hide dock icon
        // NSApplicationActivationPolicyAccessory = 1
        SEL setActivationPolicy_sel = sel_registerName("setActivationPolicy:");
        if (class_respondsToSelector(object_getClass(nsApp), setActivationPolicy_sel)) {
            ((BOOL(*)(id, SEL, NSInteger))objc_msgSend)(nsApp, setActivationPolicy_sel, 1);
        }

        // Also hide the application
        SEL hide_sel = sel_registerName("hide:");
        if (class_respondsToSelector(object_getClass(nsApp), hide_sel)) {
            // Hide the application - pass nil as sender
            ((void(*)(id, SEL, id))objc_msgSend)(nsApp, hide_sel, nil);
        }
        return WEBVIEW_ERROR_OK;
    }

    // Fallback to just hiding the window
    id window = (id)nswindow;
    SEL orderOut_sel = sel_registerName("orderOut:");
    if (class_respondsToSelector(object_getClass(window), orderOut_sel)) {
        ((void(*)(id, SEL, id))objc_msgSend)(window, orderOut_sel, window);
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    if (gtk_widget_get_visible(GTK_WIDGET(gtkwindow))) {
#if GTK_MAJOR_VERSION >= 4
        gtk_widget_set_visible(GTK_WIDGET(gtkwindow), FALSE);
#else
        gtk_widget_hide(GTK_WIDGET(gtkwindow));
#endif
    }
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_show(webview_t w)
{
    if (!w) return WEBVIEW_ERROR_INVALID_STATE;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;
    ShowWindow(hwnd, SW_SHOW);
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    // Show the application (including dock icon) and bring window to front
    // Get shared NSApplication instance
    Class nsAppClass = objc_getClass("NSApplication");
    SEL sharedApp_sel = sel_registerName("sharedApplication");
    id nsApp = ((id(*)(Class, SEL))objc_msgSend)(nsAppClass, sharedApp_sel);
    if (nsApp) {
        // Set activation policy back to Regular to show dock icon
        // NSApplicationActivationPolicyRegular = 0
        SEL setActivationPolicy_sel = sel_registerName("setActivationPolicy:");
        if (class_respondsToSelector(object_getClass(nsApp), setActivationPolicy_sel)) {
            ((BOOL(*)(id, SEL, NSInteger))objc_msgSend)(nsApp, setActivationPolicy_sel, 0);
        }

        // Unhide the application first
        SEL unhide_sel = sel_registerName("unhide:");
        if (class_respondsToSelector(object_getClass(nsApp), unhide_sel)) {
            ((void(*)(id, SEL, id))objc_msgSend)(nsApp, unhide_sel, nil);
        }

        // Activate the application to bring it to front
        SEL activateIgnoringOtherApps_sel = sel_registerName("activateIgnoringOtherApps:");
        if (class_respondsToSelector(object_getClass(nsApp), activateIgnoringOtherApps_sel)) {
            ((void(*)(id, SEL, BOOL))objc_msgSend)(nsApp, activateIgnoringOtherApps_sel, YES);
        }
    }

    // Show and focus the window
    id window = (id)nswindow;
    SEL makeKeyAndOrderFront_sel = sel_registerName("makeKeyAndOrderFront:");
    if (class_respondsToSelector(object_getClass(window), makeKeyAndOrderFront_sel)) {
        ((void(*)(id, SEL, id))objc_msgSend)(window, makeKeyAndOrderFront_sel, window);
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;
    if (!gtk_widget_get_visible(GTK_WIDGET(gtkwindow))) {
#if GTK_MAJOR_VERSION >= 4
        gtk_widget_set_visible(GTK_WIDGET(gtkwindow), TRUE);
#else
        gtk_widget_show(GTK_WIDGET(gtkwindow));
#endif
    }
    gtk_window_present(GTK_WINDOW(gtkwindow));
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

// Window state query functions
WEBVIEW_API webview_error_t webview_window_is_fullscreen(webview_t w, int *result)
{
    if (!w || !result) return WEBVIEW_ERROR_INVALID_ARGUMENT;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    DWORD style = GetWindowLong(hwnd, GWL_STYLE);
    *result = (style & WS_OVERLAPPEDWINDOW) ? 0 : 1;
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL styleMask_sel = sel_registerName("styleMask");
    if (class_respondsToSelector(object_getClass(window), styleMask_sel)) {
        // NSWindowStyleMaskFullScreen = 1 << 14 = 16384
        NSUInteger styleMask = ((NSUInteger(*)(id, SEL))objc_msgSend)(window, styleMask_sel);
        *result = ((styleMask & (1 << 14)) != 0) ? 1 : 0;
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;

#if GTK_MAJOR_VERSION >= 4
    GdkSurface *surface = GTK_GET_SURFACE(gtkwindow);
    if (surface) {
        GdkToplevelState state = GTK_SURFACE_STATE(surface);
        *result = (state & GDK_TOPLEVEL_STATE_FULLSCREEN) ? 1 : 0;
    } else {
        *result = 0;
    }
#else
    GdkWindow *gdkwindow = GTK_GET_SURFACE(gtkwindow);
    if (gdkwindow) {
        GdkWindowState state = GTK_SURFACE_STATE(gdkwindow);
        *result = (state & GDK_WINDOW_STATE_FULLSCREEN) ? 1 : 0;
    } else {
        *result = 0;
    }
#endif
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_is_maximized(webview_t w, int *result) {
    if (!w || !result) return WEBVIEW_ERROR_INVALID_ARGUMENT;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    WINDOWPLACEMENT wp = { sizeof(wp) };
    if (GetWindowPlacement(hwnd, &wp)) {
        *result = (wp.showCmd == SW_MAXIMIZE) ? 1 : 0;
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL isZoomed_sel = sel_registerName("isZoomed");
    if (class_respondsToSelector(object_getClass(window), isZoomed_sel)) {
        BOOL isZoomed = ((BOOL(*)(id, SEL))objc_msgSend)(window, isZoomed_sel);
        *result = isZoomed ? 1 : 0;
        return WEBVIEW_ERROR_OK;
    }
    return WEBVIEW_ERROR_INVALID_STATE;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;

#if GTK_MAJOR_VERSION >= 4
    GdkSurface *surface = GTK_GET_SURFACE(gtkwindow);
    if (surface) {
        GdkToplevelState state = GTK_SURFACE_STATE(surface);
        *result = (state & GDK_TOPLEVEL_STATE_MAXIMIZED) ? 1 : 0;
    } else {
        *result = 0;
    }
#else
    GdkWindow *gdkwindow = GTK_GET_SURFACE(gtkwindow);
    if (gdkwindow) {
        GdkWindowState state = GTK_SURFACE_STATE(gdkwindow);
        *result = (state & GDK_WINDOW_STATE_MAXIMIZED) ? 1 : 0;
    } else {
        *result = 0;
    }
#endif
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_is_minimized(webview_t w, int *result)
{
    if (!w || !result) return WEBVIEW_ERROR_INVALID_ARGUMENT;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    WINDOWPLACEMENT wp = { sizeof(wp) };
    if (GetWindowPlacement(hwnd, &wp)) {
        *result = (wp.showCmd == SW_MINIMIZE || wp.showCmd == SW_SHOWMINIMIZED) ? 1 : 0;
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL isMiniaturized_sel = sel_registerName("isMiniaturized");
    if (class_respondsToSelector(object_getClass(window), isMiniaturized_sel)) {
        BOOL isMiniaturized = ((BOOL(*)(id, SEL))objc_msgSend)(window, isMiniaturized_sel);
        *result = isMiniaturized ? 1 : 0;
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;

#if GTK_MAJOR_VERSION >= 4
    GdkSurface *surface = GTK_GET_SURFACE(gtkwindow);
    if (surface) {
        GdkToplevelState state = GTK_SURFACE_STATE(surface);
        *result = (state & GDK_TOPLEVEL_STATE_MINIMIZED) ? 1 : 0;
    } else {
        *result = 0;
    }
#else
    GdkWindow *gdkwindow = GTK_GET_SURFACE(gtkwindow);
    if (gdkwindow) {
        GdkWindowState state = GTK_SURFACE_STATE(gdkwindow);
        *result = (state & GDK_WINDOW_STATE_ICONIFIED) ? 1 : 0;
    } else {
        *result = 0;
    }
#endif
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}

WEBVIEW_API webview_error_t webview_window_is_visible(webview_t w, int *result)
{
    if (!w || !result) return WEBVIEW_ERROR_INVALID_ARGUMENT;

#ifdef _WIN32
    HWND hwnd = (HWND)webview_get_window(w);
    if (!hwnd) return WEBVIEW_ERROR_INVALID_STATE;

    *result = IsWindowVisible(hwnd) ? 1 : 0;
    return WEBVIEW_ERROR_OK;

#elif defined(__APPLE__)
    void *nswindow = webview_get_window(w);
    if (!nswindow) return WEBVIEW_ERROR_INVALID_STATE;

    id window = (id)nswindow;
    SEL isVisible_sel = sel_registerName("isVisible");
    if (class_respondsToSelector(object_getClass(window), isVisible_sel)) {
        BOOL isVisible = ((BOOL(*)(id, SEL))objc_msgSend)(window, isVisible_sel);
        *result = isVisible ? 1 : 0;
    }
    return WEBVIEW_ERROR_OK;

#elif defined(__linux__)
    void *gtkwindow = webview_get_window(w);
    if (!gtkwindow) return WEBVIEW_ERROR_INVALID_STATE;

    *result = gtk_widget_get_visible(GTK_WIDGET(gtkwindow)) ? 1 : 0;
    return WEBVIEW_ERROR_OK;
#else
    return WEBVIEW_ERROR_UNSPECIFIED;
#endif
}
