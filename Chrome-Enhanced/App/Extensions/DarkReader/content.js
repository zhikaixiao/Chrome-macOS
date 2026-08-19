// Dark Reader Content Script
(function() {
    'use strict';
    
    function applyDarkReader(settings) {
        if (!settings || !settings.enabled) {
            if (typeof DarkReader !== 'undefined') {
                DarkReader.disable();
            }
            return;
        }
        
        const theme = {
            brightness: settings.brightness || 100,
            contrast: settings.contrast || 100,
            sepia: settings.sepia || 0
        };
        
        if (settings.mode === 'auto') {
            DarkReader.auto(theme);
        } else {
            DarkReader.enable(theme);
        }
    }
    
    if (typeof chrome !== 'undefined' && chrome.storage && chrome.storage.local) {
        chrome.storage.local.get(['darkreader_settings'], function(result) {
            const settings = result.darkreader_settings || { enabled: false, mode: 'manual', brightness: 100, contrast: 100 };
            applyDarkReader(settings);
        });
        
        chrome.storage.onChanged.addListener(function(changes, areaName) {
            if (areaName === 'local' && changes.darkreader_settings) {
                applyDarkReader(changes.darkreader_settings.newValue);
            }
        });
    }
})();