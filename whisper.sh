#!/usr/bin/env bash
#~/code/whisper.cpp/"$@"
whisper_path="/Users/jk/code/whisper.cpp"
$whisper_path/main -t 1 -p 6 -bo 5 -su -otxt -pc -pp -nt -l auto --prompt "$2" -m "$whisper_path"/models/ggml-medium.bin -f "$(pwd)/$1" -of "$(pwd)/$1"