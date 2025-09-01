#!/usr/bin/env python3
"""
Internationalization (i18n) module for Biomass Conversion Index Monitoring System
Handles loading and formatting localized strings
"""
import json
import os
from pathlib import Path

class I18n:
    def __init__(self, lang=None):
        self.lang = lang or self._detect_language()
        self.strings = self._load_strings()
    
    def _detect_language(self):
        """Detect language from environment variables"""
        # Check common environment variables in order of preference
        for env_var in ['LC_MESSAGES', 'LC_ALL', 'LANG']:
            if env_var in os.environ:
                locale = os.environ[env_var]
                if locale:
                    # Extract language code (e.g., 'es_ES.UTF-8' -> 'es')
                    lang = locale.split('_')[0].split('.')[0]
                    if lang and len(lang) == 2:
                        return lang
        
        # Default to English
        return 'en'
    
    def _load_strings(self):
        """Load strings for the detected/specified language"""
        # Get the directory where this script is located
        script_dir = Path(__file__).parent
        locales_dir = script_dir / 'locales'
        
        # Try to load the requested language
        lang_file = locales_dir / f'{self.lang}.json'
        if lang_file.exists():
            try:
                with open(lang_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        
        # Fallback to English
        en_file = locales_dir / 'en.json'
        try:
            with open(en_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            # Ultimate fallback: empty dict
            return {}
    
    def get(self, key_path, **kwargs):
        """
        Get a localized string by key path (e.g., 'stats.title')
        Supports string formatting with kwargs
        """
        keys = key_path.split('.')
        value = self.strings
        
        # Navigate through the nested dictionary
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                # Return the key path if not found (for debugging)
                return f"[{key_path}]"
        
        # If it's a string, format it with provided kwargs
        if isinstance(value, str) and kwargs:
            try:
                return value.format(**kwargs)
            except (KeyError, ValueError):
                # If formatting fails, return unformatted string
                return value
        
        return value
    
    def get_list(self, key_path):
        """Get a list value (e.g., for curse words)"""
        value = self.get(key_path)
        if isinstance(value, list):
            return value
        return []

# Global instance - can be overridden by setting environment variables
_i18n = None

def init_i18n(lang=None):
    """Initialize the global i18n instance"""
    global _i18n
    _i18n = I18n(lang)
    return _i18n

def get_i18n():
    """Get the global i18n instance, initializing if needed"""
    global _i18n
    if _i18n is None:
        _i18n = I18n()
    return _i18n

def _(key_path, **kwargs):
    """Shorthand function for getting localized strings"""
    return get_i18n().get(key_path, **kwargs)

def _list(key_path):
    """Shorthand function for getting localized lists"""
    return get_i18n().get_list(key_path)

# Command line support for testing
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        lang = sys.argv[1]
        i18n = I18n(lang)
        print(f"Testing i18n with language: {lang}")
        print(f"App name: {i18n.get('app.name')}")
        print(f"Install title: {i18n.get('install.title')}")
        print(f"Stats title: {i18n.get('stats.title', period='Daily')}")
    else:
        print("Usage: python3 i18n.py [language_code]")
        print("Example: python3 i18n.py es")