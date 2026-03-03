
# Script to generate CCNA1 Quiz Site - V4 (Visual & Functional Overhaul)
$url = "https://ccnareponses.com/ccna-1-examen-final-itnv7-questions-et-reponses-francais/"
$outputHtml = "index.html"
$sourceFile = "page_source.html"

# Download if not exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Downloading content..."
    Invoke-WebRequest -Uri $url -OutFile $sourceFile
}

$content = Get-Content -Path $sourceFile -Raw -Encoding UTF8

# Remove scripts to reduce noise
$content = $content -replace '(?s)<script.*?</script>', ''

# Parsing logic (improved regex)
$chunks = $content -split '(?=<strong>\s*\d+\.)'
$chunks = $chunks | Select-Object -Skip 1

$questionsData = @()
$seenIds = @{}

foreach ($chunk in $chunks) {
    if ($chunk -match '(?s)<strong>\s*(\d+)\.\s*(.*?)</strong>') {
        $qNum = $matches[1]
        $qTextRaw = $matches[2]
        
        if ($seenIds.ContainsKey($qNum)) { continue }
        $seenIds[$qNum] = $true

        $qText = [System.Net.WebUtility]::HtmlDecode($qTextRaw).Trim()

        $isMultiSelect = $false
        if ($qText -match '(?i)choisissez.*?trois|choisissez.*?deux|choisissez.*?plusieurs') {
            $isMultiSelect = $true
        }

        $options = @()
        if ($chunk -match '(?s)<ul>(.*?)</ul>') {
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
        }
        
        $explanation = ""
        if ($chunk -match '(?s)<div class="message_box announce">.*?<b>.*?(?:Explique|Explication|Expliquer).*?</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
        } elseif ($chunk -match '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>(.*?)</p>') {
             $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
        }
        
        $imageSrc = ""
        if ($chunk -match '(?s)<img.*?src="(.*?)".*?>') {
            $imageSrc = $matches[1]
        }
        
        if ($options.Count -gt 1) {
            $questionsData += @{
                id = $qNum
                text = $qText
                options = $options
                explanation = $explanation
                image = $imageSrc
                multi = $isMultiSelect
            }
        }
    }
}

$questionsData = $questionsData | Sort-Object { [int]$_.id }
$json = $questionsData | ConvertTo-Json -Depth 10

# HTML Template matching the screenshot
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz CCNA1</title>
    <style>
        :root {
            --bg-body: #f5f7fa;
            --btn-blue: #3498db;
            --btn-blue-hover: #2980b9;
            --btn-purple: #9b59b6;
            --btn-purple-hover: #8e44ad;
            --btn-orange: #f39c12;
            --btn-orange-hover: #e67e22;
            --text-color: #2c3e50;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-body);
            color: var(--text-color);
            margin: 0;
            padding: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
            min-height: 100vh;
        }

        .container {
            width: 100%;
            max-width: 800px;
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            text-align: center;
        }

        h1 {
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 2.5em;
        }

        .subtitle {
            margin-bottom: 30px;
            color: #34495e;
            font-size: 1.1em;
        }

        /* Menu Buttons */
        .menu-btn {
            display: block;
            width: 100%;
            max-width: 500px;
            margin: 0 auto 15px;
            padding: 15px 20px;
            border: none;
            border-radius: 5px;
            color: white;
            font-size: 1.1em;
            cursor: pointer;
            transition: transform 0.1s, background-color 0.2s;
            text-decoration: none;
        }

        .menu-btn:active { transform: scale(0.98); }

        .btn-training { background-color: var(--btn-blue); }
        .btn-training:hover { background-color: var(--btn-blue-hover); }

        .btn-exam { background-color: var(--btn-blue); }
        .btn-exam:hover { background-color: var(--btn-blue-hover); }

        .btn-mock { background-color: var(--btn-purple); margin-bottom: 40px; }
        .btn-mock:hover { background-color: var(--btn-purple-hover); }

        hr {
            border: 0;
            border-top: 1px solid #eee;
            margin: 30px 0;
        }

        .series-title {
            font-weight: bold;
            margin-bottom: 20px;
            font-size: 1.2em;
        }

        .series-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
            max-width: 600px;
            margin: 0 auto;
        }

        .btn-series {
            background-color: var(--btn-orange);
            color: white;
            border: none;
            padding: 12px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1em;
            transition: background-color 0.2s;
        }

        .btn-series:hover { background-color: var(--btn-orange-hover); }

        /* Quiz Interface (Hidden by default) */
        #quiz-interface { display: none; text-align: left; }
        
        .quiz-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 1px solid #eee;
        }

        .btn-home {
            background: none;
            border: 1px solid #ccc;
            padding: 5px 10px;
            border-radius: 4px;
            cursor: pointer;
            color: #777;
        }

        .question-card {
            font-size: 1.1em;
        }
        
        .question-text {
            font-weight: 600;
            margin-bottom: 20px;
            color: #2c3e50;
        }

        .options-list {
            list-style: none;
            padding: 0;
        }

        .option-item {
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            margin-bottom: 10px;
            cursor: pointer;
            transition: all 0.2s;
        }

        .option-item:hover { border-color: #bdc3c7; background-color: #f9f9f9; }
        .option-item.selected { border-color: var(--btn-blue); background-color: #ebf5fb; }
        
        /* Feedback styles (only shown in training or result mode) */
        .option-item.correct { border-color: #27ae60; background-color: #d4efdf; color: #0e6655; }
        .option-item.incorrect { border-color: #c0392b; background-color: #f2d7d5; color: #922b21; }

        .controls {
            display: flex;
            justify-content: space-between;
            margin-top: 30px;
        }

        .nav-btn {
            background-color: var(--btn-blue);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
        }
        .nav-btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn-validate { background-color: #27ae60; }
        
        .timer { font-weight: bold; color: var(--btn-purple); }

        .explanation {
            margin-top: 20px;
            padding: 15px;
            background-color: #fcf3cf;
            border-left: 4px solid #f1c40f;
            display: none;
        }
        
        /* Result Screen */
        #result-screen { display: none; text-align: center; }
        .score-display { font-size: 3em; font-weight: bold; color: var(--btn-blue); margin: 20px 0; }
        
        @media (max-width: 600px) {
            .series-grid { grid-template-columns: repeat(2, 1fr); }
            .container { padding: 20px; }
        }
    </style>
</head>
<body>

    <div class="container" id="home-screen">
        <h1>Quiz CCNA1</h1>
        <p class="subtitle">Choisissez votre mode de jeu :</p>

        <button class="menu-btn btn-training" onclick="startMode('training')">Mode Entraînement (Réponse immédiate)</button>
        <button class="menu-btn btn-exam" onclick="startMode('exam')">Mode Examen (Toutes les questions, résultats à la fin)</button>
        <button class="menu-btn btn-mock" onclick="startMode('mock')">Mode Examen Blanc (60 questions aléatoires)</button>

        <hr>

        <p class="series-title">Séries d'entraînement (10 questions)</p>
        <div class="series-grid" id="series-container">
            <!-- Series buttons injected via JS -->
        </div>
    </div>

    <!-- Quiz Interface -->
    <div class="container" id="quiz-interface">
        <div class="quiz-header">
            <button class="btn-home" onclick="showHome()">← Accueil</button>
            <span id="quiz-progress">Question 1/10</span>
        </div>
        
        <div id="question-container"></div>
        
        <div class="controls">
            <button class="nav-btn" id="btn-prev" onclick="moveQuestion(-1)">Précédent</button>
            <button class="nav-btn btn-validate" id="btn-check" onclick="handleMainButton()">Valider</button>
            <button class="nav-btn" id="btn-next" onclick="moveQuestion(1)">Suivant</button>
        </div>
    </div>

    <!-- Result Screen -->
    <div class="container" id="result-screen">
        <h1>Résultats</h1>
        <div class="score-display" id="final-score">0%</div>
        <p id="score-details"></p>
        <button class="menu-btn btn-training" onclick="showHome()">Retour à l'accueil</button>
        <button class="menu-btn btn-exam" onclick="reviewErrors()">Revoir les erreurs</button>
    </div>

    <script>
        const allQuestions = __JSON_DATA__;
        let currentQuestions = [];
        let currentIndex = 0;
        let userAnswers = {}; // { q_id: { selected: [], validated: bool, isCorrect: bool } }
        let currentMode = ''; // 'training', 'exam', 'mock'
        let reviewMode = false;

        // Init Series Grid
        const seriesContainer = document.getElementById('series-container');
        const totalSeries = Math.ceil(allQuestions.length / 10);
        for(let i=1; i<=totalSeries; i++) {
            const btn = document.createElement('button');
            btn.className = 'btn-series';
            btn.innerText = `Série ${i}`;
            btn.onclick = () => startSeries(i);
            seriesContainer.appendChild(btn);
        }

        function showHome() {
            document.getElementById('home-screen').style.display = 'block';
            document.getElementById('quiz-interface').style.display = 'none';
            document.getElementById('result-screen').style.display = 'none';
        }

        function startMode(mode) {
            currentMode = mode;
            userAnswers = {};
            currentIndex = 0;
            reviewMode = false;

            if (mode === 'training' || mode === 'exam') {
                currentQuestions = [...allQuestions];
            } else if (mode === 'mock') {
                // Shuffle and take 60
                const shuffled = [...allQuestions].sort(() => 0.5 - Math.random());
                currentQuestions = shuffled.slice(0, 60);
            }
            
            launchQuiz();
        }

        function startSeries(seriesNum) {
            currentMode = 'training'; // Series are always training mode
            userAnswers = {};
            currentIndex = 0;
            reviewMode = false;
            
            const start = (seriesNum - 1) * 10;
            const end = start + 10;
            currentQuestions = allQuestions.slice(start, end);
            
            launchQuiz();
        }

        function launchQuiz() {
            document.getElementById('home-screen').style.display = 'none';
            document.getElementById('result-screen').style.display = 'none';
            document.getElementById('quiz-interface').style.display = 'block';
            
            updateMainButtonState();
            renderQuestion();
        }

        function renderQuestion() {
            if (currentIndex >= currentQuestions.length) {
                // If we went past the end, usually via 'Next' on last question
                finishQuiz();
                return;
            }

            const q = currentQuestions[currentIndex];
            // Safe init
            if (!userAnswers[q.id]) userAnswers[q.id] = { selected: [], validated: false, isCorrect: false };
            const state = userAnswers[q.id];
            
            document.getElementById('quiz-progress').innerText = `Question ${currentIndex + 1} / ${currentQuestions.length}`;

            let html = `<div class="question-card">
                <div class="question-text">${q.text}</div>`;
            
            if (q.image) {
                html += `<img src="${q.image}" style="max-width:100%; margin-bottom:15px; border-radius:5px;">`;
            }

            html += `<ul class="options-list">`;
            
            q.options.forEach((opt, idx) => {
                let classes = 'option-item';
                const isSelected = state.selected.includes(idx);
                
                // Show colors if:
                // 1. Training mode AND validated
                // 2. Review mode (exam finished)
                const showFeedback = (currentMode === 'training' && state.validated) || reviewMode;

                if (showFeedback) {
                     if (opt.isCorrect) classes += ' correct';
                     else if (isSelected) classes += ' incorrect';
                     
                     // Highlight missed correct answers
                     if(opt.isCorrect && !isSelected) classes += ' missed';
                } else {
                    if (isSelected) classes += ' selected';
                }

                html += `<li class="${classes}" onclick="selectOption(${idx})">${opt.text}</li>`;
            });
            html += `</ul>`;

            // Explanation
            if (showFeedback && q.explanation) {
                 html += `<div class="explanation" style="display:block"><strong>Explication:</strong><br>${q.explanation}</div>`;
            }

            html += `</div>`;
            document.getElementById('question-container').innerHTML = html;

            document.getElementById('btn-prev').disabled = (currentIndex === 0);
            
            // Handle Next Button
            // If training mode: always active? No, let's keep it simple.
            document.getElementById('btn-next').disabled = false;
            if(currentIndex === currentQuestions.length - 1) {
                document.getElementById('btn-next').style.display = 'none';
            } else {
                document.getElementById('btn-next').style.display = 'block';
            }

            updateMainButtonState();
        }

        function selectOption(optIdx) {
            const q = currentQuestions[currentIndex];
            if (!userAnswers[q.id]) userAnswers[q.id] = { selected: [], validated: false, isCorrect: false };
            const state = userAnswers[q.id];

            // Lock if validation happened in training, OR if we are in review mode
            if ((currentMode === 'training' && state.validated) || reviewMode) return;

            if (q.multi) {
                const i = state.selected.indexOf(optIdx);
                if (i > -1) state.selected.splice(i, 1);
                else state.selected.push(optIdx);
            } else {
                state.selected = [optIdx];
            }
            renderQuestion();
        }

        function handleMainButton() {
            const btn = document.getElementById('btn-check');
            const text = btn.innerText;
            
            if (text === "Terminer le quiz") {
                finishQuiz();
                return;
            }
            
            if (text === "Valider") {
                validateAnswer();
                return;
            }
            
            if(text === "Suivant") { // Fallback
                moveQuestion(1);
            }
        }

        function updateMainButtonState() {
             const btn = document.getElementById('btn-check');
             const q = currentQuestions[currentIndex];
             const state = userAnswers[q.id] || { selected: [], validated: false };
             
             // Review Mode: Hide validation/finish button, handled by 'Review' flow naturally
             if (reviewMode) {
                 btn.style.display = 'none';
                 // Show 'Next' even on last question if we want to loop? No, just prev/next
                 return;
             }

             // Exam / Mock Mode
             if (currentMode === 'exam' || currentMode === 'mock') {
                 // Only show "Finish" on the last question
                 if (currentIndex === currentQuestions.length - 1) {
                     btn.style.display = 'block';
                     btn.innerText = "Terminer le quiz";
                     btn.className = "nav-btn btn-validate"; // Green
                 } else {
                     btn.style.display = 'none';
                 }
                 return;
             }

             // Training Mode
             if (currentMode === 'training') {
                 // If already validated, button might be 'Next' or hidden?
                 // Let's keep it simple: "Valider" if not validated.
                 // If validated, maybe show nothing or "Next"?
                 // Creating a unified flow is better.
                 
                 btn.style.display = 'block';
                 if (state.validated) {
                     // If validated, usually we just go next. 
                     // But the main generic 'Next' button exists.
                     // So we disable or hide 'Valider'.
                     btn.disabled = true;
                     btn.innerText = "Validé";
                 } else {
                     btn.disabled = false;
                     btn.innerText = "Valider";
                 }
                 
                 // On last question of series/training, if validated, change to 'Terminer'
                 if (currentIndex === currentQuestions.length - 1 && state.validated) {
                     btn.disabled = false;
                     btn.innerText = "Terminer le quiz";
                 }
             }
        }

        function validateAnswer() {
            const q = currentQuestions[currentIndex];
            if (!userAnswers[q.id]) userAnswers[q.id] = { selected: [], validated: false };
            
            // Check correctness
            const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1);
            const userIndices = userAnswers[q.id].selected.sort();
            const correctSorted = correctIndices.sort().toString();
            const userSorted = userIndices.toString();
            
            userAnswers[q.id].isCorrect = (correctSorted === userSorted);
            userAnswers[q.id].validated = true;
            
            renderQuestion();
        }

        function moveQuestion(delta) {
            const newIndex = currentIndex + delta;
            if (newIndex >= 0 && newIndex < currentQuestions.length) {
                currentIndex = newIndex;
                renderQuestion();
            }
        }

        function finishQuiz() {
            let correctCount = 0;
            let totalAnswered = 0; // In exam mode, we count all as answered effectively (or skipped)

            currentQuestions.forEach(q => {
                let state = userAnswers[q.id];
                
                // If not visited/answered, init empty state
                if (!state) {
                    state = { selected: [], validated: true, isCorrect: false };
                    userAnswers[q.id] = state;
                } else {
                    // Start validation for all
                    const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1);
                    const userIndices = state.selected.sort();
                    const correctSorted = correctIndices.sort().toString();
                    const userSorted = userIndices.toString();
                    
                    state.isCorrect = (correctSorted === userSorted);
                    state.validated = true;
                }

                if (state.isCorrect) correctCount++;
            });

            const score = Math.round((correctCount / currentQuestions.length) * 100);
            
            document.getElementById('quiz-interface').style.display = 'none';
            document.getElementById('result-screen').style.display = 'block';
            document.getElementById('final-score').innerText = `${score}%`;
            document.getElementById('score-details').innerText = `${correctCount} bonnes réponses sur ${currentQuestions.length} questions.`;
        }
        
        function reviewErrors() {
             reviewMode = true;
             document.getElementById('result-screen').style.display = 'none';
             document.getElementById('quiz-interface').style.display = 'block';
             currentIndex = 0;
             renderQuestion();
        }

    </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__JSON_DATA__', $json)
$html | Out-File $outputHtml -Encoding UTF8
Write-Host "Quiz v4 generated successfully at $outputHtml"
