
# Script to generate CCNA1 Quiz Site - V3 (Bug Fixes & Improvements)
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

# Split by the question number pattern more aggressively
# We check for <strong>NUMBER. which seems to be the consistent marker
# We use a lookahead so the delimiter is kept in the text
$chunks = $content -split '(?=<strong>\s*\d+\.)'

# The first chunk is header junk
$chunks = $chunks | Select-Object -Skip 1

$questionsData = @()
$seenIds = @{}

foreach ($chunk in $chunks) {
    # Extract ID and Text
    # Valid question pattern: <strong>123. Question text...</strong>
    if ($chunk -match '(?s)<strong>\s*(\d+)\.\s*(.*?)</strong>') {
        $qNum = $matches[1]
        $qTextRaw = $matches[2]
        
        # Check for duplicates
        if ($seenIds.ContainsKey($qNum)) { continue }
        $seenIds[$qNum] = $true

        # Decode HTML
        $qText = [System.Net.WebUtility]::HtmlDecode($qTextRaw).Trim()

        # Check for multi-select
        $isMultiSelect = $false
        if ($qText -match '(?i)choisissez.*?trois|choisissez.*?deux|choisissez.*?plusieurs') {
            $isMultiSelect = $true
        }

        # Extract Options (usually in <ul>)
        $options = @()
        if ($chunk -match '(?s)<ul>(.*?)</ul>') {
            $ulContent = $matches[1]
            $liMatches = [regex]::Matches($ulContent, '(?s)<li(.*?)>(.*?)</li>')
            
            foreach ($li in $liMatches) {
                $liAttr = $li.Groups[1].Value
                $liText = $li.Groups[2].Value
                
                # Check for correct answer class
                $isCorrect = $liAttr -match 'correct_answer'
                $optText = [System.Net.WebUtility]::HtmlDecode($liText).Trim()
                
                $options += @{
                    text = $optText
                    isCorrect = $isCorrect
                }
            }
        }
        
        # Extract Explanation
        $explanation = ""
        # Matches: Explique:, Explication:, Expliquer : etc. inside message_box
        if ($chunk -match '(?s)<div class="message_box announce">.*?<b>.*?(?:Explique|Explication|Expliquer).*?</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
        } elseif ($chunk -match '(?s)<p><strong>(?:Explique|Explication|Expliquer).*?</strong>(.*?)</p>') {
             $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1]).Trim()
        }
        
        # Extract Image
        $imageSrc = ""
        if ($chunk -match '(?s)<img.*?src="(.*?)".*?>') {
            $imageSrc = $matches[1]
        }
        
        # Filter out questions with no options (unless it's drag-drop we can't handle yet)
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

# Sort by ID to ensure correct order
$questionsData = $questionsData | Sort-Object { [int]$_.id }

$json = $questionsData | ConvertTo-Json -Depth 10

# HTML Template with LocalStorage and improved UI
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz CCNA1 - Révision Complète</title>
    <style>
        :root {
            --primary: #2c3e50;
            --accent: #3498db;
            --success: #27ae60;
            --danger: #e74c3c;
            --bg: #ecf0f1;
            --card-bg: #ffffff;
        }
        body { font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: var(--bg); color: #333; line-height: 1.6; max-width: 900px; margin: 0 auto; padding: 20px; }
        h1 { text-align: center; color: var(--primary); margin-bottom: 2rem; }
        
        .header-controls { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; background: var(--card-bg); padding: 15px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.05); flex-wrap: wrap; gap: 10px; }
        .score-badge { font-weight: bold; font-size: 1.1em; color: var(--primary); }
        .reset-btn { background: none; border: 1px solid var(--danger); color: var(--danger); padding: 5px 10px; border-radius: 4px; cursor: pointer; font-size: 0.9em; }
        .reset-btn:hover { background: var(--danger); color: white; }

        .card { background: var(--card-bg); border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); padding: 30px; margin-bottom: 20px; transition: transform 0.2s; }
        .question-header { display: flex; justify-content: space-between; margin-bottom: 15px; color: #7f8c8d; font-size: 0.9em; text-transform: uppercase; letter-spacing: 1px; }
        .question-text { font-size: 1.25em; font-weight: 600; margin-bottom: 20px; color: var(--primary); }
        
        .question-image { max-width: 100%; border-radius: 8px; margin: 15px 0; display: block; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        
        .options { list-style: none; padding: 0; display: grid; gap: 10px; }
        .option-item { padding: 15px; border: 2px solid #e0e0e0; border-radius: 8px; cursor: pointer; transition: all 0.2s ease; position: relative; }
        .option-item:hover { border-color: var(--accent); background-color: #f8fbfe; }
        .option-item.selected { border-color: var(--accent); background-color: #ebf5fb; font-weight: 500; }
        
        /* Validated States */
        .option-item.correct { border-color: var(--success); background-color: #d4efdf; color: #145a32; }
        .option-item.correct::after { content: "✓"; position: absolute; right: 15px; font-weight: bold; }
        
        .option-item.incorrect { border-color: var(--danger); background-color: #fadbd8; color: #78281f; }
        .option-item.incorrect::after { content: "✗"; position: absolute; right: 15px; font-weight: bold; }
        
        .option-item.missed { border-color: var(--success); border-style: dashed; background-color: #e9f7ef; }
        .option-item.missed::after { content: "Correction"; position: absolute; right: 15px; font-size: 0.8em; opacity: 0.7; }

        .explanation { background-color: #fef9e7; color: #9a7d0a; padding: 20px; border-radius: 8px; margin-top: 20px; border-left: 5px solid #f1c40f; display: none; margin-top: 20px; animation: fadeIn 0.3s; }
        .explanation strong { display: block; margin-bottom: 5px; color: #7d6608; }

        .controls { display: flex; justify-content: space-between; margin-top: 30px; gap: 10px; }
        button.nav-btn { padding: 12px 25px; border: none; border-radius: 6px; cursor: pointer; font-size: 1em; font-weight: 600; transition: background 0.2s; flex: 1; max-width: 150px; }
        .btn-check { background-color: var(--success); color: white; flex: 2 !important; max-width: none !important; }
        .btn-check:hover { background-color: #219150; }
        .btn-next { background-color: var(--accent); color: white; }
        .btn-next:hover { background-color: #2980b9; }
        .btn-prev { background-color: #95a5a6; color: white; }
        .btn-prev:hover { background-color: #7f8c8d; }
        button:disabled { opacity: 0.5; cursor: not-allowed; filter: grayscale(1); }

        .filter-controls { text-align: center; margin-bottom: 20px; }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        @media (max-width: 600px) {
            .controls { flex-direction: column-reverse; }
            button.nav-btn { max-width: 100%; }
            .btn-check { margin-bottom: 10px; }
        }
    </style>
</head>
<body>

    <h1>Quiz CCNA 1 v7</h1>
    
    <div class="header-controls">
        <span class="score-badge" id="progress">Question 1 / 0</span>
        <span class="score-badge" id="score">Score: 0%</span>
        <button class="reset-btn" onclick="resetQuiz()">Réinitialiser tout</button>
    </div>

    <div class="filter-controls">
         <label><input type="checkbox" id="show-unanswered" onchange="toggleUnansweredMode()"> Mode "Questions non répondues uniquement"</label>
    </div>

    <div id="quiz-container">
        <!-- Question will be injected here -->
    </div>

    <div class="controls">
        <button class="nav-btn btn-prev" id="btn-prev" onclick="changeQuestion(-1)">← Précédent</button>
        <button class="nav-btn btn-check" id="btn-check" onclick="checkAnswer()">Vérifier la réponse</button>
        <button class="nav-btn btn-next" id="btn-next" onclick="changeQuestion(1)">Suivant →</button>
    </div>

    <script>
        const questions = __JSON_DATA__;
        
        // State
        let currentIdx = 0;
        let userAnswers = {}; // { qId: { selected: [], checked: boolean, isCorrect: boolean } }
        let showUnansweredOnly = false;
        let filteredIndices = questions.map((_, i) => i);

        function init() {
            // Load from LocalStorage
            const saved = localStorage.getItem('ccna1_quiz_state');
            if (saved) {
                try {
                    userAnswers = JSON.parse(saved);
                } catch(e) { console.error('Save corrupted'); }
            }
            
            // Load last position
            const lastIdx = localStorage.getItem('ccna1_quiz_idx');
            if (lastIdx) currentIdx = parseInt(lastIdx);
            if (currentIdx >= questions.length) currentIdx = 0;

            updateFilter();
            renderQuestion();
        }

        function saveState() {
            localStorage.setItem('ccna1_quiz_state', JSON.stringify(userAnswers));
            localStorage.setItem('ccna1_quiz_idx', currentIdx);
        }

        function resetQuiz() {
            if(confirm("Voulez-vous vraiment effacer toute votre progression ?")) {
                localStorage.removeItem('ccna1_quiz_state');
                localStorage.removeItem('ccna1_quiz_idx');
                userAnswers = {};
                currentIdx = 0;
                location.reload();
            }
        }

        function toggleUnansweredMode() {
            showUnansweredOnly = document.getElementById('show-unanswered').checked;
            updateFilter();
            // Jump to first valid question if current is hidden
            if (!filteredIndices.includes(currentIdx)) {
                currentIdx = filteredIndices[0] || 0;
            }
            renderQuestion();
        }

        function updateFilter() {
            if (showUnansweredOnly) {
                filteredIndices = questions.map((q, i) => {
                    const state = userAnswers[q.id];
                    // Keep if not checked or (checked but incorrect)
                    if (!state || !state.checked || !state.isCorrect) return i;
                    return -1;
                }).filter(i => i !== -1);
            } else {
                filteredIndices = questions.map((_, i) => i);
            }
            
            if (filteredIndices.length === 0 && showUnansweredOnly) {
                alert("Bravo ! Aucune question non résolue restante.");
                document.getElementById('show-unanswered').checked = false;
                toggleUnansweredMode();
            }
        }

        function getRealIndex() {
            // If we are in filtered mode, currentIdx might refer to the Nth filtered item
            // But let's keep currentIdx as the global index for simplicity 
            // and use prev/next to skip iterations
            return currentIdx;
        }

        function renderQuestion() {
            if (currentIdx < 0 || currentIdx >= questions.length) {
                currentIdx = 0;
            }

            const q = questions[currentIdx];
            const container = document.getElementById('quiz-container');
            const state = userAnswers[q.id] || { selected: [], checked: false };
            
            // Stats
            const answeredCount = Object.keys(userAnswers).filter(k => userAnswers[k].checked).length;
            const correctCount = Object.keys(userAnswers).filter(k => userAnswers[k].isCorrect).length;
            const scorePercent = answeredCount > 0 ? Math.round((correctCount / answeredCount) * 100) : 0;
            
            document.getElementById('progress').innerText = `Question ${q.id} (${currentIdx + 1}/${questions.length})`;
            document.getElementById('score').innerText = `Score: ${scorePercent}% (${correctCount}/${answeredCount})`;

            let html = `<div class="card">
                <div class="question-header">Question ID: ${q.id} ${q.multi ? '• Choix Multiples' : ''}</div>
                <div class="question-text">${q.text}</div>`;
            
            if (q.image) {
                html += `<img src="${q.image}" class="question-image" alt="Illustration" loading="lazy">`;
            }
            
            html += `<ul class="options">`;
            
            q.options.forEach((opt, idx) => {
                let classes = 'option-item';
                let isSelected = state.selected.includes(idx);
                
                if (state.checked) {
                    if (opt.isCorrect) classes += ' correct';
                    else if (isSelected) classes += ' incorrect';
                    
                    if (opt.isCorrect && !isSelected) classes += ' missed';
                } else {
                    if (isSelected) classes += ' selected';
                }
                
                // Click handler
                const onClick = state.checked ? '' : `onclick="selectOption(${idx})"`;
                // Checkbox/Radio visual
                const inputType = q.multi ? 'checkbox' : 'radio';
                const checkedAttr = isSelected ? 'checked' : '';
                
                html += `<li class="${classes}" ${onClick}>
                    <input type="${inputType}" ${checkedAttr} disabled style="margin-right:10px;">
                    ${opt.text}
                </li>`;
            });
            
            html += `</ul>`;
            
            if (state.checked && q.explanation) {
                html += `<div class="explanation" style="display:block"><strong>Explication:</strong><br>${q.explanation}</div>`;
            }
            
            html += `</div>`;
            container.innerHTML = html;
            
            updateControls();
            saveState();
        }

        function selectOption(optIdx) {
            const q = questions[currentIdx];
            if (!userAnswers[q.id]) userAnswers[q.id] = { selected: [], checked: false };
            const state = userAnswers[q.id];

            if (q.multi) {
                const idx = state.selected.indexOf(optIdx);
                if (idx > -1) state.selected.splice(idx, 1);
                else state.selected.push(optIdx);
            } else {
                state.selected = [optIdx];
            }
            renderQuestion();
        }

        function checkAnswer() {
            const q = questions[currentIdx];
            if (!userAnswers[q.id] || userAnswers[q.id].selected.length === 0) return;
            
            const state = userAnswers[q.id];
            state.checked = true;
            
            const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1);
            const correctSorted = correctIndices.sort().toString();
            const selectedSorted = state.selected.sort().toString();
            
            state.isCorrect = (correctSorted === selectedSorted);
            
            renderQuestion();
        }

        function changeQuestion(delta) {
            // Find next index in filtered list
            if (showUnansweredOnly) {
                let currentIndexInFiltered = filteredIndices.indexOf(currentIdx);
                if (currentIndexInFiltered === -1 && delta > 0) {
                     // Find next valid
                     const next = filteredIndices.find(i => i > currentIdx);
                     if (next !== undefined) currentIdx = next;
                } else if (currentIndexInFiltered === -1 && delta < 0) {
                     // Find prev valid
                     const prev = [...filteredIndices].reverse().find(i => i < currentIdx);
                     if (prev !== undefined) currentIdx = prev;
                } else {
                    let nextIdx = currentIndexInFiltered + delta;
                    if (nextIdx >= 0 && nextIdx < filteredIndices.length) {
                        currentIdx = filteredIndices[nextIdx];
                    }
                }
            } else {
                const nextIdx = currentIdx + delta;
                if (nextIdx >= 0 && nextIdx < questions.length) {
                    currentIdx = nextIdx;
                }
            }
            renderQuestion();
        }

        function updateControls() {
            const q = questions[currentIdx];
            const state = userAnswers[q.id];
            
            document.getElementById('btn-check').disabled = (state && state.checked) || (!state || state.selected.length === 0);
            
            // Check boundaries
            let isFirst = false; 
            let isLast = false;

            if (showUnansweredOnly) {
                const idx = filteredIndices.indexOf(currentIdx);
                isFirst = idx <= 0;
                isLast = idx >= filteredIndices.length - 1;
            } else {
                isFirst = currentIdx === 0;
                isLast = currentIdx === questions.length - 1;
            }

            document.getElementById('btn-prev').disabled = isFirst;
            document.getElementById('btn-next').disabled = isLast;
        }

        init();
    </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__JSON_DATA__', $json)
$html | Out-File $outputHtml -Encoding UTF8
Write-Host "Quiz v3 generated at $outputHtml with $($questionsData.Count) questions."
