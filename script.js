let currentQuestionIndex = 0;
let score = 0;
let currentMode = ''; // 'training' ou 'exam'
let userAnswers = []; // Pour stocker les réponses en mode examen
let selectedOptionIndices = []; // Tableau pour gérer multiples sélections

// Éléments du DOM
const homeScreen = document.getElementById('home');
const quizScreen = document.getElementById('quiz');
const resultsScreen = document.getElementById('results');

const questionText = document.getElementById('question-text');
const optionsContainer = document.getElementById('options-container');
const nextBtn = document.getElementById('next-btn');
const validateBtn = document.getElementById('validate-btn');
const feedback = document.getElementById('feedback');
const counterDisplay = document.getElementById('question-counter');
const scoreDisplay = document.getElementById('score-display');

function startQuiz(mode) {
    currentMode = mode;
    currentQuestionIndex = 0;
    score = 0;
    userAnswers = [];
    selectedOptionIndices = [];

    homeScreen.style.display = 'none';
    quizScreen.style.display = 'block';
    resultsScreen.style.display = 'none';
    
    if (mode === 'training') {
        scoreDisplay.style.display = 'block';
        updateScoreDisplay();
    } else {
        scoreDisplay.style.display = 'none';
    }

    loadQuestion();
}

function loadQuestion() {
    const question = questions[currentQuestionIndex];
    questionText.innerHTML = question.question;
    optionsContainer.innerHTML = '';
    feedback.style.display = 'none';
    feedback.className = 'feedback';
    
    // Réinitialiser les boutons
    nextBtn.style.display = 'none';
    validateBtn.style.display = 'none';
    selectedOptionIndices = [];
    
    counterDisplay.innerHTML = `Question ${currentQuestionIndex + 1}/${questions.length}`;

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

    question.options.forEach((option, index) => {
        const button = document.createElement('button');
        button.innerHTML = option;
        button.classList.add('option-btn');
        button.onclick = () => selectOption(index, button, isMultiselect);
        optionsContainer.appendChild(button);
    });
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
    if (selectedOptionIndices.length === 0) return;

    const question = questions[currentQuestionIndex];
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
        if (isCorrect) {
            feedback.textContent = "Bonne réponse !";
            feedback.classList.add('success');
            score++;
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
        userAnswers.push({
            questionIndex: currentQuestionIndex,
            selected: [...selectedOptionIndices], // Copie
            isCorrect: isCorrect,
            correctAnswer: correctAnswers // Stocker pour affichage résultats
        });
        if (isCorrect) score++;
    }
}

function nextQuestion() {
    currentQuestionIndex++;
    if (currentQuestionIndex < questions.length) {
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

    const percentage = Math.round((score / questions.length) * 100);
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
                const q = questions[ans.questionIndex];
                
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

