
import json
import re
import html

# Files
QUESTIONS_FILE = r"c:\Users\Flavio\Desktop\quizz CCNA1\questions.js"
HTML_FILE = r"c:\Users\Flavio\Desktop\quizz CCNA1\page_source.html"
OUTPUT_FILE = r"c:\Users\Flavio\Desktop\quizz CCNA1\fixes.json"

def load_questions():
    with open(QUESTIONS_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
        # Remove variable declaration
        content = re.sub(r'^\s*const\s+questions\s*=\s*', '', content)
        content = re.sub(r';\s*$', '', content)
        return json.loads(content)

def load_html():
    with open(HTML_FILE, 'r', encoding='utf-8') as f:
        return f.read()

def normalize_text(text):
    # Remove HTML tags, unescape, normalize whitespace
    text = html.unescape(text)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def simple_key(s):
    # Remove non-alphanumeric and lowercase
    return re.sub(r'\W+', '', s).lower()

def solve():
    questions = load_questions()
    html_content = load_html()
    
    # Identify null answers and create lookup map
    # Key: simple_key(question_text), Value: original_question_obj
    missing_q_map = {}
    for q in questions:
        if q.get('answer') is None:
            k = simple_key(q['question'])
            # Store with key. If duplicate keys (unlikely), we might overwrite.
            missing_q_map[k] = q

    print(f"DEBUG: Found {len(missing_q_map)} questions with null answer.")
    
    fixes = []
    
    # Find all <ul> blocks in HTML
    # We capture the full UL content including tags
    ul_matches = list(re.finditer(r'<ul\b[^>]*>(.*?)</ul>', html_content, re.DOTALL))
    
    for ul in ul_matches:
        ul_content = ul.group(1)
        ul_full = ul.group(0) # The full <ul>...</ul> string
        
        # Check for answer indicators
        has_answer = False
        if 'correct_answer' in ul_full:
            has_answer = True
        elif 'color: #ff0000' in ul_full or 'color: red' in ul_full:
            has_answer = True
            
        if not has_answer:
            continue
            
        # This UL has an answer. Now find which question it belongs to.
        # Look backwards from ul.start()
        # We search a reasonable window, say 3000 chars.
        search_start = max(0, ul.start() - 3000)
        preceding_text_chunk = html_content[search_start:ul.start()]
        
        # Normalize the preceding text for matching
        # We remove tags but keep structure somewhat? No, simple_key ignores structure.
        # But we need to find the *closest* question.
        # The simple_key approach removes all separators, so "Question One" and "Question Two" become "questiononequestiontwo".
        # If we search for "questiontwo" in that big string, we'll find it.
        
        # Let's find matches for ALL missing questions in this chunk.
        # And pick the one with the highest start index (closest to UL).
        
        best_match_q = None
        best_match_idx = -1
        
        # Optimize: preprocessing all missing keys is expensive if loop is tight?
        # But we only have ~100 questions probably.
        
        normalized_chunk = simple_key(html.unescape(re.sub(r'<[^>]+>', ' ', preceding_text_chunk)))
        # Wait, if we normalize the chunk like this, we lose position info relative to the original HTML.
        # We need the position in the chunk to know which is closest.
        
        # Revised strategy:
        # Iterate over all missing questions. Check if their simple_key exists in the normalized chunk.
        # If it does, find the index.
        # But `normalized_chunk` indices don't map to `preceding_text_chunk` indices easily.
        # However, we only need to know which question appears *last* in the chunk (closest to the end).
        
        # Since `simple_key` transforms text significantly, searching for `simple_key(q)` inside `simple_key(chunk)` works for existence.
        # To find position: `normalized_chunk.rfind(key)` gives the index in the normalized string.
        # The higher the index, the later it appears in the text, so the closer it is to the UL.
        
        for k, q in missing_q_map.items():
            idx = normalized_chunk.rfind(k)
            if idx != -1:
                # Found a candidate
                if idx > best_match_idx:
                    best_match_idx = idx
                    best_match_q = q
        
        if best_match_q:
            # We found the question for this UL!
            # Extract options and answer
            
            # Parse LIs
            # Use regex to find <li> content and attributes
            li_matches = re.finditer(r'<li(.*?)>(.*?)</li>', ul_content, re.DOTALL)
            
            options_text = []
            correct_indices = []
            
            for i, m in enumerate(li_matches):
                attrs = m.group(1)
                content = m.group(2)
                
                # Check for correct answer
                is_correct = False
                if 'class="correct_answer"' in attrs or "class='correct_answer'" in attrs:
                    is_correct = True
                elif 'color: #ff0000' in attrs or 'color: red' in attrs:
                    is_correct = True
                elif 'color: #ff0000' in content or 'color: red' in content: # Sometimes inside span
                    is_correct = True
                
                if is_correct:
                    correct_indices.append(i)
                
                # Clean option text
                # Normalize text handles unescaping and tag strip
                opt_clean = normalize_text(content)
                options_text.append(opt_clean)
            
            # Construct fix
            if correct_indices:
                ans = correct_indices[0] if len(correct_indices) == 1 else correct_indices
                
                snippet = best_match_q['question'][:50]
                # Fix encoding in snippet for JSON output (it will be auto handled by json.dumps)
                
                fix_entry = {
                    "questionTextSnippet": snippet,
                    "options": options_text,
                    "answer": ans
                }
                
                # Check for image
                # Look in the preceding chunk for <img>
                # We should look closer to the question position.
                # Since we don't have exact position of question start in original HTML (lost in normalization),
                # we'll look in the chunk.
                # Usually image is AFTER the question text.
                
                # Let's clean the chunk to find image src
                # We need the original HTML chunk for this `preceding_text_chunk`
                
                img_matches = list(re.finditer(r'<img[^>]+src=["\']([^"\']+)["\']', preceding_text_chunk))
                if img_matches:
                    # Take the last image, as it's most likely associated with the question immediately preceding the answers
                    last_img = img_matches[-1]
                    img_src = last_img.group(1)
                    
                    # Verify it's not a generic icon (like 'apple-touch-icon' or header images)
                    # Check if it looks like a question image (usually uploads/... .jpg or .png)
                    if 'uploads' in img_src:
                         fix_entry['image'] = img_src
                
                # Add to fixes list
                # Check if we already have a fix for this question (duplicate ULs?)
                # If so, overwrite or skip? 
                # Use snippet as unique ID for now.
                
                exists = False
                for f in fixes:
                    if f['questionTextSnippet'] == snippet:
                        exists = True
                        break
                if not exists:
                    fixes.append(fix_entry)
            else:
                 print(f"DEBUG: Found matching question {best_match_q['question'][:20]} but no correct options in UL.")

    print(json.dumps(fixes, indent=2))

if __name__ == '__main__':
    solve()
