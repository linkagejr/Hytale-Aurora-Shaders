// Native SDL3 interposition. The installed proxy forwards other exports through its
// DT_NEEDED dependency on the unchanged original SDL3. The optional preload build
// intercepts explicit dlsym lookups used by Hytale's NativeAOT client instead.
// SDL handles GLX/EGL and X11/Wayland; no display-server-specific input polling.
typedef PROC (*SDL_GetProc)(const char *);
static SDL_GetProc linux_sdl_getproc;
static bool (*linux_sdl_swap)(void *);
static const bool *(*linux_sdl_keys)(int *);
static void *(*linux_sdl_focus)(void);
static bool (*linux_sdl_size)(void *, int *, int *);
static void *linux_sdl_handle;
static pthread_once_t linux_init_once = PTHREAD_ONCE_INIT;
static int linux_notify = -1;
static double linux_reload_at;

__declspec(dllexport) PROC SDL_GL_GetProcAddress(const char *name);
__declspec(dllexport) bool SDL_GL_SwapWindow(void *window);

#if AU_SDL_PROXY
// Identifies our library to the installer without relying on a filename or file size.
__attribute__((used)) static const char linux_proxy_marker[] = "AURORA_SDL_PROXY_V1";
#endif

static void *linux_real_dlsym(void *handle, const char *name)
{
    // x86_64 glibc's original symbol version predates Ubuntu's supported releases.
    typedef void *(*Lookup)(void *, const char *);
    Lookup lookup = (Lookup)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.2.5");
    return lookup ? lookup(handle, name) : NULL;
}

#include "linux_menu.h"

#if !AU_SDL_PROXY
// Preloaded (LD_PRELOAD, e.g. through a Flatpak override), the library is in every process the
// launcher starts; only the game itself is hooked. AURORA_PROCESS names another executable,
// AURORA_DISABLE=1 turns the hook off.
static int linux_game_process(void)
{
    static int cached = -1;
    int known = __atomic_load_n(&cached, __ATOMIC_ACQUIRE);
    if (known >= 0) return known;
    int game = 0;
    const char *off = getenv("AURORA_DISABLE");
    char exe[MAX_PATH];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    if ((!off || !*off || !strcmp(off, "0")) && n > 0) {
        exe[n] = 0;
        const char *want = getenv("AURORA_PROCESS");
        if (!want || !*want) want = "HytaleClient";
        const char *base = strrchr(exe, '/');
        base = base ? base + 1 : exe;
        size_t len = strlen(want);
        game = !strncmp(base, want, len) && (base[len] == 0 || base[len] == '.');
    }
    __atomic_store_n(&cached, game, __ATOMIC_RELEASE);
    return game;
}

// The real dlsym, found by version (the unversioned name would find ours).
typedef void *(*AuDlsym)(void *, const char *);
__attribute__((visibility("hidden"), used)) AuDlsym aurora_real_dlsym;
static void aurora_find_dlsym(void)
{
    if (__atomic_load_n(&aurora_real_dlsym, __ATOMIC_ACQUIRE)) return;
    void *p = dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.34");
    if (!p) p = dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.2.5");
    __atomic_store_n(&aurora_real_dlsym, (AuDlsym)p, __ATOMIC_RELEASE);
}
__attribute__((constructor)) static void aurora_preload_init(void) { aurora_find_dlsym(); }

// Called first by dlsym (below); NULL means "not ours" and dlsym continues straight into the
// real one with the caller's return address still on the stack, so RTLD_NEXT and RTLD_DEFAULT
// keep meaning what they mean for the caller (a plain C wrapper made every RTLD_NEXT lookup in
// the process resolve relative to this library, which broke other preloaded layers).
__attribute__((visibility("hidden"), used)) void *aurora_dlsym_filter(void *handle, const char *name, void *caller)
{
    (void)caller;
    aurora_find_dlsym();
    if (!name || handle == RTLD_NEXT || strncmp(name, "SDL_", 4) || !aurora_real_dlsym) return NULL;
    bool getproc = !strcmp(name, "SDL_GL_GetProcAddress"), swap = !strcmp(name, "SDL_GL_SwapWindow");
    // The menu's input hooks (linux_menu.h): events, keyboard and mouse state, mouse capture.
    void *menu = getproc || swap ? NULL : linux_menu_lookup(name);
    if ((!getproc && !swap && !menu) || !linux_game_process()) return NULL;
    void *p = aurora_real_dlsym(handle == RTLD_DEFAULT ? RTLD_NEXT : handle, name);
    if (!p || p == (void *)SDL_GL_GetProcAddress || p == (void *)SDL_GL_SwapWindow || p == menu) return NULL;
    if (getproc) linux_sdl_getproc = (SDL_GetProc)p;
    else if (swap) linux_sdl_swap = (bool (*)(void *))p;
    linux_sdl_handle = handle == RTLD_DEFAULT ? RTLD_NEXT : handle;
    return getproc ? (void *)SDL_GL_GetProcAddress : swap ? (void *)SDL_GL_SwapWindow : menu;
}

// void *dlsym(void *handle, const char *name)
__asm__(
    ".text\n"
    ".globl dlsym\n"
    ".type dlsym, @function\n"
    "dlsym:\n"
    "    .cfi_startproc\n"
    "    endbr64\n"
    "    subq $24, %rsp\n"
    "    .cfi_adjust_cfa_offset 24\n"
    "    movq %rdi, (%rsp)\n"
    "    movq %rsi, 8(%rsp)\n"
    "    movq 24(%rsp), %rdx\n"           // the caller's return address
    "    call aurora_dlsym_filter\n"
    "    testq %rax, %rax\n"
    "    jnz 1f\n"
    "    movq (%rsp), %rdi\n"
    "    movq 8(%rsp), %rsi\n"
    "    addq $24, %rsp\n"
    "    .cfi_adjust_cfa_offset -24\n"
    "    jmp *aurora_real_dlsym(%rip)\n"
    "1:\n"
    "    .cfi_adjust_cfa_offset 24\n"
    "    addq $24, %rsp\n"
    "    .cfi_adjust_cfa_offset -24\n"
    "    ret\n"
    "    .cfi_endproc\n"
    ".size dlsym, .-dlsym\n");
#endif

static PROC linux_gl_proc(const char *name)
{
    return linux_sdl_getproc && name ? linux_sdl_getproc(name) : NULL;
}

// The installer notes which HytaleClient build the shaders were prepared from
// (original/source.txt: "size N", "mtime N"). After a game update the prepared shaders may no
// longer match: run the game's own shaders until the installer runs again.
static void linux_check_game_build(void)
{
    char *txt = read_file("original/source.txt", NULL);
    if (!txt) return;
    long long size = -1, mtime = -1;
    char *save = NULL;
    for (char *line = strtok_r(txt, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
        sscanf(line, "size %lld", &size);
        sscanf(line, "mtime %lld", &mtime);
    }
    free(txt);
    char exe[MAX_PATH];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    struct stat st;
    if (size < 0 || mtime < 0 || n <= 0) return;
    exe[n] = 0;
    if (stat(exe, &st)) return;
    if ((long long)st.st_size != size || (long long)st.st_mtime != mtime) {
        g_packStale = 1;
        g_enabled = 0;
        logf_("HytaleClient changed since the shaders were prepared (game update?): using the game's own shaders. "
              "Run install.sh again.");
    }
}

static void linux_init(void)
{
#if AU_SDL_PROXY
    Dl_info library;
    char original[MAX_PATH];
    if (dladdr((void *)linux_init, &library) && realpath(library.dli_fname, original)) {
        char *slash = strrchr(original, '/');
        if (slash) {
            *slash = 0;
            if (strlen(original) + sizeof("/libSDL3.aurora-original.so") < sizeof original) {
                strcat(original, "/libSDL3.aurora-original.so");
                linux_sdl_handle = dlopen(original, RTLD_NOW | RTLD_LOCAL);
            }
        }
    }
#endif
    // Also supports programs linked directly against SDL3.
    if (!linux_sdl_handle) linux_sdl_handle = RTLD_NEXT;
    if (!linux_sdl_getproc) linux_sdl_getproc = (SDL_GetProc)linux_real_dlsym(linux_sdl_handle, "SDL_GL_GetProcAddress");
    if (!linux_sdl_swap) linux_sdl_swap = (bool (*)(void *))linux_real_dlsym(linux_sdl_handle, "SDL_GL_SwapWindow");
    linux_sdl_keys = (const bool *(*)(int *))linux_real_dlsym(linux_sdl_handle, "SDL_GetKeyboardState");
    linux_sdl_focus = (void *(*)(void))linux_real_dlsym(linux_sdl_handle, "SDL_GetKeyboardFocus");
    linux_sdl_size = (bool (*)(void *, int *, int *))linux_real_dlsym(linux_sdl_handle, "SDL_GetWindowSizeInPixels");
    real_wglGetProcAddress = linux_gl_proc;
    InitializeCriticalSection(&g_lock);
    InitializeCriticalSection(&g_menuLock);
    const char *pack = getenv("AURORA_SHADERPACK");
    char path[MAX_PATH];
    if (!pack || !*pack) {
        Dl_info info;
        if (dladdr((void *)linux_init, &info) && realpath(info.dli_fname, path)) {
            char *slash = strrchr(path, '/');
            if (slash) *slash = 0;
#if AU_SDL_PROXY
            const char *suffix = "/.aurora/shaderpack";
#else
            const char *suffix = "/shaderpack";
#endif
            if (strlen(path) + strlen(suffix) < sizeof path) strcat(path, suffix);
            pack = path;
        } else pack = "shaderpack";
    }
    au_to_wide(g_packDir, MAX_PATH, pack);
    wchar_t wide[MAX_PATH];
    pack_path(wide, "hook.log");
    g_log = _wfopen(wide, L"w");
    g_dump = pack_flag("dump");
    pack_path(wide, "errors");
    CreateDirectoryW(wide, NULL);
    QueryPerformanceFrequency(&g_freq);
    QueryPerformanceCounter(&g_t0);
    g_enabled = !pack_flag("programs/_disabled");
    settings_load();
    load_index(); load_shares(); load_textures_cfg(); load_forward_cfg();
    linux_check_game_build();
    r_glBindTexture = (PFN_glBindTexture)linux_gl_proc("glBindTexture");
    r_glDrawArrays = (PFN_glDrawArrays)linux_gl_proc("glDrawArrays");
    r_glDrawElements = (PFN_glDrawElements)linux_gl_proc("glDrawElements");
    linux_notify = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (linux_notify >= 0) {
        const char *dirs[] = {"programs", "include"};
        for (int i = 0; i < 2; i++) {
            pack_path(wide, dirs[i]);
            au_to_utf8(path, sizeof path, wide);
            if (inotify_add_watch(linux_notify, path, IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | IN_DELETE) < 0)
                logf_("cannot watch %s for shader edits", path);
        }
    }
    logf_("Aurora native Linux SDL3 hook loaded (%s); DLSS unavailable; dump=%d",
#if AU_SDL_PROXY
          "automatic proxy",
#else
          "preload",
#endif
          g_dump);
}

static void linux_input(void *window)
{
    const int keys[] = {menu_hotkey_scan(g_menuHotkey), 82, 81, 80, 79, 41, 75, 78, 72};
    static bool down[9];
    static double next[9];
    double t = now_sec();
    if (linux_notify >= 0) {
        char events[4096];
        while (read(linux_notify, events, sizeof events) > 0) linux_reload_at = t + 0.4;
        if (linux_reload_at && t >= linux_reload_at) {
            linux_reload_at = 0;
            InterlockedExchange(&g_reloadRequested, 1);
        }
    }
    if (g_menuWriteAt && t >= g_menuWriteAt) {
        g_menuWriteAt = 0;
        menu_save();
        InterlockedExchange(&g_reloadRequested, 1);
        swprintf(g_menuStatus, 96, L"Saved - shaders reloading");
        g_menuDirty = 1;
    }
    if (!linux_sdl_keys || !linux_sdl_focus) return;
    int count = 0;
    const bool *state = linux_sdl_keys(&count);
    bool focus = linux_sdl_focus() == window;
    if (g_menuBinding) {
        unsigned char pressed[256] = {0};
        for (int key = 8; state && key < 256; key++) {
            int scan = menu_hotkey_scan(key);
            pressed[key] = scan > 0 && scan < count && state[scan];
        }
        menu_bind_poll(pressed, focus);
        for (int index = 0; index < 9; index++) {
            int scan = index == 0 ? menu_hotkey_scan(g_menuHotkey) : keys[index];
            down[index] = focus && state && scan < count && state[scan];
        }
        return;
    }
    if (focus && state && g_menuOpen && (g_menuPresetNaming || (g_menuMouseMode && g_menuSearchFocus))) {
        static bool textDown[58];
        bool shifted = count > 229 && (state[225] || state[229]);
        for (int key = 4; key < 58 && key < count; key++) {
            bool pressed = state[key];
            bool fire = pressed && !textDown[key];
            textDown[key] = pressed;
            if (!fire) continue;
            if (key == 40) { if (g_menuPresetNaming) menu_profile_finish(); else g_menuSearchFocus = 0; break; }
            if (key == 41) { menu_profile_cancel(); break; }
            size_t length = wcslen(g_menuSearch);
            if (key == 42 && length) g_menuSearch[length - 1] = 0;
            else if (length < 63) {
                wchar_t character = key >= 4 && key <= 29 ? (shifted ? L'A' : L'a') + key - 4
                    : key >= 30 && key <= 38 ? L'1' + key - 30 : key == 39 ? L'0'
                    : key == 44 ? L' ' : key == 45 ? (shifted ? L'_' : L'-') : 0;
                if (character) { g_menuSearch[length] = character; g_menuSearch[length + 1] = 0; }
            }
            g_moTop = 0;
            if (!g_menuPresetNaming) menu_rebuild_rows();
            g_menuDirty = 1;
        }
        return;
    }
    for (int k = 0; k < 9; k++) {
        bool d = focus && state && keys[k] < count && state[keys[k]];
        bool repeat = d && down[k] && k >= 1 && k <= 4 && t >= next[k];
        bool fire = (d && !down[k]) || repeat;
        if (fire) next[k] = t + (repeat ? 0.06 : 0.35);
        down[k] = d;
        if (!fire) continue;
        if (k == 8) {
            g_toggleOff = !g_toggleOff;
            InterlockedExchange(&g_reloadRequested, 1);
            if (g_menuOpen) menu_load();
            g_menuDirty = 1;
        } else if (k == 0) {
            g_menuOpen = !g_menuOpen;
            if (g_menuOpen) { menu_load(); g_menuStatus[0] = 0; }
            g_menuDirty = 1;
        } else if (g_menuOpen) {
            bool sliding = g_moSel >= 0 && g_mo[g_moSel].kind == MO_RANGE;
            switch (k) {
            case 1: menu_move(-1); break;
            case 2: menu_move(1); break;
            case 3: if (!repeat || sliding) menu_change(-1, 0); break;
            case 4: if (!repeat || sliding) menu_change(1, 0); break;
            case 5: menu_profile_cancel(); g_menuOpen = 0; break;
            case 6: if (g_menuTabCount) menu_activate_tab((g_menuTab + g_menuTabCount - 1) % g_menuTabCount); break;
            case 7: if (g_menuTabCount) menu_activate_tab((g_menuTab + 1) % g_menuTabCount); break;
            }
        }
    }
}

__declspec(dllexport) PROC SDL_GL_GetProcAddress(const char *name)
{
#if !AU_SDL_PROXY
    // Another program in the same sandbox, linked directly against SDL3: stay out of its way.
    if (!linux_game_process()) {
        static SDL_GetProc next;
        if (!next) next = (SDL_GetProc)linux_real_dlsym(RTLD_NEXT, "SDL_GL_GetProcAddress");
        return next && name ? next(name) : NULL;
    }
#endif
    pthread_once(&linux_init_once, linux_init);
    return name ? hook_get_proc(name) : NULL;
}

__declspec(dllexport) bool SDL_GL_SwapWindow(void *window)
{
#if !AU_SDL_PROXY
    if (!linux_game_process()) {
        static bool (*next)(void *);
        if (!next) next = (bool (*)(void *))linux_real_dlsym(RTLD_NEXT, "SDL_GL_SwapWindow");
        return next ? next(window) : false;
    }
#endif
    pthread_once(&linux_init_once, linux_init);
    g_postPresent = 0;
    linux_menu_init();
    lm_window = window;
    linux_menu_sync();
    linux_input(window);
    linux_menu_sync();
    int sw = 0, sh = 0;
    if (g_menuOpen && linux_sdl_size && linux_sdl_size(window, &sw, &sh) && sw > 0 && sh > 0 && ov_init()) {
        if (g_menuDirty || sh != g_ovScreenH || sw != g_ovScreenW) {
            menu_render(sw, sh);
            g_ovScreenH = sh; g_ovScreenW = sw; g_ovUpload = 1; g_menuDirty = 0;
        }
        if (g_ovBits) menu_draw(sw, sh);
    }
    return linux_sdl_swap ? linux_sdl_swap(window) : false;
}
