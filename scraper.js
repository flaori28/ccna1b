// INSTRUCTIONS POUR RECUPERER LES QUESTIONS
// 1. Allez sur le site https://ccnareponses.com/ccna-1-examen-final-itnv7-questions-et-reponses-francais/
// 2. Faites F12 pour ouvrir la console du navigateur
// 3. Copiez tout le code ci-dessous et collez-le dans la console, puis appuyez sur Entrée
// 4. Copiez le texte qui s'affiche (le JSON) et collez-le dans le fichier questions.js à la place de l'existant.

(function() {
    let questions = [];
    
    // Select all paragraphs that contain a strong tag (usually the question text)
    // The exact structure based on inspection: p > strong
    let pTags = document.querySelectorAll('p');
    
    pTags.forEach((p, index) => {
        let strong = p.querySelector('strong');
        if (!strong) return; // Skip paragraphs without bold text
        
        let text = strong.innerText.trim();
        // Check if it starts with a number like "1." or "10."
        let match = text.match(/^(\d+)\.\s*(.*)/);
        if (!match) return; // Not a numbered question
        
        let questionText = match[2]; // The text after "1. "
        
        // The options are usually in the NEXT <ul> element following the <p>
        let ul = p.nextElementSibling;
        // Skip intermediary elements if any (like empty divs or brs) until we find a UL or another P (start of next question)
        while(ul && ul.tagName !== 'UL' && ul.tagName !== 'P' && ul.tagName !== 'DIV') {
             ul = ul.nextElementSibling;
        }
        
        if (!ul || ul.tagName !== 'UL') return; // formats differ sometimes, but main ones use UL
        
        let options = [];
        let correctIndices = []; // Can be multiple
        
        let lis = ul.querySelectorAll('li');
        lis.forEach((li, i) => {
            options.push(li.innerText.trim());
            // Detection strategy for correct answer:
            // 1. Class "correct_answer"
            // 2. Color style (red or #ff0000)
            // 3. Span with color style
            let isCorrect = false;
            
            if (li.className.includes('correct')) isCorrect = true;
            
            // Check styles
            let style = li.getAttribute('style') || '';
            if (style && (style.includes('red') || style.includes('#ff0000'))) isCorrect = true;
            
            // Check child spans
            let spans = li.querySelectorAll('span');
            spans.forEach(span => {
                 let sStyle = span.getAttribute('style') || '';
                 if (sStyle && (sStyle.includes('red') || sStyle.includes('#ff0000'))) isCorrect = true;
                 if (span.className.includes('correct')) isCorrect = true;
            });
            
            if (isCorrect) correctIndices.push(i);
        });
        
        // Find Image if any
        // Usually inside the <p> or before the <ul>
        let img = p.querySelector('img');
        if (!img) {
            // Check previous element if it is a figure or separate p with img
            let prev = p.previousElementSibling;
            if (prev && prev.querySelector('img')) img = prev.querySelector('img');
            
            // Check next element (between p and ul)
             let next = p.nextElementSibling;
             if (next && next !== ul && next.querySelector('img')) img = next.querySelector('img');
        }
        
        let imgSrc = img ? img.src : null;
        
        // Only add if we found options
        if (options.length > 0) {
            // If no correct answer detected (site structure might vary), default to 0 to avoid breaking, or user can fix
            let finalAnswer = correctIndices.length > 0 ? (correctIndices.length === 1 ? correctIndices[0] : correctIndices) : 0;
            
            questions.push({
                question: questionText,
                options: options,
                answer: finalAnswer,
                image: imgSrc // Store the remote URL directly
            });
        }
    });
    
    // Output result
    let jsonOutput = "const questions = " + JSON.stringify(questions, null, 4) + ";";
    console.log(jsonOutput);
    
    // Try to copy to clipboard
    try {
        navigator.clipboard.writeText(jsonOutput);
        alert(`Succès ! ${questions.length} questions récupérées et copiées dans le presse-papier.`);
    } catch(e) {
        alert(`Terminé ! ${questions.length} questions trouvées. Regardez dans la console (F12) pour copier le résultat.`);
    }
})();
