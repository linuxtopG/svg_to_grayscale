#!/bin/bash
# ============================================
# SVG to Grayscale Converter - Complete Version
# Handles both regular files and symbolic links
# Prevents 'style redefined' errors
# ============================================

INPUT_DIR="$1"
OUTPUT_DIR="${2:-${INPUT_DIR}_grayscale}"

show_help() {
    echo "🎨 SVG to Grayscale Icon Converter"
    echo "=================================="
    echo "Handles:"
    echo "  • Symbolic Links (like 1password.svg -> password-manager.svg)"
    echo "  • Regular SVG Files"
    echo "  • Prevents 'style redefined' errors"
    echo ""
    echo "Usage:"
    echo "  $0 <input_directory> [output_directory]"
    echo ""
    echo "Example:"
    echo "  $0 my-icons"
}

if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ Error: Directory doesn't exist '$INPUT_DIR'"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "🔍 Analyzing directory '$INPUT_DIR'..."
echo ""

# Count all file types
REGULAR_FILES=$(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.svg" -o -iname "*.SVG" \) | wc -l)
SYMBOLIC_LINKS=$(find "$INPUT_DIR" -maxdepth 1 -type l \( -iname "*.svg" -o -iname "*.SVG" \) | wc -l)
TOTAL_FILES=$((REGULAR_FILES + SYMBOLIC_LINKS))

echo "📊 Directory Analysis:"
echo "   📄 Regular files: $REGULAR_FILES"
echo "   🔗 Symbolic links: $SYMBOLIC_LINKS"
echo "   📁 Total files: $TOTAL_FILES"
echo ""

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "⚠️  No SVG files found in this directory"
    exit 1
fi

echo "🚀 Starting comprehensive processing..."
echo "📁 Output directory: $OUTPUT_DIR"
echo ""

# ============================================
# Function to convert a regular SVG file
# ============================================
convert_regular_file() {
    local input_file="$1"
    local output_file="$2"
    local filename="$3"
    
    # Read file content
    local content
    content=$(cat "$input_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "   ❌ Error reading file"
        return 1
    fi
    
    # Check if it's a valid SVG file
    if [[ ! "$content" =~ \<svg ]]; then
        echo "   ⚠️  Not a valid SVG file (copied as is)"
        cp "$input_file" "$output_file"
        return 2
    fi
    
    # 1. Remove any existing style attributes from svg tag
    local new_content="$content"
    local changed=0
    
    # Remove style="anything" from svg tag
    while [[ "$new_content" =~ (\<svg)([^>]*)([[:space:]]style=\"[^\"]*\")([^>]*)(\>) ]]; do
        new_content="${new_content//${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}}"
        changed=1
    done
    
    # 2. Add a single style attribute
    if [[ "$new_content" =~ (\<svg)([^>]*)(\>) ]]; then
        new_content="${new_content//${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}/${BASH_REMATCH[1]}${BASH_REMATCH[2]} style=\"filter: grayscale(100%);\"${BASH_REMATCH[3]}}"
        changed=1
    fi
    
    # 3. Save the new file
    if [ "$changed" -eq 1 ]; then
        echo "$new_content" > "$output_file"
        
        # Verify the result
        if grep -q 'style="filter: grayscale' "$output_file"; then
            local style_count
            style_count=$(grep -o 'style="[^"]*"' "$output_file" | wc -l)
            
            if [ "$style_count" -eq 1 ]; then
                echo "   ✅ Filter added successfully"
                return 0
            else
                echo "   ⚠️  Found $style_count style attributes"
                return 1
            fi
        else
            echo "   ❌ Failed to add filter"
            return 1
        fi
    else
        # If nothing changed, copy the file as is
        cp "$input_file" "$output_file"
        echo "   ⚠️  File not modified"
        return 2
    fi
}

# ============================================
# Function to process a symbolic link
# ============================================
process_symbolic_link() {
    local link_path="$1"
    local output_dir="$2"
    local link_name="$3"
    
    # Get the real target
    local target_file
    target_file=$(readlink -f "$link_path" 2>/dev/null)
    
    if [ -z "$target_file" ] || [ ! -f "$target_file" ]; then
        echo "   ❌ Broken link or target doesn't exist"
        return 1
    fi
    
    local target_name
    target_name=$(basename "$target_file")
    
    # Check if target already exists in output directory
    if [ -f "$output_dir/$target_name" ]; then
        # Converted file already exists, create link to it
        ln -sf "$target_name" "$output_dir/$link_name" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "   🔗 Created link to existing converted file"
            return 0
        else
            return 1
        fi
    fi
    
    # Convert the target file first
    echo "   ↪️  Points to: $target_name"
    
    if convert_regular_file "$target_file" "$output_dir/$target_name" "$target_name"; then
        # Now create symbolic link to the converted file
        ln -sf "$target_name" "$output_dir/$link_name" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "   🔗 Created link to converted file"
            return 0
        else
            echo "   ❌ Failed to create link"
            return 1
        fi
    else
        echo "   ❌ Failed to convert target file"
        return 1
    fi
}

# ============================================
# Main Processing
# ============================================

REGULAR_SUCCESS=0
REGULAR_FAILED=0
LINK_SUCCESS=0
LINK_FAILED=0
UNIQUE_TARGETS=0

echo "🔄 Processing regular files first..."
echo ""

# First: Process all regular files
if [ "$REGULAR_FILES" -gt 0 ]; then
    INDEX=0
    while IFS= read -r -d $'\0' file; do
        INDEX=$((INDEX + 1))
        FILENAME=$(basename "$file")
        OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
        
        printf "\r   [%3d/%d] 📄 %-40s" "$INDEX" "$REGULAR_FILES" "$FILENAME"
        
        if convert_regular_file "$file" "$OUTPUT_FILE" "$FILENAME"; then
            REGULAR_SUCCESS=$((REGULAR_SUCCESS + 1))
        else
            REGULAR_FAILED=$((REGULAR_FAILED + 1))
        fi
    done < <(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.svg" -o -iname "*.SVG" \) -print0)
    
    printf "\n"
else
    echo "   ℹ️  No regular files to process"
fi

echo ""
echo "🔗 Processing symbolic links..."
echo ""

# Second: Process all symbolic links
if [ "$SYMBOLIC_LINKS" -gt 0 ]; then
    # Database to track unique target files
    declare -A TARGETS_CONVERTED
    
    INDEX=0
    while IFS= read -r -d $'\0' link; do
        INDEX=$((INDEX + 1))
        LINK_NAME=$(basename "$link")
        
        printf "\r   [%3d/%d] 🔗 %-40s" "$INDEX" "$SYMBOLIC_LINKS" "$LINK_NAME"
        
        if process_symbolic_link "$link" "$OUTPUT_DIR" "$LINK_NAME"; then
            LINK_SUCCESS=$((LINK_SUCCESS + 1))
            
            # Track unique target files
            TARGET_FILE=$(readlink -f "$link" 2>/dev/null)
            if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
                TARGET_BASENAME=$(basename "$TARGET_FILE")
                if [ -z "${TARGETS_CONVERTED[$TARGET_BASENAME]}" ]; then
                    TARGETS_CONVERTED["$TARGET_BASENAME"]=1
                    UNIQUE_TARGETS=$((UNIQUE_TARGETS + 1))
                fi
            fi
        else
            LINK_FAILED=$((LINK_FAILED + 1))
        fi
    done < <(find "$INPUT_DIR" -maxdepth 1 -type l \( -iname "*.svg" -o -iname "*.SVG" \) -print0)
    
    printf "\n"
else
    echo "   ℹ️  No symbolic links to process"
fi

echo ""
echo "========================================"
echo "🎉 Processing Complete!"
echo "========================================"
echo ""
echo "📊 Detailed Results:"
echo ""
echo "📄 Regular Files:"
echo "   ✅ Successful: $REGULAR_SUCCESS"
echo "   ❌ Failed: $REGULAR_FAILED"
echo "   📁 Total: $REGULAR_FILES"
echo ""
echo "🔗 Symbolic Links:"
echo "   ✅ Successful: $LINK_SUCCESS"
echo "   ❌ Failed: $LINK_FAILED"
echo "   🔗 Total: $SYMBOLIC_LINKS"
echo "   🎯 Unique target files: $UNIQUE_TARGETS"
echo ""
echo "📦 Files in output directory:"
OUTPUT_TOTAL=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.svg" | wc -l)
OUTPUT_REGULAR=$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.svg" | wc -l)
OUTPUT_LINKS=$(find "$OUTPUT_DIR" -maxdepth 1 -type l -name "*.svg" | wc -l)
echo "   📄 Regular files: $OUTPUT_REGULAR"
echo "   🔗 Symbolic links: $OUTPUT_LINKS"
echo "   📁 Total: $OUTPUT_TOTAL"
echo ""
echo "📂 Output location:"
echo "   $OUTPUT_DIR"
echo ""

# Create helper scripts
cat > "$OUTPUT_DIR/cleanup_duplicates.sh" << 'EOF'
#!/bin/bash
# Remove duplicate files and fix broken links

echo "🧹 Cleaning and fixing SVG files..."
echo ""

# 1. Fix broken symbolic links
BROKEN_LINKS=0
for link in *.svg; do
    if [ -L "$link" ] && [ ! -e "$(readlink -f "$link" 2>/dev/null)" ]; then
        echo "🔗 Fixing broken link: $link"
        
        # Look for target file in current directory
        TARGET_NAME=$(basename "$(readlink "$link" 2>/dev/null)" 2>/dev/null)
        if [ -n "$TARGET_NAME" ] && [ -f "$TARGET_NAME" ]; then
            # Recreate the link
            rm "$link"
            ln -sf "$TARGET_NAME" "$link"
            echo "   ✅ Fixed"
        else
            echo "   ❌ Target not found"
        fi
        BROKEN_LINKS=$((BROKEN_LINKS + 1))
    fi
done

# 2. Check for duplicate files (same content)
echo ""
echo "🔍 Looking for duplicate files..."
declare -A FILE_HASHES
DUPLICATES=0

for file in *.svg; do
    if [ -f "$file" ]; then
        HASH=$(md5sum "$file" | cut -d' ' -f1)
        
        if [ -n "${FILE_HASHES[$HASH]}" ]; then
            echo "📄 Duplicate: $file (same as ${FILE_HASHES[$HASH]})"
            DUPLICATES=$((DUPLICATES + 1))
            
            # Suggest deletion
            echo "   💡 Can be removed: rm '$file'"
        else
            FILE_HASHES["$HASH"]="$file"
        fi
    fi
done

echo ""
echo "📊 Results:"
echo "   🔗 Broken links fixed: $BROKEN_LINKS"
echo "   📄 Duplicate files found: $DUPLICATES"
EOF

chmod +x "$OUTPUT_DIR/cleanup_duplicates.sh"

cat > "$OUTPUT_DIR/quick_test.sh" << 'EOF'
#!/bin/bash
# Quick test to display converted SVG files

echo "🔍 Testing converted SVG files..."
echo ""

# Test first 5 files
COUNT=0
for file in *.svg; do
    if [ -f "$file" ]; then
        COUNT=$((COUNT + 1))
        
        # Check if filter was added
        if grep -q 'style="filter: grayscale' "$file"; then
            echo "✅ $file - Filter added"
        else
            echo "❌ $file - No filter"
        fi
        
        if [ "$COUNT" -ge 5 ]; then
            break
        fi
    fi
done

echo ""
echo "💡 To open all files:"
echo "   for f in *.svg; do xdg-open \"\$f\" 2>/dev/null & done"
EOF

chmod +x "$OUTPUT_DIR/quick_test.sh"

cat > "$OUTPUT_DIR/README.md" << EOF
# SVG Grayscale Conversion Results

## Summary
- **Input directory**: $INPUT_DIR
- **Output directory**: $OUTPUT_DIR
- **Conversion date**: $(date)

## Statistics
- Regular files converted: $REGULAR_SUCCESS/$REGULAR_FILES
- Symbolic links processed: $LINK_SUCCESS/$SYMBOLIC_LINKS
- Unique target files: $UNIQUE_TARGETS
- Total output files: $OUTPUT_TOTAL

## What was changed?
Each SVG file now has this attribute added to the first \`<svg>\` tag:
\`\`\`
style="filter: grayscale(100%);"
\`\`\`

This converts colors to grayscale when viewed in a browser or image viewer.

## How to use
1. Open any file in a web browser or SVG viewer
2. All icons will appear in grayscale
3. To restore original colors, remove the \`style\` attribute

## Helper scripts
- \`./cleanup_duplicates.sh\` - Remove duplicate files
- \`./quick_test.sh\` - Test conversion results

## View files
\`\`\`bash
# Open first few files
xdg-open *.svg 2>/dev/null

# Count files
ls *.svg | wc -l

# Check file types
file *.svg | head -10
\`\`\`
EOF

echo "🔧 Helper scripts created in output directory:"
echo "   1. ./cleanup_duplicates.sh - Clean duplicate files"
echo "   2. ./quick_test.sh - Quick test of results"
echo "   3. README.md - Conversion information"
echo ""
echo "💡 If some regular files are missing:"
echo "   They might be in subdirectories. Try:"
echo "   find '$INPUT_DIR' -name '*.svg' -type f"
echo ""
echo "📌 To check a specific file:"
echo "   grep -n 'style=' '$OUTPUT_DIR/filename.svg'"
