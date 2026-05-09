# Стартовый корпус анти-ИИ-клише

> Корпус паттернов, которые **запрещены в авторском тексте по умолчанию**, потому что выдают генерацию большим языковым моделям. Корпус собран на этапе 02 как стартовый набор для будущего модуля анти-ИИ-клише (этап 11) и как сверка с практикой автора (этап 03).
>
> **Состав:** 29 паттернов из Humanizer (https://github.com/blader/humanizer, MIT) + Wikipedia: Signs of AI writing (CC BY-SA 4.0, https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) + 5 дополнительных паттернов из обзоров MIT Technology Review / Nieman Lab. Итого: **34 паттерна**.
>
> **Локализация на русский язык — НЕ задача этапа 02.** Все паттерны зафиксированы в оригинальной (английской) формулировке. Локализация в этап 11 (дизайн анти-ИИ-клише модуля) и этап 12 (наполнение скиллов). Каждый паттерн помечен меткой «**требует локализации**».

## Источники

- **Humanizer SKILL.md** — https://github.com/blader/humanizer/blob/main/SKILL.md (загружен 2026-05-04, 29 паттернов с before/after примерами).
- **Wikipedia: Signs of AI writing** — https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing (CC BY-SA 4.0). Поддерживается WikiProject AI Cleanup.
- **MIT Technology Review** — https://www.technologyreview.com (серии обзоров AI-writing detection 2023–2025).
- **Nieman Lab / Nieman Reports** — https://www.niemanlab.org (журналистский угол).

## Структура карточки паттерна

```
### N. Имя паттерна (категория)

- **Trigger words / признаки:** список ключевых маркеров.
- **Why it's bad:** почему это AI-ism.
- **Before (AI):**
- **After (human):**
- **Категория:** content / language / style / communication / filler.
- **Источник:** Humanizer #N | Wikipedia | MIT Tech Review.
- **Требует локализации:** ✅ / ❌ (всегда ✅ для этого корпуса).
```

---

## Категория 1 — Content patterns (содержательные паттерны)

### 1. Undue Emphasis on Significance, Legacy, and Broader Trends

- **Trigger words / признаки:** «stands as», «serves as», «is a testament», «is a reminder», «plays a vital/significant/crucial/pivotal/key role», «underscores its importance», «reflects broader», «symbolizing its ongoing/enduring/lasting», «contributing to the», «setting the stage for», «marking a significant».
- **Why it's bad:** искусственное раздувание значимости. LLM-модели часто заканчивают абзацы фразой про «значимость», когда нет основания.
- **Before (AI):** «This experiment serves as a testament to the enduring power of human curiosity, underscoring its significance in the broader history of science.»
- **After (human):** «This experiment found one thing — and it broke a 50-year-old assumption.»
- **Категория:** content.
- **Источник:** Humanizer #1, Wikipedia: Signs of AI writing.
- **Требует локализации:** ✅

### 2. Undue Emphasis on Notability and Media Coverage

- **Trigger words / признаки:** «featured in», «recognized as», «widely regarded as», «received critical acclaim», «notable for», «celebrated for», «hailed as».
- **Why it's bad:** name-dropping, попытка добавить весомости через «известных людей хвалят». Маркер promotional language.
- **Before (AI):** «The book has been widely regarded as a landmark in the field, hailed by critics as a tour de force.»
- **After (human):** «The book changed how I think about X — three specific reasons below.»
- **Категория:** content.
- **Источник:** Humanizer #2, Wikipedia: Signs of AI writing.
- **Требует локализации:** ✅

### 3. Superficial Analyses with -ing Endings

- **Trigger words / признаки:** «shaping the», «contributing to», «underlining the importance of», «highlighting the role of», «paving the way for», «setting the stage for», «adding to», «reinforcing the».
- **Why it's bad:** -ing endings создают видимость анализа, но без содержания. Часто завершают абзац пустым «…paving the way for future research».
- **Before (AI):** «This finding contributes to the growing body of evidence, highlighting the role of social media in shaping public discourse and paving the way for further inquiry.»
- **After (human):** «So now we know teens see 4× more political content than adults. The next question: does it change how they vote.»
- **Категория:** content.
- **Источник:** Humanizer #3, Wikipedia: Signs of AI writing.
- **Требует локализации:** ✅

### 4. Promotional and Advertisement-like Language

- **Trigger words / признаки:** «cutting-edge», «innovative», «groundbreaking», «state-of-the-art», «revolutionize», «unparalleled», «seamless», «robust».
- **Why it's bad:** маркетинговый язык, не информация. В авторском нон-фикшн читается как пресс-релиз.
- **Before (AI):** «This cutting-edge, state-of-the-art framework offers an unparalleled, seamless experience that revolutionizes how teams collaborate.»
- **After (human):** «It does one thing — keeps state in a markdown file. That sounds boring; that's the point.»
- **Категория:** content.
- **Источник:** Humanizer #4, Wikipedia: Signs of AI writing.
- **Требует локализации:** ✅

### 5. Vague Attributions and Weasel Words

- **Trigger words / признаки:** «studies suggest», «experts say», «critics argue», «it has been observed», «many believe», «research shows» (без ссылки).
- **Why it's bad:** ссылка без ссылки. Создаёт видимость основанности, но проверить нельзя.
- **Before (AI):** «Studies suggest that frequent breaks improve productivity by up to 40%, with experts arguing that the brain needs time to consolidate.»
- **After (human):** «Boice (1990) tracked 27 academics for 10 weeks; daily writers produced 3.5–9× more than binge writers. https://doi.org/10.1016/0005-7967(89)90144-7»
- **Категория:** content.
- **Источник:** Humanizer #5, Wikipedia: Signs of AI writing.
- **Требует локализации:** ✅

### 6. Outline-like "Challenges and Future Prospects" Sections

- **Trigger words / признаки:** концовка раздела с обязательной парой «Challenges» + «Future prospects». Бывает с подзаголовками или без.
- **Why it's bad:** механический шаблон LLM-эссе; реальный автор так не пишет.
- **Before (AI):** «**Challenges:** Implementation remains complex.\n**Future prospects:** Continued research will likely reveal new opportunities.»
- **After (human):** «What's still broken: nobody knows how to debug it when it fails silently. That's the next ugly problem.»
- **Категория:** content.
- **Источник:** Humanizer #6, Wikipedia: Signs of AI writing.
- **Требует локализации:** ✅

---

## Категория 2 — Language and grammar patterns

### 7. Overused "AI Vocabulary" Words

- **Trigger words / признаки:** «delve», «underscores», «leveraging», «navigate», «journey», «landscape», «ecosystem», «realm», «tapestry», «testament», «moreover», «furthermore», «in conclusion».
- **Why it's bad:** конкретные слова стали статистическими маркерами LLM-генерации.
- **Before (AI):** «Let's delve into this complex landscape, leveraging insights from various ecosystems.»
- **After (human):** «Let's look at three things that surprised me.»
- **Категория:** language.
- **Источник:** Humanizer #7, Wikipedia: Signs of AI writing (раздел «Common LLM tells»).
- **Требует локализации:** ✅

### 8. Avoidance of "is"/"are" (Copula Avoidance)

- **Trigger words / признаки:** замена «X is Y» на «X functions as Y», «X serves as Y», «X represents Y», «X embodies Y».
- **Why it's bad:** LLM избегает прямого утверждения, делая текст вычурным.
- **Before (AI):** «The function serves as a wrapper that embodies the principle of separation of concerns.»
- **After (human):** «It's a wrapper. That's it.»
- **Категория:** language.
- **Источник:** Humanizer #8.
- **Требует локализации:** ✅

### 9. Negative Parallelisms and Tailing Negations

- **Trigger words / признаки:** «not just X, but Y», «not only X, but also Y», «X is not just A, it's also B».
- **Why it's bad:** rule of three / двойного отрицания, превращающийся в речёвку. Один-два раза в тексте — норма; на каждой странице — AI-ism.
- **Before (AI):** «It's not just a tool, it's a way of thinking. Not only does it solve problems, but it also reshapes the entire workflow.»
- **After (human):** «It's a tool. Side effect: it reshaped my workflow.»
- **Категория:** language.
- **Источник:** Humanizer #9, Wikipedia.
- **Требует локализации:** ✅

### 10. Rule of Three Overuse

- **Trigger words / признаки:** систематическая структура «A, B, and C» в каждом абзаце. Любая мысль выражается тройкой.
- **Why it's bad:** rule-of-three хорош в умеренной дозе; LLM применяет на автомате.
- **Before (AI):** «We need clarity, brevity, and impact. The system must be fast, reliable, and intuitive. Users want speed, simplicity, and control.»
- **After (human):** «It needs to be fast. The rest can be ugly.»
- **Категория:** language.
- **Источник:** Humanizer #10, Wikipedia.
- **Требует локализации:** ✅

### 11. Elegant Variation (Synonym Cycling)

- **Trigger words / признаки:** одно понятие — несколько синонимов в одном абзаце. «The article — the piece — the work — the analysis…».
- **Why it's bad:** учительский стиль «не повторяйся» в исполнении LLM приводит к синонимическим прыжкам, которые затрудняют чтение.
- **Before (AI):** «The study examined the data. The research analyzed the metrics. The investigation revealed the patterns.»
- **After (human):** «The study examined the data and found three patterns.»
- **Категория:** language.
- **Источник:** Humanizer #11, Wikipedia.
- **Требует локализации:** ✅

### 12. False Ranges

- **Trigger words / признаки:** «from X to Y, and everything in between», «at every level, from beginner to expert».
- **Why it's bad:** ложная всеохватность; реально автор не покрывает «всё между».
- **Before (AI):** «The framework helps developers at every level, from junior coders to senior architects, and everyone in between.»
- **After (human):** «I tested it on a junior team. Senior architects probably don't need it.»
- **Категория:** language.
- **Источник:** Humanizer #12.
- **Требует локализации:** ✅

### 13. Passive Voice and Subjectless Fragments

- **Trigger words / признаки:** «It is observed that», «It can be seen that», «It must be noted».
- **Why it's bad:** академический passive в местах, где живой автор сказал бы «я заметил».
- **Before (AI):** «It must be noted that the results were unexpected.»
- **After (human):** «I didn't expect this.»
- **Категория:** language.
- **Источник:** Humanizer #13, Wikipedia.
- **Требует локализации:** ✅

---

## Категория 3 — Style patterns

### 14. Em Dash Overuse

- **Trigger words / признаки:** систематическое появление em dash (`—`) в каждом абзаце. Часто как сноска внутри предложения.
- **Why it's bad:** GPT-4-class модели очень любят em dash; стало главным визуальным маркером AI-текста.
- **Before (AI):** «The system — designed for scale — handles millions of requests — without breaking a sweat — even under load.»
- **After (human):** «The system handles millions of requests at peak.»
- **Категория:** style.
- **Источник:** Humanizer #14, Wikipedia.
- **Требует локализации:** ✅ (русский: тире — типографически отдельная сущность; нужны отдельные правила для русскоязычного hook).

### 15. Overuse of Boldface

- **Trigger words / признаки:** **bold** на каждый второй существительный для «акцентов». Bullet-список с **bold:** в начале каждого пункта.
- **Why it's bad:** структурированность ради структурированности; реальный нон-фикшн почти не использует bold вне заголовков.
- **Before (AI):** «**Speed**: The system is **fast**. **Reliability**: It is **robust**. **Cost**: The pricing is **affordable**.»
- **After (human):** «It's fast, robust, and cheap. Specifically: 12k req/s, 99.9% uptime, $40/mo.»
- **Категория:** style.
- **Источник:** Humanizer #15, Wikipedia.
- **Требует локализации:** ✅

### 16. Inline-Header Vertical Lists

- **Trigger words / признаки:** список «**Term**: definition / **Term**: definition».
- **Why it's bad:** Wiki-стиль в местах, где живой автор написал бы абзацем.
- **Before (AI):** «**Latency**: time to first byte.\n**Throughput**: bytes per second.\n**Concurrency**: simultaneous requests.»
- **After (human):** «Latency is the wait until first byte. Throughput is bytes per second. Concurrency is how many people can wait at once.»
- **Категория:** style.
- **Источник:** Humanizer #16.
- **Требует локализации:** ✅

### 17. Title Case in Headings

- **Trigger words / признаки:** заголовки в английском стиле Title Case («The Best Way to Do X») в местах, где автор пишет sentence case.
- **Why it's bad:** технически правильный английский, но статистически — маркер LLM-эссе. Sentence case («The best way to do X») считается «человечнее» в современном англо-нон-фикшн.
- **Before (AI):** «### The Five Best Practices for Writing Great Code»
- **After (human):** «### Five practices that actually work»
- **Категория:** style.
- **Источник:** Humanizer #17, Wikipedia.
- **Требует локализации:** ❌ (русский язык не имеет проблемы Title Case — но требует анализа эквивалентного маркера; помечается «изучить локально» в этап 11).

### 18. Emojis

- **Trigger words / признаки:** эмодзи в нон-фикшн или серьёзном тексте.
- **Why it's bad:** LLM-модели по умолчанию вставляют эмодзи как «дружелюбность»; в серьёзном письме это дисквалифицирующий маркер.
- **Before (AI):** «Let's dive in! 🚀 Here are the top 5 tips ✨ that will help you 💯»
- **After (human):** «Five things I learned the hard way.»
- **Категория:** style.
- **Источник:** Humanizer #18, Wikipedia.
- **Требует локализации:** ✅ (универсально для русского).

### 19. Curly Quotation Marks

- **Trigger words / признаки:** автоматическая замена `"text"` на `“text”` и `'text'` на `‘text’` LLM-моделью даже там, где исходный контекст плоский ASCII.
- **Why it's bad:** в техническом или неформальном тексте curly quotes выглядят как машинная пост-обработка.
- **Before (AI):** «He said “I’ll be right back” and left.»
- **After (human):** «He said "I'll be right back" and left.» (в техническом контексте; для финального оформления типографские кавычки норма).
- **Категория:** style.
- **Источник:** Humanizer #19.
- **Требует локализации:** ⚠️ (русские «ёлочки» — типографская норма; правило применимо ограниченно — нужна доработка в этап 11).

---

## Категория 4 — Communication artifacts

### 20. Collaborative Communication Artifacts

- **Trigger words / признаки:** «Let me know if you'd like me to expand on this», «I hope this helps», «Feel free to ask any clarifying questions», «I'd be happy to dive deeper».
- **Why it's bad:** assistant-isms внутри **авторского** текста. Чистый артефакт того, что писатель — на самом деле LLM-ассистент.
- **Before (AI):** «In conclusion, the framework offers many benefits. Let me know if you'd like me to expand on any section!»
- **After (human):** (отрезать целиком).
- **Категория:** communication.
- **Источник:** Humanizer #20, Wikipedia.
- **Требует локализации:** ✅

### 21. Knowledge-Cutoff Disclaimers

- **Trigger words / признаки:** «As of my last training data», «I don't have access to real-time information», «My knowledge cutoff is...».
- **Why it's bad:** assistant-disclaimer в авторском тексте. Не уместен.
- **Before (AI):** «As of my last training, the framework was being adopted by major companies.»
- **After (human):** «Last I checked (October 2024), three Fortune 500 had pilots running.»
- **Категория:** communication.
- **Источник:** Humanizer #21.
- **Требует локализации:** ✅

### 22. Sycophantic / Servile Tone

- **Trigger words / признаки:** «Great question!», «That's a fascinating point», «Excellent observation», «What a wonderful idea», подхалимство и переоценка собеседника.
- **Why it's bad:** assistant-режим. Авторский текст не разговаривает с читателем как с особенным гостем.
- **Before (AI):** «That's a great question! It really gets to the heart of what makes this framework so powerful.»
- **After (human):** «Yes — and the answer's not what most people think.»
- **Категория:** communication.
- **Источник:** Humanizer #22, Wikipedia.
- **Требует локализации:** ✅

---

## Категория 5 — Filler and hedging

### 23. Filler Phrases

- **Trigger words / признаки:** «It is important to note that», «It is worth mentioning that», «It should be noted», «As previously stated», «In other words».
- **Why it's bad:** не несут информации; объём ради объёма.
- **Before (AI):** «It is important to note that, as previously stated, the framework offers significant advantages.»
- **After (human):** «The framework saves 40% time. Repeating because it matters.»
- **Категория:** filler.
- **Источник:** Humanizer #23, Wikipedia.
- **Требует локализации:** ✅

### 24. Excessive Hedging

- **Trigger words / признаки:** «may potentially», «could possibly», «might perhaps», «in some cases, it may be that...».
- **Why it's bad:** двойное-тройное хеджирование вместо одного «возможно».
- **Before (AI):** «This may potentially be useful in some cases, although it could possibly depend on context.»
- **After (human):** «Useful in three cases. Useless in one. Try it.»
- **Категория:** filler.
- **Источник:** Humanizer #24.
- **Требует локализации:** ✅

### 25. Generic Positive Conclusions

- **Trigger words / признаки:** «In conclusion, X is a powerful tool that can transform Y», «Overall, the future is bright», «Ultimately, the possibilities are endless».
- **Why it's bad:** концовка без содержания, оценочное «всё хорошо».
- **Before (AI):** «In conclusion, BookBench is a powerful framework that can transform how authors write, paving the way for a new era of human-AI collaboration.»
- **After (human):** «Three months in, I'm using it daily. The boring file structure turned out to be the killer feature.»
- **Категория:** filler.
- **Источник:** Humanizer #25, Wikipedia.
- **Требует локализации:** ✅

### 26. Hyphenated Word Pair Overuse

- **Trigger words / признаки:** «cutting-edge», «state-of-the-art», «next-generation», «hands-on», «forward-thinking», «out-of-the-box» — концентрация в одном абзаце.
- **Why it's bad:** один такой термин — норма; четыре подряд — AI-ism.
- **Before (AI):** «This next-generation, state-of-the-art, cutting-edge framework offers a hands-on, out-of-the-box solution.»
- **After (human):** «New framework. Works without configuration.»
- **Категория:** filler.
- **Источник:** Humanizer #26.
- **Требует локализации:** ✅ (русский эквивалент: «передовой / инновационный / прорывной» — близкий маркер).

### 27. Persuasive Authority Tropes

- **Trigger words / признаки:** «As any expert will tell you», «It is widely known», «Everyone agrees that», «There is no doubt that».
- **Why it's bad:** ссылка на авторитет в стиле «никто не сомневается»; легко не заметить, что аргумент пустой.
- **Before (AI):** «There is no doubt that, as any expert will tell you, the future of writing is collaborative AI.»
- **After (human):** «Three of five book editors I asked agree; two strongly disagree.»
- **Категория:** filler.
- **Источник:** Humanizer #27.
- **Требует локализации:** ✅

### 28. Signposting and Announcements

- **Trigger words / признаки:** «In this section, we will discuss...», «As we will see in the following paragraphs...», «Now let's turn to...».
- **Why it's bad:** meta-discourse, который Pinker критикует в «Sense of Style». Нужен изредка как навигация, не на каждом разделе.
- **Before (AI):** «In this section, we will discuss three approaches. As we will see, each has its merits.»
- **After (human):** «Three approaches. Each works in different cases.»
- **Категория:** filler.
- **Источник:** Humanizer #28.
- **Требует локализации:** ✅

### 29. Fragmented Headers

- **Trigger words / признаки:** заголовки уровня h3-h4 на каждый параграф; излишняя сегментация структурой.
- **Why it's bad:** LLM сегментирует текст как Wikipedia-статью; реальный нон-фикшн часто пишет несколько страниц без заголовков, держа связность за счёт текста.
- **Before (AI):** «### Introduction\nWe begin...\n### Background\nThe context is...\n### Definition\n...» (8 заголовков на 2 страницы текста)
- **After (human):** один h2-заголовок главы + 4–5 h3 на ключевые поворотные точки. Внутри — связный текст.
- **Категория:** filler.
- **Источник:** Humanizer #29.
- **Требует локализации:** ✅

---

## Дополнительные паттерны (за пределами Humanizer-каталога)

> Источник: MIT Technology Review (серия 2023–2025), Nieman Lab, наблюдения автора в этапе 03 (промпт `web-claude-prompt-example.md`).

### 30. Англицизмы в русском авторском тексте

- **Trigger words / признаки:** «контент», «нарратив», «инсайт», «фреймворк», «бэкграунд» — там, где есть точный русский эквивалент («материал», «изложение», «открытие», «методика», «прошлое»).
- **Why it's bad:** маркер машинного перевода или некритичного следования English-speaking AI-моделям.
- **Before (AI):** «Контент должен иметь сильный нарратив, чтобы создать инсайт у пользователя.»
- **After (human):** «Текст должен рассказывать историю — иначе читатель не поймёт идею.»
- **Категория:** language.
- **Источник:** наблюдение в практике автора (промпт `web-claude-prompt-example.md`); MIT Tech Review «AI-translated journalism is everywhere» (2024).
- **Требует локализации:** ❌ (паттерн **рождается из** локализации; для русского формулируется так).

### 31. «Бабушкин тест» провален: концепция без якоря в реальности

- **Trigger words / признаки:** абзац вводит абстрактный термин («квантовая запутанность», «эпигенетика», «реентерантность») — и не даёт примера на знакомом материале в течение 3 предложений.
- **Why it's bad:** LLM любит вводить терминологию с уверенностью; читатель-непрофильник теряется. Нарушение T5.2 (curse of knowledge) и T5.5 (ladder of abstraction).
- **Before (AI):** «Квантовая запутанность — это нелокальное состояние, при котором свойства системы коррелированы независимо от расстояния между частицами.»
- **After (human):** «Представь две монеты: одну ты подбрасываешь в Москве, другую — в Токио. Если они "запутаны", то результат на одной монете мгновенно определяет результат на другой. Расстояние не важно. Это и есть запутанность.»
- **Категория:** content.
- **Источник:** методология этапа 02 (T5.2 Pinker, T5.5 Clark); прямо реализуется как hook у писателя научпопа.
- **Требует локализации:** ❌ (паттерн универсальный, но триггеры зависят от языка).

### 32. Излишняя структура там, где нужен поток мысли

- **Trigger words / признаки:** длинные нумерованные списки в местах, где живой автор написал бы 2-3 связных абзаца. Явный признак ChatGPT-генерации стандартного «10 причин почему».
- **Why it's bad:** связано с T6.2 (паттерн #29 fragmented headers), но шире. Любой раздел из 7+ пунктов с одной структурой — анти-паттерн.
- **Before (AI):** список из 12 пунктов «причин выбрать X», каждый с bold-заголовком и одним предложением.
- **After (human):** «Главных причин три. Есть ещё мелкие, но они вытекают из этих трёх. Вот основные.» — далее 3 связных абзаца.
- **Категория:** style.
- **Источник:** Nieman Lab, «How to spot AI-written op-eds» (2024).
- **Требует локализации:** ✅

### 33. Generic названия / заголовки

- **Trigger words / признаки:** заголовки в стиле «The Power of X», «The Ultimate Guide to X», «X: A Comprehensive Overview», «Mastering X».
- **Why it's bad:** SEO-LLM-стиль; не отражает содержание, а маркетит его. Хороший автор называет статью более конкретно.
- **Before (AI):** «The Power of Subagents: A Comprehensive Guide to AI-Driven Writing»
- **After (human):** «Five subagents that wrote chapter 3 (and one that didn't)»
- **Категория:** style.
- **Источник:** наблюдение MIT Tech Review «How to spot AI-generated content» (2024).
- **Требует локализации:** ✅

### 34. Сводное «ИИ-предложение» — три SUCCESs-маркера в одном

- **Trigger words / признаки:** одно длинное предложение с (а) метафорой («mosaic of innovation»), (б) усилителем («groundbreaking»), (в) обобщением («for the modern era»).
- **Why it's bad:** концентрированная демонстрация AI-isms; одно такое предложение на главу — норма, два — уже тревога, три — текст сгенерирован.
- **Before (AI):** «BookBench is a groundbreaking framework that weaves together a mosaic of subagents, redefining the way authors craft narratives in the modern era.»
- **After (human):** «BookBench — это плагин Claude Code, который разбивает работу над книгой на роли. Я начал делать его 4 мая 2026 года, потому что устал писать в claude.ai.»
- **Категория:** content + style + filler (мета-паттерн).
- **Источник:** наблюдение автора в практике + Humanizer audit-pass logic.
- **Требует локализации:** ✅

---

## Использование в BookBench

**На этапе 11** этот корпус превращается в:

1. **Skill `anti-ai-cliche`** (`.skill.md` в плагине) — инжектируется через `skills:` в писательский и редакторский субагенты. Содержит сжатые формулировки 34 паттернов с примерами before/after.
2. **Hook PostToolUse** на `Edit|Write` у писателя и редактора. При записи текста проверяет наличие trigger words из таблицы. Найденные совпадения возвращаются в контекст роли с инструкцией «либо обоснуй сознательное использование, либо перепиши».
3. **Команда `/book:audit-cliche <file>`** — точечный запуск audit-pass: «прочитай этот файл, найди оставшиеся AI-isms, переспроси с явным вопросом 'что выдаёт ИИ?'».

**На этапе 03** (извлечение методологии из практики автора): корпус сверяется с тем, что автор уже зафиксировал в `web-claude-prompt-example.md`. Дельта (что у автора уникально, что не покрыто корпусом) добавляется как паттерны #35+.

**На этапе 12** (наполнение скиллов): корпус переводится / адаптируется на русский язык. Каждый паттерн получает:
- Русский trigger words list.
- Русский before/after.
- Регулярки/grep-паттерны для использования в hook.

## Сигналы для следующих этапов

**Этап 03:** сверить корпус с авторским 4-этапным промптом. Зафиксировать дельту: что у автора есть, чего нет в корпусе; что в корпусе есть, что у автора нет. Это даст финальный набор для этапа 11.

**Этап 11 (микро-цикл главы и анти-ИИ-клише модуль):**
- Корпус — стартовая база для skill `anti-ai-cliche`.
- Hook PostToolUse у писателя — проверка по trigger words.
- Audit-pass как обязательная стадия микро-цикла после первого drafting'а.

**Этап 12 (наполнение скиллов):** русская локализация всех 34 паттернов; написание regex'ов для hook'а.

**Этап 16 (документация):** упомянуть корпус в README BookBench как одну из ключевых фич («встроенный модуль анти-ИИ-клише на 34 паттерна»).

---
*Создан: 2026-05-04*
