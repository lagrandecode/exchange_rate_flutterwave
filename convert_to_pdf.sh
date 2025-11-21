#!/bin/bash

# Script to convert HTML documentation to PDF on macOS

HTML_FILE="DJANGO_BACKEND_DOCUMENTATION.html"
PDF_FILE="DJANGO_BACKEND_DOCUMENTATION.pdf"

# Check if HTML file exists
if [ ! -f "$HTML_FILE" ]; then
    echo "Error: $HTML_FILE not found!"
    exit 1
fi

# Try using Safari's headless print-to-PDF (macOS 10.12+)
if command -v osascript &> /dev/null; then
    echo "Converting HTML to PDF using Safari..."
    osascript <<EOF
tell application "Safari"
    activate
    open POSIX file "$(pwd)/$HTML_FILE"
    delay 2
    tell application "System Events"
        keystroke "p" using {command down}
        delay 1
        keystroke "s" using {command down}
        delay 1
        keystroke "$(pwd)/$PDF_FILE"
        delay 1
        keystroke return
        delay 2
    end tell
    quit
end tell
EOF
    echo "PDF created: $PDF_FILE"
else
    echo "Please open $HTML_FILE in your browser and use 'Print to PDF' to save as PDF"
fi

