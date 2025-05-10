#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;  // Store a reference to the main window
  gboolean is_fullscreen;  // Track fullscreen state
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Get the main window
GtkWindow* my_application_get_window(MyApplication* self) {
  return self->window;
}

// Toggle fullscreen state
gboolean my_application_toggle_fullscreen(MyApplication* self) {
  if (!self->window) {
    return FALSE;
  }

  // Check the actual window state to ensure accuracy
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(self->window));
  if (!gdk_window) {
    return FALSE;
  }

  // Get the current window state
  GdkWindowState state = gdk_window_get_state(gdk_window);
  gboolean is_fullscreen = (state & GDK_WINDOW_STATE_FULLSCREEN) != 0;

  // Update our tracking to match reality
  self->is_fullscreen = is_fullscreen;

  // Toggle the fullscreen state
  if (self->is_fullscreen) {
    gtk_window_unfullscreen(self->window);
    self->is_fullscreen = FALSE;
  } else {
    gtk_window_fullscreen(self->window);
    self->is_fullscreen = TRUE;
  }

  // Ensure window state changes are processed
  while (gtk_events_pending()) {
    gtk_main_iteration();
  }

  // Return the new state
  return self->is_fullscreen;
}

// Check if window is fullscreen
gboolean my_application_is_fullscreen(MyApplication* self) {
  if (!self->window) {
    return FALSE;
  }

  // Check the actual window state to ensure accuracy
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(self->window));
  if (!gdk_window) {
    return FALSE;
  }

  // Get the current window state
  GdkWindowState state = gdk_window_get_state(gdk_window);
  gboolean is_fullscreen = (state & GDK_WINDOW_STATE_FULLSCREEN) != 0;

  // Update our tracking to match reality
  self->is_fullscreen = is_fullscreen;

  return self->is_fullscreen;
}

// Method channel handler
static void method_call_handler(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "enterFullscreen") == 0) {
    // First check the current state
    gboolean currentState = my_application_is_fullscreen(self);

    if (!currentState && self->window) {
      gtk_window_fullscreen(self->window);

      // Ensure window state changes are processed
      while (gtk_events_pending()) {
        gtk_main_iteration();
      }

      self->is_fullscreen = TRUE;
    }
    fl_method_call_respond_success(method_call, fl_value_new_bool(self->is_fullscreen), nullptr);
  } else if (strcmp(method, "exitFullscreen") == 0) {
    // First check the current state
    gboolean currentState = my_application_is_fullscreen(self);

    if (currentState && self->window) {
      gtk_window_unfullscreen(self->window);

      // Ensure window state changes are processed
      while (gtk_events_pending()) {
        gtk_main_iteration();
      }

      self->is_fullscreen = FALSE;
    }
    fl_method_call_respond_success(method_call, fl_value_new_bool(FALSE), nullptr);
  } else if (strcmp(method, "toggleFullscreen") == 0) {
    gboolean result = my_application_toggle_fullscreen(self);
    fl_method_call_respond_success(method_call, fl_value_new_bool(result), nullptr);
  } else if (strcmp(method, "isFullscreen") == 0) {
    gboolean result = my_application_is_fullscreen(self);
    fl_method_call_respond_success(method_call, fl_value_new_bool(result), nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Store window reference
  self->window = window;
  self->is_fullscreen = FALSE;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "mojar-player-pro");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "mojar-player-pro");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Set up the method channel
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.mojarplayer.mojar_player_pro/system",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_handler, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(application);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(application);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->window = NULL;
  self->is_fullscreen = FALSE;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
