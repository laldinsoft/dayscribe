#include "WhisperBridge.h"
#include "whisper.h"
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>

// No transcript or audio is written to logs.
static void silent_log(enum ggml_log_level, const char *, void *) {}

void * ds_whisper_create(const char * path) {
    whisper_log_set(silent_log, nullptr);
    auto params = whisper_context_default_params();
    params.use_gpu = true;
    params.flash_attn = true;
    return whisper_init_from_file_with_params(path, params);
}

void ds_whisper_destroy(void * context) {
    if (context) whisper_free(static_cast<whisper_context *>(context));
}

char * ds_whisper_transcribe(void * context, const float * samples, int count) {
    if (!context || !samples || count <= 0) return nullptr;
    auto * ctx = static_cast<whisper_context *>(context);
    auto params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH);
    params.n_threads = std::max(1u, std::min(8u, std::thread::hardware_concurrency()));
    params.language = "en";
    params.translate = false;
    params.no_context = true;
    params.no_timestamps = true;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.suppress_nst = true;
    params.beam_search.beam_size = 5;
    if (whisper_full(ctx, params, samples, count) != 0) return nullptr;
    std::string result;
    for (int i = 0; i < whisper_full_n_segments(ctx); ++i) {
        result += whisper_full_get_segment_text(ctx, i);
    }
    return strdup(result.c_str());
}

void ds_whisper_free_text(char * text) { free(text); }
