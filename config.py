#!/usr/bin/env python3
"""
Configuration management for Biomass Conversion Index Monitoring System
Handles user preferences, language settings, and persistent configuration
"""
import json
import os
from pathlib import Path

class Config:
    def __init__(self, config_path=None):
        self.config_path = Path(config_path or Path.home() / '.biomass-config.json')
        self.config = self._load_config()
        self.languages = self._load_languages()
    
    def _load_config(self):
        """Load user configuration from file"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        
        # Default configuration
        return {
            "language": None,  # Will be set during installation
            "install_type": "user",
            "data_dir": str(Path.home() / '.claude' / 'prompt-data'),
            "version": "1.0.0",
            "created": None,
            "last_updated": None
        }
    
    def _load_languages(self):
        """Load available languages configuration"""
        # Try to find languages.json in the same directory as this script
        script_dir = Path(__file__).parent
        lang_file = script_dir / 'languages.json'
        
        if lang_file.exists():
            try:
                with open(lang_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        
        # Fallback to minimal English-only config
        return {
            "available_languages": [
                {
                    "code": "en",
                    "name": "English", 
                    "native_name": "English",
                    "flag": "🇺🇸",
                    "status": "complete"
                }
            ],
            "default_language": "en",
            "fallback_language": "en",
            "auto_detect": True
        }
    
    def get_available_languages(self, status_filter=None):
        """Get list of available languages, optionally filtered by status"""
        languages = self.languages.get('available_languages', [])
        if status_filter:
            languages = [lang for lang in languages if lang.get('status') == status_filter]
        return languages
    
    def get_language_by_code(self, code):
        """Get language info by code"""
        for lang in self.get_available_languages():
            if lang['code'] == code:
                return lang
        return None
    
    def detect_system_language(self):
        """Detect system language from environment"""
        for env_var in ['LC_MESSAGES', 'LC_ALL', 'LANG']:
            if env_var in os.environ:
                locale = os.environ[env_var]
                if locale:
                    # Extract language code (e.g., 'es_ES.UTF-8' -> 'es')
                    lang = locale.split('_')[0].split('.')[0]
                    if len(lang) == 2 and self.get_language_by_code(lang):
                        return lang
        return self.languages.get('default_language', 'en')
    
    def get_preferred_language(self, cli_override=None):
        """
        Get preferred language based on priority:
        1. CLI override (--lang flag)
        2. User config file
        3. Environment variables (if auto_detect enabled)
        4. Default language
        """
        # 1. CLI override has highest priority
        if cli_override and self.get_language_by_code(cli_override):
            return cli_override
        
        # 2. User config file
        if self.config.get('language') and self.get_language_by_code(self.config['language']):
            return self.config['language']
        
        # 3. Environment detection (if enabled)
        if self.languages.get('auto_detect', True):
            detected = self.detect_system_language()
            if detected and self.get_language_by_code(detected):
                return detected
        
        # 4. Fallback to default
        return self.languages.get('fallback_language', 'en')
    
    def set_language(self, language_code):
        """Set user's preferred language"""
        if self.get_language_by_code(language_code):
            self.config['language'] = language_code
            return True
        return False
    
    def set_install_type(self, install_type):
        """Set installation type (project or user)"""
        if install_type in ['project', 'user']:
            self.config['install_type'] = install_type
            return True
        return False
    
    def set_data_dir(self, data_dir):
        """Set data directory path"""
        self.config['data_dir'] = str(data_dir)
    
    def save_config(self):
        """Save configuration to file"""
        from datetime import datetime
        
        # Update timestamps
        now = datetime.now().isoformat()
        if not self.config.get('created'):
            self.config['created'] = now
        self.config['last_updated'] = now
        
        # Ensure parent directory exists
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            return True
        except IOError:
            return False
    
    def get_config_summary(self):
        """Get a summary of current configuration"""
        lang = self.get_language_by_code(self.config.get('language', 'en'))
        return {
            'language': lang['native_name'] if lang else 'Unknown',
            'language_code': self.config.get('language', 'en'),
            'install_type': self.config.get('install_type', 'user'),
            'data_dir': self.config.get('data_dir'),
            'config_path': str(self.config_path)
        }

# Global config instance
_config = None

def get_config():
    """Get the global config instance, initializing if needed"""
    global _config
    if _config is None:
        _config = Config()
    return _config

def init_config(config_path=None):
    """Initialize the global config instance"""
    global _config
    _config = Config(config_path)
    return _config

# Command line support for testing
if __name__ == "__main__":
    import sys
    
    config = Config()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == 'languages':
            print("Available languages:")
            for lang in config.get_available_languages():
                status = f"[{lang['status']}]"
                print(f"  {lang['flag']} {lang['code']}: {lang['native_name']} {status}")
        
        elif sys.argv[1] == 'detect':
            detected = config.detect_system_language()
            preferred = config.get_preferred_language()
            print(f"System detected: {detected}")
            print(f"Preferred: {preferred}")
        
        elif sys.argv[1] == 'config':
            summary = config.get_config_summary()
            print("Current configuration:")
            for key, value in summary.items():
                print(f"  {key}: {value}")
    
    else:
        print("Usage: python3 config.py [languages|detect|config]")
        print("  languages - Show available languages")
        print("  detect    - Show language detection")
        print("  config    - Show current configuration")