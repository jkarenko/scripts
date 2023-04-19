#!/usr/bin/env bash

COLOR_REST="$(tput sgr0)"
COLOR_GREEN="$(tput setaf 2)"

system1="Write a 1000 word abstract of the video contents in the style of a college essay."
system2="You are a summarising expert who finds the important aspects in a text."
system3="Write an article that is very long and extremely detailed. Handle every major subject in its own paragraph."
system4="Rewrite text in the style of yellow press. Be as hyperbolic and click-baity as possible. Lie if you must."
system5="Kirjoita tiivistelmä seuraavasta tekstistä."
system="$system2"
printf "\n\n$COLOR_GREEN $system $COLOR_REST\n\n"

# Get youtube video audio only
filename="$(yt-dlp --get-filename -o '%(title)s' $1 | tr ' ' '_')"
if [ ! -f "$filename" ]; then
    echo "Downloading video and extracting audio"
    yt-dlp -x --extract-audio --audio-format wav --ppa "ffmpeg:-acodec pcm_s16le -ar 16000" -o "$filename" $1
fi
# Run whisper.cpp text inference for downloaded wav
if [ ! -f "$filename.wav.txt" ]; then
    echo "Starting speech-to-text inference"
    whisper_path="/Users/jk/code/whisper.cpp"
    $whisper_path/main -t 1 -p 6 -bo 5 -su -otxt -pc -pp -nt -l auto --prompt "$2" -m "$whisper_path"/models/ggml-medium.bin -f "$(pwd)/$filename.wav" -of "$(pwd)/$filename.wav"
fi
filename="$filename.wav.txt"

max_bytes=30000

# Remove newlines and save the content to a temporary file
tr -d '\n' < "$filename" > tmp_content.txt

# Count the number of words in the file
byte_count=$(wc -c < tmp_content.txt)

# Initialize an array to store the results of each chunk
results=()

# If the word count exceeds the maximum allowed words, split the file into chunks
if [ "$byte_count" -gt "$max_bytes" ]; then
    # Use the 'split' command to split the file into chunks of 6000 words each
    echo "Text too long, splitting into chunks"
    split -d -a 3 "-b $max_bytes" "$filename" chunk_
else
    cp "$filename" chunk_0
fi
  count=0
  # Loop through each chunk and send a request for each
    for chunk in chunk_*; do
    content=$(<"$chunk")
    json_template='{
        "model": "gpt-4",
        "messages": [
        {"role": "system", "content": $system},
        {"role": "user", "content": $content}
        ]
    }'
    json_payload=$(jq -n --arg system "$system" --arg content "$content" "$json_template")

    echo "processing chunk $count"
    count=$((count+1))

    # Append the result to the results array
    results+=("$(curl -s https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$json_payload" | yq -P '.choices[0].message.content')")
  done

  # Clean up the chunks
  rm chunk_*

# Combine the results and use them as content in the next phase
combined_results=$(printf "%s" "${results[@]}")
    json_template='{
        "model": "gpt-4",
        "messages": [
            {"role": "system", "content": $system},
            {"role": "user", "content": $content}
        ]
    }'
    json_payload=$(jq -n --arg system "$system" --arg content "$combined_results" "$json_template")

# Send the request with the combined results as content
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$json_payload" | yq -P '.choices[0].message.content'
