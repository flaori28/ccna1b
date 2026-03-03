
# Script to generate CCNA1 Quiz Site
$url = "https://ccnareponses.com/ccna-1-examen-final-itnv7-questions-et-reponses-francais/"
$outputHtml = "index.html"
$sourceFile = "page_source.html"

# Download if not exists
if (-not (Test-Path $sourceFile)) {
    Write-Host "Downloading content..."
    Invoke-WebRequest -Uri $url -OutFile $sourceFile
}

$content = Get-Content -Path $sourceFile -Raw -Encoding UTF8

# Basic cleanup to help regex
$content = $content -replace '(?s)<script.*?</script>', ''

# Questions usually start with <p><strong>NUMBER.
$chunks = $content -split '(?=<p><strong>\d+\.)'

# The first chunk is header junk
$chunks = $chunks | Select-Object -Skip 1

$questionsData = @()

foreach ($chunk in $chunks) {
    if ($chunk -match '(?s)<p><strong>(\d+)\.\s*(.*?)</strong></p>') {
        $qNum = $matches[1]
        $qText = $matches[2]
        
        $qText = [System.Net.WebUtility]::HtmlDecode($qText)
        
        $options = @()
        $isMultiSelect = $qText -match "Choisissez.*?trois|Choisissez.*?deux"

        if ($chunk -match '(?s)<ul>(.*?)</ul>') {
            $ulContent = $matches[1]
            $liMatches = [regex]::Matches($ulContent, '(?s)<li(.*?)>(.*?)</li>')
            
            foreach ($li in $liMatches) {
                $liAttr = $li.Groups[1].Value
                $liText = $li.Groups[2].Value
                
                $isCorrect = $liAttr -match "correct_answer"
                $optText = [System.Net.WebUtility]::HtmlDecode($liText)
                
                $options += @{
                    text = $optText
                    isCorrect = $isCorrect
                }
            }
        }
        
        $explanation = ""
        if ($chunk -match '(?s)<div class="message_box announce"><p><b>(?:Explique|Explication|Expliquer)(?:\s*:|)\s*</b>(.*?)</p>') {
            $explanation = [System.Net.WebUtility]::HtmlDecode($matches[1])
        }
        
        $imageSrc = ""
        if ($chunk -match '(?s)<img.*?src="(.*?)".*?>') {
            $imageSrc = $matches[1]
        }

        if ($options.Count -gt 0) {
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

$json = $questionsData | ConvertTo-Json -Depth 10

# Create HTML Template using single quotes
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz CCNA1 - Révision</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f9; color: #333; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { text-align: center; color: #2c3e50; }
        .card { background: white; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; }
        .question-text { font-size: 1.1em; font-weight: 600; margin-bottom: 15px; }
        .question-image { max-width: 100%; border-radius: 4px; margin-bottom: 15px; display: block; }
        .options { list-style: none; padding: 0; }
        .option-item { padding: 10px; margin-bottom: 8px; border: 1px solid #ddd; border-radius: 4px; cursor: pointer; transition: background 0.2s; }
        .option-item:hover { background-color: #f8f9fa; }
        .option-item.selected { background-color: #e3f2fd; border-color: #2196f3; }
        
        .option-item.correct { background-color: #d4edda; border-color: #28a745; color: #155724; }
        .option-item.incorrect { background-color: #f8d7da; border-color: #dc3545; color: #721c24; }
        .option-item.missed { border-color: #28a745; border-style: dashed; }

        .explanation { background-color: #fff3cd; color: #856404; padding: 15px; border-radius: 4px; margin-top: 15px; display: none; border-left: 5px solid #ffeeba; }
        .controls { display: flex; justify-content: space-between; margin-top: 20px; }
        button { padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; font-size: 1em; }
        .btn-check { background-color: #28a745; color: white; }
        .btn-next { background-color: #007bff; color: white; }
        .btn-prev { background-color: #6c757d; color: white; }
        button:disabled { opacity: 0.5; cursor: not-allowed; }
        .status-bar { margin-bottom: 20px; display: flex; justify-content: space-between; font-weight: bold; }
    </style>
</head>
<body>

    <h1>Quiz de Révision CCNA 1</h1>
    
    <div class="status-bar">
        <span id="progress">Question 1 / 0</span>
        <span id="score">Score: 0</span>
    </div>

    <div id="quiz-container">
        <!-- Question will be injected here -->
    </div>

    <div class="controls">
        <button class="btn-prev" id="btn-prev" onclick="prevQuestion()">Précédent</button>
        <button class="btn-check" id="btn-check" onclick="checkAnswer()">Vérifier</button>
        <button class="btn-next" id="btn-next" onclick="nextQuestion()">Suivant</button>
    </div>

    <script>
        const questions = __JSON_DATA__;
        let currentIdx = 0;
        let score = 0;
        let userAnswers = {}; 

        function init() {
            document.getElementById('progress').innerText = `Question 1 / ${questions.length}`;
            renderQuestion();
        }

        function renderQuestion() {
            const q = questions[currentIdx];
            const container = document.getElementById('quiz-container');
            
            const state = userAnswers[currentIdx] || { selected: [], checked: false };
            
            let html = `<div class="card">
                <div class="question-text">${q.id}. ${q.text}</div>`;
            
            if (q.image) {
                html += `<img src="${q.image}" class="question-image" alt="Illustration">`;
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
                
                const onClick = state.checked ? '' : `onclick="selectOption(${idx})"`;
                
                html += `<li class="${classes}" ${onClick}>${opt.text}</li>`;
            });
            
            html += `</ul>`;
            
            if (state.checked && q.explanation) {
                html += `<div class="explanation" style="display:block"><strong>Explication:</strong><br>${q.explanation}</div>`;
            }
            
            html += `</div>`;
            container.innerHTML = html;
            
            updateControls();
        }

        function selectOption(optIdx) {
            const q = questions[currentIdx];
            if (!userAnswers[currentIdx]) userAnswers[currentIdx] = { selected: [], checked: false };
            const state = userAnswers[currentIdx];

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
            if (!userAnswers[currentIdx]) return;
            const state = userAnswers[currentIdx];
            state.checked = true;
            
            const q = questions[currentIdx];
            const correctIndices = q.options.map((o, i) => o.isCorrect ? i : -1).filter(i => i !== -1);
            
            const correctSorted = correctIndices.sort().toString();
            const selectedSorted = state.selected.sort().toString();
            
            if (!state.scored) {
                 if (correctSorted === selectedSorted) {
                    score++;
                 }
                 state.scored = true;
                 updateHeader();
            }
            renderQuestion();
        }

        function nextQuestion() {
            if (currentIdx < questions.length - 1) {
                currentIdx++;
                updateHeader();
                renderQuestion();
            }
        }

        function prevQuestion() {
            if (currentIdx > 0) {
                currentIdx--;
                updateHeader();
                renderQuestion();
            }
        }

        function updateHeader() {
            document.getElementById('progress').innerText = `Question ${currentIdx + 1} / ${questions.length}`;
            document.getElementById('score').innerText = `Score: ${score}`;
        }

        function updateControls() {
            const state = userAnswers[currentIdx];
            document.getElementById('btn-check').disabled = state && state.checked;
            document.getElementById('btn-prev').disabled = currentIdx === 0;
            document.getElementById('btn-next').disabled = currentIdx === questions.length - 1;
        }

        init();
    </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__JSON_DATA__', $json)
$html | Out-File $outputHtml -Encoding UTF8
Write-Host "Quiz generated at $outputHtml with $($questionsData.Count) questions."
