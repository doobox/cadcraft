#ifndef ARCWORKS_BRIDGE_H
#define ARCWORKS_BRIDGE_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ArcWorksSession ArcWorksSession;

ArcWorksSession *arcworks_session_new(void);
char *arcworks_command_catalog(void);
void arcworks_session_free(ArcWorksSession *session);
char *arcworks_session_new_drawing(ArcWorksSession *session, bool metric);
char *arcworks_session_open(ArcWorksSession *session, const char *path);
char *arcworks_session_save(ArcWorksSession *session);
char *arcworks_session_save_as(ArcWorksSession *session, const char *path);
char *arcworks_session_export(ArcWorksSession *session, const char *path);
char *arcworks_session_autosave_configure(ArcWorksSession *session, const char *path,
                                          uint32_t minutes);
char *arcworks_session_autosave_tick(ArcWorksSession *session);
char *arcworks_session_recover(ArcWorksSession *session, const char *path,
                               const char *title);
char *arcworks_session_discard_recovery(ArcWorksSession *session, const char *path);
char *arcworks_session_autosave_shutdown(ArcWorksSession *session);
char *arcworks_session_command(ArcWorksSession *session, const char *command);
char *arcworks_session_clipboard_text(ArcWorksSession *session);
char *arcworks_session_load_clipboard(ArcWorksSession *session, const char *text);
char *arcworks_session_view_pan(ArcWorksSession *session, double screen_x, double screen_y,
                                double viewport_width, double viewport_height);
char *arcworks_session_view_zoom(ArcWorksSession *session, double factor, double screen_x,
                                 double screen_y, double viewport_width,
                                 double viewport_height);
char *arcworks_session_zoom_extents(ArcWorksSession *session, double viewport_width,
                                    double viewport_height);
char *arcworks_session_point(ArcWorksSession *session, double x, double y, bool shift,
                             double viewport_width, double viewport_height);
char *arcworks_session_cursor(ArcWorksSession *session, double x, double y, bool shift,
                              double world_per_pixel, double viewport_width,
                              double viewport_height, double now);
char *arcworks_session_window(ArcWorksSession *session, double start_x, double start_y,
                              double end_x, double end_y, bool shift,
                              double viewport_width, double viewport_height);
char *arcworks_session_begin_grip(ArcWorksSession *session, const char *handle,
                                  size_t index);
char *arcworks_session_drafting_toggle(ArcWorksSession *session, const char *setting);
char *arcworks_session_set_layout(ArcWorksSession *session, const char *name);
char *arcworks_session_create_layout(ArcWorksSession *session);
char *arcworks_session_set_annotation_scale(ArcWorksSession *session, const char *name);
char *arcworks_session_set_current_layer(ArcWorksSession *session, const char *name);
char *arcworks_session_set_selection_layer(ArcWorksSession *session, const char *name);
char *arcworks_session_set_selection_property(ArcWorksSession *session, const char *key,
                                              const char *value_json);
char *arcworks_session_layer_action(ArcWorksSession *session, const char *action,
                                    const char *name, const char *value);
char *arcworks_session_enter(ArcWorksSession *session);
char *arcworks_session_cancel(ArcWorksSession *session);
char *arcworks_session_snapshot(ArcWorksSession *session);
void arcworks_string_free(char *string);

#ifdef __cplusplus
}
#endif

#endif

