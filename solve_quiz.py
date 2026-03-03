import json
import re
import html

def normalize_text(text):
    if text is None:
        return ""
    # Unescape HTML entities (e.g., &rsquo; -> ’)
    text = html.unescape(text)
    # Remove HTML tags if any (basic removal)
    text = re.sub(r'<[^>]+>', '', text)
    # Remove non-alphanumeric characters and lowercase
    text = re.sub(r'\W+', '', text).lower()
    return text

def parse_html_to_map(html_content):
    """
    Parses HTML content to map question text to a set of correct option texts.
    """
    question_map = {}
    
    # Split by something that typically separates questions, e.g., <p><strong>
    # This is a heuristic. We need to be careful.
    # The HTML structure seems to be: <p><strong>Question...</strong></p><ul><li>...</li></ul>
    
    # Let's verify the structure from the read_file output. 
    # It seems questions often start with <p><strong> or <strong>. 
    # And are followed by <ul> containing <li>.
    
    # Strategy: Find all occurrences of potential questions and their lists.
    # Regex might be fragile for large HTML, but let's try a state-machine approach or loose regex.
    
    # We will iterate through the file looking for patterns.
    # Pattern: 
    # 1. Question text block
    # 2. <ul> block with <li> items
    
    # Remove newlines for easier regex matching
    content_flat = html_content.replace('\n', ' ')
    
    # Regex to find <p><strong>...</strong>...<ul>...</ul>
    # Note: Sometimes there is an image in between.
    
    # Let's try to extract <ul> blocks and look at the preceding text.
    ul_blocks = re.split(r'(<ul.*?>.*?</ul>)', content_flat, flags=re.IGNORECASE)
    
    # ul_blocks will alternate: [text, ul, text, ul, ...] if split captures the delimiter.
    
    last_text = ""
    
    for i in range(len(ul_blocks)):
        block = ul_blocks[i]
        
        if block.lower().startswith('<ul'):
            # This is an options block.
            # Parse options
            matches = re.findall(r'<li(.*?)>(.*?)</li>', block, flags=re.IGNORECASE)
            correct_options = []
            all_options = []
            
            for attrs, opt_text in matches:
                # Check if correct
                is_correct = False
                if 'correct_answer' in attrs or '#ff0000' in attrs or 'color: red' in attrs:
                    is_correct = True
                
                # Double check inside the text for spans with color red
                if 'color: #ff0000' in opt_text or 'color: red' in opt_text or 'color:#ff0000' in opt_text:
                    is_correct = True

                norm_opt = normalize_text(opt_text)
                if is_correct:
                    correct_options.append(norm_opt)
                all_options.append(norm_opt)
            
            # The preceding block should contain the question.
            # We look for the last <strong> content or just the text before the <ul>.
            # Sometimes there are images <img ...> between text and <ul>.
            
            if last_text:
                # Try to extract the question. It's usually in <strong> tags.
                # Find all strong tags in the last text chunk.
                strongs = re.findall(r'<strong>(.*?)</strong>', last_text, flags=re.IGNORECASE)
                
                # Also consider <p> tags if no strong tags, or just the raw text.
                # The question is usually consistently the last "significant" text before the list.
                
                if strongs:
                    # Take the last strong tag as the candidate question
                    q_text_candidate = strongs[-1]
                    
                    # Remove number prefix if present (e.g. "1. Question")
                    q_text_candidate = re.sub(r'^\d+\.\s*', '', q_text_candidate)
                    
                    q_key = normalize_text(q_text_candidate)
                    
                    if q_key:
                        question_map[q_key] = correct_options
                        
                        # Also try normalizing without the number stripping just in case
                        q_key_raw = normalize_text(strongs[-1])
                        question_map[q_key_raw] = correct_options
                
                # In case the question isn't in <strong> (less likely based on sample),
                # we could search backwards, but let's stick to strong for now.
                
        else:
            last_text = block
            
    return question_map

def main():
    questions_path = r"c:\Users\Flavio\Desktop\quizz CCNA1\questions.js"
    html_path = r"c:\Users\Flavio\Desktop\quizz CCNA1\page_source.html"

    # 1. Load JS Questions
    try:
        with open(questions_path, 'r', encoding='utf-8') as f:
            js_content = f.read()
            # Extract JSON array
            match = re.search(r'const\s+questions\s*=\s*(\[.*\]);?', js_content, re.DOTALL)
            if not match:
                print("Error: Could not find 'const questions = [...]' in questions.js")
                return
            
            questions_data = json.loads(match.group(1))
    except Exception as e:
        print(f"Error reading questions.js: {e}")
        return

    # 2. Load HTML Content
    try:
        with open(html_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
    except Exception as e:
        print(f"Error reading page_source.html: {e}")
        return

    # 3. Parse HTML to build lookup map
    # Key: Normalized Question Text -> Value: [Normalized Correct Option 1, ...]
    html_qa_map = parse_html_to_map(html_content)
    
    updates = []
    
    # 4. Iterate JS questions and find answers for those that are null
    for idx, q_item in enumerate(questions_data):
        if q_item.get('answer') is None:
            q_text = q_item.get('question', '')
            q_options = q_item.get('options', [])
            
            q_key = normalize_text(q_text)
            
            # Try to find in map
            correct_opts_norm = html_qa_map.get(q_key)
            
            # Fallback: exact match might fail due to "Choose three" text variations etc.
            # Try fuzzy match if not found? 
            # Or try removing " (Choisissez...)" part from the text.
            if not correct_opts_norm:
                 # Remove parenthesized instructions like (Choisissez trois réponses.)
                q_text_stripped = re.sub(r'\s*\(.*?\)', '', q_text)
                q_key_stripped = normalize_text(q_text_stripped)
                correct_opts_norm = html_qa_map.get(q_key_stripped)

            # If still not found, try searching the keys for substring (or vice versa)
            if not correct_opts_norm:
                # Valid keys are those in html_qa_map. 
                # Let's see if q_key is a substring of a key in map or vice versa.
                # This is O(N^2) for missed hits, but N is small (100-200).
                for k, v in html_qa_map.items():
                    if len(k) > 20 and ((k in q_key) or (q_key in k)):
                        correct_opts_norm = v
                        break
            
            if correct_opts_norm:
                # We found the correct answers texts. Now find their indices in JS options.
                found_indices = []
                for i, opt in enumerate(q_options):
                    norm_opt = normalize_text(opt)
                    # Check if this option is in the correct list
                    # We iterate to allow fuzzy matching if needed, but exact set check first
                    if norm_opt in correct_opts_norm:
                        found_indices.append(i)
                    else:
                        # Fallback for options
                         for c_opt in correct_opts_norm:
                             if len(norm_opt) > 10 and c_opt in norm_opt: # Partial match
                                 found_indices.append(i)
                                 break
                
                # Dedup and sort
                found_indices = sorted(list(set(found_indices)))
                
                if found_indices:
                    # Format answer: single int or list of ints
                    ans = found_indices[0] if len(found_indices) == 1 else found_indices
                    updates.append({"index": idx, "answer": ans})
                else:
                    # Found question but couldn't match options?
                    # Maybe options format differs significantly.
                    pass
            else:
                # Couldn't find question text in HTML
                # print(f"Could not find question {idx} in HTML: {q_text[:50]}...")
                pass

    # 5. Output JSON
    print(json.dumps(updates, indent=4))

if __name__ == '__main__':
    main()
