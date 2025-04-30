#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication, my_application, MY, APPLICATION,
                     GtkApplication)

/**
 * my_application_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* my_application_new();

// Get the main window of the application
GtkWindow* my_application_get_window(MyApplication* self);

// Toggle fullscreen state
gboolean my_application_toggle_fullscreen(MyApplication* self);

// Check if window is fullscreen
gboolean my_application_is_fullscreen(MyApplication* self);

#endif  // FLUTTER_MY_APPLICATION_H_
