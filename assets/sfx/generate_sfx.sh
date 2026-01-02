#!/bin/bash
# Suno API Sound Effect Generator for WFL Show Mode
# Replace YOUR_API_KEY with your actual Suno API key

API_KEY="YOUR_API_KEY"
BASE_URL="https://api.sunoapi.org/api/v1/generate"

# 1. Rimshot (ba-dum-tss)
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "Quick comedy rimshot ba dum tss, snare drum hit followed by cymbal crash, classic joke punchline sound effect, 2 seconds",
  "style": "Comedy, Sound Effect, Drums",
  "title": "rimshot"
}'

echo "---"

# 2. Sad Trombone (wah wah wah)
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "Sad trombone wah wah wah descending notes, comedy fail sound effect, disappointment horn, 3 seconds",
  "style": "Comedy, Sound Effect, Brass",
  "title": "sad_trombone"
}'

echo "---"

# 3. Airhorn
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "MLG airhorn sound effect, loud party horn blast, hype celebration horn, 2 seconds",
  "style": "EDM, Sound Effect, Horn",
  "title": "airhorn"
}'

echo "---"

# 4. Laugh Track
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": false,
  "model": "V4_5ALL",
  "prompt": "Sitcom audience laughter, crowd laughing at joke, studio audience laugh track, warm genuine laughter, 4 seconds",
  "style": "Comedy, Audience, Laughter",
  "title": "laugh_track"
}'

echo "---"

# 5. Drumroll
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "Dramatic drumroll building tension, snare drum roll crescendo ending with cymbal crash, 4 seconds",
  "style": "Drums, Sound Effect, Dramatic",
  "title": "drumroll"
}'

echo "---"

# 6. Whoosh
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "Quick swoosh whoosh transition sound effect, fast air movement, cinematic transition, 1 second",
  "style": "Sound Effect, Cinematic, Transition",
  "title": "whoosh"
}'

echo "---"

# 7. Ding
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "Bright ding bell notification sound, correct answer bell, game show ding, cheerful bell chime, 1 second",
  "style": "Sound Effect, Bell, Notification",
  "title": "ding"
}'

echo "---"

# 8. Buzzer
curl --request POST \
  --url $BASE_URL \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "customMode": true,
  "instrumental": true,
  "model": "V4_5ALL",
  "prompt": "Wrong answer buzzer sound effect, game show incorrect buzzer, loud error buzz, 1 second",
  "style": "Sound Effect, Buzzer, Game Show",
  "title": "buzzer"
}'

echo ""
echo "All requests sent! Check callback URL or poll for results."
