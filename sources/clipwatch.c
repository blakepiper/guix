/* AlpineWS: XFixes selection events, without a polling/Bash clipboard daemon.
 * SPDX-License-Identifier: MIT */
#include <X11/Xlib.h>
#include <X11/extensions/Xfixes.h>
#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void) {
    Display *d = XOpenDisplay(NULL);
    int base, error;
    if (!d || !XFixesQueryExtension(d, &base, &error)) {
        fputs("clipwatch: XFixes is unavailable\n", stderr);
        if (d) XCloseDisplay(d);
        return 1;
    }
    Atom clipboard = XInternAtom(d, "CLIPBOARD", False);
    Window w = XCreateSimpleWindow(d, DefaultRootWindow(d), 0, 0, 1, 1, 0, 0, 0);
    XFixesSelectSelectionInput(d, w, clipboard, XFixesSetSelectionOwnerNotifyMask);
    XFlush(d);
    for (;;) {
        XEvent event;
        XNextEvent(d, &event);
        if (event.type != base + XFixesSelectionNotify) continue;
        XFixesSelectionNotifyEvent *selection = (XFixesSelectionNotifyEvent *)&event;
        if (selection->owner == None) continue;
        pid_t pid = fork();
        if (pid == 0) {
            close(ConnectionNumber(d));
            execlp("clipboard-history", "clipboard-history", "--record", (char *)NULL);
            _exit(127);
        }
        if (pid < 0) { perror("clipwatch: fork"); continue; }
        while (waitpid(pid, NULL, 0) < 0 && errno == EINTR) {}
    }
}
