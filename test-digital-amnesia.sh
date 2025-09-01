#!/bin/bash
# Test script for the Digital Amnesia command

echo "🧪 Testing Digital Amnesia Command"
echo "=================================="
echo ""

# Set up test environment
TEST_DIR="/tmp/test-biomass-$(date +%s)"
export BIOMASS_DATA_DIR="$TEST_DIR"

echo "📁 Creating test data directory: $TEST_DIR"
mkdir -p "$TEST_DIR"

# Create some fake data files
echo "📝 Creating fake biomass data files..."
for i in {1..5}; do
    DATE=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "-${i} days" +%Y-%m-%d)
    FILE="$TEST_DIR/prompts_${DATE}.jsonl"
    echo '{"timestamp":"2024-01-01T12:00:00","prompt":"test damn","curse_count":1,"found_curses":["damn"],"date":"'$DATE'","hour":12}' > "$FILE"
    echo "   Created: prompts_${DATE}.jsonl"
done

echo ""
echo "📊 Test data created. Files in $TEST_DIR:"
ls -la "$TEST_DIR"

echo ""
echo "🚀 Testing digital-amnesia.py (with --force flag to skip prompts)..."
echo ""

# Run the digital amnesia script
python3 templates/digital-amnesia.py --force

echo ""
echo "✅ Test complete. Checking if files were deleted..."
if [ -z "$(ls -A $TEST_DIR/prompts_*.jsonl 2>/dev/null)" ]; then
    echo "   SUCCESS: All data files were deleted!"
else
    echo "   WARNING: Some files remain:"
    ls -la "$TEST_DIR"
fi

echo ""
echo "🧹 Cleaning up test directory..."
rm -rf "$TEST_DIR"

echo ""
echo "✨ Test complete!"