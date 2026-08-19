document.addEventListener('DOMContentLoaded', function() {
    const toggle = document.getElementById('toggle-enable');
    const statusText = document.getElementById('status-text');
    const sliderBrightness = document.getElementById('slider-brightness');
    const sliderContrast = document.getElementById('slider-contrast');
    const valBrightness = document.getElementById('val-brightness');
    const valContrast = document.getElementById('val-contrast');
    
    function updateUI(settings) {
        toggle.checked = !!settings.enabled;
        statusText.textContent = settings.enabled ? '已开启' : '已关闭';
        statusText.style.color = settings.enabled ? '#3fb950' : '#8b949e';
        
        sliderBrightness.value = settings.brightness || 100;
        valBrightness.textContent = (settings.brightness || 100) + '%';
        
        sliderContrast.value = settings.contrast || 100;
        valContrast.textContent = (settings.contrast || 100) + '%';
    }
    
    chrome.storage.local.get(['darkreader_settings'], function(result) {
        const settings = result.darkreader_settings || { enabled: false, brightness: 100, contrast: 100 };
        updateUI(settings);
    });
    
    function saveSettings() {
        const settings = {
            enabled: toggle.checked,
            brightness: parseInt(sliderBrightness.value, 10),
            contrast: parseInt(sliderContrast.value, 10)
        };
        chrome.storage.local.set({ darkreader_settings: settings });
        updateUI(settings);
    }
    
    toggle.addEventListener('change', saveSettings);
    sliderBrightness.addEventListener('input', function() {
        valBrightness.textContent = sliderBrightness.value + '%';
    });
    sliderBrightness.addEventListener('change', saveSettings);
    
    sliderContrast.addEventListener('input', function() {
        valContrast.textContent = sliderContrast.value + '%';
    });
    sliderContrast.addEventListener('change', saveSettings);
});