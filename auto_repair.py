import json
import re
import html
import os

QUESTIONS_FILE = r"c:\Users\Flavio\Desktop\quizz CCNA1\questions.js"
HTML_FILE = r"c:\Users\Flavio\Desktop\quizz CCNA1\page_source.html"

def normalize_text(text):
    if text is None: return ""
    text = html.unescape(text)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'\W+', '', text).lower()
    return text

def parse_html_to_map(content):
    q_map = {}
    
    # Split by something that delineates questions in the source HTML
    # The source seems to have <p><strong>Question...</strong></p> followed by <ul>
    
    # Use regex to find question blocks
    # Pattern: <strong>...</strong> ... <ul>...</ul>
    
    # Let's simple iterate over all ULs and look at preceding paragraph
    
    ul_matches = list(re.finditer(r'<ul\b[^>]*>(.*?)</ul>', content, re.DOTALL))
    
    for ul in ul_matches:
        ul_content = ul.group(1)
        start_idx = ul.start()
        
        # Look backwards for the question text
        # Search for <strong>...</strong>
        # Limit search to 1000 chars before
        search_chunk = content[max(0, start_idx-1000):start_idx]
        
        strongs = re.findall(r'<strong>(.*?)</strong>', search_chunk, re.DOTALL)
        if not strongs:
            continue
            
        # The last strong tag is likely the question
        question_text_raw = strongs[-1]
        # Remove numbers like "40. "
        question_text_clean = re.sub(r'^\d+\.\s*', '', question_text_raw)
        q_key = normalize_text(question_text_clean)
        
        # Parse options in UL
        li_matches = re.findall(r'<li(.*?)>(.*?)</li>', ul_content, re.DOTALL)
        
        correct_opts_text = []
        
        for attrs, opt_text in li_matches:
            is_correct = False
            if 'correct_answer' in attrs or 'color: #ff0000' in attrs or 'color: red' in attrs:
                is_correct = True
            if 'color: #ff0000' in opt_text or 'color: red' in opt_text: # sometimes inside text
                is_correct = True
                
            if is_correct:
                correct_opts_text.append(normalize_text(opt_text))
        
        if q_key and correct_opts_text:
            q_map[q_key] = correct_opts_text
            
    return q_map

def main():
    if not os.path.exists(QUESTIONS_FILE) or not os.path.exists(HTML_FILE):
        print("Files not found")
        return

    with open(QUESTIONS_FILE, 'r', encoding='utf-8') as f:
        js_content = f.read()

    # Extract JSON array
    match = re.search(r'=\s*(\[.*\]);?', js_content, re.DOTALL)
    if not match:
        print("Could not find array")
        return
        
    questions_data = json.loads(match.group(1))

    with open(HTML_FILE, 'r', encoding='utf-8') as f:
        html_content = f.read()

    qa_map = parse_html_to_map(html_content)
    
    fixed_count = 0
    
    for q in questions_data:
        if q.get('answer') is None and q.get('type') != 'association':
            q_text = q.get('question', '')
            q_key = normalize_text(q_text)
            
            # Key lookup
            correct_texts = qa_map.get(q_key)
            
            # Fuzzy fallback
            if not correct_texts:
                # Try finding key in map that contains q_key
                for k, v in qa_map.items():
                    if len(k) > 20 and (k in q_key or q_key in k):
                        correct_texts = v
                        break
            
            if correct_texts:
                # Find indices in options
                found_indices = []
                options = q.get('options', [])
                for i, opt in enumerate(options):
                    norm_opt = normalize_text(opt)
                    # Check if this option matches any correct text
                    for c_text in correct_texts:
                        if c_text == norm_opt or (len(c_text) > 10 and c_text in norm_opt):
                            found_indices.append(i)
                            break
                
                if found_indices:
                    # Update question
                    q['answer'] = found_indices[0] if len(found_indices) == 1 else found_indices
                    fixed_count += 1
                    # print(f"Fixed: {q_text[:30]}... -> {q['answer']}")
                # else:
                #     print(f"Could not map options for: {q_text[:30]}")

    print(f"Total fixed: {fixed_count}")
    
    # Save back
    new_js = f"const questions = {json.dumps(questions_data, ensure_ascii=False)};"
    with open(QUESTIONS_FILE, 'w', encoding='utf-8') as f:
        f.write(new_js)

if __name__ == '__main__':
    main()
