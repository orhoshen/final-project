#!/bin/bash

# Clean up old files first
rm -rf assets/piano_notes/*

# Create the directory if it doesn't exist
mkdir -p assets/piano_notes

# URL for high-quality piano samples (University of Iowa Piano Samples)
BASE_URL="https://theremin.music.uiowa.edu/MISpiano_files"

# Map MIDI notes to filenames
declare -A files=(
  [60]="Piano.pp.C4.mp3"   # C4
  [61]="Piano.pp.Db4.mp3"  # C#4/Db4
  [62]="Piano.pp.D4.mp3"   # D4
  [63]="Piano.pp.Eb4.mp3"  # D#4/Eb4
  [64]="Piano.pp.E4.mp3"   # E4
  [65]="Piano.pp.F4.mp3"   # F4
  [66]="Piano.pp.Gb4.mp3"  # F#4/Gb4
  [67]="Piano.pp.G4.mp3"   # G4
  [68]="Piano.pp.Ab4.mp3"  # G#4/Ab4
  [69]="Piano.pp.A4.mp3"   # A4
  [70]="Piano.pp.Bb4.mp3"  # A#4/Bb4
  [71]="Piano.pp.B4.mp3"   # B4
  [72]="Piano.pp.C5.mp3"   # C5
)

# Download each note
for note in {60..72}; do
  filename=${files[$note]}
  url="$BASE_URL/$filename"
  output="assets/piano_notes/note_$note.mp3"
  
  echo "Downloading piano note $note ($filename)..."
  curl -L -o "$output" "$url"
  
  # Verify file was downloaded
  if [ -f "$output" ]; then
    filesize=$(wc -c < "$output")
    if [ "$filesize" -lt 1000 ]; then
      echo "Warning: Downloaded file for note $note is too small ($filesize bytes)."
    else
      echo "Success: Downloaded note $note ($filesize bytes)."
    fi
  else
    echo "Error: Failed to download note $note."
  fi
done

# Alternative download - use lower quality but reliable samples if above fails
if [ $(ls assets/piano_notes/note_*.mp3 | wc -l) -lt 5 ]; then
  echo "Falling back to alternative piano samples source..."
  
  # Clean directory
  rm -f assets/piano_notes/note_*.mp3
  
  # Alternative URL (tonejs audio samples)
  ALT_BASE_URL="https://tonejs.github.io/audio/salamander"
  
  declare -A alt_files=(
    [60]="C4.mp3"
    [61]="Db4.mp3"
    [62]="D4.mp3"
    [63]="Eb4.mp3"
    [64]="E4.mp3"
    [65]="F4.mp3"
    [66]="Gb4.mp3"
    [67]="G4.mp3"
    [68]="Ab4.mp3"
    [69]="A4.mp3"
    [70]="Bb4.mp3"
    [71]="B4.mp3"
    [72]="C5.mp3"
  )
  
  for note in {60..72}; do
    filename=${alt_files[$note]}
    url="$ALT_BASE_URL/$filename"
    output="assets/piano_notes/note_$note.mp3"
    
    echo "Downloading alternative piano note $note ($filename)..."
    curl -L -o "$output" "$url"
  done
fi

echo "Download complete."
echo "Files in assets/piano_notes/:"
ls -la assets/piano_notes/ 