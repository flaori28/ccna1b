const fs = require('fs');

const content = fs.readFileSync('questions.js', 'utf8');
// Remove "const questions = " and trailing ";"
const jsonStr = content.replace(/^const questions = /, '').replace(/;$/, '');
const questions = JSON.parse(jsonStr);

console.log("Q22 (Index 21):");
console.log(JSON.stringify(questions[21], null, 2));

// Search for any question starting with "22." in the question text as well, just in case
console.log("\nSearching for '22.' in text:");
questions.forEach((q, i) => {
    if (q.question && q.question.startsWith("22.")) {
        console.log(`Index ${i}: ${q.question}`);
    }
});
