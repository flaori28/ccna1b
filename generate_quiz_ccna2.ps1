
# Script to generate CCNA 2 Quiz Site - Special Edition
# URL for CCNA 2
$url = "https://ccnareponses.com/ccna-2-examen-final-de-cours-srwe-v7-0-questions-reponses/"
$outputHtml = "ccna2_quiz.html"
$sourceFile = "ccna2_source.html"

# Download if not exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Downloading CCNA 2 content..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $sourceFile -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    } catch {
        Write-Error "Failed to download content. Please check internet connection or URL."
        exit
    }
}

# Force read as UTF-8
$content = [System.IO.File]::ReadAllText("$PWD\$sourceFile", [System.Text.Encoding]::UTF8)

Write-Host "Cleaning content..."
# --- CLEANING PHASE ---
$content = $content -replace '(?s)<script.*?</script>', ''
$content = $content -replace '(?s)<style.*?</style>', ''
$content = $content -replace '(?s)<div[^>]*?(?:akcelo|Ccnareponses|cookie|consent)[^>]*?>.*?</div>', ''
$content = $content -replace '(?s)<div[^>]*?data-index="\d+"[^>]*?>.*?</div>', ''
$content = $content -replace '<p>\s*</p>', ''

# --- SPLITTING ---
# Split by question number pattern "Number."
$chunks = $content -split '(?=<strong>\s*\d+\.)'
$chunks = $chunks | Select-Object -Skip 1

$questionsData = @()
$seenIds = @{}

Write-Host "Processing $($chunks.Count) chunks..."

foreach ($chunk in $chunks) {
    # Extract Question ID and Title
    if ($chunk -match '(?s)<strong>\s*(\d+)\.\s*(.*?)</strong>') {
        $qNum = $matches[1]
        $qTitleRaw = $matches[2]
        
        if ($seenIds.ContainsKey($qNum)) { continue }
        $seenIds[$qNum] = $true

        $type = "quiz" 
        $qTitle = [System.Net.WebUtility]::HtmlDecode($qTitleRaw).Trim()

        # Check if multi-select
        $isMultiSelect = $false
        if ($qTitle -match '(?i)choisissez.*?trois|choisissez.*?deux|choisissez.*?plusieurs') {
            $isMultiSelect = $true
        }

        $chunkRest = $chunk -replace '(?s)^.*?</strong>', '' # Remove title
        
        # --- OPTIONS PARSING ---
        # Handle cases with multiple ULs or separated lists
        $options = @()
        $ulMatches = [regex]::Matches($chunkRest, '(?s)<ul.*?>(.*?)</ul>')
        
        if ($ulMatches.Count -gt 0) {
            foreach ($ulMatch in $ulMatches) {
                $ulContent = $ulMatch.Groups[1].Value
                $liMatches = [regex]::Matches($ulContent, '(?s)<li(.*?)>(.*?)</li>')
                
                foreach ($li in $liMatches) {
                    $liAttr = $li.Groups[1].Value
                    $liText = $li.Groups[2].Value
                    
                    # Check for "correct_answer" class or similar markers if website structure changed
                    # Based on v7 script, it looks for 'correct_answer' in li attributes
                    $isCorrect = $liAttr -match 'correct_answer'
                    
                    # Sometimes correct answer is bolded or marked differently, but let's stick to the v7 logic first
                    
                    $optText = [System.Net.WebUtility]::HtmlDecode($liText).Trim()
                    
                    if (-not [string]::IsNullOrWhiteSpace($optText)) {
                        $options += @{
                            text = $optText
                            isCorrect = $isCorrect
                        }
                    }
                }
            }
            # Remove ULs from explanation search
            $chunkRest = $chunkRest -replace '(?s)<ul.*?>.*?</ul>', ''
        } else {
             $type = "info" # Fallback
        }
        
        # --- EXPLANATION ---
        $explanation = ""
        # Try different patterns for explanation
        if ($chunkRest -match '(?s)<div class="message_box announce">.*?<b>.*?(?:Explique|Explication|Expliquer).*?</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
        } elseif ($chunkRest -match '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>(.*?)</p>') {
             $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
        }
        
        # --- IMAGES ---
        # Extract image src
        $imageSrc = ""
        if ($chunkRest -match '(?s)<img.*?src="(.*?)".*?>') {
            $imageSrc = $matches[1]
        }
        # Sometimes images refer to wp-content, ensure they are preserved
        
        # Only add valid questions
        if ($options.Count -gt 0) {
            $questionsData += @{
                id = [int]$qNum
                title = $qTitle
                options = $options
                explanation = $explanation
                image = $imageSrc
                multi = $isMultiSelect
                type = $type
            }
        }
    }
}

Write-Host "Found $($questionsData.Count) valid questions."

$json = $questionsData | ConvertTo-Json -Depth 10 -Compress

# --- HTML TEMPLATE (Beautiful Visual) ---
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CCNA 2 SRWE - Examen Final V7</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #5c6ac4; /* Indigo */
            --primary-dark: #3f4eac;
            --secondary: #00d2d3; /* Cyan/Teal */
            --bg: #f0f2f5;
            --card-bg: #ffffff;
            --text: #2d3436;
            --text-light: #636e72;
            --success: #00b894;
            --error: #d63031;
            --radius: 12px;
            --shadow: 0 4px 20px rgba(0,0,0,0.05);
        }

        body {
            font-family: 'Poppins', sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            min-height: 100vh;
        }

        .container {
            width: 100%;
            max-width: 850px;
            margin: 20px;
            background: var(--card-bg);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            overflow: hidden;
            display: flex;
            flex-direction: column;
            min-height: 80vh;
        }

        /* HEADER */
        header {
            background: linear-gradient(135deg, var(--primary), var(--primary-dark));
            color: white;
            padding: 25px 30px;
            position: relative;
        }

        header h1 {
            margin: 0;
            font-size: 1.8rem;
            font-weight: 600;
        }

        header p {
            margin: 5px 0 0;
            opacity: 0.9;
            font-size: 0.95rem;
        }

        .mode-switch {
            position: absolute;
            top: 25px;
            right: 30px;
            display: flex;
            gap: 10px;
        }

        .btn-mode {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 8px 15px;
            border-radius: 20px;
            cursor: pointer;
            font-size: 0.85rem;
            transition: 0.3s;
            backdrop-filter: blur(5px);
        }

        .btn-mode.active {
            background: white;
            color: var(--primary);
            font-weight: 600;
        }

        /* CONTENT AREA */
        .content {
            padding: 30px;
            flex: 1;
        }

        /* QUESTION CARD */
        .q-card {
            animation: fadeIn 0.4s ease;
        }

        .q-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }

        .q-badge {
            background: #e1e4fb;
            color: var(--primary);
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.8rem;
            font-weight: 600;
        }

        .q-num {
            font-size: 1.2rem;
            font-weight: 600;
            color: var(--text-light);
        }

        .q-text {
            font-size: 1.15rem;
            line-height: 1.6;
            margin-bottom: 25px;
        }

        .q-img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        /* OPTIONS */
        .options {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        .opt-btn {
            background: #f8f9fa;
            border: 2px solid #e9ecef;
            padding: 15px 20px;
            border-radius: 10px;
            text-align: left;
            cursor: pointer;
            font-family: inherit;
            font-size: 1rem;
            color: var(--text);
            transition: all 0.2s;
            position: relative;
        }

        .opt-btn:hover {
            border-color: var(--primary);
            background: #fbfbff;
        }

        .opt-btn.selected {
            border-color: var(--primary);
            background: #eff1fc;
            color: var(--primary-dark);
        }

        .opt-btn.correct {
            border-color: var(--success);
            background: #e6fffa;
            color: #006b54;
        }

        .opt-btn.wrong {
            border-color: var(--error);
            background: #fff5f5;
            color: #c0392b;
        }
        
        /* EXPLANATION */
        .explanation {
            margin-top: 25px;
            padding: 20px;
            background: #e3f2fd;
            border-left: 5px solid #2196f3;
            border-radius: 6px;
            display: none;
            font-size: 0.95rem;
            line-height: 1.5;
        }

        /* FOOTER CONTROLS */
        .controls {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
        }

        .btn {
            padding: 12px 25px;
            border-radius: 8px;
            border: none;
            font-size: 1rem;
            cursor: pointer;
            font-weight: 500;
            transition: 0.3s;
        }

        .btn-secondary {
            background: #e9ecef;
            color: var(--text-light);
        }

        .btn-secondary:hover:not(:disabled) {
            background: #dee2e6;
            color: var(--text);
        }

        .btn-primary {
            background: var(--primary);
            color: white;
            box-shadow: 0 4px 10px rgba(92, 106, 196, 0.3);
        }

        .btn-primary:hover {
            background: var(--primary-dark);
            transform: translateY(-1px);
        }
        
        .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
        }

        /* PROGRESS BAR */
        .progress-container {
            height: 6px;
            background: #e9ecef;
            width: 100%;
        }

        .progress-bar {
            height: 100%;
            background: var(--secondary);
            width: 0%;
            transition: width 0.3s;
        }

        /* RESULT VIEW */
        .result-view {
            text-align: center;
            padding: 40px 20px;
        }

        .score-circle {
            width: 150px;
            height: 150px;
            border-radius: 50%;
            background: conic-gradient(var(--success) 0%, #eee 0%);
            margin: 0 auto 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }

        .score-circle::before {
            content: '';
            position: absolute;
            width: 130px;
            height: 130px;
            background: white;
            border-radius: 50%;
        }

        .score-text {
            position: absolute;
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--text);
        }

        .result-msg {
            font-size: 1.2rem;
            color: var(--text-light);
            margin-bottom: 30px;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }

    </style>
</head>
<body>

    <div class="container">
        <!-- HEADER -->
        <header>
            <h1>CCNA 2 SRWE</h1>
            <p>Switching, Routing, and Wireless Essentials v7.0 (SRWE)</p>
            <div class="mode-switch">
                <button class="btn-mode active" id="mode-train" onclick="setMode('training')">Entra&icirc;nement</button>
                <button class="btn-mode" id="mode-exam" onclick="setMode('exam')">Examen</button>
            </div>
        </header>

        <!-- PROGRESS BAR -->
        <div class="progress-container">
            <div class="progress-bar" id="progress-bar"></div>
        </div>

        <!-- CONTENT -->
        <div class="content">
            
            <!-- QUIZ VIEW -->
            <div id="view-quiz">
                <div class="q-card" id="q-box">
                    <!-- Question Injected Here -->
                </div>

                <div class="controls">
                    <button class="btn btn-secondary" id="btn-prev" onclick="move(-1)">Pr&eacute;c&eacute;dent</button>
                    <div>
                        <button class="btn btn-primary" id="btn-valid" onclick="validate()">Valider</button>
                        <button class="btn btn-primary" id="btn-next" style="display:none;" onclick="move(1)">Suivant</button>
                    </div>
                </div>
            </div>

            <!-- RESULT VIEW -->
            <div id="view-result" style="display:none;" class="result-view">
                <h2>R&eacute;sultats Termines</h2>
                <div class="score-circle" id="score-circle">
                    <span class="score-text" id="score-text">0%</span>
                </div>
                <div class="result-msg" id="score-msg"></div>
                <button class="btn btn-secondary" onclick="location.reload()">Recommencer</button>
                <button class="btn btn-primary" onclick="reviewMode()">Revoir les r&eacute;ponses</button>
            </div>

        </div>
    </div>

    <script>
        const questions = __JSON_DATA__;
        
        let currentIndex = 0;
        let currentMode = 'training'; // 'training' or 'exam'
        let userAnswers = {}; // Map: id -> { selected: [], validated: bool, isCorrect: bool }
        let isReview = false;

        // Init
        function init() {
            // Shuffle questions? Optional. Let's keep order for now or maybe shuffle.
            // questions.sort(() => Math.random() - 0.5); 
            renderQuestion();
            updateProgress();
        }

        function setMode(mode) {
            if(confirm("Changer de mode r\u00e9initialisera la progression. Continuer ?")) {
                currentMode = mode;
                document.getElementById('mode-train').className = mode === 'training' ? 'btn-mode active' : 'btn-mode';
                document.getElementById('mode-exam').className = mode === 'exam' ? 'btn-mode active' : 'btn-mode';
                
                // Reset
                currentIndex = 0;
                userAnswers = {};
                isReview = false;
                document.getElementById('view-result').style.display = 'none';
                document.getElementById('view-quiz').style.display = 'block';
                renderQuestion();
                updateProgress();
            }
        }

        function renderQuestion() {
            const q = questions[currentIndex];
            const box = document.getElementById('q-box');
            
            // State
            if(!userAnswers[q.id]) {
                userAnswers[q.id] = { selected: [], validated: false, isCorrect: false };
            }
            const state = userAnswers[q.id];

            let html = `
                <div class="q-header">
                    <span class="q-badge">Question ${currentIndex + 1} / ${questions.length}</span>
                    <span class="q-num">#${q.id}</span>
                </div>
                <div class="q-text">${q.title}</div>
            `;

            if(q.image) {
                html += `<img src="${q.image}" class="q-img" alt="Illustration Question">`;
            }

            html += `<div class="options">`;
            
            q.options.forEach((opt, idx) => {
                let cls = 'opt-btn';
                const isSelected = state.selected.includes(idx);
                
                if(isSelected) cls += ' selected';
                
                // Show validation colors
                if(state.validated || isReview) {
                    if(opt.isCorrect) cls += ' correct';
                    else if(isSelected && !opt.isCorrect) cls += ' wrong';
                }

                html += `<button class="${cls}" onclick="selectOption(${idx})">${opt.text}</button>`;
            });
            html += `</div>`;

            // Explanation (only show if validated training mode OR review mode)
            if( (currentMode === 'training' && state.validated) || isReview ) {
                if(q.explanation) {
                     html += `<div class="explanation"><strong>Explication:</strong><br>${q.explanation}</div>`;
                }
            }

            box.innerHTML = html;

            // Update buttons
            document.getElementById('btn-prev').disabled = (currentIndex === 0);
            
            const btnValid = document.getElementById('btn-valid');
            const btnNext = document.getElementById('btn-next');

            if(isReview) {
                btnValid.style.display = 'none';
                btnNext.style.display = 'block';
                btnNext.innerText = (currentIndex === questions.length - 1) ? "Retour R\u00e9sultats" : "Suivant";
            } else if (currentMode === 'training') {
                if(state.validated) {
                    btnValid.style.display = 'none';
                    btnNext.style.display = 'block';
                    btnNext.innerText = (currentIndex === questions.length - 1) ? "Voir R\u00e9sultats" : "Suivant";
                } else {
                    btnValid.style.display = 'block';
                    btnNext.style.display = 'none';
                }
            } else { // Exam mode
                btnValid.style.display = 'none';
                btnNext.style.display = 'block';
                btnNext.innerText = (currentIndex === questions.length - 1) ? "Terminer" : "Suivant";
            }

            updateProgress();
        }

        function selectOption(idx) {
            const q = questions[currentIndex];
            const state = userAnswers[q.id];

            if(state.validated || isReview) return; // Locked

            if(q.multi) {
                const i = state.selected.indexOf(idx);
                if(i > -1) state.selected.splice(i, 1);
                else state.selected.push(idx);
            } else {
                // Single choice toggle
                if(state.selected.includes(idx)) state.selected = [];
                else state.selected = [idx];
            }
            renderQuestion();
        }

        function validate() {
            const q = questions[currentIndex];
            const state = userAnswers[q.id];
            
            // Logic: Mark as validated, check correctness
            state.validated = true;
            
            // Check correctness
            // Get indices of correct options
            const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1).sort().join(',');
            const userIndices = state.selected.sort().join(',');
            
            state.isCorrect = (correctIndices === userIndices && userIndices !== "");
            
            renderQuestion();
        }

        function move(dir) {
            const next = currentIndex + dir;
            
            // Button Logic for "Finish" or "Back to Result"
            if(isReview && next >= questions.length) {
                document.getElementById('view-quiz').style.display = 'none';
                document.getElementById('view-result').style.display = 'block';
                return;
            }

            if(!isReview && next >= questions.length) {
                finishQuiz();
                return;
            }

            if(next >= 0 && next < questions.length) {
                currentIndex = next;
                renderQuestion();
            }
        }

        function finishQuiz() {
            let correct = 0;
            let total = 0;

            questions.forEach(q => {
                let st = userAnswers[q.id];
                if(!st) {
                     st = { selected:[], validated:true, isCorrect:false };
                     userAnswers[q.id] = st;
                }
                
                // For Exam mode, validate now
                if(!st.validated) {
                    st.validated = true;
                    const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1).sort().join(',');
                    const userIndices = st.selected.sort().join(',');
                    st.isCorrect = (correctIndices === userIndices && userIndices !== "");
                }

                if(q.type === 'quiz') {
                    total++;
                    if(st.isCorrect) correct++;
                }
            });

            const pct = total > 0 ? Math.round((correct / total) * 100) : 0;
            
            // Render Result
            document.getElementById('view-quiz').style.display = 'none';
            document.getElementById('view-result').style.display = 'block';
            
            // Color circle
            const circle = document.getElementById('score-circle');
            const color = pct >= 75 ? '#00b894' : '#d63031';
            circle.style.background = `conic-gradient(${color} ${pct}%, #eee ${pct}%)`;
            
            document.getElementById('score-text').innerText = pct + "%";
            document.getElementById('score-msg').innerHTML = `Vous avez <b>${correct}</b> bonnes r&eacute;ponses sur <b>${total}</b>.<br>` +
                (pct >= 75 ? "Excellent travail ! Vous &ecirc;tes pr&ecirc;t." : "Continuez \u00e0 r\u00e9viser.");
        }

        function reviewMode() {
            isReview = true;
            currentIndex = 0;
            document.getElementById('view-result').style.display = 'none';
            document.getElementById('view-quiz').style.display = 'block';
            renderQuestion();
        }

        function updateProgress() {
            const pct = ((currentIndex + 1) / questions.length) * 100;
            document.getElementById('progress-bar').style.width = pct + "%";
        }

        // Start
        init();

    </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__JSON_DATA__', $json)
[System.IO.File]::WriteAllText("$PWD/$outputHtml", $html, [System.Text.Encoding]::UTF8)

Write-Host "Site CCNA 2 generated: $outputHtml"
Write-Host "Done."
