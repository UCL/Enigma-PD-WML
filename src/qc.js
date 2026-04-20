
const subjectData = {};
let globalSliceSkip = parseInt(document.getElementById('slice-skip-input').value);
const STORAGE_KEY = 'enigma_wml_qc_data_DATASET_NAME_PLACEHOLDER_REG_TYPE_PLACEHOLDER';
const AUTOSAVE_INTERVAL = 30000; // 30 seconds

// Auto-save function
function autoSave() {
    try {
        const dataToSave = {
            timestamp: new Date().toISOString(),
            subjects: subjectData
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(dataToSave));
        console.log('Auto-saved at', new Date().toLocaleTimeString());
    } catch (e) {
        console.error('Auto-save failed:', e);
    }
}

// Restore from localStorage
function restoreFromStorage() {
    try {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) {
            const parsed = JSON.parse(saved);
            const savedTime = new Date(parsed.timestamp);
            const now = new Date();
            const hoursSince = (now - savedTime) / (1000 * 60 * 60);
            
            if (hoursSince < 24) { // Only restore if less than 24 hours old
                const restore = confirm(
                    `Found saved QC data from ${savedTime.toLocaleString()}.\n` +
                    `Do you want to restore your previous work?`
                );
                
                if (restore) {
                    // Restore data for matching subjects
                    for (const subject in parsed.subjects) {
                        if (subjectData[subject]) {
                            subjectData[subject] = {
                                ...subjectData[subject],
                                ...parsed.subjects[subject]
                            };
                        }
                    }
                    
                    // Update UI to reflect restored data
                    updateUIFromData();
                    
                    alert('Previous work restored successfully!');
                    return true;
                }
            } else {
                // Clear old data
                localStorage.removeItem(STORAGE_KEY);
            }
        }
    } catch (e) {
        console.error('Failed to restore data:', e);
    }
    return false;
}

// Update UI elements based on restored data
function updateUIFromData() {
    for (const subject in subjectData) {
        const data = subjectData[subject];
        
        // Skip missing subjects
        if (data.isMissing) continue;
        
        // Restore PASS status
        if (data.isPassed) {
            const button = document.querySelector(`[data-subject="${subject}"] .pass-button`);
            if (button) {
                button.classList.add('clicked');
                button.textContent = 'PASSED';
            }
        }
        
        // Restore FAIL status
        if (data.isFailed) {
            const button = document.querySelector(`[data-subject="${subject}"] .fail-button`);
            if (button) {
                button.classList.add('clicked');
                button.textContent = 'FAILED';
            }
            
            const reasonDropdown = document.getElementById(`reason-${subject}`);
            if (reasonDropdown && data.failureReason) {
                reasonDropdown.value = data.failureReason;
            }
        }
        
        // Restore LATER status
        if (data.isLater) {
            const button = document.querySelector(`[data-subject="${subject}"] .later-button`);
            if (button) {
                button.classList.add('clicked');
                button.textContent = 'FLAGGED FOR LATER QC';
            }
        }
        
        // Restore comments
        if (data.comment) {
            const commentField = document.getElementById(`comment-${subject}`);
            if (commentField) {
                commentField.value = data.comment;
            }
        }
        
        // Restore slice position
        if (data.currentSlice !== undefined) {
            updateImages(subject);
        }
        
        // Restore overlay state
        if (data.showOverlay) {
            const toggle = document.querySelector(`[data-subject="${subject}"] .toggle`);
            if (toggle) {
                toggle.classList.add('active');
            }
            updateImages(subject);
        }
    }
}

// Clear saved data
function clearSavedData() {
    if (confirm('Are you sure you want to clear all saved data? This cannot be undone.')) {
        localStorage.removeItem(STORAGE_KEY);
        alert('Saved data cleared.');
    }
}

document.addEventListener('DOMContentLoaded', function() {
    const subjects = document.querySelectorAll('.subject-container, .missing-subject-container');
    subjects.forEach(container => {
        const subject = container.dataset.subject;
        const totalSlicesElement = container.querySelector('.total-slices');
        const totalSlices = totalSlicesElement ? parseInt(totalSlicesElement.textContent) : 0;
        const isMissing = container.classList.contains('missing-subject-container');
        
        let startingSlice = 65;
        if (isMissing || startingSlice >= totalSlices + 1) {
            startingSlice = 0;
        } else if (startingSlice > totalSlices) {
            startingSlice = totalSlices;
        }
        
        subjectData[subject] = {
            currentSlice: startingSlice,
            totalSlices: totalSlices,
            showOverlay: false,
            isPassed: false,
            isFailed: false,
            isLater: false,
            isMissing: isMissing,
            failureReason: '',
            comment: ''
        };
    });
    
    // Try to restore previous work
    restoreFromStorage();
    
    // Start auto-save interval
    setInterval(autoSave, AUTOSAVE_INTERVAL);
});

function openQCGuide() {
    document.getElementById('qc-guide-module').style.display = 'block';
}

function closeQCGuide() {
    document.getElementById('qc-guide-module').style.display = 'none';
}

window.onclick = function(event) {
    const module = document.getElementById('qc-guide-module');
    if (event.target === module) {
        module.style.display = 'none';
    }
}

function toggleOverlay(subject) {
    const toggle = document.querySelector(`[data-subject="${subject}"] .toggle`);
    const data = subjectData[subject];
    
    data.showOverlay = !data.showOverlay;
    toggle.classList.toggle('active');
    
    updateImages(subject);
}

function updateImages(subject) {
    const img = document.getElementById(`img-${subject}`);
    
    if (!img) {
        console.error(`Image element not found for subject: ${subject}`);
        return;
    }
    
    const data = subjectData[subject];
    if (!data) {
        console.error(`Subject data not found for: ${subject}`);
        return;
    }
    
    const imageType = data.showOverlay ? 'overlay' : 'base';
    
    const currentSrc = img.src;
    const basePath = currentSrc.substring(0, currentSrc.lastIndexOf('/') + 1);
    
    img.src = `${basePath}${data.currentSlice}_${imageType}.png`;
    
    const container = document.querySelector(`[data-subject="${subject}"]`);
    const currentSliceSpan = container ? container.querySelector('.current-slice') : null;
    if (currentSliceSpan) {
        currentSliceSpan.textContent = data.currentSlice;
    }
    
    const slider = document.getElementById(`slider-${subject}`);
    if (slider) {
        slider.value = data.currentSlice;
    }
}

function sliderChange(subject, value) {
    const data = subjectData[subject];
    if (!data) {
        console.error(`Subject data not found for: ${subject}`);
        return;
    }
    
    let sliceNum = parseInt(value);
    
    // Apply slice skip
    sliceNum = Math.round(sliceNum / globalSliceSkip) * globalSliceSkip;
    if (sliceNum > data.totalSlices) sliceNum = data.totalSlices;
    
    if (!isNaN(sliceNum) && sliceNum >= 0 && sliceNum <= data.totalSlices) {
        data.currentSlice = sliceNum;
        updateImages(subject);
    }
}

function jumpToSlice(subject) {
    const data = subjectData[subject];
    const sliceNum = prompt(`Enter slice number (0-${data.totalSlices}):`);
    const slice = parseInt(sliceNum);
    
    if (!isNaN(slice) && slice >= 0 && slice <= data.totalSlices) {
        data.currentSlice = slice;
        updateImages(subject);
    } else {
        alert('Invalid slice number');
    }
}

function togglePass(subject) {
    const button = document.querySelector(`[data-subject="${subject}"] .pass-button`);
    const failButton = document.querySelector(`[data-subject="${subject}"] .fail-button`);
    const laterButton = document.querySelector(`[data-subject="${subject}"] .later-button`);
    const reasonDropdown = document.getElementById(`reason-${subject}`);
    const data = subjectData[subject];
    
    // Clear other statuses (mutually exclusive)
    if (data.isFailed) {
        data.isFailed = false;
        failButton.classList.remove('clicked');
        failButton.textContent = 'Mark as FAIL';
        reasonDropdown.classList.remove('required');
        reasonDropdown.value = '';
        data.failureReason = '';
    }
    
    if (data.isLater) {
        data.isLater = false;
        laterButton.classList.remove('clicked');
        laterButton.textContent = 'Flag for Later QC';
    }
    
    // Toggle PASS
    data.isPassed = !data.isPassed;
    
    if (data.isPassed) {
        button.classList.add('clicked');
        button.textContent = 'PASSED';
    } else {
        button.classList.remove('clicked');
        button.textContent = 'Mark as PASS';
    }
}

function toggleFail(subject) {
    const button = document.querySelector(`[data-subject="${subject}"] .fail-button`);
    const passButton = document.querySelector(`[data-subject="${subject}"] .pass-button`);
    const laterButton = document.querySelector(`[data-subject="${subject}"] .later-button`);
    const reasonDropdown = document.getElementById(`reason-${subject}`);
    const data = subjectData[subject];
    
    // Clear other statuses (mutually exclusive)
    if (data.isPassed) {
        data.isPassed = false;
        passButton.classList.remove('clicked');
        passButton.textContent = 'Mark as PASS';
    }
    
    if (data.isLater) {
        data.isLater = false;
        laterButton.classList.remove('clicked');
        laterButton.textContent = 'Flag for Later QC';
    }
    
    // Toggle FAIL
    data.isFailed = !data.isFailed;
    
    if (data.isFailed) {
        button.classList.add('clicked');
        button.textContent = 'FAILED';
        reasonDropdown.classList.add('required');
    } else {
        button.classList.remove('clicked');
        button.textContent = 'Mark as FAIL';
        reasonDropdown.classList.remove('required');
        reasonDropdown.value = '';
        data.failureReason = '';
    }
}

function toggleLater(subject) {
    const button = document.querySelector(`[data-subject="${subject}"] .later-button`);
    const passButton = document.querySelector(`[data-subject="${subject}"] .pass-button`);
    const failButton = document.querySelector(`[data-subject="${subject}"] .fail-button`);
    const reasonDropdown = document.getElementById(`reason-${subject}`);
    const data = subjectData[subject];
    
    // Clear other statuses (mutually exclusive)
    if (data.isPassed) {
        data.isPassed = false;
        passButton.classList.remove('clicked');
        passButton.textContent = 'Mark as PASS';
    }
    
    if (data.isFailed) {
        data.isFailed = false;
        failButton.classList.remove('clicked');
        failButton.textContent = 'Mark as FAIL';
        reasonDropdown.classList.remove('required');
        reasonDropdown.value = '';
        data.failureReason = '';
    }
    
    // Toggle LATER
    data.isLater = !data.isLater;
    
    if (data.isLater) {
        button.classList.add('clicked');
        button.textContent = 'FLAGGED FOR LATER QC';
    } else {
        button.classList.remove('clicked');
        button.textContent = 'Flag for Later QC';
    }
}

function updateFailureReason(subject, reason) {
    const data = subjectData[subject];
    const reasonDropdown = document.getElementById(`reason-${subject}`);
    const passButton = document.querySelector(`[data-subject="${subject}"] .pass-button`);
    const failButton = document.querySelector(`[data-subject="${subject}"] .fail-button`);
    const laterButton = document.querySelector(`[data-subject="${subject}"] .later-button`);
    
    data.failureReason = reason;
    
    // Auto-mark as FAIL if reason is selected
    if (reason && !data.isFailed) {
        // Clear other statuses
        if (data.isPassed) {
            data.isPassed = false;
            passButton.classList.remove('clicked');
            passButton.textContent = 'Mark as PASS';
        }
        
        if (data.isLater) {
            data.isLater = false;
            laterButton.classList.remove('clicked');
            laterButton.textContent = 'Flag for Later QC';
        }
        
        data.isFailed = true;
        failButton.classList.add('clicked');
        failButton.textContent = 'FAILED';
    }
    
    if (data.isFailed && reason) {
        reasonDropdown.classList.remove('required');
    }
}

document.addEventListener('input', function(e) {
    if (e.target.classList.contains('text-input')) {
        const subject = e.target.id.replace('comment-', '');
        subjectData[subject].comment = e.target.value;
    }
    
    if (e.target.id === 'slice-skip-input') {
        const newSkip = parseInt(e.target.value);
        if (!isNaN(newSkip) && newSkip >= 1 && newSkip <= 10) {
            globalSliceSkip = newSkip;
        }
    }
});

function saveToCSV() {
    let missingReasons = [];
    for (const subject in subjectData) {
        const data = subjectData[subject];
        if (data.isFailed && !data.failureReason) {
            missingReasons.push(subject);
        }
    }
    
    if (missingReasons.length > 0) {
        alert(`Please select a failure reason for the following subjects:\n${missingReasons.join('\n')}`);
        
        missingReasons.forEach(subject => {
            const dropdown = document.getElementById(`reason-${subject}`);
            dropdown.classList.add('required');
        });
        
        return;
    }
    
    // Count subjects by status
    let passCount = 0;
    let failCount = 0;
    let laterCount = 0;
    let missingCount = 0;
    let autoPassCount = 0;
    
    for (const subject in subjectData) {
        const data = subjectData[subject];
        if (data.isMissing) {
            missingCount++;
        } else if (data.isFailed) {
            failCount++;
        } else if (data.isLater) {
            laterCount++;
        } else if (data.isPassed) {
            passCount++;
        } else {
            // Not marked - will be auto-passed
            autoPassCount++;
        }
    }
    
    // Show confirmation with summary
    const confirmMsg = 
        `Ready to save QC results:\n\n` +
        `PASS (marked): ${passCount} | PASS (auto): ${autoPassCount}\n` +
        `FAIL: ${failCount} | FLAG FOR LATER: ${laterCount} | MISSING: ${missingCount}\n\n` +
        `Note: Subjects not marked will auto-save as PASS.\n\n` +
        `Proceed with saving?`;
    
    if (!confirm(confirmMsg)) {
        return;
    }
    
    let csvContent = "Subject,QC Status,Failure Reason,Comments\n";
    
    for (const subject in subjectData) {
        const data = subjectData[subject];
        let status;
        
        if (data.isMissing) {
            status = 'MISSING';
        } else if (data.isFailed) {
            status = 'FAIL';
        } else if (data.isLater) {
            status = 'FLAG_FOR_LATER_QC';
        } else {
            // Auto-pass if not marked
            status = 'PASS';
        }
        
        const failureReason = data.failureReason.replace(/"/g, '""');
        const comment = data.comment.replace(/"/g, '""');
        csvContent += `"${subject}","${status}","${failureReason}","${comment}"\n`;
    }
    
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const dateString = `${year}-${month}-${day}_${hours}-${minutes}`;
    
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `DATASET_NAME_PLACEHOLDER_ENIGMA_WML_QC_REG_LABEL_PLACEHOLDER_${dateString}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    const status = document.getElementById('save-status');
    status.textContent = 'Saved!';
    setTimeout(() => status.textContent = '', 2000);
}

function scrollToSubject(subjectId) {
    if (subjectId) {
        const element = document.getElementById(`subject-${subjectId}`);
        if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'center' });
            document.getElementById('subject-selector').value = '';
            element.style.transform = 'scale(1.01)';
            element.style.transition = 'transform 0.3s ease';
            setTimeout(() => {
                element.style.transform = 'scale(1)';
            }, 500);
        }
    }
}

// Track if user is typing in a text input
let isTypingInInput = false;

// Add focus/blur listeners to all text inputs
document.addEventListener('focusin', function(e) {
    if (e.target.classList.contains('text-input')) {
        isTypingInInput = true;
    }
});

document.addEventListener('focusout', function(e) {
    if (e.target.classList.contains('text-input')) {
        isTypingInInput = false;
    }
});

document.addEventListener('keydown', function(e) {
    // Don't process keyboard shortcuts if user is typing in an input field
    if (isTypingInInput) {
        return;
    }
    
    const subjects = document.querySelectorAll('.subject-container');
    let currentSubject = null;
    
    subjects.forEach(container => {
        const rect = container.getBoundingClientRect();
        const headerHeight = 80;
        if (rect.top <= headerHeight + 100 && rect.bottom >= headerHeight + 100) {
            currentSubject = container.dataset.subject;
        }
    });
    
    if (currentSubject && subjectData[currentSubject]) {
        switch(e.key) {
            case 'ArrowLeft':
                e.preventDefault();
                const leftSlice = Math.max(0, subjectData[currentSubject].currentSlice - globalSliceSkip);
                sliderChange(currentSubject, leftSlice);
                break;
            case 'ArrowRight':
                e.preventDefault();
                const rightSlice = Math.min(subjectData[currentSubject].totalSlices, subjectData[currentSubject].currentSlice + globalSliceSkip);
                sliderChange(currentSubject, rightSlice);
                break;
            case ' ':
                e.preventDefault();
                toggleOverlay(currentSubject);
                break;
        }
    }
});