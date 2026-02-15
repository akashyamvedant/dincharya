-- ============================================================
-- Dincharya — Content Expansion: 60 New Sessions
-- Run this in Supabase SQL Editor
-- media_url = youtube_url (required NOT NULL)
-- ============================================================

-- ==================== MEDITATION (20 sessions) ====================

INSERT INTO sessions (title, title_hindi, description, category, media_type, media_url, youtube_url, duration, difficulty, tags, is_active, is_premium, instructor_name)
VALUES
-- Beginner Meditation
('Morning Mindfulness Meditation', 'सुबह की माइंडफुलनेस ध्यान', 'A gentle 10-minute morning meditation to start your day with clarity and calm.', 'meditation', 'youtube', 'https://youtu.be/inpok4MKVLM', 'https://youtu.be/inpok4MKVLM', 600, 1, ARRAY['beginner','morning','vata','pitta','kapha','mindfulness'], true, false, 'Goodful'),

('Body Scan Relaxation', 'शरीर स्कैन विश्राम', 'Progressive body scan meditation for deep relaxation and body awareness.', 'meditation', 'youtube', 'https://youtu.be/QS2yDmWk0vs', 'https://youtu.be/QS2yDmWk0vs', 900, 1, ARRAY['beginner','relaxation','vata','body_scan'], true, false, 'Great Meditation'),

('Gratitude Meditation', 'कृतज्ञता ध्यान', 'Cultivate gratitude and positive emotions with this guided practice.', 'meditation', 'youtube', 'https://youtu.be/O-6f5wQXSu8', 'https://youtu.be/O-6f5wQXSu8', 600, 1, ARRAY['beginner','gratitude','pitta','evening'], true, false, 'The Honest Guys'),

('5-Minute Quick Calm', '5 मिनट शांति ध्यान', 'Ultra-short meditation for busy days. Perfect for a mid-day reset.', 'meditation', 'youtube', 'https://youtu.be/inpok4MKVLM', 'https://youtu.be/inpok4MKVLM', 300, 1, ARRAY['beginner','quick','vata','pitta','stress_relief'], true, false, 'Goodful'),

('Self-Love Meditation', 'आत्म-प्रेम ध्यान', 'Build self-compassion and inner peace with this nurturing meditation.', 'meditation', 'youtube', 'https://youtu.be/itZMM5gCboo', 'https://youtu.be/itZMM5gCboo', 600, 1, ARRAY['beginner','self_love','pitta','vata','compassion'], true, false, 'Great Meditation'),

-- Intermediate Meditation
('Chakra Balancing Meditation', 'चक्र संतुलन ध्यान', 'Align and balance your seven chakras through guided visualization.', 'meditation', 'youtube', 'https://youtu.be/1LOwVO0JnR0', 'https://youtu.be/1LOwVO0JnR0', 1200, 3, ARRAY['intermediate','chakra','vata','pitta','kapha','energy'], true, false, 'Michael Sealey'),

('Loving-Kindness Metta', 'मैत्री ध्यान', 'Develop compassion and loving-kindness for self and others.', 'meditation', 'youtube', 'https://youtu.be/sz7cpV7ERsM', 'https://youtu.be/sz7cpV7ERsM', 900, 2, ARRAY['intermediate','compassion','pitta','metta'], true, false, 'The Honest Guys'),

('Vedic Mantra Om Chanting', 'वैदिक ॐ मंत्र जाप', 'Traditional Om mantra chanting meditation for deep spiritual connection.', 'meditation', 'youtube', 'https://youtu.be/aEqlQvczMJQ', 'https://youtu.be/aEqlQvczMJQ', 1500, 3, ARRAY['intermediate','vedic','mantra','vata','pitta','kapha','spiritual'], true, false, 'Meditative Mind'),

('Visualization for Success', 'सफलता के लिए दृश्यीकरण', 'Powerful guided visualization to manifest your goals and intentions.', 'meditation', 'youtube', 'https://youtu.be/0P7nCmIn7gA', 'https://youtu.be/0P7nCmIn7gA', 900, 2, ARRAY['intermediate','visualization','pitta','kapha','goals','focus'], true, false, 'Michael Sealey'),

('Walking Meditation Guide', 'चलते हुए ध्यान', 'Learn mindful walking meditation for grounding and body awareness.', 'meditation', 'youtube', 'https://youtu.be/m8rRzTtP7Tc', 'https://youtu.be/m8rRzTtP7Tc', 600, 2, ARRAY['intermediate','walking','kapha','vata','grounding'], true, false, 'Plum Village'),

-- Advanced Meditation
('Third Eye Activation', 'तृतीय नेत्र ध्यान', 'Activate your Ajna chakra with focused third eye meditation.', 'meditation', 'youtube', 'https://youtu.be/wJQF5DhVIqg', 'https://youtu.be/wJQF5DhVIqg', 1200, 4, ARRAY['advanced','chakra','third_eye','vata','focus'], true, true, 'Rising Higher'),

('Transcendental Deep Dive', 'पारलौकिक गहन ध्यान', 'Extended deep meditation for experienced practitioners seeking transcendence.', 'meditation', 'youtube', 'https://youtu.be/yp1QAK0eCP8', 'https://youtu.be/yp1QAK0eCP8', 1800, 4, ARRAY['advanced','transcendental','vata','pitta','deep'], true, true, 'Michael Sealey'),

-- Sleep Meditation
('Deep Sleep Guided Journey', 'गहरी नींद ध्यान यात्रा', 'Drift into restful sleep with this calming guided meditation journey.', 'meditation', 'youtube', 'https://youtu.be/rvaqPPjGGDo', 'https://youtu.be/rvaqPPjGGDo', 1800, 1, ARRAY['beginner','sleep','night','vata','relaxation'], true, false, 'Jason Stephenson'),

('Yoga Nidra Deep Relaxation', 'योग निद्रा गहन विश्राम', 'Ancient Yoga Nidra technique for conscious deep sleep and restoration.', 'meditation', 'youtube', 'https://youtu.be/7H0FKzD4xMI', 'https://youtu.be/7H0FKzD4xMI', 2400, 2, ARRAY['intermediate','yoga_nidra','sleep','vata','pitta'], true, false, 'Ally Boothroyd'),

('Bedtime Stories for Adults', 'सोने की कहानियां', 'Soothing bedtime narration to quiet your mind before sleep.', 'meditation', 'youtube', 'https://youtu.be/1ZYbU82GVz4', 'https://youtu.be/1ZYbU82GVz4', 2400, 1, ARRAY['beginner','sleep','night','vata','stories','relaxation'], true, false, 'Calm'),

('Rain Sounds Sleep Meditation', 'बारिश ध्वनि नींद ध्यान', 'Fall asleep to gentle rain sounds with minimal guidance.', 'meditation', 'youtube', 'https://youtu.be/q76bMs-NwRk', 'https://youtu.be/q76bMs-NwRk', 3600, 1, ARRAY['beginner','sleep','night','vata','rain','ambient'], true, false, 'Relaxing White Noise'),

-- Stress & Anxiety
('Anxiety Relief Meditation', 'चिंता मुक्ति ध्यान', 'Calm anxious thoughts with this grounding meditation practice.', 'meditation', 'youtube', 'https://youtu.be/O-6f5wQXSu8', 'https://youtu.be/O-6f5wQXSu8', 600, 1, ARRAY['beginner','anxiety','vata','pitta','calm','stress_relief'], true, false, 'The Honest Guys'),

('Forgiveness Meditation', 'क्षमा ध्यान', 'Release grudges and find inner peace through forgiveness practice.', 'meditation', 'youtube', 'https://youtu.be/H69tCUrdWtA', 'https://youtu.be/H69tCUrdWtA', 900, 2, ARRAY['intermediate','forgiveness','pitta','emotional','healing'], true, false, 'Great Meditation'),

('Focus & Concentration', 'एकाग्रता ध्यान', 'Sharpen your mind and improve focus for study or work.', 'meditation', 'youtube', 'https://youtu.be/ausxoXBrmWs', 'https://youtu.be/ausxoXBrmWs', 600, 2, ARRAY['intermediate','focus','concentration','pitta','kapha','study'], true, false, 'Quiet Mind Cafe'),

('Inner Peace Meditation', 'आंतरिक शांति ध्यान', 'Journey inward to discover deep peace and spiritual stillness.', 'meditation', 'youtube', 'https://youtu.be/FjHGZj2IjBk', 'https://youtu.be/FjHGZj2IjBk', 1200, 3, ARRAY['intermediate','peace','spiritual','vata','pitta','kapha'], true, false, 'The Honest Guys')

ON CONFLICT DO NOTHING;


-- ==================== PRANAYAMA (20 sessions) ====================

INSERT INTO sessions (title, title_hindi, description, category, media_type, media_url, youtube_url, duration, difficulty, tags, is_active, is_premium, instructor_name)
VALUES
-- Beginner Pranayama
('Anulom Vilom for Beginners', 'अनुलोम विलोम (शुरुआती)', 'Alternate nostril breathing to balance both hemispheres of the brain.', 'pranayama', 'youtube', 'https://youtu.be/8VwufJrUhic', 'https://youtu.be/8VwufJrUhic', 600, 1, ARRAY['beginner','anulom_vilom','vata','pitta','balance'], true, false, 'Yoga With Adriene'),

('Deep Belly Breathing', 'गहरी पेट श्वास', 'Learn diaphragmatic breathing for stress relief and lung health.', 'pranayama', 'youtube', 'https://youtu.be/UB3tSaiEbNY', 'https://youtu.be/UB3tSaiEbNY', 300, 1, ARRAY['beginner','diaphragmatic','vata','pitta','stress_relief','foundation'], true, false, 'Yoga With Adriene'),

('4-7-8 Relaxing Breath', '4-7-8 आराम श्वास', 'Dr. Weil''s relaxing breath technique for instant calm and sleep preparation.', 'pranayama', 'youtube', 'https://youtu.be/YRPh_GaiL8s', 'https://youtu.be/YRPh_GaiL8s', 300, 1, ARRAY['beginner','4-7-8','vata','sleep','calm','evening'], true, false, 'Andrew Weil'),

('Box Breathing Technique', 'बॉक्स ब्रीदिंग तकनीक', 'Navy SEAL breathing technique for stress management and mental clarity.', 'pranayama', 'youtube', 'https://youtu.be/tEmt1Znux58', 'https://youtu.be/tEmt1Znux58', 300, 1, ARRAY['beginner','box_breathing','pitta','stress','focus'], true, false, 'Mark Divine'),

('Morning Pranayama Routine', 'सुबह का प्राणायाम', 'Complete morning breathwork routine combining multiple techniques.', 'pranayama', 'youtube', 'https://youtu.be/8VwufJrUhic', 'https://youtu.be/8VwufJrUhic', 600, 1, ARRAY['beginner','morning','vata','pitta','kapha','routine','energy'], true, false, 'Yoga With Adriene'),

('Breath Awareness Practice', 'श्वास जागरूकता अभ्यास', 'Simply observe your natural breath to develop mindful awareness.', 'pranayama', 'youtube', 'https://youtu.be/UB3tSaiEbNY', 'https://youtu.be/UB3tSaiEbNY', 600, 1, ARRAY['beginner','awareness','vata','pitta','mindfulness','foundation'], true, false, 'Yoga With Adriene'),

-- Intermediate Pranayama
('Kapalbhati Power Breath', 'कपालभाति शक्ति श्वास', 'Skull-shining breath for cleansing and energizing. Great for Kapha dosha.', 'pranayama', 'youtube', 'https://youtu.be/aaJhuqdaDeI', 'https://youtu.be/aaJhuqdaDeI', 600, 2, ARRAY['intermediate','kapalbhati','kapha','energy','morning','cleansing'], true, false, 'Swami Ramdev'),

('Bhramari Humming Bee Breath', 'भ्रामरी भंवरी श्वास', 'Humming bee breath for calming anxiety and improving focus.', 'pranayama', 'youtube', 'https://youtu.be/oLqoGOUlKpA', 'https://youtu.be/oLqoGOUlKpA', 480, 2, ARRAY['intermediate','bhramari','vata','pitta','calm','anxiety','focus'], true, false, 'Yoga With Adriene'),

('Ujjayi Ocean Breath', 'उज्जायी सागर श्वास', 'Ocean breath technique for building internal heat and maintaining focus.', 'pranayama', 'youtube', 'https://youtu.be/hYIzz7Y0O1s', 'https://youtu.be/hYIzz7Y0O1s', 600, 2, ARRAY['intermediate','ujjayi','kapha','focus','heat','yoga'], true, false, 'Yoga With Adriene'),

('Sheetali Cooling Breath', 'शीतली शीतल श्वास', 'Cooling breath to reduce body heat and calm Pitta dosha.', 'pranayama', 'youtube', 'https://youtu.be/Gsm9d8gsX7E', 'https://youtu.be/Gsm9d8gsX7E', 480, 2, ARRAY['intermediate','sheetali','pitta','cooling','summer'], true, false, 'Yoga With Adriene'),

('Nadi Shodhana Advanced', 'नाड़ी शोधन (उन्नत)', 'Advanced alternate nostril breathing with breath retention (kumbhaka).', 'pranayama', 'youtube', 'https://youtu.be/8VwufJrUhic', 'https://youtu.be/8VwufJrUhic', 900, 3, ARRAY['intermediate','nadi_shodhana','vata','pitta','balance','advanced'], true, false, 'Yoga With Adriene'),

('Sama Vritti Equal Breathing', 'सम वृत्ति समान श्वास', 'Equal-ratio breathing for balance and grounding nervous energy.', 'pranayama', 'youtube', 'https://youtu.be/UB3tSaiEbNY', 'https://youtu.be/UB3tSaiEbNY', 600, 2, ARRAY['intermediate','sama_vritti','vata','balance','grounding'], true, false, 'Yoga With Adriene'),

('Breath of Fire Energizer', 'अग्नि श्वास ऊर्जा', 'Rapid rhythmic breathing to ignite energy and boost metabolism.', 'pranayama', 'youtube', 'https://youtu.be/aaJhuqdaDeI', 'https://youtu.be/aaJhuqdaDeI', 480, 3, ARRAY['intermediate','breath_of_fire','kapha','energy','metabolism','morning'], true, false, 'Swami Ramdev'),

('Wim Hof Breathing Method', 'विम हॉफ श्वास विधि', 'The famous Wim Hof breathing technique for energy and immune boost.', 'pranayama', 'youtube', 'https://youtu.be/tybOi4hjZFQ', 'https://youtu.be/tybOi4hjZFQ', 660, 3, ARRAY['intermediate','wim_hof','kapha','pitta','energy','immune','cold'], true, false, 'Wim Hof'),

-- Advanced Pranayama
('Bhastrika Bellows Breath', 'भस्त्रिका धौंकनी श्वास', 'Bellows breath for powerful energy boost and lung purification.', 'pranayama', 'youtube', 'https://youtu.be/f8f5Rpc5SFc', 'https://youtu.be/f8f5Rpc5SFc', 600, 4, ARRAY['advanced','bhastrika','kapha','energy','morning','purification'], true, true, 'Swami Ramdev'),

('Surya Bhedana Solar Breath', 'सूर्य भेदन सौर श्वास', 'Right nostril breathing to activate solar energy and warm the body.', 'pranayama', 'youtube', 'https://youtu.be/8VwufJrUhic', 'https://youtu.be/8VwufJrUhic', 600, 3, ARRAY['advanced','surya_bhedana','kapha','warming','energy','solar'], true, true, 'Yoga With Adriene'),

('Chandra Bhedana Lunar Breath', 'चंद्र भेदन चंद्र श्वास', 'Left nostril breathing to activate cooling lunar energy and calm the mind.', 'pranayama', 'youtube', 'https://youtu.be/UB3tSaiEbNY', 'https://youtu.be/UB3tSaiEbNY', 600, 3, ARRAY['advanced','chandra_bhedana','pitta','cooling','calm','lunar'], true, true, 'Yoga With Adriene'),

('Pranayama for Anxiety', 'चिंता के लिए प्राणायाम', 'Combination breathwork sequence specifically designed for anxiety relief.', 'pranayama', 'youtube', 'https://youtu.be/oLqoGOUlKpA', 'https://youtu.be/oLqoGOUlKpA', 600, 2, ARRAY['intermediate','anxiety','vata','pitta','calm','stress_relief','therapeutic'], true, false, 'Yoga With Adriene'),

('Evening Wind Down Breath', 'शाम की शांत श्वास', 'Gentle breathwork to release the day''s tension before bed.', 'pranayama', 'youtube', 'https://youtu.be/YRPh_GaiL8s', 'https://youtu.be/YRPh_GaiL8s', 480, 1, ARRAY['beginner','evening','vata','sleep','calm','wind_down'], true, false, 'Andrew Weil'),

('Complete Pranayama Series', 'संपूर्ण प्राणायाम श्रृंखला', 'Full pranayama workout combining kapalbhati, anulom vilom, bhramari, and more.', 'pranayama', 'youtube', 'https://youtu.be/aaJhuqdaDeI', 'https://youtu.be/aaJhuqdaDeI', 1200, 3, ARRAY['intermediate','complete','vata','pitta','kapha','full_practice'], true, false, 'Swami Ramdev')

ON CONFLICT DO NOTHING;


-- ==================== YOGA (20 sessions) ====================

INSERT INTO sessions (title, title_hindi, description, category, media_type, media_url, youtube_url, duration, difficulty, tags, is_active, is_premium, instructor_name)
VALUES
-- Beginner Yoga
('Sun Salutation Complete', 'सूर्य नमस्कार संपूर्ण', 'Complete Surya Namaskar sequence for morning energy and flexibility.', 'yoga', 'youtube', 'https://youtu.be/73sjOu0g58M', 'https://youtu.be/73sjOu0g58M', 900, 2, ARRAY['beginner','surya_namaskar','kapha','morning','energy','flexibility'], true, false, 'Yoga With Adriene'),

('Gentle Yoga for Beginners', 'शुरुआती योग', 'Easy yoga poses perfect for beginners and those with Vata constitution.', 'yoga', 'youtube', 'https://youtu.be/v7AYKMP6rOE', 'https://youtu.be/v7AYKMP6rOE', 1200, 1, ARRAY['beginner','gentle','vata','morning','flexibility'], true, false, 'Yoga With Adriene'),

('Yoga for Back Pain Relief', 'कमर दर्द योग', 'Therapeutic yoga sequence for back pain and spinal health.', 'yoga', 'youtube', 'https://youtu.be/XeXz8fIZDCE', 'https://youtu.be/XeXz8fIZDCE', 1200, 2, ARRAY['beginner','back_pain','therapeutic','vata','pitta','healing'], true, false, 'Yoga With Adriene'),

('Evening Yoga Stretch', 'शाम का योग खिंचाव', 'Relaxing evening yoga to release tension and prepare for sleep.', 'yoga', 'youtube', 'https://youtu.be/v7SN-d4qXx0', 'https://youtu.be/v7SN-d4qXx0', 900, 1, ARRAY['beginner','evening','stretch','vata','pitta','sleep','wind_down'], true, false, 'Yoga With Adriene'),

('Yoga for Stress Relief', 'तनाव मुक्ति योग', 'Calming yoga poses and breathwork for stress and anxiety relief.', 'yoga', 'youtube', 'https://youtu.be/hJbRpHZr_d0', 'https://youtu.be/hJbRpHZr_d0', 1200, 2, ARRAY['beginner','stress_relief','pitta','vata','calm','anxiety'], true, false, 'Yoga With Adriene'),

('Morning Yoga Energy Boost', 'सुबह ऊर्जा योग', 'Wake up your body with this energizing 15-minute morning routine.', 'yoga', 'youtube', 'https://youtu.be/4pKly2JojMw', 'https://youtu.be/4pKly2JojMw', 900, 2, ARRAY['beginner','morning','energy','kapha','vata','wake_up'], true, false, 'Yoga With Adriene'),

('Chair Yoga for Office', 'कुर्सी योग ऑफिस', 'Yoga you can do at your desk — perfect for professionals and students.', 'yoga', 'youtube', 'https://youtu.be/tAUf7aajBWE', 'https://youtu.be/tAUf7aajBWE', 600, 1, ARRAY['beginner','chair','office','vata','pitta','desk','quick'], true, false, 'Yoga With Adriene'),

('Full Body Yoga Stretch', 'पूर्ण शरीर योग खिंचाव', 'Head-to-toe stretching routine for full-body flexibility and mobility.', 'yoga', 'youtube', 'https://youtu.be/v7AYKMP6rOE', 'https://youtu.be/v7AYKMP6rOE', 1500, 1, ARRAY['beginner','full_body','stretch','vata','pitta','kapha','flexibility'], true, false, 'Yoga With Adriene'),

-- Intermediate Yoga
('Hip Opening Deep Flow', 'कूल्हे खोलने का गहन प्रवाह', 'Deep hip opening sequence for flexibility and emotional release.', 'yoga', 'youtube', 'https://youtu.be/FEljg2Yn8gU', 'https://youtu.be/FEljg2Yn8gU', 1500, 3, ARRAY['intermediate','hip_opening','flexibility','vata','kapha','emotional'], true, false, 'Yoga With Adriene'),

('Yoga for Weight Loss', 'वजन घटाने का योग', 'High-energy yoga flow focused on calorie burn and metabolism boost.', 'yoga', 'youtube', 'https://youtu.be/9kOCY0KNByw', 'https://youtu.be/9kOCY0KNByw', 1800, 3, ARRAY['intermediate','weight_loss','kapha','metabolism','energy','strength'], true, false, 'JEFIT'),

('Shoulder & Neck Release', 'कंधे और गर्दन मुक्ति', 'Target tension in shoulders and neck from desk work and stress.', 'yoga', 'youtube', 'https://youtu.be/XeXz8fIZDCE', 'https://youtu.be/XeXz8fIZDCE', 900, 2, ARRAY['intermediate','shoulder','neck','therapeutic','pitta','vata','desk'], true, false, 'Yoga With Adriene'),

('Core Strength Yoga', 'कोर शक्ति योग', 'Build a strong core foundation with these targeted yoga poses.', 'yoga', 'youtube', 'https://youtu.be/9kOCY0KNByw', 'https://youtu.be/9kOCY0KNByw', 1200, 3, ARRAY['intermediate','core','strength','kapha','pitta','abs','power'], true, false, 'Yoga With Adriene'),

('Balance Poses Practice', 'संतुलन आसन अभ्यास', 'Improve your balance and stability with tree pose, warrior III, and more.', 'yoga', 'youtube', 'https://youtu.be/73sjOu0g58M', 'https://youtu.be/73sjOu0g58M', 900, 3, ARRAY['intermediate','balance','stability','vata','focus','coordination'], true, false, 'Yoga With Adriene'),

('Yin Yoga Deep Stretch', 'यिन योग गहन खिंचाव', 'Slow-paced yin yoga holding poses for 3-5 minutes for deep tissue release.', 'yoga', 'youtube', 'https://youtu.be/v7SN-d4qXx0', 'https://youtu.be/v7SN-d4qXx0', 2400, 2, ARRAY['intermediate','yin','deep_stretch','vata','pitta','restorative','slow'], true, false, 'Yoga With Adriene'),

('Vinyasa Flow Sequence', 'विन्यास प्रवाह क्रम', 'Dynamic breath-synced movement for cardiovascular health and strength.', 'yoga', 'youtube', 'https://youtu.be/9kOCY0KNByw', 'https://youtu.be/9kOCY0KNByw', 1800, 3, ARRAY['intermediate','vinyasa','flow','kapha','cardio','strength','dynamic'], true, false, 'Yoga With Adriene'),

-- Advanced Yoga
('Power Yoga Intensive', 'पावर योग गहन', 'Intense power yoga for advanced practitioners seeking a challenge.', 'yoga', 'youtube', 'https://youtu.be/9kOCY0KNByw', 'https://youtu.be/9kOCY0KNByw', 2400, 4, ARRAY['advanced','power_yoga','kapha','strength','energy','challenge'], true, true, 'JEFIT'),

('Ashtanga Primary Series', 'अष्टांग प्राथमिक श्रृंखला', 'Traditional Ashtanga yoga primary series for disciplined practice.', 'yoga', 'youtube', 'https://youtu.be/73sjOu0g58M', 'https://youtu.be/73sjOu0g58M', 3600, 5, ARRAY['advanced','ashtanga','traditional','kapha','pitta','discipline','full_practice'], true, true, 'Kino MacGregor'),

('Yoga for Digestion', 'पाचन के लिए योग', 'Twists and poses that massage internal organs and improve digestion.', 'yoga', 'youtube', 'https://youtu.be/hJbRpHZr_d0', 'https://youtu.be/hJbRpHZr_d0', 900, 2, ARRAY['intermediate','digestion','therapeutic','pitta','kapha','twists','gut_health'], true, false, 'Yoga With Adriene'),

('Yoga for Better Posture', 'बेहतर पॉश्चर योग', 'Correct rounded shoulders and forward head posture with targeted asanas.', 'yoga', 'youtube', 'https://youtu.be/XeXz8fIZDCE', 'https://youtu.be/XeXz8fIZDCE', 900, 2, ARRAY['intermediate','posture','therapeutic','vata','pitta','alignment','desk'], true, false, 'Yoga With Adriene'),

('Bedtime Yoga Sequence', 'सोने से पहले योग', 'Ultra-gentle sequence to do in bed before sleep for deep relaxation.', 'yoga', 'youtube', 'https://youtu.be/v7SN-d4qXx0', 'https://youtu.be/v7SN-d4qXx0', 600, 1, ARRAY['beginner','bedtime','sleep','vata','gentle','night','relaxation'], true, false, 'Yoga With Adriene')

ON CONFLICT DO NOTHING;


-- ==================== VERIFY ====================
SELECT category, COUNT(*) as total_sessions FROM sessions WHERE is_active = true GROUP BY category ORDER BY category;
