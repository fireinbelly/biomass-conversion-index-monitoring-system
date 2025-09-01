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
    
    const installerUrl = `${REPO_URL}/install-interactive.sh`;
    const curlCommand = `curl -sSL "${installerUrl}" | bash`;
    
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
    console.log(`   curl -sSL ${REPO_URL}/install-interactive.sh | bash`);
    process.exit(1);
}