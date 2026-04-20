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
    local file_num=$(printf "%02d" $((batch + 1)))
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
    <link href="qc-styles.css" rel="stylesheet" />
    <script defer src="qc.js"></script>
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

        local base_count=$(ls "$png_dir/$subject/$reg_type"/*_base.png 2>/dev/null | wc -l)
        local overlay_count=$(ls "$png_dir/$subject/$reg_type"/*_overlay.png 2>/dev/null | wc -l)

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
        local base_count=$(ls "$png_dir/$subject/$reg_type"/*_base.png 2>/dev/null | wc -l)
        local overlay_count=$(ls "$png_dir/$subject/$reg_type"/*_overlay.png 2>/dev/null | wc -l)

        local is_valid=0
        local error_msg=""

        if [ "$base_count" -gt 0 ] || [ "$overlay_count" -gt 0 ]; then
            if [ "$base_count" -ne "$overlay_count" ]; then
                error_msg="Count mismatch: base=$base_count, overlay=$overlay_count"
            else
                local missing_pairs=""
                for base_file in "$png_dir/$subject/$reg_type"/*_base.png; do
                    if [ -f "$base_file" ]; then
                        local slice_num=$(basename "$base_file" | sed 's/_base.png//')
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

    # Replace placeholders in JavaScript
    sed -i "s/DATASET_NAME_PLACEHOLDER/$dataset_name/g" "$output_dir/qc.js"
    sed -i "s/REG_TYPE_PLACEHOLDER/$reg_type/g" "$output_dir/qc.js"
    sed -i "s/REG_LABEL_PLACEHOLDER/$reg_label/g" "$output_dir/qc.js"

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
        if [ "$lin_ok" -eq 0 ] && [ "$lin_base_count" -gt 0 -o "$lin_overlay_count" -gt 0 ]; then
            missing_linear+=("$subject (base=$lin_base_count, overlay=$lin_overlay_count)")
        fi
        if [ "$nonlin_ok" -eq 0 ] && [ "$nonlin_base_count" -gt 0 -o "$nonlin_overlay_count" -gt 0 ]; then
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
