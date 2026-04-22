#!/bin/bash
# Author: Sunanda Somu
# ENIGMA WML QC: Generates separate HTML files for linear and nonlinear registrations

# ----------- Usage ----------
# ./MAKE_HTML_VER3.sh subjects.txt /path/to/png_dir /path/to/output_dir /path/to/qc_guide_dir [dataset_name]
# Sunanda's cmd: ./MAKE_HTML.sh /scratch/faculty/njahansh/nerds/sunanda/Pipelines/Enigma-PD-WML/scripts/QC/ver3/UCSF_subjects.txt /scratch/faculty/njahansh/nerds/sunanda/Pipelines/Enigma-PD-WML/scripts/QC/ver3/UCSF_PNGS/ /scratch/faculty/njahansh/nerds/sunanda/Pipelines/Enigma-PD-WML/scripts/QC/ver3/ /scratch/faculty/njahansh/nerds/sunanda/Pipelines/Enigma-PD-WML/scripts/QC/ver3/QC_GUIDE_EXAMPLES/ UCSF
# ----------------------------

#### UPDATE THE FOLLOWING TO INTEGRATE WITH EXISTING PIPELINE
#### Please add code for better logging wherever necessary
#### <<START EDIT>>
subjects_file=/path/to/subjects.txt
png_dir=/bids/derivatives/enigma-pd-wml/PNGS/
output_dir=/bids/derivatives/enigma-pd-wml/QC.
qc_guide_dir=/bids/derivatives/enigma-pd-wml/QC/QC_GUIDE_EXAMPLES/
#### <<END EDIT>>

dataset_name=${5:-ENIGMA_WML_QC}
slice_skip=2  # Landing page slice skip is fixed at 2
starting_slice=65 # Landing page slice
subjects_per_html=200 # Each html displays a maximum of 200 subjects/scans

mkdir -p "$output_dir"

subjects=($(cat "$subjects_file"))
total_subjects=${#subjects[@]}
num_html_files=$(( (total_subjects + subjects_per_html - 1) / subjects_per_html ))

png_relative_path=$(realpath --relative-to="$output_dir" "$png_dir")
qc_guide_relative_path=$(realpath --relative-to="$output_dir" "$qc_guide_dir")

echo "========================================="
echo "Generating $num_html_files HTML file(s) for each registration type (linear and nonlinear)"
echo "Subjects per file: $subjects_per_html"
echo "Default slice skip interval: $slice_skip"
echo "========================================="
echo ""

# Function to generate HTML for a specific registration type
generate_html_for_registration() {
    local reg_type=$1  # "lin" or "nonlin"
    local reg_label=$2  # "Linear" or "Nonlinear"
    local batch=$3
    local start_idx=$4
    local end_idx=$5

    # Determine HTML filename
    local file_num
    file_num=$(printf "%02d" $((batch + 1)))
    local current_html="${dataset_name}_ENIGMA_WML_QC_${reg_label}_${file_num}.html"

    echo "Generating $current_html (subjects $((start_idx + 1)) to $end_idx)..."

    # Generate HTML header with CSS
    cat > "$output_dir/${current_html}" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ENIGMA-WML QC - REG_LABEL_PLACEHOLDER</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 80px 20px 20px 20px;
            background: #000000;
            min-height: 100vh;
            color: #ffffff;
        }
        .sticky-header {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 1000;
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: rgba(15, 15, 15, 0.95);
            padding: 15px 25px;
            backdrop-filter: blur(10px);
            box-shadow: 0 2px 20px rgba(74, 222, 128, 0.1);
            border-bottom: 1px solid rgba(74, 222, 128, 0.2);
            flex-wrap: wrap;
            gap: 15px;
        }
        .header-left h1 {
            color: #4ade80;
            text-shadow: 0 0 10px rgba(74, 222, 128, 0.3);
            margin: 0;
            font-size: 20px;
        }
        .header-left .reg-type-badge {
            display: inline-block;
            background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
            color: #ffffff;
            padding: 4px 12px;
            border-radius: 6px;
            font-size: 14px;
            margin-left: 10px;
            font-weight: bold;
        }
        .header-right {
            display: flex;
            align-items: center;
            gap: 15px;
            flex-wrap: wrap;
        }
        .clear-btn {
            padding: 8px 16px;
            background: linear-gradient(135deg, #ff8c00 0%, #ff6347 100%);
            color: #ffffff;
            border: 1px solid rgba(255, 140, 0, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            transition: all 0.3s ease;
            position: relative;
        }
        .clear-btn:hover {
            background: linear-gradient(135deg, #ffa733 0%, #ff8c00 100%);
            box-shadow: 0 4px 15px rgba(255, 140, 0, 0.4);
            transform: translateY(-1px);
        }
        .clear-btn::after {
            content: 'Auto-saving every 30s';
            position: absolute;
            bottom: -35px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(20, 20, 20, 0.95);
            color: #ffffff;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: normal;
            white-space: nowrap;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.3s ease;
            border: 1px solid rgba(255, 140, 0, 0.3);
            z-index: 1001;
        }
        .clear-btn:hover::after {
            opacity: 1;
        }
        .slice-skip-control {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #b0b0b0;
            font-size: 13px;
            background: rgba(40, 40, 40, 0.8);
            padding: 6px 12px;
            border-radius: 6px;
            border: 1px solid rgba(74, 222, 128, 0.3);
        }
        .slice-skip-input {
            width: 50px;
            padding: 4px 6px;
            border: 1px solid rgba(74, 222, 128, 0.3);
            border-radius: 4px;
            font-size: 13px;
            background: rgba(20, 20, 20, 0.9);
            color: #ffffff;
            text-align: center;
        }
        .subject-dropdown, .failure-reason-dropdown {
            padding: 8px 12px;
            background: rgba(40, 40, 40, 0.9);
            color: #ffffff;
            border: 1px solid rgba(74, 222, 128, 0.3);
            border-radius: 6px;
            font-size: 14px;
            min-width: 180px;
            cursor: pointer;
        }
        .failure-reason-dropdown {
            background: rgba(60, 30, 30, 0.9);
            border-color: rgba(255, 68, 68, 0.3);
            min-width: 200px;
            max-width: 220px;
        }
        .failure-reason-dropdown.required {
            border-color: #ff4444;
            box-shadow: 0 0 10px rgba(255, 68, 68, 0.5);
            animation: pulse 1s infinite;
        }
        @keyframes pulse {
            0%, 100% { box-shadow: 0 0 10px rgba(255, 68, 68, 0.5); }
            50% { box-shadow: 0 0 20px rgba(255, 68, 68, 0.8); }
        }
        .qc-guide-button {
            padding: 8px 16px;
            background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
            color: #ffffff;
            border: 1px solid rgba(139, 92, 246, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        .qc-guide-button:hover {
            background: linear-gradient(135deg, #a78bfa 0%, #8b5cf6 100%);
            box-shadow: 0 4px 15px rgba(139, 92, 246, 0.4);
            transform: translateY(-1px);
        }
        .save-btn {
            padding: 8px 16px;
            background: linear-gradient(135deg, #4ade80 0%, #22c55e 100%);
            color: #000000;
            border: 1px solid rgba(74, 222, 128, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        .save-btn:hover {
            background: linear-gradient(135deg, #6ee7a7 0%, #4ade80 100%);
            box-shadow: 0 4px 15px rgba(74, 222, 128, 0.4);
            transform: translateY(-1px);
        }
        .save-status {
            color: #4ade80;
            font-weight: bold;
            font-size: 12px;
            margin-left: 5px;
        }
        .qc-guide-modal {
            display: none;
            position: fixed;
            z-index: 2000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.8);
            overflow-y: auto;
        }
        .qc-guide-content {
            background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
            margin: 5% auto;
            padding: 30px;
            border: 2px solid rgba(139, 92, 246, 0.3);
            border-radius: 12px;
            width: 90%;
            max-width: 1200px;
            box-shadow: 0 8px 40px rgba(139, 92, 246, 0.3);
        }
        .qc-guide-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
            padding-bottom: 15px;
            border-bottom: 2px solid rgba(139, 92, 246, 0.3);
        }
        .qc-guide-header h2 {
            color: #a78bfa;
            margin: 0;
            font-size: 28px;
        }
        .close-guide {
            color: #ffffff;
            font-size: 32px;
            font-weight: bold;
            cursor: pointer;
            transition: color 0.3s;
        }
        .close-guide:hover {
            color: #a78bfa;
        }
        .qc-example {
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(139, 92, 246, 0.2);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .qc-example h3 {
            color: #a78bfa;
            margin-top: 0;
            font-size: 20px;
        }
        .qc-example img {
            width: 100%;
            max-width: 600px;
            border: 2px solid rgba(139, 92, 246, 0.3);
            border-radius: 8px;
            margin: 15px 0;
        }
        .qc-example p {
            color: #cccccc;
            line-height: 1.6;
            margin: 10px 0;
        }
        .missing-subject-container {
            background: rgba(40, 30, 20, 0.8);
            margin-bottom: 30px;
            border-radius: 12px;
            border: 1px solid rgba(255, 165, 0, 0.3);
            overflow: hidden;
        }
        .missing-subject-header {
            background: linear-gradient(90deg, #664d1a 0%, #4d3a1a 100%);
            color: #ffaa44;
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid rgba(255, 165, 0, 0.2);
        }
        .missing-subject-name {
            font-size: 18px;
            font-weight: bold;
            color: #ffaa44;
        }
        .missing-status {
            font-weight: bold;
            font-size: 14px;
            color: #ffffff;
            background: rgba(255, 165, 0, 0.2);
            padding: 5px 10px;
            border-radius: 6px;
            border: 1px solid rgba(255, 165, 0, 0.3);
        }
        .missing-content {
            padding: 20px;
            text-align: center;
            background: #1a1610;
        }
        .missing-info {
            color: #ddaa77;
            font-size: 14px;
            font-family: 'Courier New', monospace;
        }
        .missing-path {
            color: #999999;
            font-size: 12px;
            margin-top: 5px;
        }
        .subject-container {
            background: rgba(20, 20, 20, 0.8);
            margin-bottom: 30px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(74, 222, 128, 0.1);
            border: 1px solid rgba(74, 222, 128, 0.2);
            overflow: hidden;
        }
        .subject-header {
            background: linear-gradient(90deg, #1a1a1a 0%, #2d2d2d 100%);
            color: #ffffff;
            padding: 15px 20px;
            border-bottom: 1px solid rgba(74, 222, 128, 0.2);
        }
        .subject-name {
            font-size: 18px;
            font-weight: bold;
            color: #4ade80;
            flex-shrink: 0;
        }
        .slice-info {
            font-weight: bold;
            font-size: 16px;
            color: #ffffff;
            background: rgba(74, 222, 128, 0.2);
            padding: 5px 10px;
            border-radius: 6px;
            border: 1px solid rgba(74, 222, 128, 0.3);
            flex-shrink: 0;
            white-space: nowrap;
        }
        .toggle-container {
            display: flex;
            align-items: center;
            gap: 10px;
            color: #b0b0b0;
            font-size: 14px;
            flex-shrink: 0;
            white-space: nowrap;
        }
        .toggle {
            position: relative;
            width: 50px;
            height: 25px;
            background-color: #333333;
            border-radius: 12px;
            cursor: pointer;
            transition: background-color 0.3s;
            border: 1px solid rgba(74, 222, 128, 0.4);
        }
        .toggle.active {
            background: linear-gradient(90deg, #4ade80 0%, #22c55e 100%);
            box-shadow: 0 0 15px rgba(74, 222, 128, 0.5);
        }
        .toggle-slider {
            position: absolute;
            top: 2px;
            left: 2px;
            width: 21px;
            height: 21px;
            background: linear-gradient(135deg, #ffffff 0%, #f0f0f0 100%);
            border-radius: 50%;
            transition: transform 0.3s;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.5);
        }
        .toggle.active .toggle-slider {
            transform: translateX(25px);
        }
        .controls-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 10px;
            flex-wrap: nowrap;
            overflow-x: auto;
        }
        .navigation {
            display: flex;
            align-items: center;
            gap: 10px;
            flex: 0 1 auto;
            min-width: 0;
        }
        .slice-slider-container {
            display: flex;
            align-items: center;
            gap: 8px;
            flex: 0 1 auto;
            min-width: 100px;
            max-width: 250px;
        }
        .slice-slider {
            flex: 1;
            height: 6px;
            background: #333333;
            border-radius: 3px;
            outline: none;
            -webkit-appearance: none;
            cursor: pointer;
        }
        .slice-slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            width: 18px;
            height: 18px;
            background: linear-gradient(135deg, #4ade80 0%, #22c55e 100%);
            border-radius: 50%;
            cursor: pointer;
            box-shadow: 0 2px 8px rgba(74, 222, 128, 0.4);
        }
        .slice-slider::-moz-range-thumb {
            width: 18px;
            height: 18px;
            background: linear-gradient(135deg, #4ade80 0%, #22c55e 100%);
            border-radius: 50%;
            cursor: pointer;
            border: none;
            box-shadow: 0 2px 8px rgba(74, 222, 128, 0.4);
        }
        .nav-btn {
            padding: 8px 12px;
            background: linear-gradient(135deg, #4ade80 0%, #22c55e 100%);
            color: #000000;
            border: 1px solid rgba(74, 222, 128, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        .nav-btn:hover {
            background: linear-gradient(135deg, #6ee7a7 0%, #4ade80 100%);
            box-shadow: 0 4px 15px rgba(74, 222, 128, 0.4);
            transform: translateY(-1px);
        }
        .review-controls {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: nowrap;
            flex-shrink: 0;
        }
        .pass-button {
            padding: 8px 12px;
            background: linear-gradient(135deg, #4ade80 0%, #22c55e 100%);
            color: #000000;
            border: 1px solid rgba(74, 222, 128, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        .pass-button:hover {
            background: linear-gradient(135deg, #6ee7a7 0%, #4ade80 100%);
            box-shadow: 0 4px 15px rgba(74, 222, 128, 0.4);
            transform: translateY(-1px);
        }
        .pass-button.clicked {
            background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
            transform: scale(0.95);
            box-shadow: 0 0 20px rgba(22, 163, 74, 0.6);
        }
        .fail-button {
            padding: 8px 12px;
            background: linear-gradient(135deg, #ff4444 0%, #cc0000 100%);
            color: #ffffff;
            border: 1px solid rgba(255, 68, 68, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        .fail-button:hover {
            background: linear-gradient(135deg, #ff6666 0%, #ff4444 100%);
            box-shadow: 0 4px 15px rgba(255, 68, 68, 0.4);
            transform: translateY(-1px);
        }
        .fail-button.clicked {
            background: linear-gradient(135deg, #990000 0%, #660000 100%);
            transform: scale(0.95);
            box-shadow: 0 0 20px rgba(153, 0, 0, 0.6);
        }
        .later-button {
            padding: 8px 12px;
            background: linear-gradient(135deg, #ffa500 0%, #ff8c00 100%);
            color: #000000;
            border: 1px solid rgba(255, 165, 0, 0.4);
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        .later-button:hover {
            background: linear-gradient(135deg, #ffb733 0%, #ffa500 100%);
            box-shadow: 0 4px 15px rgba(255, 165, 0, 0.4);
            transform: translateY(-1px);
        }
        .later-button.clicked {
            background: linear-gradient(135deg, #cc8400 0%, #aa6f00 100%);
            transform: scale(0.95);
            box-shadow: 0 0 20px rgba(204, 132, 0, 0.6);
        }
        .text-input {
            width: 150px;
            padding: 6px 10px;
            border: 1px solid rgba(74, 222, 128, 0.3);
            border-radius: 6px;
            font-size: 12px;
            background: rgba(40, 40, 40, 0.8);
            color: #ffffff;
        }
        .text-input:focus {
            outline: none;
            border-color: #4ade80;
            box-shadow: 0 0 10px rgba(74, 222, 128, 0.3);
        }
        .image-section {
            padding: 20px;
            background: #111111;
            display: flex;
            gap: 20px;
            justify-content: center;
            flex-wrap: wrap;
        }
        .registration-view {
            flex: 1;
            min-width: 300px;
            max-width: 800px;
        }
        .registration-label {
            text-align: center;
            color: #4ade80;
            font-weight: bold;
            font-size: 16px;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .brain-image {
            width: 100%;
            height: auto;
            border: 2px solid rgba(74, 222, 128, 0.3);
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(74, 222, 128, 0.2);
        }
    </style>
</head>
<body>
    <div class="sticky-header">
        <div class="header-left">
            <h1>ENIGMA-WML QC<span class="reg-type-badge">REG_LABEL_PLACEHOLDER Registration</span></h1>
        </div>
        <div class="header-right">
            <div class="slice-skip-control">
                <span>Show every</span>
                <input type="number" class="slice-skip-input" id="slice-skip-input" value="SLICE_SKIP_PLACEHOLDER" min="1" max="10">
                <span>slice(s)</span>
            </div>
            <select class="subject-dropdown" id="subject-selector" onchange="scrollToSubject(this.value)">
                <option value="">Jump to subject...</option>
EOF

    # Edit registration type label placeholder
    sed -i "s/REG_LABEL_PLACEHOLDER/$reg_label/g" "$output_dir/${current_html}"

    # Add subjects to html dropdown
    for ((i=start_idx; i<end_idx; i++)); do
        local subject="${subjects[$i]}"

        local base_count
        base_count=$(ls "$png_dir/$subject/$reg_type"/*_base.png 2>/dev/null | wc -l)
        local overlay_count
        overlay_count=$(ls "$png_dir/$subject/$reg_type"/*_overlay.png 2>/dev/null | wc -l)

        if [ "$base_count" -gt 0 ] && [ "$base_count" -eq "$overlay_count" ]; then
            cat >> "$output_dir/${current_html}" <<EOF
                <option value="$subject">$subject</option>
EOF
        fi
    done

    # Edit slice skip placeholder
    sed -i "s/SLICE_SKIP_PLACEHOLDER/$slice_skip/g" "$output_dir/${current_html}"

    # Add QC Guide
    cat >> "$output_dir/${current_html}" <<EOF
            </select>
            <button class="qc-guide-button" onclick="openQCGuide()">QC Guide</button>
            <button class="save-btn" onclick="saveToCSV()">Save to CSV</button>
            <button class="clear-btn" onclick="clearSavedData()">Clear Auto-Save</button>
            <span class="save-status" id="save-status"></span>
        </div>
    </div>

    <!-- QC Guide Module -->
    <div id="qc-guide-module" class="qc-guide-modal">
        <div class="qc-guide-content">
            <div class="qc-guide-header">
                <h2>Quality Control Guide</h2>
                <span class="close-guide" onclick="closeQCGuide()">&times;</span>
            </div>

            <div class="qc-example">
                <h3>Good Segmentation</h3>
                <img src="$qc_guide_relative_path/good_segmentation.png" alt="Good segmentation">
                <p>A good segmentation accurately captures all visible WML lesions with minimal false positives.</p>
            </div>

            <div class="qc-example">
                <h3>Registration Issue</h3>
                <img src="$qc_guide_relative_path/registration_issue.png" alt="Registration issue">
                <p>Poor alignment between subject's brain and template resulting in distorted shapes or misaligned structures.</p>
            </div>

            <div class="qc-example">
                <h3>Missed Deep WML</h3>
                <img src="$qc_guide_relative_path/missed_deep_wml.png" alt="Missed deep WML">
                <p>Deep white matter lesions away from ventricles are not captured by the segmentation.</p>
            </div>

            <div class="qc-example">
                <h3>Missed Periventricular WML</h3>
                <img src="$qc_guide_relative_path/missed_periventricular_wml.png" alt="Missed periventricular WML">
                <p>Lesions adjacent to the ventricles are not detected.</p>
            </div>

            <div class="qc-example">
                <h3>Missed Deep and Periventricular WML</h3>
                <img src="$qc_guide_relative_path/missed_both_wml.png" alt="Missed both">
                <p>Segmentation fails to capture lesions in both deep white matter and periventricular regions.</p>
            </div>

            <div class="qc-example">
                <h3>Overestimation of WML</h3>
                <img src="$qc_guide_relative_path/overestimation_wml.png" alt="Overestimation">
                <p>Segmentation includes too much tissue, capturing regions that are not truly WML.</p>
            </div>

            <div class="qc-example">
                <h3>Underestimation of WML</h3>
                <img src="$qc_guide_relative_path/underestimation_wml.png" alt="Underestimation">
                <p>Segmentation captures some WML but misses significant portions.</p>
            </div>

            <div class="qc-example">
                <h3>WML Outside of White Matter</h3>
                <img src="$qc_guide_relative_path/wml_outside_white_matter.png" alt="Outside white matter">
                <p>Segmented regions extend beyond white matter boundaries.</p>
            </div>
        </div>
    </div>

EOF

    # Generate subject sections
    for ((i=start_idx; i<end_idx; i++)); do
        local subject="${subjects[$i]}"

        # Count and validate PNGs for registration type
        local base_count
        base_count=$(ls "$png_dir/$subject/$reg_type"/*_base.png 2>/dev/null | wc -l)
        local overlay_count
        overlay_count=$(ls "$png_dir/$subject/$reg_type"/*_overlay.png 2>/dev/null | wc -l)

        local is_valid=0
        local error_msg=""

        if [ "$base_count" -gt 0 ] || [ "$overlay_count" -gt 0 ]; then
            if [ "$base_count" -ne "$overlay_count" ]; then
                error_msg="Count mismatch: base=$base_count, overlay=$overlay_count"
            else
                local missing_pairs=""
                for base_file in "$png_dir/$subject/$reg_type"/*_base.png; do
                    if [ -f "$base_file" ]; then
                        local slice_num
                        slice_num=$(basename "$base_file" | sed 's/_base.png//')
                        local overlay_file="$png_dir/$subject/$reg_type/${slice_num}_overlay.png"
                        if [ ! -f "$overlay_file" ]; then
                            missing_pairs="${missing_pairs}${slice_num} "
                        fi
                    fi
                done
                if [ -n "$missing_pairs" ]; then
                    error_msg="Missing overlay for slices: $missing_pairs"
                else
                    is_valid=1
                fi
            fi
        fi

        # Generate HTML
        if [ "$is_valid" -eq 0 ]; then
            # Missing or incomplete PNGs
            if [ "$base_count" -eq 0 ] && [ "$overlay_count" -eq 0 ]; then
                cat >> "$output_dir/${current_html}" <<EOF
    <div class="missing-subject-container" data-subject="$subject" id="subject-$subject">
        <div class="missing-subject-header">
            <div class="missing-subject-name">$subject</div>
            <div class="missing-status">NO PNG Files</div>
        </div>
        <div class="missing-content">
            <div class="missing-info">No PNG files found for $reg_label registration</div>
            <div class="missing-path">Expected: $png_dir/$subject/$reg_type/</div>
        </div>
    </div>

EOF
            else
                cat >> "$output_dir/${current_html}" <<EOF
    <div class="missing-subject-container" data-subject="$subject" id="subject-$subject">
        <div class="missing-subject-header">
            <div class="missing-subject-name">$subject</div>
            <div class="missing-status">Incomplete PNGs</div>
        </div>
        <div class="missing-content">
            <div class="missing-info">$reg_label registration has incomplete PNGs</div>
            <div class="missing-path">$reg_label (base=$base_count, overlay=$overlay_count): ${error_msg}</div>
        </div>
    </div>

EOF
            fi
        else
            # Valid subject
            local slice_count=$base_count

            local actual_starting_slice=$starting_slice
            if [ "$actual_starting_slice" -ge "$slice_count" ]; then
                actual_starting_slice=$((slice_count - 1))
            fi

            cat >> "$output_dir/${current_html}" <<EOF
    <div class="subject-container" data-subject="$subject" id="subject-$subject">
        <div class="subject-header">
            <div class="controls-row">
                <span class="subject-name">$subject</span>
                <div class="toggle-container">
                    <span>WML OVERLAY OFF</span>
                    <div class="toggle" onclick="toggleOverlay('$subject')">
                        <div class="toggle-slider"></div>
                    </div>
                    <span>ON</span>
                </div>
                <div class="slice-info">
                    Slice: <span class="current-slice">$actual_starting_slice</span> / <span class="total-slices">$((slice_count - 1))</span>
                </div>
                <div class="navigation">
                    <div class="slice-slider-container">
                        <input type="range" class="slice-slider" id="slider-$subject"
                               min="0" max="$((slice_count - 1))" value="$actual_starting_slice"
                               onchange="sliderChange('$subject', this.value)"
                               oninput="sliderChange('$subject', this.value)">
                    </div>
                    <button class="nav-btn" onclick="jumpToSlice('$subject')">Jump to Slice</button>
                </div>
                <div class="review-controls">
                    <button class="pass-button" onclick="togglePass('$subject')">Mark as PASS</button>
                    <button class="fail-button" onclick="toggleFail('$subject')">Mark as FAIL</button>
                    <button class="later-button" onclick="toggleLater('$subject')">Flag for Later QC</button>
                    <select class="failure-reason-dropdown" id="reason-$subject" onchange="updateFailureReason('$subject', this.value)">
                        <option value="">Select failure reason...</option>
                        <option value="${reg_label} Registration Issue">${reg_label} Registration Issue</option>
                        <option value="Missed Deep WML">Missed Deep WML</option>
                        <option value="Missed Periventricular WML">Missed Periventricular WML</option>
                        <option value="Missed Deep and Periventricular WML">Missed Deep and Periventricular WML</option>
                        <option value="Overestimation of WML">Overestimation of WML</option>
                        <option value="Underestimation of WML">Underestimation of WML</option>
                        <option value="WML Outside of White Matter">WML Outside of White Matter</option>
                        <option value="Other Issue">Other Issue</option>
                    </select>
                    <input type="text" class="text-input" id="comment-$subject" placeholder="Additional comments...">
                </div>
            </div>
        </div>

        <div class="image-section">
            <div class="registration-view">
                <div class="registration-label">$reg_label Registration</div>
                <img class="brain-image" id="img-$subject" src="$png_relative_path/$subject/$reg_type/${actual_starting_slice}_base.png" alt="$reg_label">
            </div>
        </div>
    </div>

EOF
        fi
    done

    # Add JavaScript with unique storage key per registration type
    cat >> "$output_dir/${current_html}" <<'JSEOF'
    <script>
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
    </script>
JSEOF

    # Replace placeholders in JavaScript
    sed -i "s/DATASET_NAME_PLACEHOLDER/$dataset_name/g" "$output_dir/${current_html}"
    sed -i "s/REG_TYPE_PLACEHOLDER/$reg_type/g" "$output_dir/${current_html}"
    sed -i "s/REG_LABEL_PLACEHOLDER/$reg_label/g" "$output_dir/${current_html}"

    # Close HTML
    cat >> "$output_dir/${current_html}" <<'EOF'
</body>
</html>
EOF
}

# Loop through batches and generate HTML files for both registration types
for ((batch=0; batch<num_html_files; batch++)); do
    start_idx=$((batch * subjects_per_html))
    end_idx=$(( (batch + 1) * subjects_per_html ))
    if [ $end_idx -gt $total_subjects ]; then
        end_idx=$total_subjects
    fi

    # Generate Linear HTML
    generate_html_for_registration "lin" "Linear" $batch $start_idx $end_idx

    # Generate Nonlinear HTML
    generate_html_for_registration "nonlin" "Nonlinear" $batch $start_idx $end_idx
done

# Summary
echo ""
echo "========================================="
echo "HTML Generation Complete!"
echo "Generated $((num_html_files * 2)) file(s) total:"
echo ""
echo "Linear Registration Files:"
for ((b=0; b<num_html_files; b++)); do
    file_num=$(printf "%02d" $((b + 1)))
    echo "  - ${dataset_name}_ENIGMA_WML_QC_Linear_${file_num}.html"
done
echo ""
echo "Nonlinear Registration Files:"
for ((b=0; b<num_html_files; b++)); do
    file_num=$(printf "%02d" $((b + 1)))
    echo "  - ${dataset_name}_ENIGMA_WML_QC_Nonlinear_${file_num}.html"
done
echo ""

# Generate summary of subjects
valid_linear=0
valid_nonlinear=0
valid_both=0
no_pngs=()
missing_linear=()
missing_nonlinear=()

for subject in "${subjects[@]}"; do
    nonlin_base_count=$(ls "$png_dir/$subject/nonlin"/*_base.png 2>/dev/null | wc -l)
    nonlin_overlay_count=$(ls "$png_dir/$subject/nonlin"/*_overlay.png 2>/dev/null | wc -l)
    lin_base_count=$(ls "$png_dir/$subject/lin"/*_base.png 2>/dev/null | wc -l)
    lin_overlay_count=$(ls "$png_dir/$subject/lin"/*_overlay.png 2>/dev/null | wc -l)

    nonlin_ok=0
    lin_ok=0

    if [ "$nonlin_base_count" -gt 0 ] && [ "$nonlin_base_count" -eq "$nonlin_overlay_count" ]; then
        nonlin_ok=1
        ((valid_nonlinear++))
    fi

    if [ "$lin_base_count" -gt 0 ] && [ "$lin_base_count" -eq "$lin_overlay_count" ]; then
        lin_ok=1
        ((valid_linear++))
    fi

    if [ "$nonlin_ok" -eq 1 ] && [ "$lin_ok" -eq 1 ]; then
        ((valid_both++))
    elif [ "$nonlin_base_count" -eq 0 ] && [ "$nonlin_overlay_count" -eq 0 ] && [ "$lin_base_count" -eq 0 ] && [ "$lin_overlay_count" -eq 0 ]; then
        no_pngs+=("$subject")
    else
        if [ "$lin_ok" -eq 0 ] && { [ "$lin_base_count" -gt 0 ] || [ "$lin_overlay_count" -gt 0 ]; }; then
            missing_linear+=("$subject (base=$lin_base_count, overlay=$lin_overlay_count)")
        fi
        if [ "$nonlin_ok" -eq 0 ] && { [ "$nonlin_base_count" -gt 0 ] || [ "$nonlin_overlay_count" -gt 0 ]; }; then
            missing_nonlinear+=("$subject (base=$nonlin_base_count, overlay=$nonlin_overlay_count)")
        fi
    fi
done

echo "Subjects with valid LINEAR PNGs: $valid_linear"
echo "Subjects with valid NONLINEAR PNGs: $valid_nonlinear"
echo "Subjects with BOTH valid: $valid_both"
echo ""

if [ ${#no_pngs[@]} -gt 0 ]; then
    echo "Subjects with NO PNGs at all (${#no_pngs[@]}):"
    for subj in "${no_pngs[@]}"; do
        echo "  - $subj"
    done
    echo ""
fi

if [ ${#missing_linear[@]} -gt 0 ]; then
    echo "Subjects with incomplete LINEAR PNGs (${#missing_linear[@]}):"
    for subj in "${missing_linear[@]}"; do
        echo "  - $subj"
    done
    echo ""
fi

if [ ${#missing_nonlinear[@]} -gt 0 ]; then
    echo "Subjects with incomplete NONLINEAR PNGs (${#missing_nonlinear[@]}):"
    for subj in "${missing_nonlinear[@]}"; do
        echo "  - $subj"
    done
    echo ""
fi

echo "========================================="
