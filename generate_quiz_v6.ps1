
# Script to generate CCNA1 Quiz Site - V6 (Explicit Modes & Feedback Icons)
$url = "https://ccnareponses.com/ccna-1-examen-final-itnv7-questions-et-reponses-francais/"
$outputHtml = "quiz_interactif_v6.html"
$sourceFile = "page_source.html"

# Download if not exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Downloading content..."
    Invoke-WebRequest -Uri $url -OutFile $sourceFile
}

$content = Get-Content -Path $sourceFile -Raw -Encoding UTF8

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

        # Reset Type for each iteration (Fixes bug where subseq questions inherit 'matching')
        $type = "quiz" 

        $qTitle = [System.Net.WebUtility]::HtmlDecode($qTitleRaw).Trim()

        $isMultiSelect = $false
        if ($qTitle -match '(?i)choisissez.*?trois|choisissez.*?deux|choisissez.*?plusieurs') {
            $isMultiSelect = $true
        }

        $chunkRest = $chunk -replace '(?s)^.*?</strong>', '' # Remove title
        
        # Options
        $options = @()
        $hasOptions = $false
        if ($chunkRest -match '(?s)<ul>(.*?)</ul>') {
            $ulContent = $matches[1]
            $liMatches = [regex]::Matches($ulContent, '(?s)<li(.*?)>(.*?)</li>')
            
            foreach ($li in $liMatches) {
                $liAttr = $li.Groups[1].Value
                $liText = $li.Groups[2].Value
                
                $isCorrect = $liAttr -match 'correct_answer'
                $optText = [System.Net.WebUtility]::HtmlDecode($liText).Trim()
                
                $options += @{
                    text = $optText
                    isCorrect = $isCorrect
                }
            }
            if ($options.Count -gt 0) { $hasOptions = $true }
            
            # Remove options <ul> to avoid duplicate text
            $chunkRest = $chunkRest -replace '(?s)<ul>.*?</ul>', ''        } else {
             # If no options, default to info. Will be overridden by matching later.
             $type = "info"        }
        
        # Explanation
        $explanation = ""
        if ($chunkRest -match '(?s)<div class="message_box announce">.*?<b>.*?(?:Explique|Explication|Expliquer).*?</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
            $chunkRest = $chunkRest -replace '(?s)<div class="message_box announce">.*?</div>', ''
        } elseif ($chunkRest -match '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>(.*?)</p>') {
             $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
             $chunkRest = $chunkRest -replace '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>.*?</p>', ''
        }
        
        # Image
        $imageSrc = $null
        if ($chunkRest -match '(?s)<img.*?src="(.*?)".*?>') {
            $imageSrc = $matches[1]
            $imgRegex = [regex]'(?s)<img.*?src=".*?".*?>'
            $chunkRest = $imgRegex.Replace($chunkRest, '', 1)
            $imgCount++
        }

        # Extra HTML (Tables, etc.)
        $extraHtml = $chunkRest.Trim()
        $fullText = $qTitle
        
        # MATCHING QUESTION PARSING
        $matchingPairs = @()
        # Look for table with 2 columns
        if ($extraHtml -match '(?s)<table.*?>(.*?)</table>') {
             $tableContent = $matches[1]
             $rows = [regex]::Matches($tableContent, '(?s)<tr>(.*?)</tr>')
             foreach ($row in $rows) {
                 $cells = [regex]::Matches($row.Groups[1].Value, '(?s)<td>(.*?)</td>')
                 if ($cells.Count -eq 2) {
                     $term = [System.Net.WebUtility]::HtmlDecode($cells[0].Groups[1].Value).Trim()
                     $def = [System.Net.WebUtility]::HtmlDecode($cells[1].Groups[1].Value).Trim()
                     # Skip header rows if they exist (usually unlikely in this dump but good safeguard)
                     if ($term -ne "" -and $def -ne "") {
                         $matchingPairs += @{ term = $term; definition = $def }
                     }
                 }
             }
        }

        if ($matchingPairs.Count -gt 0) {
             # It's a matching matching question
             $type = "matching"
             # Remove the table from the display text since we will render it interactively
             $tableToRemove = [regex]::Match($extraHtml, '(?s)<table.*?</table>').Value
             $extraHtml = $extraHtml.Replace($tableToRemove, '')
             
             # Also add to explanation for reference
             if ([string]::IsNullOrWhiteSpace($explanation)) {
                 $explanation = "<strong>Correspondance correcte :</strong><br>" + $tableToRemove
             } else {
                 $explanation += "<br><br><strong>Correspondance correcte :</strong><br>" + $tableToRemove
             }
        }

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
Write-Host "Questions with Images (Found during parse): $imgCount"

$json = $questionsData | ConvertTo-Json -Depth 10

# HTML Template
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz CCNA1 - V6</title>
    <style>
        :root {
            --bg-body: #f5f7fa;
            --btn-blue: #3498db;
            --btn-blue-hover: #2980b9;
            --btn-purple: #9b59b6;
            --btn-orange: #f39c12;
            --text-color: #2c3e50;
            --correct-bg: #d4efdf;
            --correct-color: #145a32;
            --incorrect-bg: #fadbd8;
            --incorrect-color: #78281f;
        }
        
        body { font-family: 'Segoe UI', system-ui, sans-serif; background-color: var(--bg-body); color: var(--text-color); margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; min-height: 100vh; }
        .container { width: 100%; max-width: 800px; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 5px 20px rgba(0,0,0,0.05); text-align: center; }
        h1 { color: #2c3e50; margin-bottom: 2rem; }
        
        /* Menu */
        .menu-btn, .btn-series { border: none; border-radius: 8px; color: white; cursor: pointer; font-size: 1.1em; padding: 18px 25px; margin-bottom: 15px; width: 100%; transition: transform 0.1s, box-shadow 0.2s; font-weight: 600; }
        .menu-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 10px rgba(0,0,0,0.1); }
        .menu-btn { max-width: 600px; display: block; margin-left: auto; margin-right: auto; }
        
        .btn-training { background: linear-gradient(135deg, #3498db, #2980b9); }
        .btn-exam { background: linear-gradient(135deg, #34495e, #2c3e50); }
        .btn-mock { background: linear-gradient(135deg, #9b59b6, #8e44ad); margin-bottom: 40px; }
        
        .btn-series { background-color: var(--btn-orange); padding: 12px; margin: 0; font-size: 1em; }
        .series-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(100px, 1fr)); gap: 10px; max-width: 700px; margin: 0 auto; }
        
        /* Quiz Layout */
        #quiz-interface, #result-screen { display: none; text-align: left; }
        #result-screen { text-align: center; }
        
        .question-text { font-weight: 700; font-size: 1.25em; margin-bottom: 20px; color: #2c3e50; line-height: 1.4; }
        .question-extras { font-weight: normal; margin-top: 15px; font-size: 0.95em; color: #444; border: 1px solid #eee; padding: 10px; border-radius: 5px; overflow-x: auto; background: #fafafa; }
        .question-extras table { width: 100%; border-collapse: collapse; }
        .question-extras td, .question-extras th { border: 1px solid #ddd; padding: 8px; }
        
        .main-image { max-width: 100%; height: auto; border-radius: 8px; margin: 15px 0; display: block; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }

        .options-list { list-style: none; padding: 0; display: flex; flex-direction: column; gap: 10px; }
        .option-item { padding: 16px; border: 2px solid #e0e0e0; border-radius: 8px; cursor: pointer; transition: all 0.2s; position: relative; font-size: 1.05em; }
        .option-item:hover { background-color: #f8f9fa; border-color: #bdc3c7; }
        .option-item.selected { border-color: var(--btn-blue); background-color: #ebf5fb; font-weight: 600; }
        
        /* Feedback Icons and Colors */
        .option-item.correct { border-color: #27ae60; background-color: var(--correct-bg); color: var(--correct-color); }
        .option-item.incorrect { border-color: #c0392b; background-color: var(--incorrect-bg); color: var(--incorrect-color); }
        
        .option-item.correct::after { content: "✓ Juste"; position: absolute; right: 20px; font-weight: bold; }
        .option-item.incorrect::after { content: "✗ Faux"; position: absolute; right: 20px; font-weight: bold; }
        .option-item.missed::after { content: "← Correction"; position: absolute; right: 20px; font-size: 0.9em; opacity: 0.8; }

        .info-box { background: #e8f6f3; padding: 15px; border-radius: 5px; border-left: 5px solid #1abc9c; margin-bottom: 25px; font-style: italic; }

        .controls { display: flex; justify-content: space-between; margin-top: 30px; gap: 15px; }
        .nav-btn { background-color: var(--btn-blue); color: white; border: none; padding: 12px 25px; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 1em; flex: 1; max-width: 200px; }
        .nav-btn:hover { filter: brightness(1.1); }
        .nav-btn:disabled { opacity: 0.5; cursor: not-allowed; filter: grayscale(1); }
        
        .explanation { margin-top: 25px; padding: 20px; background-color: #fef9e7; border-left: 5px solid #f1c40f; border-radius: 5px; display: none; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
        .explanation strong { color: #d35400; display: block; margin-bottom: 8px; }

        /* Matching Question Styles */
        .match-row { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; align-items: start; margin-bottom: 15px; padding: 15px; background: white; border: 1px solid #eee; border-radius: 8px; }
        .match-row:hover { border-color: var(--btn-blue); box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
        .match-term { font-weight: 600; padding-top: 5px; }
        .match-select { width: 100%; padding: 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 0.95em; background: white; cursor: pointer; }
        .match-select:focus { outline: none; border-color: var(--btn-blue); box-shadow: 0 0 0 2px rgba(52, 152, 219, 0.2); }
        
        /* Feedback for Matching */
        .match-select.correct { border: 2px solid #27ae60; background-color: #f0fff4; color: #145a32; }
        .match-select.incorrect { border: 2px solid #e74c3c; background-color: #fce8e6; color: #c0392b; }
        .match-feedback { /* Icon */ font-size: 1.2em; margin-left:10px; }
    </style>
</head>
<body>

    <div class="container" id="home-screen">
        <h1>Quiz CCNA1 v7</h1>
        <button class="menu-btn btn-training" onclick="startMode('training')">Mode Entraînement<br><small style="font-size:0.8em; opacity:0.9;">(Correction immédiate)</small></button>
        <button class="menu-btn btn-mock" onclick="startMode('mock')">Mode Examen Blanc<br><small style="font-size:0.8em; opacity:0.9;">(60 questions aléatoires - Note à la fin)</small></button>
        <button class="menu-btn btn-exam" onclick="startMode('exam')">Mode Examen Complet<br><small style="font-size:0.8em; opacity:0.9;">(La totalité des questions)</small></button>
        
        <hr style="border:0; border-top:1px solid #eee; margin:30px 0;">
        <h3 style="color:#7f8c8d; margin-bottom:20px;">Séries d'entraînement (10 questions)</h3>
        <div class="series-grid" id="series-container"></div>
    </div>

    <!-- Quiz Interface -->
    <div class="container" id="quiz-interface">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; border-bottom:2px solid #f0f2f5; padding-bottom:15px;">
            <button class="nav-btn" style="padding:8px 15px; background:white; border:1px solid #ddd; color:#666; font-weight:normal;" onclick="showHome()">← Accueil</button>
            <div style="text-align:right;">
                <span id="quiz-progress" style="font-weight:bold; color:var(--btn-blue); font-size:1.1em;">Question 1/1</span>
                <div id="mode-badge" style="font-size:0.8em; color:#999; margin-top:4px;"></div>
            </div>
        </div>
        
        <div id="question-container"></div>
        
        <div class="controls">
            <button class="nav-btn" id="btn-prev" onclick="move(-1)" style="background:#bdc3c7;">Précédent</button>
            <button class="nav-btn" id="btn-reset" onclick="resetQuestion()" style="background:#f39c12; display:none;">Refaire</button>
            <button class="nav-btn" id="btn-action" style="background:#27ae60; flex:2;" onclick="handleAction()">Valider</button>
            <button class="nav-btn" id="btn-next" onclick="move(1)">Suivant</button>
        </div>
    </div>

    <!-- Result Screen -->
    <div class="container" id="result-screen">
        <h1 style="margin-bottom:10px;">Résultats</h1>
        <div id="final-score" style="font-size:4em; font-weight:800; color:var(--btn-blue); margin:10px 0;"></div>
        <p id="score-details" style="font-size:1.2em; color:#555; margin-bottom:40px;"></p>
        
        <button class="menu-btn btn-training" onclick="showHome()">Retour à l'accueil</button>
        <button class="menu-btn btn-exam" onclick="reviewErrors()">Revoir la correction</button>
    </div>

    <script>
        const data = __JSON_DATA__;
        let questions = [];
        let curIdx = 0;
        let answers = {};
        let mode = 'training'; // training, exam, mock
        let isReview = false;

        // Populate Series
        const seriesCont = document.getElementById('series-container');
        const numSeries = Math.ceil(data.length / 10);
        for(let i=1; i<=numSeries; i++) {
            const b = document.createElement('button');
            b.className = 'btn-series';
            b.innerText = `Série ${i}`;
            b.onclick = () => startSeries(i);
            seriesCont.appendChild(b);
        }

        function showHome() {
            if(Object.keys(answers).length > 0 && document.getElementById('quiz-interface').style.display === 'block') {
                if(!confirm("Quitter le quiz en cours ? Votre progression sera perdue.")) return;
            }
            document.getElementById('home-screen').style.display = 'block';
            document.getElementById('quiz-interface').style.display = 'none';
            document.getElementById('result-screen').style.display = 'none';
        }

        function startMode(m) {
            mode = m;
            isReview = false;
            answers = {};
            curIdx = 0;
            
            if(m === 'mock') {
                // Shuffle copy
                questions = [...data].sort(() => 0.5 - Math.random()).slice(0, 60);
                document.getElementById('mode-badge').innerText = "Examen blanc";
            } else if (m === 'exam') {
                questions = [...data];
                document.getElementById('mode-badge').innerText = "Examen complet";
            } else {
                questions = [...data];
                document.getElementById('mode-badge').innerText = "Entraînement";
            }
            launch();
        }

        function startSeries(n) {
            mode = 'training';
            isReview = false;
            answers = {};
            curIdx = 0;
            const start = (n-1)*10;
            questions = data.slice(start, start+10);
            document.getElementById('mode-badge').innerText = `Série ${n}`;
            launch();
        }

        function launch() {
            document.getElementById('home-screen').style.display = 'none';
            document.getElementById('result-screen').style.display = 'none';
            document.getElementById('quiz-interface').style.display = 'block';
            render();
        }

        function render() {
            if(curIdx >= questions.length) { finish(); return; }
            
            const q = questions[curIdx];
            if(!answers[q.id]) answers[q.id] = { selected: [], validated: false, isCorrect: false };
            const st = answers[q.id];
            
            document.getElementById('quiz-progress').innerText = `Question ${curIdx+1} / ${questions.length}`;
            
            let html = ``;
            if (q.type === 'info') {
                 html += `<div class="info-box"><strong>Information :</strong> Cette question nécessite une analyse visuelle. Répondez mentalement puis validez pour voir la solution.</div>`;
            } else if (q.type === 'matching') {
                 html += `<div class="info-box"><strong>Instructions :</strong> Associez chaque élément de gauche à sa définition correcte.</div>`;
            }
            
            html += `<div class="question-text">${q.text}</div>`;
            // Hide image for matching questions as it likely contains the answer (lines)
            if(q.image && q.type !== 'matching') html += `<img src="${q.image}" class="main-image">`;
            
            // RENDERING OPTIONS - Check Type
            if (q.type === 'matching') {
                // Initialize if matching state empty
                if (!st.shuffledDefs) {
                    st.shuffledDefs = [...q.matching].map(pair => pair.definition).sort(() => 0.5 - Math.random());
                    // Or keep definitions sorted/fixed for clean list? No, shuffle is better.
                    // Actually, if we just want to match Term -> Def, we can list definitions in random order.
                }
                if (!st.selectedMatches) {
                    st.selectedMatches = new Array(q.matching.length).fill(-1);
                }

                html += `<div class="matching-container">`;
                
                q.matching.forEach((pair, i) => {
                    const term = pair.term;
                    const selectedIdx = st.selectedMatches[i]; // Index of definition in shuffledDefs
                    const isVal = st.validated;
                    
                    // Matching Row
                    html += `<div class="match-row">
                        <div class="match-term">${term}</div>
                        <div style="flex:1;">
                            <select 
                                class="match-select" 
                                id="match-${i}" 
                                onchange="selectMatch(${i}, this.value)" 
                                ${(mode === 'training' && st.validated) || isReview ? 'disabled' : ''}>
                                <option value="-1">-- Choisir --</option>`;
                    
                    st.shuffledDefs.forEach((def, defIdx) => {
                         const isSel = (selectedIdx == defIdx);
                         html += `<option value="${defIdx}" ${isSel ? 'selected' : ''}>${def}</option>`;
                    });
                    
                    html += `</select>`;
                    
                    // Feedback icon
                    if (isVal) {
                        // Check if correct
                        const chosenDef = selectedIdx > -1 ? st.shuffledDefs[selectedIdx] : "";
                        const actualDef = pair.definition;
                        const ok = (chosenDef === actualDef);
                        if (ok) html += `<span class="match-feedback" style="color:#27ae60;">✓</span>`;
                        else html += `<span class="match-feedback" style="color:#e74c3c;">✗</span>`;
                    }
                    
                    html += `</div></div>`;
                });
                
                html += `</div>`;
            } 
            else if(q.options && q.options.length > 0) {
                html += `<ul class="options-list">`;
                q.options.forEach((opt, i) => {
                    let cls = 'option-item';
                    const sel = st.selected.includes(i);
                    const showFeedback = (mode === 'training' && st.validated) || isReview;
                    
                    if(showFeedback) {
                        if(opt.isCorrect) cls += ' correct';
                        else if(sel) cls += ' incorrect';
                        else if(!sel && opt.isCorrect) cls += ' missed'; 
                    } else {
                        if(sel) cls += ' selected';
                    }
                    
                    html += `<li class="${cls}" onclick="clickOpt(${i})">${opt.text}</li>`;
                });
                html += `</ul>`;
            }

            // Explanation
            if(((mode === 'training' && st.validated) || isReview) && q.explanation) {
                html += `<div class="explanation" style="display:block"><strong>Explication :</strong><br>${q.explanation}</div>`;
            }
            
            document.getElementById('question-container').innerHTML = html;
            
            // --- Button Logic ---
            const btnAct = document.getElementById('btn-action');
            const btnNext = document.getElementById('btn-next');
            
            document.getElementById('btn-prev').disabled = (curIdx === 0);
            
            // Hide Next/Prev in favor of flow? No, keep them for navigation in exams.
            // In training, we guide via Validate -> Next.
            
            if (isReview) {
                btnAct.style.display = 'none';
                btnNext.style.display = 'block';
            } else if (mode === 'training') {
                btnNext.style.display = 'block'; // Always allow skipping
                
                if (st.validated) {
                    btnAct.style.display = 'none';
                    if (curIdx === questions.length - 1) {
                         btnNext.innerText = "Terminer";
                         btnNext.onclick = finish;
                    } else {
                         btnNext.innerText = "Suivant";
                         btnNext.onclick = () => move(1);
                    }
                } else {
                    btnAct.style.display = 'block';
                    btnAct.innerText = "Valider";
                    // Disable validate if nothing selected (except info types)
                    btnAct.disabled = (q.type !== 'info' && st.selected.length === 0);
                    
                    // Reset Next button to standard
                    btnNext.innerText = "Suivant";
                    btnNext.onclick = () => move(1);
                }
            } else {
                // Exam / Mock
                btnAct.style.display = 'none';
                btnNext.style.display = 'block';
                btnNext.innerText = "Suivant";
                btnNext.onclick = () => move(1);
                
                if (curIdx === questions.length - 1) {
                    btnNext.innerText = "Terminer l'examen";
                    btnNext.onclick = finish;
                }
            }
        }

        function selectMatch(i, val) {
            const q = questions[curIdx];
            const st = answers[q.id];
            if (isReview || (mode === 'training' && st.validated)) return;
            
            st.selectedMatches[i] = parseInt(val);
            render();
        }

        function clickOpt(i) {
            if(isReview) return;
            const q = questions[curIdx];
            const st = answers[q.id];
            
            // Block changing answer if validated in training mode
            if(mode === 'training' && st.validated) return;
            
            if(q.multi) {
                const idx = st.selected.indexOf(i);
                if(idx > -1) st.selected.splice(idx,1);
                else st.selected.push(i);
            } else {
                if( st.selected.includes(i) ) st.selected = []; // toggle off if single
                else st.selected = [i];
            }
            render();
        }

        function handleAction() {
            const q = questions[curIdx];
            const st = answers[q.id];
            
            // Mark as validated
            st.validated = true;
            
            // Check correctness
            if(q.type === 'info') {
                st.isCorrect = true; 
            } else if (q.type === 'matching') {
                 let allCorrect = true;
                 q.matching.forEach((pair, i) => {
                     const chosenIdx = st.selectedMatches[i];
                     if (chosenIdx === -1) { allCorrect = false; return; }
                     const chosenDef = st.shuffledDefs[chosenIdx];
                     if (chosenDef !== pair.definition) allCorrect = false;
                 });
                 st.isCorrect = allCorrect;
            } else {
                const correct = q.options.map((o,x) => o.isCorrect ? x : -1).filter(x=>x!==-1).sort().toString();
                const sel = st.selected.sort().toString();
                st.isCorrect = (correct === sel);
            }
            render();
        }

        function move(d) {
            const n = curIdx + d;
            if(n >= 0 && n < questions.length) {
                curIdx = n;
                render();
            }
        }

        function finish() {
            let pts = 0;
            // Count score
            questions.forEach(q => {
                let st = answers[q.id];
                if(!st) { 
                    // Init default state if not visited
                    st = {selected:[], validated:true, isCorrect:false}; 
                    if(q.type === 'matching') {
                         st.selectedMatches = new Array(q.matching.length).fill(-1);
                         st.shuffledDefs = [...q.matching].map(pair => pair.definition).sort(() => 0.5 - Math.random());
                    }
                    answers[q.id] = st;
                }
                
                // Validate silently for exam modes
                if(mode !== 'training') {
                    if(q.type === 'info') {
                        // Info: no score
                    } else if (q.type === 'matching') {
                         let allCorrect = true;
                         q.matching.forEach((pair, i) => {
                             const chosenIdx = st.selectedMatches[i];
                             if (chosenIdx === -1) { allCorrect = false; return; }
                             const chosenDef = st.shuffledDefs[chosenIdx];
                             if (chosenDef !== pair.definition) allCorrect = false;
                         });
                         st.isCorrect = allCorrect;
                    } else {
                        const correct = q.options.map((o,x) => o.isCorrect ? x : -1).filter(x=>x!==-1).sort().toString();
                        const sel = st.selected.sort().toString();
                        if(correct === sel && sel !== "") st.isCorrect = true;
                    }
                    st.validated = true;
                }
                
                if(st.isCorrect) pts++;
            });
            
            const quizQuestions = questions.filter(q => q.type === 'quiz' || q.type === 'matching').length;
            const finalScore = quizQuestions > 0 ? Math.round((pts / quizQuestions) * 100) : 0;
            
            document.getElementById('quiz-interface').style.display = 'none';
            document.getElementById('result-screen').style.display = 'block';
            
            const msg = finalScore >= 75 ? "Bravo !" : "Continuez vos efforts !";
            const color = finalScore >= 75 ? "#27ae60" : "#e74c3c";
            
            document.getElementById('final-score').innerHTML = `<span style="color:${color}">${finalScore}%</span>`;
            document.getElementById('score-details').innerHTML = `${msg}<br>${pts} bonnes réponses sur ${quizQuestions}`;
        }

        function reviewErrors() {
            isReview = true;
            document.getElementById('result-screen').style.display = 'none';
            document.getElementById('quiz-interface').style.display = 'block';
            curIdx = 0;
            render();
        }
    </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__JSON_DATA__', $json)
$html | Out-File $outputHtml -Encoding UTF8
Write-Host "V6 Generated Successfully."
