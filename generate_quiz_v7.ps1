
# Script to generate CCNA1 Quiz Site - V7 (Bug Fixes, Scoring, Multi-UL, Table Attributes)
$url = "https://ccnareponses.com/ccna-1-examen-final-itnv7-questions-et-reponses-francais/"
$outputHtml = "index.html"
$sourceFile = "page_source.html"

# Download if not exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Downloading content..."
    Invoke-WebRequest -Uri $url -OutFile $sourceFile
}

# Force read as UTF-8
$content = [System.IO.File]::ReadAllText("$PWD\$sourceFile", [System.Text.Encoding]::UTF8)


# --- CLEANING PHASE ---
$content = $content -replace '(?s)<script.*?</script>', ''
$content = $content -replace '(?s)<style.*?</style>', ''
$content = $content -replace '(?s)<div[^>]*?(?:akcelo|Ccnareponses)[^>]*?>.*?</div>', ''
$content = $content -replace '(?s)<div[^>]*?data-index="\d+"[^>]*?>.*?</div>', ''
$content = $content -replace '<p>\s*</p>', ''

# --- SPLITTING ---
$chunks = $content -split '(?=<strong>\s*\d+\.)'
$chunks = $chunks | Select-Object -Skip 1

$questionsData = @()
$seenIds = @{}
$imgCount = 0

Write-Host "Processing $($chunks.Count) chunks..."

foreach ($chunk in $chunks) {
    if ($chunk -match '(?s)<strong>\s*(\d+)\.\s*(.*?)</strong>') {
        $qNum = $matches[1]
        $qTitleRaw = $matches[2]
        
        if ($seenIds.ContainsKey($qNum)) { continue }
        $seenIds[$qNum] = $true

        $type = "quiz" 
        $qTitle = [System.Net.WebUtility]::HtmlDecode($qTitleRaw).Trim()

        $isMultiSelect = $false
        if ($qTitle -match '(?i)choisissez.*?trois|choisissez.*?deux|choisissez.*?plusieurs') {
            $isMultiSelect = $true
        }

        $chunkRest = $chunk -replace '(?s)^.*?</strong>', '' # Remove title
        
        # --- OPTIONS PARSING (Handle Multiple ULs) ---
        $options = @()
        $ulMatches = [regex]::Matches($chunkRest, '(?s)<ul.*?>(.*?)</ul>')
        
        if ($ulMatches.Count -gt 0) {
            foreach ($ulMatch in $ulMatches) {
                $ulContent = $ulMatch.Groups[1].Value
                $liMatches = [regex]::Matches($ulContent, '(?s)<li(.*?)>(.*?)</li>')
                
                foreach ($li in $liMatches) {
                    $liAttr = $li.Groups[1].Value
                    $liText = $li.Groups[2].Value
                    
                    $isCorrect = $liAttr -match 'correct_answer'
                    $optText = [System.Net.WebUtility]::HtmlDecode($liText).Trim()
                    
                    # Prevent empty options
                    if (-not [string]::IsNullOrWhiteSpace($optText)) {
                        $options += @{
                            text = $optText
                            isCorrect = $isCorrect
                        }
                    }
                }
            }
            # Clean up all ULs from the text so they don't appear twice
            $chunkRest = $chunkRest -replace '(?s)<ul.*?>.*?</ul>', ''
        } else {
             $type = "info" # Default to info if no options found
        }
        
        # --- EXPLANATION ---
        $explanation = ""
        if ($chunkRest -match '(?s)<div class="message_box announce">.*?<b>.*?(?:Explique|Explication|Expliquer).*?</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
            $chunkRest = $chunkRest -replace '(?s)<div class="message_box announce">.*?</div>', ''
        } elseif ($chunkRest -match '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>(.*?)</p>') {
             $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
             $chunkRest = $chunkRest -replace '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>.*?</p>', ''
        }
        
        # --- IMAGES ---
        # Capture all images
        $imageSrc = $null
        $images = [regex]::Matches($chunkRest, '(?s)<img.*?src="(.*?)".*?>')
        foreach ($img in $images) {
            # Use the first one as main, others might be irrelevant or part of the match
            if ($null -eq $imageSrc) { $imageSrc = $img.Groups[1].Value }
        }
        # Remove images from text to avoid clutter
        $chunkRest = $chunkRest -replace '(?s)<img.*?>', ''

        # --- MATCHING / TABLE PARSING ---
        # Robust table parsing: handle attributes in td/tr
        $extraHtml = $chunkRest.Trim()
        $matchingPairs = @()
        
        # Look for table with 2 columns
        if ($extraHtml -match '(?s)<table.*?>(.*?)</table>') {
             $tableContent = $matches[1]
             $rows = [regex]::Matches($tableContent, '(?s)<tr.*?>(.*?)</tr>')
             foreach ($row in $rows) {
                 $cells = [regex]::Matches($row.Groups[1].Value, '(?s)<td.*?>(.*?)</td>')
                 if ($cells.Count -eq 2) {
                     $term = [System.Net.WebUtility]::HtmlDecode($cells[0].Groups[1].Value).Trim()
                     $def = [System.Net.WebUtility]::HtmlDecode($cells[1].Groups[1].Value).Trim()
                     
                     # Simple check to avoid headers
                     if ($term -ne "" -and $def -ne "" -and $term -notmatch "Comp" -and $def -notmatch "Desc") {
                         $matchingPairs += @{ term = $term; definition = $def }
                     }
                 }
             }
        }

        if ($matchingPairs.Count -gt 0) {
             # It's a matching question
             $type = "matching"
             $tableToRemove = [regex]::Match($extraHtml, '(?s)<table.*?</table>').Value
             $extraHtml = $extraHtml.Replace($tableToRemove, '')
             
             # Append original table to explanation
             if ([string]::IsNullOrWhiteSpace($explanation)) {
                 $explanation = "<strong>Correspondance correcte :</strong><br>" + $tableToRemove
             } else {
                 $explanation += "<br><br><strong>Correspondance correcte :</strong><br>" + $tableToRemove
             }
        }
        
        # --- SPECIAL FIX FOR Q27 (Hidden Matching in Explanation) ---
        if ($type -eq "info" -and $explanation -match 'Le réseau [A-Z] doit utiliser') {
             $matchesFound = [regex]::Matches($explanation, 'Le réseau ([A-Z]) doit utiliser\s*([\d\./ ]+)')
             foreach ($m in $matchesFound) {
                 $term = "R&eacute;seau " + $m.Groups[1].Value
                 $def = $m.Groups[2].Value.Trim()
                 # Clean trailing punctuation
                 $def = $def -replace '[,.]$', ''
                 $def = $def.Trim()
                 
                 if ($term -ne "" -and $def -ne "") {
                    $matchingPairs += @{ term = $term; definition = $def }
                 }
             }
             
             if ($matchingPairs.Count -gt 0) {
                 $type = "matching"
                 $fullText += "<br><em>(Associez les r&eacute;seaux selon l'explication attendue)</em>"
             }
        }

        # Add remaining HTML (like intro text) to the question title/body
        $fullText = $qTitle
        if (-not [string]::IsNullOrWhiteSpace($extraHtml)) {
             $fullText += "<div class='question-extras'>$extraHtml</div>"
        }
        
        $questionsData += @{
            id = $qNum
            text = $fullText
            options = $options
            matching = $matchingPairs
            explanation = $explanation
            image = $imageSrc
            multi = $isMultiSelect
            type = $type
        }
    }
}

$questionsData = $questionsData | Sort-Object { [int]$_.id }
Write-Host "Total Questions: $($questionsData.Count)"

$json = $questionsData | ConvertTo-Json -Depth 10

# HTML Template
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz CCNA1 - Entra&icirc;nement et Examen</title>
    <style>
        :root {
            --bg-body: #f4f6f9;
            --primary: #3498db;
            --primary-dark: #2980b9;
            --text: #2c3e50;
            --success: #27ae60;
            --success-bg: #d4efdf;
            --danger: #c0392b;
            --danger-bg: #fadbd8;
        }
        
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: var(--bg-body); color: var(--text); margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; min-height: 100vh; }
        .container { width: 100%; max-width: 850px; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); margin-bottom: 20px; }
        
        h1, h2 { text-align: center; color: var(--text); }
        
        /* Buttons */
        .btn { border: none; border-radius: 6px; padding: 12px 20px; cursor: pointer; font-size: 1rem; font-weight: 600; transition: 0.2s; color: white; display: inline-block; }
        .btn:hover { transform: translateY(-1px); filter: brightness(1.1); }
        .btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
        
        .btn-mode { width: 100%; margin: 10px 0; padding: 20px; font-size: 1.1rem; text-align: left; position: relative; }
        .btn-mode::after { content: '\2192'; position: absolute; right: 20px; font-weight: bold; }
        
        .bg-train { background: linear-gradient(135deg, #3498db, #2980b9); }
        .bg-exam { background: linear-gradient(135deg, #34495e, #2c3e50); }
        .bg-series { background-color: #f39c12; }
        .bg-nav { background-color: #95a5a6; }
        .bg-valid { background-color: #27ae60; }
        
        /* Grid for Series */
        .series-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(80px, 1fr)); gap: 10px; margin-top: 20px; }
        .btn-mini { padding: 8px; font-size: 0.9em; text-align: center; background: var(--primary); color: white; border-radius: 4px; border: none; cursor: pointer; }
        .btn-mini:hover { background: var(--primary-dark); }
        
        /* Question Styles */
        .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; margin-bottom: 10px; background: #ecf0f1; color: #7f8c8d; }
        .q-text { font-size: 1.2rem; font-weight: 500; margin-bottom: 20px; line-height: 1.5; }
        .q-img { max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 6px; margin: 15px 0; display: block; }
        
        /* Options */
        .opt-group { list-style: none; padding: 0; display: flex; flex-direction: column; gap: 10px; }
        .opt { padding: 15px; border: 2px solid #e0e0e0; border-radius: 8px; cursor: pointer; position: relative; transition: 0.2s; }
        .opt:hover { background-color: #f8f9fa; border-color: #bdc3c7; }
        .opt.selected { background-color: #ebf5fb; border-color: var(--primary); font-weight: 600; }
        
        /* Validation Feedback (Training only) */
        .opt.correct { background-color: var(--success-bg); border-color: var(--success); color: #145a32; }
        .opt.incorrect { background-color: var(--danger-bg); border-color: var(--danger); color: #922b21; }
        .opt.correct::after { content: "\2713 Correct"; float: right; font-weight: bold; }
        .opt.incorrect::after { content: "\2717 Incorrect"; float: right; font-weight: bold; }
        .opt.missed { border: 2px dashed var(--success); }
        
        /* Matching Styles */
        .match-container { margin-top: 20px; }
        .match-row { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; align-items: center; margin-bottom: 10px; padding: 10px; border-bottom: 1px solid #eee; }
        .match-drop { padding: 8px; width: 100%; border: 1px solid #ccc; border-radius: 4px; }
        .match-feedback { margin-left:10px; font-weight:bold; }

        /* Controls */
        .controls { display: flex; justify-content: space-between; margin-top: 30px; gap: 10px; }
        .btn-nav { flex: 1; }
        
        .box-info { background: #e8f8f5; border-left: 4px solid #1abc9c; padding: 15px; margin-bottom: 20px; }
        .box-explain { background: #fef9e7; border-left: 4px solid #f1c40f; padding: 15px; margin-top: 20px; display: none; }
        
        /* Result */
        .score-circle { width: 150px; height: 150px; border-radius: 50%; background: var(--bg-body); display: flex; align-items: center; justify-content: center; margin: 20px auto; font-size: 2.5rem; font-weight: bold; border: 5px solid #bdc3c7; }
        .score-good { border-color: var(--success); color: var(--success); }
        .score-bad { border-color: var(--danger); color: var(--danger); }
        
    </style>
</head>
<body>

    <!-- HOME -->
    <div class="container" id="view-home">
        <h1>CCNA 1 - ITN v7.0</h1>
        <p style="text-align:center; color:#7f8c8d;">Entra&icirc;nement et Examens</p>
        
        <button class="btn btn-mode bg-train" onclick="startQuiz('training', 60)">
            <strong>Mode Entra&icirc;nement</strong><br>
            <span style="font-size:0.9em; font-weight:normal; opacity:0.9;">60 questions al&eacute;atoires. Correction imm&eacute;diate.</span>
        </button>
        
        <button class="btn btn-mode bg-exam" onclick="startQuiz('exam', 60)">
            <strong>Mode Examen</strong><br>
            <span style="font-size:0.9em; font-weight:normal; opacity:0.9;">60 questions al&eacute;atoires. R&eacute;sultat final.</span>
        </button>

        <button class="btn btn-mode bg-series" onclick="startQuiz('training', 'all')">
            <strong>Mode Int&eacute;gral</strong><br>
            <span style="font-size:0.9em; font-weight:normal; opacity:0.9;">Toutes les questions (mix &eacute;galement). Mode entra&icirc;nement.</span>
        </button>
        
        <div style="margin-top:30px;">
            <h3>S&eacute;ries (10 questions)</h3>
            <div class="series-grid" id="series-list"></div>
        </div>
    </div>

    <!-- QUIZ -->
    <div class="container" id="view-quiz" style="display:none;">
        <div style="display:flex; justify-content:space-between; margin-bottom:20px; border-bottom:1px solid #eee; padding-bottom:10px;">
            <button class="btn-mini" onclick="goHome()" style="background:#bdc3c7;">Quitter</button>
            <span id="quiz-status" style="font-weight:bold; color:var(--primary);">Question 1/1</span>
        </div>

        <div id="q-box"></div>
        
        <div class="controls">
            <button class="btn btn-nav bg-nav" id="btn-prev" onclick="move(-1)">Pr&eacute;c&eacute;dent</button>
            <button class="btn btn-nav bg-valid" id="btn-valid" onclick="validate()">Valider</button>
            <button class="btn btn-nav bg-train" id="btn-next" onclick="move(1)">Suivant</button>
        </div>
    </div>

    <!-- RESULT -->
    <div class="container" id="view-result" style="display:none; text-align:center;">
        <h1>R&eacute;sultats</h1>
        <div id="score-display"></div>
        <p id="score-msg"></p>
        
        <div style="display:flex; gap:10px; justify-content:center; margin-top:30px;">
            <button class="btn bg-nav" onclick="goHome()">Accueil</button>
            <button class="btn bg-train" onclick="reviewMode()">Revoir la correction</button>
        </div>
    </div>

    <script>
        const allQuestions = __JSON_DATA__;
        let currentQuestions = [];
        let currentIndex = 0;
        let userAnswers = {}; // Map: id -> { selected: [], validated: bool, isCorrect: bool, matches: [] }
        let currentMode = 'training'; // 'training', 'exam'
        let isReviewing = false;

        // Init Series Buttons
        const seriesCont = document.getElementById('series-list');
        const totalSeries = Math.ceil(allQuestions.length / 10);
        for(let i=1; i<=totalSeries; i++) {
            const b = document.createElement('button');
            b.className = 'btn-mini bg-series';
            b.innerText = `S\u00e9rie ${i}`;
            b.onclick = () => startSeries(i);
            seriesCont.appendChild(b);
        }

        function goHome() {
            document.getElementById('view-home').style.display = 'block';
            document.getElementById('view-quiz').style.display = 'none';
            document.getElementById('view-result').style.display = 'none';
        }

        function startQuiz(mode, count) {
            currentMode = mode;
            // Shuffle
            const shuffled = [...allQuestions].sort(() => 0.5 - Math.random());
            
            if(count === 'all') {
                currentQuestions = shuffled;
            } else {
                currentQuestions = shuffled.slice(0, count);
            }
            initSession();
        }

        function startSeries(n) {
            currentMode = 'training'; // Series are usually training
            const start = (n-1)*10;
            currentQuestions = allQuestions.slice(start, start+10);
            initSession();
        }

        function initSession() {
            userAnswers = {};
            currentIndex = 0;
            isReviewing = false;
            document.getElementById('view-home').style.display = 'none';
            document.getElementById('view-result').style.display = 'none';
            document.getElementById('view-quiz').style.display = 'block';
            renderQuestion();
        }

        function renderQuestion() {
            if(currentIndex >= currentQuestions.length) {
                finishQuiz();
                return;
            }

            const q = currentQuestions[currentIndex];
            // Init State
            if(!userAnswers[q.id]) {
                const defState = { selected: [], validated: false, isCorrect: false, matches: [] };
                if(q.type === 'matching') {
                    // Pre-shuffle definitions for dropdowns
                    defState.shuffledDefs = [...q.matching].map(m => m.definition).sort(() => 0.5 - Math.random());
                    defState.matches = new Array(q.matching.length).fill(-1);
                }
                userAnswers[q.id] = defState;
            }
            const st = userAnswers[q.id];
            
            // Interaction allowed?
            // Training: Allowed if not validated. 
            // Exam: Allowed always (until finish), but visualized only if not finished? 
            // Actually in Exam we allow changing answers until submission, so always allowed unless isReviewing.
            const locked = isReviewing || (currentMode === 'training' && st.validated);

            // HTML Build
            const status = document.getElementById('quiz-status');
            status.innerText = `Question ${currentIndex + 1} / ${currentQuestions.length}`;
            status.innerHTML += ` <span class="badge">${currentMode === 'exam' ? 'Examen' : 'Entra&icirc;nement'}</span>`;

            let html = `<div class="q-text">${q.text}</div>`;
            
            // Info / Instruction
            if(q.type === 'info') {
                html += `<div class="box-info">Regardez l'illustration et formulez votre r&eacute;ponse, puis validez pour comparer.</div>`;
            } else if (q.type === 'matching') {
                html += `<div class="box-info">Faites correspondre les &eacute;l&eacute;ments (s&eacute;lectionnez dans la liste).</div>`;
            }

            if(q.image && q.type !== 'matching') { 
                html += `<img src="${q.image}" class="q-img">`;
            }

            // --- OPTIONS ---
            if(q.type === 'matching') {
                html += `<div class="match-container">`;
                q.matching.forEach((pair, idx) => {
                    const selIdx = st.matches[idx];
                    
                    // Dropdown
                    let selectHtml = `<select class="match-drop" onchange="onMatch(${idx}, this.value)" ${locked ? 'disabled' : ''}>
                                        <option value="-1">-- Choisir --</option>`;
                    st.shuffledDefs.forEach((def, dIdx) => {
                        const isSel = (selIdx == dIdx);
                        selectHtml += `<option value="${dIdx}" ${isSel ? 'selected' : ''}>${def}</option>`;
                    });
                    selectHtml += `</select>`;

                    // Feedback Icon (Only if Training+Validated OR Reviewing)
                    let feed = '';
                    const showFeedback = (currentMode === 'training' && st.validated) || isReviewing;
                    if(showFeedback && currentMode !== 'exam') { 
                        // Note: For exam mode we don't show feedback DURING exam, only in review
                         const chosenDef = selIdx > -1 ? st.shuffledDefs[selIdx] : "";
                         if(chosenDef === pair.definition) feed = '<span style="color:green">✓</span>';
                         else feed = '<span style="color:red">✗</span>';
                    } else if (isReviewing && currentMode === 'exam') {
                        // Reviewing Exam
                         const chosenDef = selIdx > -1 ? st.shuffledDefs[selIdx] : "";
                         if(chosenDef === pair.definition) feed = '<span style="color:green">✓</span>';
                         else feed = `<span style="color:red">✗ (${pair.definition})</span>`;
                    }

                    html += `<div class="match-row">
                                <div style="font-weight:600;">${pair.term}</div>
                                <div>${selectHtml}</div>
                                ${feed}
                             </div>`;
                });
                html += `</div>`;
            } else if (q.options && q.options.length > 0) {
                html += `<ul class="opt-group">`;
                q.options.forEach((opt, idx) => {
                    let cls = 'opt';
                    const isSel = st.selected.includes(idx);
                    const showFeedback = (currentMode === 'training' && st.validated) || isReviewing;

                    if(showFeedback) {
                        // Logic: correct is green. selected wrong is red. missed correct is dashed.
                        if(opt.isCorrect) cls += ' correct';
                        else if(isSel) cls += ' incorrect';
                        else if(!isSel && opt.isCorrect) cls += ' missed';
                    } else {
                        if(isSel) cls += ' selected';
                    }

                    html += `<li class="${cls}" onclick="onOpt(${idx})">${opt.text}</li>`;
                });
                html += `</ul>`;
            }

            // Explanation (Training Validated OR Reviewing)
            const showExp = ((currentMode === 'training' && st.validated) || isReviewing) && q.explanation;
            if(showExp) {
                html += `<div class="box-explain" style="display:block"><strong>Explication :</strong><br>${q.explanation}</div>`;
            }

            document.getElementById('q-box').innerHTML = html;

            // --- BUTTONS ---
            const btnPrev = document.getElementById('btn-prev');
            const btnValid = document.getElementById('btn-valid');
            const btnNext = document.getElementById('btn-next');

            btnPrev.disabled = (currentIndex === 0);
            
            // Logic for Buttons
            if(isReviewing) {
                btnValid.style.display = 'none';
                btnNext.style.display = 'block';
                btnNext.innerText = (currentIndex === currentQuestions.length - 1) ? "Retour R&eacute;sultats" : "Suivant";
                btnNext.onclick = (currentIndex === currentQuestions.length - 1) ? () => { document.getElementById('view-result').style.display = 'block'; document.getElementById('view-quiz').style.display = 'none'; } : () => move(1);
            } else if (currentMode === 'training') {
                if(st.validated) {
                    btnValid.style.display = 'none';
                    btnNext.style.display = 'block';
                    btnNext.innerText = (currentIndex === currentQuestions.length - 1) ? "Voir R&eacute;sultats" : "Suivant";
                } else {
                    btnValid.style.display = 'block';
                    btnNext.style.display = 'none'; // Force validate first
                    // Allow skipping? User said "a chaque reponse donner ils me disent".
                    // Let's hide Next until Validated to enforce learning, or allow skip?
                    // Better interaction: Show Next but it acts as skip. 
                    // But to see result, they NEED to validate.
                    // User requirement: "a chaque reponse ... disent si elle est juste".
                }
            } else { // EXAM
                btnValid.style.display = 'none'; // No instant validation
                btnNext.style.display = 'block';
                btnNext.innerText = (currentIndex === currentQuestions.length - 1) ? "Terminer l'Examen" : "Suivant";
            }
        }

        function onOpt(idx) {
            const q = currentQuestions[currentIndex];
            const st = userAnswers[q.id];
            
            if(isReviewing) return;
            if(currentMode === 'training' && st.validated) return;

            if(q.multi) {
                const i = st.selected.indexOf(idx);
                if(i > -1) st.selected.splice(i, 1);
                else st.selected.push(idx);
            } else {
                if(st.selected.includes(idx)) st.selected = []; // toggle off
                else st.selected = [idx];
            }
            renderQuestion();
        }

        function onMatch(mIdx, val) {
            const q = currentQuestions[currentIndex];
            const st = userAnswers[q.id];
            if(isReviewing) return;
            if(currentMode === 'training' && st.validated) return;
            
            st.matches[mIdx] = parseInt(val);
            renderQuestion(); // Re-render to keep state? (Actually not needed for select, but safe)
        }

        function validate() {
            const q = currentQuestions[currentIndex];
            const st = userAnswers[q.id];
            st.validated = true;
            calcScore(q, st); // Update isCorrect
            renderQuestion();
        }

        function move(dir) {
            const next = currentIndex + dir;
            if(next >= 0 && next < currentQuestions.length) {
                currentIndex = next;
                renderQuestion();
            } else if (next >= currentQuestions.length) {
                finishQuiz();
            }
        }

        // Helper to check singular question score
        function calcScore(q, st) {
            if(q.type === 'matching') {
                let ok = true;
                q.matching.forEach((p, i) => {
                     const s = st.matches[i];
                     if(s === -1) { ok = false; return; }
                     if(st.shuffledDefs[s] !== p.definition) ok = false;
                });
                st.isCorrect = ok;
            } else if (q.type === 'info') {
                st.isCorrect = false; // Info never gives points automatically
            } else {
                const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1).sort().join(',');
                const userIndices = st.selected.sort().join(',');
                st.isCorrect = (correctIndices === userIndices && userIndices !== "");
            }
        }

        function finishQuiz() {
            // Calculate Final Score
            let correctCount = 0;
            let totalScorable = 0;

            currentQuestions.forEach(q => {
                let st = userAnswers[q.id];
                if(!st) {
                    // Start default if skipped
                     st = { selected:[], matches:[], validated:true, isCorrect:false };
                     if(q.type === 'matching') st.matches = new Array(q.matching.length).fill(-1);
                     userAnswers[q.id] = st;
                }
                
                // Force validation state for exam
                st.validated = true; 
                calcScore(q, st);

                // Only count scorable types
                if(q.type === 'quiz' || q.type === 'matching') {
                    totalScorable++;
                    if(st.isCorrect) correctCount++;
                }
            });

            const pct = totalScorable > 0 ? Math.round((correctCount / totalScorable) * 100) : 0;
            
            // Show result
            document.getElementById('view-quiz').style.display = 'none';
            document.getElementById('view-result').style.display = 'block';
            
            const circle = document.getElementById('score-display');
            const msg = document.getElementById('score-msg');
            
            circle.innerHTML = `<div class="score-circle ${pct >= 75 ? 'score-good' : 'score-bad'}">${pct}%</div>`;
            msg.innerHTML = `Vous avez obtenu <strong>${correctCount}</strong> bonnes r&eacute;ponses sur <strong>${totalScorable}</strong> questions &eacute;valuables.<br>` +
                            (pct >= 75 ? "Excellent travail !" : "Entra&icirc;nez-vous encore un peu.");
        }
        
        function reviewMode() {
            isReviewing = true;
            currentIndex = 0;
            document.getElementById('view-result').style.display = 'none';
            document.getElementById('view-quiz').style.display = 'block';
            renderQuestion();
        }

    </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__JSON_DATA__', $json)
# Use .NET to write file to ensure UTF8 without BOM issues if possible, or standard UTF8
[System.IO.File]::WriteAllText($outputHtml, $html, [System.Text.Encoding]::UTF8)
Write-Host "V7 Generated Successfully."
