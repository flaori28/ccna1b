let currentQuestionIndex = 0;
let score = 0;
let currentMode = ''; // 'training' ou 'exam'
let userAnswers = []; // Pour stocker les réponses en mode examen
let selectedOptionIndices = []; // Tableau pour gérer multiples sélections
let currentQuizQuestions = []; // Questions actives pour la session

// Éléments du DOM
const homeScreen = document.getElementById('home');
const quizScreen = document.getElementById('quiz');
const resultsScreen = document.getElementById('results');

const questionText = document.getElementById('question-text');
const optionsContainer = document.getElementById('options-container');
const nextBtn = document.getElementById('next-btn');
const validateBtn = document.getElementById('validate-btn');
const prevBtn = document.getElementById('prev-btn');
const feedback = document.getElementById('feedback');
const counterDisplay = document.getElementById('question-counter');
const scoreDisplay = document.getElementById('score-display');

function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
}

function startQuiz(mode) {
    currentQuestionIndex = 0;
    score = 0;
    userAnswers = [];
    selectedOptionIndices = [];
    currentQuizQuestions = [];

    // Filter valid questions (ignore null answers)
    const validQuestions = questions.filter(q => q.answer !== null);

    if (mode === 'training') {
        currentMode = 'training';
        currentQuizQuestions = [...validQuestions];
        scoreDisplay.style.display = 'block';
    } else if (mode === 'exam') {
        currentMode = 'exam';
        currentQuizQuestions = [...validQuestions];
        scoreDisplay.style.display = 'none';
    } else if (mode === 'series60') {
        currentMode = 'exam'; // Exam Blanc is Exam mode
        scoreDisplay.style.display = 'none';
        // Random 60 questions
        currentQuizQuestions = shuffleArray([...validQuestions]).slice(0, 60);
    } else if (mode && mode.startsWith('series_')) {
        currentMode = 'training'; // Series are Training
        scoreDisplay.style.display = 'block';
        const seriesNum = parseInt(mode.split('_')[1]);
        const start = (seriesNum - 1) * 10;
        const end = start + 10;
        // Take contiguous slice from the valid list
        currentQuizQuestions = validQuestions.slice(start, end);
    }
    
    if (currentQuizQuestions.length === 0) {
        alert("Cette série ne contient pas encore de questions valides.");
        return;
    }

    homeScreen.style.display = 'none';
    quizScreen.style.display = 'block';
    resultsScreen.style.display = 'none';
    
    if (currentMode === 'training') {
        updateScoreDisplay();
    }

    loadQuestion();
}

function loadQuestion() {
    const question = currentQuizQuestions[currentQuestionIndex];
    questionText.innerHTML = question.question;
    optionsContainer.innerHTML = '';
    feedback.innerHTML = '';
    feedback.style.display = 'none';
    feedback.className = 'feedback';
    
    // Réinitialiser les boutons
    nextBtn.style.display = 'none';
    validateBtn.style.display = 'none';
    prevBtn.style.display = (currentQuestionIndex > 0) ? 'inline-block' : 'none';

    // Restauration de l'état
    const savedAnswer = userAnswers.find(a => a.questionIndex === currentQuestionIndex);
    
    if (savedAnswer) {
        selectedOptionIndices = [...savedAnswer.selected];
    } else {
        selectedOptionIndices = [];
    }
    
    counterDisplay.innerHTML = `Question ${currentQuestionIndex + 1}/${currentQuizQuestions.length}`;

    // Affichage image si présente
    if (question.image) {
        let img = document.getElementById('question-image');
        if (!img) {
            img = document.createElement('img');
            img.id = 'question-image';
            img.style.maxWidth = '100%';
            img.style.marginTop = '10px';
            questionText.parentNode.insertBefore(img, optionsContainer);
        }
        img.src = question.image;
        img.style.display = 'block';
    } else {
        const img = document.getElementById('question-image');
        if (img) img.style.display = 'none';
    }

    if (question.type === 'association') {
        renderAssociationQuestion(question);
        return;
    }

    const isMultiselect = Array.isArray(question.answer);
    
    // Ajout indication visuelle (optionnel)
    if (isMultiselect) {
        const hint = document.createElement('p');
        hint.innerHTML = "(Plusieurs réponses possibles)";
        hint.style.fontStyle = "italic";
        hint.style.fontSize = "0.9em";
        hint.style.color = "#555";
        optionsContainer.appendChild(hint);
    }

    const buttons = [];
    question.options.forEach((option, index) => {
        const button = document.createElement('button');
        button.innerHTML = option;
        button.classList.add('option-btn');
        if (selectedOptionIndices.includes(index)) {
             button.classList.add('selected');
             button.style.backgroundColor = '#3498db';
             button.style.color = 'white';
        }
        button.onclick = () => selectOption(index, button, isMultiselect);
        optionsContainer.appendChild(button);
        buttons.push(button);
    });

    // Logique de restauration visuelle selon le mode
    if (savedAnswer) {
        if (currentMode === 'training') {
             // Mode Entraînement : On fige tout et on montre le résultat
             validateBtn.style.display = 'none';
             nextBtn.style.display = 'inline-block';
             
             // Désactiver les boutons
             buttons.forEach(btn => btn.disabled = true);
             
             // Récupérer les bonnes réponses pour l'affichage
             const correctAnswers = savedAnswer.correctAnswer || (Array.isArray(question.answer) ? question.answer : [question.answer]);
             
             if (savedAnswer.isCorrect) {
                 feedback.textContent = "Bonne réponse !";
                 feedback.classList.add('success');
                 // Vert pour les sélections justes
                 savedAnswer.selected.forEach(idx => {
                    if(buttons[idx]) buttons[idx].style.backgroundColor = '#2ecc71';
                 });
             } else {
                 feedback.textContent = "Mauvaise réponse."; 
                 feedback.classList.add('error');
                 
                 // Rouge pour les erreurs utilisateur
                 savedAnswer.selected.forEach(idx => {
                     if(buttons[idx]) buttons[idx].style.backgroundColor = '#e74c3c';
                 });
                 
                 // Vert pour les bonnes réponses manquées
                 correctAnswers.forEach(idx => {
                     if(buttons[idx]) buttons[idx].style.backgroundColor = '#2ecc71';
                 });
                 
                 const correctText = correctAnswers.map(i => question.options[i]).join("<br>- ");
                 feedback.innerHTML = `Mauvaise réponse. Les bonnes réponses étaient :<br>- ${correctText}`;
             }
             
             // Logic Glossaire 
             const glossaryTerms = findGlossaryTerms(question.question);
             if (glossaryTerms.length > 0) {
                const glossaryContainer = document.createElement('div');
                glossaryContainer.className = 'glossary-container';
                glossaryContainer.style.marginTop = '15px';
                glossaryContainer.style.borderTop = '1px solid #ccc';
                glossaryContainer.style.paddingTop = '10px';
                
                const title = document.createElement('h4');
                title.textContent = "Mots-clés et Définitions :";
                title.style.margin = '0 0 10px 0';
                title.style.fontSize = '0.9em';
                glossaryContainer.appendChild(title);
                
                glossaryTerms.forEach(item => {
                    const termDiv = document.createElement('div');
                    termDiv.style.marginBottom = '5px';
                    termDiv.style.fontSize = '0.9em';
                    termDiv.innerHTML = `<strong style="color:#2980b9">${item.term}:</strong> ${item.definition}`;
                    glossaryContainer.appendChild(termDiv);
                });
                
                feedback.appendChild(glossaryContainer);
            }
             
             feedback.style.display = 'block';

        } else {
             // Mode Exam : On permet de changer la réponse
             validateBtn.style.display = 'inline-block';
        }
    }
}

function selectOption(index, button, isMultiselect) {
    if (isMultiselect) {
        // Toggle selection
        const pos = selectedOptionIndices.indexOf(index);
        if (pos === -1) {
            selectedOptionIndices.push(index);
            button.classList.add('selected');
            button.style.backgroundColor = '#3498db';
            button.style.color = 'white';
        } else {
            selectedOptionIndices.splice(pos, 1);
            button.classList.remove('selected');
            button.style.backgroundColor = '';
            button.style.color = '';
        }
    } else {
        // Single selection functionality
        selectedOptionIndices = [index];
        const allButtons = optionsContainer.querySelectorAll('.option-btn');
        allButtons.forEach(btn => {
            btn.style.backgroundColor = ''; 
            btn.style.color = '';
            btn.classList.remove('selected');
        });
        button.classList.add('selected');
        button.style.backgroundColor = '#3498db';
        button.style.color = 'white';
    }

    // Afficher valider s'il y a au moins une sélection
    if (selectedOptionIndices.length > 0) {
        validateBtn.style.display = 'inline-block';
    } else {
        validateBtn.style.display = 'none';
    }
}

function validateAnswer() {
    const question = currentQuizQuestions[currentQuestionIndex];
    if (question.type === 'association') {
        validateAssociationAnswer(question);
        return;
    }

    if (selectedOptionIndices.length === 0) return;

    const question = currentQuizQuestions[currentQuestionIndex];
    let isCorrect = false;
    let correctAnswers = [];

    // Normaliser la réponse correcte en tableau
    if (Array.isArray(question.answer)) {
        correctAnswers = question.answer;
        // Vérifier si les tableaux sont identiques (ordre ne compte pas ici car trié implicitement par index croissant dans la logique de saisie si on veut être strict, mais ici on compare le contenu)
        // Mais attention selectOption pousse dans l'ordre du clic. Donc on doit trier.
        const userSorted = [...selectedOptionIndices].sort((a,b) => a-b);
        const correctSorted = [...correctAnswers].sort((a,b) => a-b);
        
        isCorrect = JSON.stringify(userSorted) === JSON.stringify(correctSorted);
    } else {
        correctAnswers = [question.answer];
        isCorrect = (selectedOptionIndices.length === 1 && selectedOptionIndices[0] === question.answer);
    }

    const allButtons = optionsContainer.querySelectorAll('button.option-btn'); // Sélecteur plus précis pour ignorer le hint p
    allButtons.forEach(btn => btn.disabled = true);

    validateBtn.style.display = 'none';
    nextBtn.style.display = 'inline-block';

    if (currentMode === 'training') {
        // Sauvegarder la réponse pour l'historique
        const existingIndex = userAnswers.findIndex(a => a.questionIndex === currentQuestionIndex);
        if (existingIndex === -1) {
             userAnswers.push({
                questionIndex: currentQuestionIndex,
                selected: [...selectedOptionIndices],
                isCorrect: isCorrect,
                correctAnswer: correctAnswers
            });
        }

        if (isCorrect) {
            feedback.textContent = "Bonne réponse !";
            feedback.classList.add('success');
            if (existingIndex === -1) score++; // Incrémenter seulement si nouvelle réponse
            // Colorer en vert les sélections (qui sont justes)
            selectedOptionIndices.forEach(idx => {
               if(allButtons[idx]) allButtons[idx].style.backgroundColor = '#2ecc71';
            });
        } else {
            feedback.textContent = "Mauvaise réponse.";
            feedback.classList.add('error');
            // Colorer en rouge les sélections utilisateur
            selectedOptionIndices.forEach(idx => {
                if(allButtons[idx]) allButtons[idx].style.backgroundColor = '#e74c3c';
            });
            // Montrer les bonnes réponses en vert
            correctAnswers.forEach(idx => {
                if(allButtons[idx]) allButtons[idx].style.backgroundColor = '#2ecc71';
            });
            
            // Construire le texte de réponse
            const correctText = correctAnswers.map(i => question.options[i]).join("<br>- ");
            feedback.innerHTML = `Mauvaise réponse. Les bonnes réponses étaient :<br>- ${correctText}`;
        }
        
        // --- Logic glossaire ---
        const glossaryTerms = findGlossaryTerms(question.question);
        if (glossaryTerms.length > 0) {
            const glossaryContainer = document.createElement('div');
            glossaryContainer.className = 'glossary-container';
            glossaryContainer.style.marginTop = '15px';
            glossaryContainer.style.borderTop = '1px solid #ccc';
            glossaryContainer.style.paddingTop = '10px';
            
            const title = document.createElement('h4');
            title.textContent = "Mots-clés et Définitions :";
            title.style.margin = '0 0 10px 0';
            title.style.fontSize = '0.9em';
            glossaryContainer.appendChild(title);
            
            glossaryTerms.forEach(item => {
                const termDiv = document.createElement('div');
                termDiv.style.marginBottom = '5px';
                termDiv.style.fontSize = '0.9em';
                termDiv.innerHTML = `<strong style="color:#2980b9">${item.term}:</strong> ${item.definition}`;
                glossaryContainer.appendChild(termDiv);
            });
            
            feedback.appendChild(glossaryContainer);
        }
        // --- Fin Logic glossaire ---

        feedback.style.display = 'block';
        updateScoreDisplay();
    } else {
        // Mode Exam
        const existingIndex = userAnswers.findIndex(a => a.questionIndex === currentQuestionIndex);
        
        if (existingIndex !== -1) {
            // Mettre à jour la réponse existante et ajuster le score
            if (userAnswers[existingIndex].isCorrect && !isCorrect) {
                 score--;
            } else if (!userAnswers[existingIndex].isCorrect && isCorrect) {
                 score++;
            }
            
            userAnswers[existingIndex] = {
                questionIndex: currentQuestionIndex,
                selected: [...selectedOptionIndices],
                isCorrect: isCorrect,
                correctAnswer: correctAnswers
            };
        } else {
            // Nouvelle réponse
            userAnswers.push({
                questionIndex: currentQuestionIndex,
                selected: [...selectedOptionIndices], // Copie
                isCorrect: isCorrect,
                correctAnswer: correctAnswers // Stocker pour affichage résultats
            });
            if (isCorrect) score++;
        }
    }
}

function prevQuestion() {
    if (currentQuestionIndex > 0) {
        currentQuestionIndex--;
        loadQuestion();
    }
}

function nextQuestion() {
    currentQuestionIndex++;
    if (currentQuestionIndex < currentQuizQuestions.length) {
        loadQuestion();
    } else {
        showResults();
    }
}

function updateScoreDisplay() {
    scoreDisplay.innerHTML = `Score: ${score}`;
}

function showResults() {
    quizScreen.style.display = 'none';
    resultsScreen.style.display = 'block';

    const percentage = Math.round((score / currentQuizQuestions.length) * 100);
    document.getElementById('final-score').innerHTML = `${percentage}%`;

    let messageText = "";
    if (percentage === 100) messageText = "Excellent ! Un sans faute !";
    else if (percentage >= 80) messageText = "Très bien !";
    else if (percentage >= 50) messageText = "Pas mal, mais peut mieux faire.";
    else messageText = "Il faut réviser encore un peu.";

    const resultMessageContainer = document.getElementById('result-message');
    resultMessageContainer.innerHTML = '';
    
    const messageP = document.createElement('p');
    messageP.textContent = messageText;
    messageP.style.fontSize = '1.2rem';
    messageP.style.marginBottom = '20px';
    resultMessageContainer.appendChild(messageP);

    if (currentMode === 'exam') {
        const wrongAnswers = userAnswers.filter(a => !a.isCorrect);
        // Bouton pour afficher/masquer les détails
        if (wrongAnswers.length > 0) {
            const h3 = document.createElement('h3');
            h3.textContent = "Corrections des erreurs (" + wrongAnswers.length + "):";
            h3.style.color = '#e74c3c';
            resultMessageContainer.appendChild(h3);

            const detailsDiv = document.createElement('div');
            detailsDiv.style.textAlign = 'left';
            
            wrongAnswers.forEach((ans) => {
                const q = currentQuizQuestions[ans.questionIndex];
                
                // Formatter les réponses utilisateur
                const userRespText = ans.selected.map(i => q.options[i]).join(", ");
                // Formatter les bonnes réponses
                const correctRespText = ans.correctAnswer.map(i => q.options[i]).join(", ");
                
                // --- Logic Glossaire ---
                const glossaryTerms = findGlossaryTerms(q.question);
                let glossaryHTML = "";
                if (glossaryTerms.length > 0) {
                     glossaryHTML = `<div style="margin-top:10px; padding-top:10px; border-top:1px dashed #ccc; font-size:0.9em;">` +
                     `<strong>Mots-clés:</strong><br>` +
                     glossaryTerms.map(t => `• <strong>${t.term}:</strong> ${t.definition}`).join("<br>") +
                     `</div>`;
                }
                // --- Fin Logic Glossaire ---

                const item = document.createElement('div');
                item.style.marginBottom = '15px';
                item.style.padding = '10px';
                item.style.backgroundColor = '#f9f9f9';
                item.style.border = '1px solid #eee';
                item.innerHTML = `<strong>Question:</strong> ${q.question}<br>
                                 <span style="color: #e74c3c">Vos réponses: ${userRespText}</span><br>
                                 <span style="color: #2ecc71">Bonnes réponses: ${correctRespText}</span>${glossaryHTML}`;
                detailsDiv.appendChild(item);
            });
            resultMessageContainer.appendChild(detailsDiv);
        }
    }
}


function renderAssociationQuestion(question) {
    // Restauration de l'état
    const savedAnswer = userAnswers.find(a => a.questionIndex === currentQuestionIndex);

    const pairsValues = Object.entries(question.matchPairs);
    // Keys (Descriptions)
    const keys = pairsValues.map(p => p[0]);
    // Values (IPs) - shuffle them
    let values = pairsValues.map(p => p[1]);
    
    // Simple shuffle
    for (let i = values.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [values[i], values[j]] = [values[j], values[i]];
    }

    const container = document.createElement('div');
    container.className = 'association-container';
    container.style.marginTop = '20px';
    
    keys.forEach((key) => {
        const row = document.createElement('div');
        row.className = 'association-row';
        row.style.marginBottom = '15px';
        row.style.display = 'flex';
        row.style.alignItems = 'center';
        row.style.justifyContent = 'space-between';
        row.style.flexWrap = 'wrap'; 
        row.style.gap = '10px';

        const label = document.createElement('span');
        label.textContent = key;
        label.style.flex = '1 1 45%'; // min width
        label.style.fontWeight = 'bold';

        const select = document.createElement('select');
        select.className = 'association-select';
        select.style.flex = '1 1 45%';
        select.style.padding = '8px';
        select.dataset.key = key; 
        
        const defaultOption = document.createElement('option');
        defaultOption.text = 'Choisir...';
        defaultOption.value = '';
        select.add(defaultOption);

        values.forEach(val => {
            const opt = document.createElement('option');
            opt.text = val;
            opt.value = val;
            select.add(opt);
        });

        // Restore previous answer
        if (savedAnswer && savedAnswer.selectedPairs) {
             select.value = savedAnswer.selectedPairs[key] || '';
             // If training mode and saved, disable
             if (currentMode === 'training') select.disabled = true;
        }

        row.appendChild(label);
        row.appendChild(select);
        container.appendChild(row);
    });

    optionsContainer.appendChild(container);

    // Validate button logic
    if (savedAnswer && currentMode === 'training') {
        validateAssociationAnswer(question, true); // replay feedback
    } else {
        validateBtn.style.display = 'inline-block';
        // Note: global check button calls validateAnswer(), which delegates to validateAssociationAnswer
    }
}

function validateAssociationAnswer(question, replay=false) {
    const selects = optionsContainer.querySelectorAll('select.association-select');
    let allCorrect = true;
    const userPairs = {};
    let missingSelection = false;
    
    selects.forEach(select => {
        const key = select.dataset.key;
        userPairs[key] = select.value;
        if (!select.value) missingSelection = true;
        if (select.value !== question.matchPairs[key]) {
             allCorrect = false;
        }
    });

    if (missingSelection && !replay) {
        alert('Veuillez sélectionner une réponse pour chaque élément.');
        return;
    }

    if (!replay) {
         // Save answer
        const existingIndex = userAnswers.findIndex(a => a.questionIndex === currentQuestionIndex);
        if (existingIndex === -1) {
            userAnswers.push({
                questionIndex: currentQuestionIndex,
                selectedPairs: userPairs,
                isCorrect: allCorrect
            });
            if (allCorrect) score++;
        }
    }

    // Visual feedback
    selects.forEach(select => {
        const key = select.dataset.key;
        select.disabled = true; // Disable regardless of mode once validated
        
        const parent = select.parentNode;
        // remove old feedback if any
        const existingMsg = parent.querySelector('.assoc-feedback');
        if(existingMsg) existingMsg.remove();
        
        if (select.value === question.matchPairs[key]) {
            select.style.border = '2px solid #2ecc71';
            select.style.backgroundColor = '#eafaf1';
        } else {
            select.style.border = '2px solid #e74c3c';
            select.style.backgroundColor = '#fadbd8';
            if (currentMode === 'training') {
                const correctSpan = document.createElement('div');
                correctSpan.className = 'assoc-feedback';
                correctSpan.textContent = 'Correction: ' + question.matchPairs[key];
                correctSpan.style.color = '#c0392b';
                correctSpan.style.fontSize = '0.9em';
                correctSpan.style.marginTop = '4px';
                correctSpan.style.width = '100%'; 
                parent.appendChild(correctSpan);
            }
        }
    });

    validateBtn.style.display = 'none';
    nextBtn.style.display = 'inline-block';
    
    if (currentMode === 'training') {
        if (allCorrect) {
            feedback.textContent = 'Tout est correct !';
            feedback.className = 'feedback success';
        } else {
            feedback.textContent = 'Il y a des erreurs. Voir les corrections.';
            feedback.className = 'feedback error';
        }
        feedback.style.display = 'block';
        updateScoreDisplay();
    }
}

