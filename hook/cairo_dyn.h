// The few cairo calls the Linux menu panel makes, loaded from libcairo.so.2 when the menu first
// opens instead of linked: a game runtime without cairo then only loses the menu, and the hook
// itself still loads (a link-time dependency made the whole library fail to load there).
// Types and values are cairo's stable ABI.
#ifndef AURORA_CAIRO_DYN_H
#define AURORA_CAIRO_DYN_H

typedef struct _cairo cairo_t;
typedef struct _cairo_surface cairo_surface_t;
typedef struct _cairo_font_options cairo_font_options_t;
typedef enum { CAIRO_STATUS_SUCCESS = 0 } cairo_status_t;
typedef enum { CAIRO_FORMAT_ARGB32 = 0 } cairo_format_t;
typedef enum { CAIRO_ANTIALIAS_DEFAULT = 0, CAIRO_ANTIALIAS_NONE = 1, CAIRO_ANTIALIAS_GRAY = 2 } cairo_antialias_t;
typedef enum { CAIRO_FONT_SLANT_NORMAL = 0 } cairo_font_slant_t;
typedef enum { CAIRO_FONT_WEIGHT_NORMAL = 0, CAIRO_FONT_WEIGHT_BOLD = 1 } cairo_font_weight_t;
typedef struct { double x_bearing, y_bearing, width, height, x_advance, y_advance; } cairo_text_extents_t;

#define AU_CAIRO_FUNCS(X) \
    X(cairo_t *, cairo_create, (cairo_surface_t *)) \
    X(void, cairo_destroy, (cairo_t *)) \
    X(cairo_status_t, cairo_status, (cairo_t *)) \
    X(cairo_surface_t *, cairo_image_surface_create, (cairo_format_t, int, int)) \
    X(unsigned char *, cairo_image_surface_get_data, (cairo_surface_t *)) \
    X(void, cairo_surface_destroy, (cairo_surface_t *)) \
    X(void, cairo_surface_flush, (cairo_surface_t *)) \
    X(void, cairo_surface_mark_dirty, (cairo_surface_t *)) \
    X(cairo_font_options_t *, cairo_font_options_create, (void)) \
    X(void, cairo_font_options_destroy, (cairo_font_options_t *)) \
    X(void, cairo_font_options_set_antialias, (cairo_font_options_t *, cairo_antialias_t)) \
    X(void, cairo_set_font_options, (cairo_t *, const cairo_font_options_t *)) \
    X(void, cairo_select_font_face, (cairo_t *, const char *, cairo_font_slant_t, cairo_font_weight_t)) \
    X(void, cairo_set_font_size, (cairo_t *, double)) \
    X(void, cairo_text_extents, (cairo_t *, const char *, cairo_text_extents_t *)) \
    X(void, cairo_show_text, (cairo_t *, const char *)) \
    X(void, cairo_set_source_rgb, (cairo_t *, double, double, double)) \
    X(void, cairo_save, (cairo_t *)) \
    X(void, cairo_restore, (cairo_t *)) \
    X(void, cairo_identity_matrix, (cairo_t *)) \
    X(void, cairo_scale, (cairo_t *, double, double)) \
    X(void, cairo_rectangle, (cairo_t *, double, double, double, double)) \
    X(void, cairo_arc, (cairo_t *, double, double, double, double, double)) \
    X(void, cairo_new_sub_path, (cairo_t *)) \
    X(void, cairo_close_path, (cairo_t *)) \
    X(void, cairo_move_to, (cairo_t *, double, double)) \
    X(void, cairo_clip, (cairo_t *)) \
    X(void, cairo_fill, (cairo_t *))

#define AU_CAIRO_FIELD(ret, name, args) ret (*name) args;
static struct { AU_CAIRO_FUNCS(AU_CAIRO_FIELD) } au_cairo;
#undef AU_CAIRO_FIELD

// 1 once every function is there; tries only once.
static int au_cairo_load(void)
{
    static int state;   // 0 untried, 1 loaded, -1 unavailable
    if (state) return state > 0;
    state = -1;
    void *lib = dlopen("libcairo.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!lib) return 0;
#define AU_CAIRO_LOAD(ret, name, args) if (!(*(void **)&au_cairo.name = dlsym(lib, #name))) return 0;
    AU_CAIRO_FUNCS(AU_CAIRO_LOAD)
#undef AU_CAIRO_LOAD
    state = 1;
    return 1;
}

#define cairo_create au_cairo.cairo_create
#define cairo_destroy au_cairo.cairo_destroy
#define cairo_status au_cairo.cairo_status
#define cairo_image_surface_create au_cairo.cairo_image_surface_create
#define cairo_image_surface_get_data au_cairo.cairo_image_surface_get_data
#define cairo_surface_destroy au_cairo.cairo_surface_destroy
#define cairo_surface_flush au_cairo.cairo_surface_flush
#define cairo_surface_mark_dirty au_cairo.cairo_surface_mark_dirty
#define cairo_font_options_create au_cairo.cairo_font_options_create
#define cairo_font_options_destroy au_cairo.cairo_font_options_destroy
#define cairo_font_options_set_antialias au_cairo.cairo_font_options_set_antialias
#define cairo_set_font_options au_cairo.cairo_set_font_options
#define cairo_select_font_face au_cairo.cairo_select_font_face
#define cairo_set_font_size au_cairo.cairo_set_font_size
#define cairo_text_extents au_cairo.cairo_text_extents
#define cairo_show_text au_cairo.cairo_show_text
#define cairo_set_source_rgb au_cairo.cairo_set_source_rgb
#define cairo_save au_cairo.cairo_save
#define cairo_restore au_cairo.cairo_restore
#define cairo_identity_matrix au_cairo.cairo_identity_matrix
#define cairo_scale au_cairo.cairo_scale
#define cairo_rectangle au_cairo.cairo_rectangle
#define cairo_arc au_cairo.cairo_arc
#define cairo_new_sub_path au_cairo.cairo_new_sub_path
#define cairo_close_path au_cairo.cairo_close_path
#define cairo_move_to au_cairo.cairo_move_to
#define cairo_clip au_cairo.cairo_clip
#define cairo_fill au_cairo.cairo_fill

#endif
