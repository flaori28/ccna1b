const fs = require('fs');

// Read questions.js
// It starts with 'const questions = ' and ends with ';'
let questionsContent = fs.readFileSync('questions.js', 'utf8');
const jsonStart = questionsContent.indexOf('[');
const jsonEnd = questionsContent.lastIndexOf(']');
const questionsJson = questionsContent.substring(jsonStart, jsonEnd + 1);
const questions = JSON.parse(questionsJson);

// Read page_source.html
const pageSource = fs.readFileSync('page_source.html', 'utf8');

// Function to find answer index
function findAnswerIndex(questionObj) {
    // 1. Locate the question text in source
    // Normalize text for search (remove simple spaces issues, maybe entities)
    // We'll search for a unique part of the question
    const qText = questionObj.question.substring(0, 50).replace(/&[a-z]+;/g, '.'); // Replace entities with wildcard char for regex? No, just substring.
    
    // Simple search
    const qIndex = pageSource.indexOf(qText.split(' ').slice(0, 5).join(' ')); // Search first 5 words
    
    if (qIndex === -1) {
        console.log(`Could not find question in source: ${questionObj.question.substring(0, 30)}...`);
        return null;
    }
    
    // Look ahead from qIndex for options
    // The options are usually in <ul>...</ul> following the question.
    // We can search for the option text.
    
    const correctIndices = [];
    
    questionObj.options.forEach((opt, idx) => {
        // Search for this option in the source, AFTER the question
        // We need to be careful not to find it in another question.
        // Let's assume the relevant HTML chunk is within next 2000 chars.
        const searchContext = pageSource.substring(qIndex, qIndex + 4000);
        
        // Normalize option text: remove entities, extra spaces.
        // Actually, the source has entities. The JSON has entities.
        // The display in source might be inside a span with style.
        
        // We look for the option text. If it is surrounded by "correct" class or red color, it's the answer.
        // Common patterns for correct answer in this source:
        // 1. <li class="correct_answer">OptionText</li>
        // 2. <li><span style="color: #ff0000;"><strong>OptionText</strong></span></li>
        // 3. <li><strong><span style="color: #ff0000;">OptionText</span></strong></li>
        
        // We can check if the option text in the source is close to "color: #ff0000" or "correct_answer".
        
        const optEscaped = opt.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // Escape regex chars
        // We might need to handle partial matches or entity differences.
        // Let's try to find the option text index in the context.
        
        const optIndex = searchContext.indexOf(opt.split(' ').slice(0, 3).join(' ')); // Match first 3 words
        
        if (optIndex !== -1) {
            // Check surroundings (before)
            const before = searchContext.substring(Math.max(0, optIndex - 100), optIndex);
            if (before.includes('color: #ff0000') || before.includes('correct_answer') || before.includes('color: red')) {
                correctIndices.push(idx);
            }
        }
    });

    if (correctIndices.length > 0) {
        if (correctIndices.length === 1) return correctIndices[0];
        return correctIndices;
    }
    return null;
}

let patchCount = 0;
questions.forEach((q, i) => {
    if (q.answer === null) {
        console.log(`Patching question ${i}...`);
        const result = findAnswerIndex(q);
        if (result !== null) {
            q.answer = result;
            console.log(`  -> Found answer: ${result}`);
            patchCount++;
        } else {
            console.log(`  -> Failed to find answer.`);
        }
    }
});

console.log(`Patched ${patchCount} questions.`);

// Write back
const newContent = `const questions = ${JSON.stringify(questions)};`;
fs.writeFileSync('questions.js', newContent, 'utf8');
console.log('Saved questions.js');
