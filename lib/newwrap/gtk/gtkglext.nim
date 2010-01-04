{.deadCodeElim: on.}
import 
  Glib2, Gdk2, 2, GdkGLExt

const 
  GLExtLib* = if defined(WIN32): "libgtkglext-win32-1.0-0.dll" else: "libgtkglext-x11-1.0.so"

const 
  HEADER_GTKGLEXT_MAJOR_VERSION* = 1
  HEADER_GTKGLEXT_MINOR_VERSION* = 0
  HEADER_GTKGLEXT_MICRO_VERSION* = 6
  HEADER_GTKGLEXT_INTERFACE_AGE* = 4
  HEADER_GTKGLEXT_BINARY_AGE* = 6

proc gl_parse_args*(argc: Plongint, argv: PPPChar): gboolean{.cdecl, 
    dynlib: GLExtLib, importc: "gtk_gl_parse_args".}
proc gl_init_check*(argc: Plongint, argv: PPPChar): gboolean{.cdecl, 
    dynlib: GLExtLib, importc: "gtk_gl_init_check".}
proc gl_init*(argc: Plongint, argv: PPPChar){.cdecl, dynlib: GLExtLib, 
    importc: "gtk_gl_init".}
proc widget_set_gl_capability*(widget: PWidget, glconfig: PGdkGLConfig, 
                               share_list: PGdkGLContext, direct: gboolean, 
                               render_type: int): gboolean{.cdecl, 
    dynlib: GLExtLib, importc: "gtk_widget_set_gl_capability".}
proc widget_is_gl_capable*(widget: PWidget): gboolean{.cdecl, dynlib: GLExtLib, 
    importc: "gtk_widget_is_gl_capable".}
proc widget_get_gl_config*(widget: PWidget): PGdkGLConfig{.cdecl, 
    dynlib: GLExtLib, importc: "gtk_widget_get_gl_config".}
proc widget_create_gl_context*(widget: PWidget, share_list: PGdkGLContext, 
                               direct: gboolean, render_type: int): PGdkGLContext{.
    cdecl, dynlib: GLExtLib, importc: "gtk_widget_create_gl_context".}
proc widget_get_gl_context*(widget: PWidget): PGdkGLContext{.cdecl, 
    dynlib: GLExtLib, importc: "gtk_widget_get_gl_context".}
proc widget_get_gl_window*(widget: PWidget): PGdkGLWindow{.cdecl, 
    dynlib: GLExtLib, importc: "gtk_widget_get_gl_window".}
proc widget_get_gl_drawable*(widget: PWidget): PGdkGLDrawable = 
  nil

proc HEADER_GTKGLEXT_CHECK_VERSION*(major, minor, micro: guint): bool = 
  result = (HEADER_GTKGLEXT_MAJOR_VERSION > major) or
      ((HEADER_GTKGLEXT_MAJOR_VERSION == major) and
      (HEADER_GTKGLEXT_MINOR_VERSION > minor)) or
      ((HEADER_GTKGLEXT_MAJOR_VERSION == major) and
      (HEADER_GTKGLEXT_MINOR_VERSION == minor) and
      (HEADER_GTKGLEXT_MICRO_VERSION >= micro))

proc widget_get_gl_drawable*(widget: PWidget): PGdkGLDrawable = 
  result = GDK_GL_DRAWABLE(widget_get_gl_window(widget))
