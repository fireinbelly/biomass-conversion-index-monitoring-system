#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO_URL = 'https://raw.githubusercontent.com/fireinbelly/biomass-conversion-index-monitoring-system/main';

console.log('🌱 Biomass Conversion Index Monitoring System');
console.log('==============================================');
console.log('');

// Download and run the interactive installer
try {
    console.log('📥 Downloading installer...');
    
    const installerUrl = `${REPO_URL}/install.sh`;
    // The installer is interactive, so it needs a real stdin: pipe it to a file and run
    // that, rather than `curl | bash` which hands bash the script on stdin.
    const curlCommand = `set -e; t=$(mktemp); curl -sSL --fail "${installerUrl}" -o "$t"; bash "$t"; rm -f "$t"`;
    
    console.log('🚀 Running interactive installer...');
    console.log('');
    
    execSync(curlCommand, { 
        stdio: 'inherit',
        shell: '/bin/bash'
    });
    
} catch (error) {
    console.error('❌ Installation failed:', error.message);
    console.log('');
    console.log('💡 Fallback: Try manual installation:');
    console.log(`   bash <(curl -sSL ${REPO_URL}/install.sh)`);
    process.exit(1);
}