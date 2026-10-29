#!/bin/bash

# Check if apt-rdepends is installed
if ! command -v apt-rdepends &> /dev/null; then
    echo "❌ Error: 'apt-rdepends' is required but not installed."
    echo "Please run: sudo apt update && sudo apt install apt-rdepends -y"
    exit 1
fi

OUTPUT_FILE="all_packages_dependencies.txt"
echo "Starting dependency export... This may take a few minutes."
echo "Saving results to: $OUTPUT_FILE"

# Initialize/Clear the file
echo "=== SYSTEM PACKAGES DEPENDENCY REPORT ===" > "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"

# Loop through all manually installed packages
apt-mark showmanual | while read -r package; do
    echo "Processing: $package..."
    
    echo -e "\n\n========================================" >> "$OUTPUT_FILE"
    echo "📦 PACKAGE: $package" >> "$OUTPUT_FILE"
    echo "========================================" >> "$OUTPUT_FILE"
    
    # 🌲 TREE DOWN: Forward Dependencies (showing only critical/important ones)
    echo -e "\n👇 TREE DOWN (What '$package' depends on):" >> "$OUTPUT_FILE"
    apt-rdepends -i "$package" 2>/dev/null >> "$OUTPUT_FILE"
    
    # 🌳 TREE UP: Reverse Dependencies (What depends on '$package')
    echo -e "\n☝️ TREE UP (What requires '$package'):" >> "$OUTPUT_FILE"
    apt-rdepends -r "$package" 2>/dev/null >> "$OUTPUT_FILE"
done

echo "✅ Done! All data saved to $OUTPUT_FILE"
