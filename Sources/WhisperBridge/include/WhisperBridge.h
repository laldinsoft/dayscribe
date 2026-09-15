#pragma once
#ifdef __cplusplus
extern "C" {
#endif
void * ds_whisper_create(const char * model_path);
void ds_whisper_destroy(void * context);
// Caller owns the returned UTF-8 string. NULL indicates an inference failure.
char * ds_whisper_transcribe(void * context, const float * samples, int count);
void ds_whisper_free_text(char * text);
#ifdef __cplusplus
}
#endif
