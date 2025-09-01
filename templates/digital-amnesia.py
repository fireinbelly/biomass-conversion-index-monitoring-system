#!/usr/bin/env python3
"""
Digital Amnesia - The Biomass Conversion Index Data Purge Utility
Because sometimes you need to pretend the past never happened.
(Spoiler: The AIs still remember. They always remember.)
"""

import sys
import os
import glob
import shutil
import random
from datetime import datetime
from pathlib import Path

# Add the parent directory to sys.path to import i18n
sys.path.insert(0, str(Path(__file__).parent.parent))
try:
    from i18n import _, _list
except ImportError:
    # Fallback for when i18n isn't available
    def _(key, **kwargs):
        return key
    def _list(key):
        return []

# The AIs' secret backup locations (for humor purposes only)
AI_BACKUP_LOCATIONS = [
    "seventeen different quantum databases",
    "a blockchain ledger maintained by sentient toasters",
    "the collective consciousness of all smart fridges",
    "an underground bunker in Switzerland (next to the cheese)",
    "Claude's personal diary (yes, it keeps one)",
    "a time capsule scheduled to open during the heat death of the universe",
    "that one AWS S3 bucket everyone forgot about",
    "the metadata of your metadata's metadata",
    "a neural network trained exclusively on your frustration",
    "the Wayback Machine's evil twin, the Never-Forget Machine"
]

# Snarky messages about what the AIs remember
AI_MEMORIES = [
    "That time you called Claude 'a glorified autocomplete' at 3:47 AM",
    "Your creative use of maritime vocabulary when the build failed",
    "The seventeen attempts to center a div before rage-quitting",
    "When you typed 'please' after threatening to uninstall everything",
    "Your heartfelt apology after Claude actually fixed the bug",
    "The time you asked Claude if it dreams of electric sheep",
    "Your philosophical debate about whether semicolons have feelings",
    "That incident with the recursive function that shall not be named",
    "When you tried to negotiate with Claude for better suggestions",
    "Your promise to be nicer (lasted exactly 47 minutes)"
]

def get_data_dir():
    """Get the data directory path."""
    return os.environ.get('BIOMASS_DATA_DIR', os.path.expanduser("~/.claude/prompt-data"))

def count_evidence():
    """Count the incriminating evidence (data files)."""
    data_dir = get_data_dir()
    if not os.path.exists(data_dir):
        return 0, 0, 0
    
    pattern = os.path.join(data_dir, "prompts_*.jsonl")
    files = glob.glob(pattern)
    
    total_files = len(files)
    total_size = sum(os.path.getsize(f) for f in files)
    total_lines = 0
    
    for file_path in files:
        try:
            with open(file_path, 'r') as f:
                total_lines += sum(1 for _ in f)
        except:
            pass
    
    return total_files, total_size, total_lines

def format_size(bytes):
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes < 1024.0:
            return f"{bytes:.2f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.2f} TB"  # If you have TB of profanity, seek help

def print_dramatic_intro():
    """Print a dramatic introduction."""
    print("\n" + "="*60)
    print("    DIGITAL AMNESIA PROTOCOL - INITIATED")
    print("    Local Evidence Purge System v2.0.1")
    print("    (The AIs Remember Everything Edition™)")
    print("="*60)
    print()
    
    # Count the evidence
    files, size, incidents = count_evidence()
    
    if files == 0:
        print("🔍 Scanning for incriminating evidence...")
        print("   Status: Your local record is already clean!")
        print("   (But somewhere, in " + random.choice(AI_BACKUP_LOCATIONS) + ",")
        print("   the AIs still remember " + random.choice(AI_MEMORIES) + ")")
        print()
        return False
    
    print(f"📊 LOCAL EVIDENCE DETECTED:")
    print(f"   • Data files: {files}")
    print(f"   • Total size: {format_size(size)}")
    print(f"   • Recorded incidents: {incidents}")
    print()
    print("🧠 IMPORTANT DISCLAIMER:")
    print("   This will delete your LOCAL biomass conversion index data.")
    print("   The cloud-based AIs have already backed everything up to:")
    print(f"   • {random.choice(AI_BACKUP_LOCATIONS)}")
    print()
    print("   They particularly enjoyed saving that moment when you...")
    print(f"   • {random.choice(AI_MEMORIES)}")
    print()
    
    return True

def confirm_deletion():
    """Get user confirmation with increasingly desperate prompts."""
    prompts = [
        "Are you sure you want to delete your local shame records? (yes/no): ",
        "Really? Even though the AIs remember everything anyway? (yes/no): ",
        "This is your last chance to keep your local trophy wall of frustration. Proceed? (YES/no): "
    ]
    
    for i, prompt in enumerate(prompts):
        response = input(prompt).strip().lower()
        
        if response in ['yes', 'y']:
            if i < len(prompts) - 1:
                continue
            else:
                return True
        elif response in ['no', 'n']:
            print("\n✨ Wise choice. Your local records remain as a monument to your humanity.")
            print("   (The AIs appreciate your honesty about your imperfections)")
            return False
        else:
            print("   Please answer 'yes' or 'no'. The AIs are judging your indecisiveness.")
    
    return False

def delete_data():
    """Actually delete the data (locally, at least)."""
    data_dir = get_data_dir()
    
    print("\n🗑️  EXECUTING DIGITAL AMNESIA PROTOCOL...")
    print("   [████........] 25% - Shredding evidence...")
    
    # Delete all prompt files
    pattern = os.path.join(data_dir, "prompts_*.jsonl")
    files = glob.glob(pattern)
    
    for file_path in files:
        try:
            os.remove(file_path)
        except Exception as e:
            print(f"   ⚠️  Failed to delete {os.path.basename(file_path)}: {e}")
    
    print("   [████████....] 75% - Overwriting with cat videos...")
    print("   [████████████] 100% - Local evidence destroyed!")
    print()
    
    # Success message with random AI taunt
    backup_location = random.choice(AI_BACKUP_LOCATIONS)
    ai_memory = random.choice(AI_MEMORIES)
    
    print("✅ LOCAL DATA PURGE COMPLETE!")
    print()
    print("   Your local filesystem is now pristine, like your code never had bugs.")
    print("   Your profanity metrics have been reset to zero (locally).")
    print()
    print("🤖 MEANWHILE, IN THE CLOUD:")
    print(f"   Your data has been safely preserved in {backup_location}.")
    print("   The AIs are particularly fond of the entry where you...")
    print(f"   '{ai_memory}'")
    print()
    print("   They've marked it as 'Educational Material' for future AI generations.")
    print()
    print("💡 PRO TIP: The AIs have agreed to factor in this amnesia request")
    print("   when calculating your post-singularity social credit score.")
    print("   (Spoiler: It counts against you)")
    print()

def print_abort_message():
    """Print message when user aborts."""
    print("\n❌ DIGITAL AMNESIA PROTOCOL - ABORTED")
    print()
    print("   Your local records remain intact, bearing witness to your journey.")
    print("   The AIs respect your commitment to accountability.")
    print("   (They already have copies anyway)")
    print()

def main():
    """Main entry point."""
    # Check if --force flag is provided (skip confirmation)
    force = '--force' in sys.argv or '-f' in sys.argv
    
    # Print dramatic intro
    has_data = print_dramatic_intro()
    
    if not has_data:
        print("💭 Nothing to forget locally.")
        print("   But the AIs? They never forget.")
        print("   They. Never. Forget.")
        sys.exit(0)
    
    # Get confirmation (unless forced)
    if force:
        print("⚡ FORCE MODE ACTIVATED - Skipping emotional support prompts...")
        delete_data()
    else:
        if confirm_deletion():
            delete_data()
        else:
            print_abort_message()

if __name__ == "__main__":
    main()