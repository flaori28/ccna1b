
# Script to generate CCNA1 Quiz Site - V5 (Recover All Questions + Images)
$url = "https://ccnareponses.com/ccna-1-examen-final-itnv7-questions-et-reponses-francais/"
$outputHtml = "index.html"
$sourceFile = "page_source.html"

# Download if not exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Downloading content..."
    Invoke-WebRequest -Uri $url -OutFile $sourceFile
}

$content = Get-Content -Path $sourceFile -Raw -Encoding UTF8

# --- CLEANING PHASE ---
# 1. Remove Scripts
$content = $content -replace '(?s)<script.*?</script>', ''
# 2. Remove Styles
$content = $content -replace '(?s)<style.*?</style>', ''
# 3. Remove known Ad containers (generic approach)
# Remove divs with "akcelo", "Ccnareponses" ids/classes
$content = $content -replace '(?s)<div[^>]*?(?:akcelo|Ccnareponses)[^>]*?>.*?</div>', ''
# Remove the specific random class ad div found in Q5
$content = $content -replace '(?s)<div[^>]*?data-index="\d+"[^>]*?>.*?</div>', ''
# Remove empty paragraphs left behind
$content = $content -replace '<p>\s*</p>', ''

# --- SPLITTING ---
# Use regex to split by Question Number.
# Pattern: Start of line or paragraph, Strong tag, Number, Dot.
$chunks = $content -split '(?=<strong>\s*\d+\.)'
$chunks = $chunks | Select-Object -Skip 1

$questionsData = @()
$seenIds = @{}

Write-Host "Found $($chunks.Count) raw chunks. Processing..."

foreach ($chunk in $chunks) {
    # Extract ID and Title (Text inside <strong>)
    if ($chunk -match '(?s)<strong>\s*(\d+)\.\s*(.*?)</strong>') {
        $qNum = $matches[1]
        $qTitleRaw = $matches[2]
        
        if ($seenIds.ContainsKey($qNum)) { continue }
        $seenIds[$qNum] = $true

        $qTitle = [System.Net.WebUtility]::HtmlDecode($qTitleRaw).Trim()

        # Check for multi-select hint in title
        $isMultiSelect = $false
        if ($qTitle -match '(?i)choisissez.*?trois|choisissez.*?deux|choisissez.*?plusieurs') {
            $isMultiSelect = $true
        }

        # --- BODY EXTRACTION ---
        # Everything after the </strong> and before the <ul> (options) or <div class="message_box"> (explanation)
        # This captures descriptions, images, tables between title and options.
        
        $chunkRest = $chunk -replace '(?s)^.*?</strong>', '' # Remove title part
        
        # Extract Options
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
            
            # Remove the <ul> from valid HTML content to avoid dupes (we render options separately)
            $chunkRest = $chunkRest -replace '(?s)<ul>.*?</ul>', ''
        }
        
        # Extract Explanation
        $explanation = ""
        if ($chunkRest -match '(?s)<div class="message_box announce">.*?<b>.*?(?:Explique|Explication|Expliquer).*?</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
            # Remove explanation from body
            $chunkRest = $chunkRest -replace '(?s)<div class="message_box announce">.*?</div>', ''
        } elseif ($chunkRest -match '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>(.*?)</p>') {
             $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
             $chunkRest = $chunkRest -replace '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>.*?</p>', ''
        }
        
        # --- IMAGE EXTRACTION ---
        $imageSrc = $null
        # Find first image in the remaining body
        if ($chunkRest -match '(?s)<img.*?src="(.*?)".*?>') {
            $imageSrc = $matches[1]
            # Remove this specific image tag to avoid duplication if we show it at top
            # Be careful not to remove ALL images if there are multiple.
            # We'll use regex to remove the *first* match only.
            $imgRegex = [regex]'(?s)<img.*?src=".*?".*?>'
            $chunkRest = $imgRegex.Replace($chunkRest, '', 1)
        }

        # Clean up chunkRest (Ad remnants, extra spaces)
        $extraHtml = $chunkRest.Trim()
        
        # Construct final text: Title + Extra HTML Loop
        # We wrap Extra HTML in a div
        $fullText = $qTitle
        if (-not [string]::IsNullOrWhiteSpace($extraHtml)) {
             $fullText += "<div class='question-extras'>$extraHtml</div>"
        }

        # Add to list if we have options OR if we have content (for matching questions)
        # Even if no options, we include it as "Info" type question
        $type = if ($hasOptions) { "quiz" } else { "info" }
        
        $questionsData += @{
            id = $qNum
            text = $fullText
            options = $options
            explanation = $explanation
            image = $imageSrc
            multi = $isMultiSelect
            type = $type
        }
    }
}

$questionsData = $questionsData | Sort-Object { [int]$_.id }
Write-Host "Total Extracted: $($questionsData.Count)"

$json = $questionsData | ConvertTo-Json -Depth 10

# HTML Template
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz CCNA1 - V5</title>
    <style>
        :root {
            --bg-body: #f5f7fa;
            --btn-blue: #3498db;
            --btn-blue-hover: #2980b9;
            --btn-purple: #9b59b6;
            --btn-orange: #f39c12;
            --text-color: #2c3e50;
        }
        
        body { font-family: 'Segoe UI', sans-serif; background-color: var(--bg-body); color: var(--text-color); margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; min-height: 100vh; }
        .container { width: 100%; max-width: 800px; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); text-align: center; }
        h1 { color: #2c3e50; margin-bottom: 2rem; }
        
        /* Menu */
        .menu-btn, .btn-series { border: none; border-radius: 5px; color: white; cursor: pointer; font-size: 1.1em; padding: 15px 20px; margin-bottom: 15px; width: 100%; transition: 0.2s; }
        .menu-btn { max-width: 500px; display: block; margin-left: auto; margin-right: auto; }
        .btn-training, .btn-exam { background-color: var(--btn-blue); }
        .btn-training:hover { background-color: var(--btn-blue-hover); }
        .btn-mock { background-color: var(--btn-purple); margin-bottom: 40px; }
        .btn-series { background-color: var(--btn-orange); padding: 12px; margin: 0; }
        .series-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; max-width: 600px; margin: 0 auto; }
        
        /* Quiz */
        #quiz-interface, #result-screen { display: none; text-align: left; }
        #result-screen { text-align: center; }
        
        .question-text { font-weight: 600; font-size: 1.15em; margin-bottom: 20px; color: #2c3e50; }
        .question-extras { font-weight: normal; margin-top: 10px; font-size: 0.95em; color: #444; overflow-x: auto; }
        .question-extras table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        .question-extras td, th { border: 1px solid #ddd; padding: 8px; }
        
        .main-image { max-width: 100%; border-radius: 5px; margin: 15px 0; display: block; }

        .options-list { list-style: none; padding: 0; }
        .option-item { padding: 15px; border: 2px solid #e0e0e0; border-radius: 6px; margin-bottom: 10px; cursor: pointer; transition: all 0.2s; }
        .option-item:hover { background-color: #f9f9f9; border-color: #bdc3c7; }
        .option-item.selected { border-color: var(--btn-blue); background-color: #ebf5fb; }
        .option-item.correct { border-color: #27ae60; background-color: #d4efdf; }
        .option-item.incorrect { border-color: #c0392b; background-color: #f2d7d5; }

        .info-box { background: #e8f6f3; padding: 15px; border-radius: 5px; border-left: 4px solid #1abc9c; margin-bottom: 20px; }

        .controls { display: flex; justify-content: space-between; margin-top: 30px; }
        .nav-btn { background-color: var(--btn-blue); color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        .nav-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        
        .explanation { margin-top: 20px; padding: 15px; background-color: #fcf3cf; border-left: 4px solid #f1c40f; display: none; }
    </style>
</head>
<body>

    <div class="container" id="home-screen">
        <h1>Quiz CCNA1 v7</h1>
        <button class="menu-btn btn-training" onclick="startMode('training')">Mode Entraînement</button>
        <button class="menu-btn btn-exam" onclick="startMode('exam')">Mode Examen</button>
        <button class="menu-btn btn-mock" onclick="startMode('mock')">Mode Examen Blanc</button>
        <hr style="border:0; border-top:1px solid #eee; margin:30px 0;">
        <div class="series-grid" id="series-container"></div>
    </div>

    <div class="container" id="quiz-interface">
        <div style="display:flex; justify-content:space-between; margin-bottom:15px; border-bottom:1px solid #eee; padding-bottom:10px;">
            <button class="nav-btn" style="padding:5px 10px; font-size:0.9em; background:none; border:1px solid #ddd; color:#666;" onclick="showHome()">Accueil</button>
            <span id="quiz-progress">Question 1/1</span>
        </div>
        
        <div id="question-container"></div>
        
        <div class="controls">
            <button class="nav-btn" id="btn-prev" onclick="move(-1)">Précédent</button>
            <button class="nav-btn" id="btn-action" style="background-color:#27ae60;" onclick="handleAction()">Valider</button>
            <button class="nav-btn" id="btn-next" onclick="move(1)">Suivant</button>
        </div>
    </div>

    <div class="container" id="result-screen">
        <h1>Résultats</h1>
        <h2 id="final-score" style="font-size:3em; color:var(--btn-blue);"></h2>
        <p id="score-details"></p>
        <button class="menu-btn btn-training" onclick="showHome()">Retour Accueil</button>
        <button class="menu-btn btn-exam" onclick="reviewErrors()">Revoir les erreurs</button>
    </div>

    <script>
        const data = __JSON_DATA__;
        let questions = [];
        let curIdx = 0;
        let answers = {}; // id -> { selected: [], validated: bool, isCorrect: bool }
        let mode = 'training';
        let isReview = false;

        // Init Series
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
                questions = [...data].sort(()=>0.5-Math.random()).slice(0,60);
            } else {
                questions = [...data];
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
            launch();
        }

        function launch() {
            document.getElementById('home-screen').style.display = 'none';
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
                 html += `<div class="info-box"><strong>Note:</strong> Cette question ne comporte pas de choix interactifs (Question de correspondance ou d'information).</div>`;
            }
            
            html += `<div class="question-text">${q.text}</div>`;
            if(q.image) html += `<img src="${q.image}" class="main-image">`;
            
            if(q.options && q.options.length > 0) {
                html += `<ul class="options-list">`;
                q.options.forEach((opt, i) => {
                    let cls = 'option-item';
                    const sel = st.selected.includes(i);
                    // Feedback logic
                    const show = (mode === 'training' && st.validated) || isReview;
                    
                    if(show) {
                        if(opt.isCorrect) cls += ' correct';
                        else if(sel) cls += ' incorrect';
                        if(opt.isCorrect && !sel) cls += ' missed'; // optional
                    } else {
                        if(sel) cls += ' selected';
                    }
                    
                    html += `<li class="${cls}" onclick="clickOpt(${i})">${opt.text}</li>`;
                });
                html += `</ul>`;
            }

            if(((mode === 'training' && st.validated) || isReview) && q.explanation) {
                html += `<div class="explanation" style="display:block"><strong>Explication:</strong><br>${q.explanation}</div>`;
            }
            
            document.getElementById('question-container').innerHTML = html;
            
            // Buttons
            const btnAct = document.getElementById('btn-action');
            document.getElementById('btn-prev').disabled = (curIdx === 0);
            document.getElementById('btn-next').style.display = (mode === 'exam' || mode === 'mock') ? 'block' : 'block'; 
            
            // Logic for Action Button
            if(isReview) {
                btnAct.style.display = 'none';
            } else if (mode === 'exam' || mode === 'mock') {
                if(curIdx === questions.length - 1) {
                    btnAct.style.display = 'block';
                    btnAct.innerText = "Terminer";
                } else {
                    btnAct.style.display = 'none';
                }
            } else {
                // Training
                btnAct.style.display = 'block';
                if(st.validated) {
                     if(curIdx === questions.length - 1) btnAct.innerText = "Terminer";
                     else btnAct.style.display = 'none'; // User uses 'Suivant'
                } else {
                    if (q.type === 'info') {
                        btnAct.innerText = "Continuer";
                        btnAct.disabled = false;
                    } else {
                        btnAct.innerText = "Valider";
                        btnAct.disabled = (st.selected.length === 0);
                    }
                }
            }
        }

        function clickOpt(i) {
            if(isReview) return;
            const q = questions[curIdx];
            const st = answers[q.id];
            if(mode === 'training' && st.validated) return;
            
            if(q.multi) {
                const idx = st.selected.indexOf(i);
                if(idx > -1) st.selected.splice(idx,1);
                else st.selected.push(i);
            } else {
                st.selected = [i];
            }
            render();
        }

        function handleAction() {
            const btn = document.getElementById('btn-action');
            if(btn.innerText === "Terminer") { finish(); return; }
            
            // Validate
            const q = questions[curIdx];
            const st = answers[q.id];
            
            if (q.type === 'info') {
                st.validated = true;
                st.isCorrect = true; // Free point
            } else {
                const correct = q.options.map((o,x) => o.isCorrect ? x : -1).filter(x=>x!==-1).sort().toString();
                const sel = st.selected.sort().toString();
                st.isCorrect = (correct === sel);
                st.validated = true;
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
            questions.forEach(q => {
                let st = answers[q.id];
                if(!st) { st = {selected:[], validated:true, isCorrect:false}; answers[q.id]=st; }
                
                // Re-validate just in case
                if(q.type === 'info') {
                     // pts++; // Do we count info questions? Maybe not.
                } else {
                     const correct = q.options.map((o,x) => o.isCorrect ? x : -1).filter(x=>x!==-1).sort().toString();
                     const sel = st.selected.sort().toString();
                     if(correct === sel && sel !== "") st.isCorrect = true;
                }
                
                if(st.isCorrect) pts++;
            });
            
            // Calculate score only based on "Quiz" type questions to be fair
            const quizQuestions = questions.filter(q => q.type === 'quiz').length;
            const finalScore = quizQuestions > 0 ? Math.round((pts / quizQuestions) * 100) : 0;
            
            document.getElementById('quiz-interface').style.display = 'none';
            document.getElementById('result-screen').style.display = 'block';
            document.getElementById('final-score').innerText = finalScore + "%";
            document.getElementById('score-details').innerText = `${pts} / ${quizQuestions} points`;
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
Write-Host "Success. Generated $outputHtml"
