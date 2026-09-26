# GU-WOW: история версий / Version history

## 1.7.0-release «Живой огонь» / "Living Flame"

### Русский

**Новое**
- Яркость и цвет в самой игре: на странице «Основные» появились «Яркость», «Контрастность», «Сочность цвета» и «Тепло картинки» — сам WoW так не умеет. 50 у любого ползунка = картинка игры без изменений, кадр при этом не трогается вовсе.
- Пресеты картинки рядом с ползунками: «Стандарт WoW», пять готовых («Живые краски», «Кино», «Мягкий вечер», «Север», «Полдень Азерота») и слот «Мой» — кнопка «+» сохраняет ваши значения, «-» удаляет. Пресеты листаются с предпросмотром, как атмосферные.
- Код настроек теперь несёт и яркость с цветом (GUW6). Старые коды и пресеты работают: недостающие значения берутся нейтральными.

**Исправлено**
- Золотые лучи рассвета и заката держат силу дневных: подгонка золота по яркости. Смена цвета на золото делала лучи на шестую часть тусклее ровно в золотые часы.
- Свечение солнца в тумане разгорается быстро, а гаснет медленно: солнце, мигающее за деревьями, держит свет ровным, а потеря солнца отпускает его плавно, как свет сквозь облака.

### English

**New**
- Brightness and colour inside the game: the Main page now has Brightness, Contrast, Colour richness and Picture warmth — WoW itself cannot do this. 50 on any slider = the game's own picture, and the frame is then left untouched entirely.
- Picture presets next to the sliders: WoW standard, five ready looks (Living colours, Cinema, Soft evening, North, Azeroth noon) and a My slot — «+» saves your values, «-» deletes them. The presets page through with a preview, like the atmosphere ones.
- The share code now carries the brightness and colour too (GUW6). Old codes and presets keep working: the missing values come out neutral.

**Fixed**
- The golden rays of sunrise and sunset keep the daytime strength: the gold is matched by luminance. The plain hue swap made the rays a sixth dimmer exactly in the golden hours.
- The sun's glow in the fog lights up fast and dies out slowly: a sun flickering behind trees keeps the light steady, and losing the sun lets it go softly, like light through clouds.

## 1.6.9-release «Живой огонь» / "Living Flame"

### Русский

**Новое**
- Меню собрано заново, четыре страницы: «GU-WOW» — приветствие с подсказками, самолечением и сообщением об ошибке; «Основные» — атмосфера, ночь, картинка и пресеты; «Дополнительно» — стили, коды, свои пресеты, поведение и движение тумана; «Фоторежим» — только снимки.
- Самолечение: команда /gu fix и кнопка на странице «Профили и фото» чинят сбои на месте — битые настройки, зависший предпросмотр, забытый вид проверки, слетевшую подложку чата — и называют, что именно починили. Если дело в сглаживании или устаревшей установке, команда прямо говорит, что сделать.
- Марево не гнёт интерфейс: чат и панели не плывут жаровыми волнами в пустыне.
- Страницы GU-WOW вписываются в стандартное окно настроек сами: окно не растягивается, ползунок масштаба меню не нужен и убран.
- Окно описания в «Сообщить об ошибке» принимает клик и ввод.
- Сообщение об ошибке одной кнопкой из игры: /gu report или кнопка на странице GU-WOW, название и описание, «Отправить» — и всё. Служебные данные (версия, настройки, логи, свежий вылет) прилагаются сами. Доставку ведёт тихий фоновый помощник без значка в трее: установщик спрашивает согласие («Не нужно» — отказ, мод работает полностью). После «Отправить» интерфейс перезагружается на пару секунд (окно отчёта предупреждает об этом заранее), и отчёт сразу уходит на GitHub; уведомление Windows говорит «доставлено» или «ошибка при отправке». Сам по себе помощник никуда ничего не шлёт и читает только файлы игры. Кнопка «Сообщить об ошибке» в установщике осталась как запасной путь.
- Мокрая земля в дождь не рябит: мелкий песок, бегавший по всей земле при движении камеры, убран, земля просто темнеет и блестит.
- Низовой туман не прыгает на вышках, на холмах и при полёте: на крыше башни и на вершине холма туман над долиной держится ровно при наклоне камеры, а взлёт и посадка плавно меняют его за полторы секунды.
- Закат без вспышек: свечение солнца в тумане разгорается и гаснет плавно, за пару секунд, даже когда игра подтормаживает. Подтормаживание протаскивало половину перехода за один кадр, и яркость кадра прыгала ступенькой.
- Дождь без белой пелены: свечение солнца в тумане глушится серым небом так же, как лучи. В дождь искатель солнца ведёт яркое облако, и его свечение заливало кадр жёлто-белым.

### English

**New**
- The menu is rebuilt into four pages: GU-WOW — a welcome with the hints, the self-heal and the bug report; Main — the atmosphere, the night, the picture and the presets; Extras — styles, codes, your presets, behaviour and the fog motion; Photo mode — only the shots.
- Self-heal: the /gu fix command and a button on the «Profiles and photo» page mend faults on the spot — broken settings, a stuck preview, a forgotten check view, a lost chat shade — and name what they fixed. When the cause is anti-aliasing or a stale install, the command says exactly what to do.
- The heat haze does not bend the interface: the chat and the bars no longer wave in the desert.
- The GU-WOW pages fit themselves into the standard options window: the window does not grow, and the menu scale slider is gone as unneeded.
- The description box of the bug report takes the click and the typing.
- A one-button bug report from the game: /gu report or the button on the GU-WOW page, a title and a description, Send — done. The service data (the version, the settings, the logs, the latest crash) is attached for you. A quiet background helper with no tray icon delivers it: the installer asks for consent first (No thanks opts out, the mod works in full). After Send the interface reloads for a couple of seconds (the report window warns about it first) and the report goes to GitHub at once; a Windows balloon says delivered or failed. On its own the helper sends nothing and reads only the game files. The installer button stays as the fallback.
- Wet ground in the rain does not ripple: the fine sand that crawled over the ground with the camera is gone, the ground simply darkens and shines.
- The low mist does not jump on towers, on hills and in flight: on a tower top or a hilltop the mist over the valley holds steady as the camera tilts, and take-off and landing change it smoothly over a second and a half.
- Sunset without flashes: the sun's glow in the fog swells and dies smoothly, over a couple of seconds, even when the game stutters. A stutter used to drag half the transition through one frame, and the frame's brightness jumped in a step.
- Rain without a white veil: the sun's glow in the fog is muted by a grey sky the same way the rays are. In the rain the sun finder follows a bright cloud, and its glow flooded the frame with yellow-white.

## 1.6.8-release «Живой огонь» / "Living Flame"

### Русский

**Новое**
- Звёзды мерцают: ночью яркие точки тёмного неба дышат, луна остаётся ровной.
- Далёкие молнии в грозу: под тяжёлой облачностью днём небо и дальняя земля мягко вспыхивают пару раз в минуту.
- Золотой час красит и дымку: на рассвете и закате освещённая солнцем сторона тумана золотится вместе с лучами.
- Виньетка чуть глубже ночью: кадр в темноте собирается к центру, днём как настроено.
- Кинорамка фоторежима с мягкой внутренней кромкой, без жёсткого среза.
- Рассвет и закат золотые: около 6:30 и 19:30 по игровым часам лучи солнца и их свечение берут глубокий золотой цвет, к полудню возвращается тёплый белый.
- Костры греют ночной туман: рядом с огнём холодная лунная дымка становится тёплым карманом света, лагерь ночью выглядит обжитым.
- Ползунок «Движение тумана» на странице «Профили и фото»: низовой туман медленно плывёт и дышит, проход сквозь него живой. Движение стоит в мире, а не на экране. 0 выключает, как раньше.
- Клавиша включения и выключения мода назначается в «Управлении» игры, раздел GU-WOW, рядом с фоторежимом и снимком.
- Команда /gu check показывает проверку глубины прямо из чата, без окна ReShade: близкое светлое, небо чёрное, красная рамка = глубины нет. /gu help перечисляет команды, /gu news показывает новости версии ещё раз.
- У рискованных ползунков предупреждение: с высоких значений плотности тумана, чёткости лучей, марева, резкости и зерна под ползунком появляется заметка о возможных артефактах.

**Исправлено**
- Персонажи, мобы и доспехи не светятся ночью сами по себе. Яркое пятно на геометрии ближе 12 ярдов считается подсветкой модели, а не источником света; ядро пламени и факел в руке ярче порога и светят как прежде.
- Низовой туман не дёргается при повороте камеры: наклон камеры подаётся в оценку земли напрямую из слежения за кадром, сглаживанию остаётся только шум.
- В меню видно предупреждение, когда включено сглаживание (MSAA): без глубины туман, лучи и ночь не работают, и теперь об этом сказано прямо на странице настроек.
- Сломанные значения настроек лечатся при входе: число вне допустимого диапазона возвращается к значению по умолчанию, ползунки не клинит.

### English

**New**
- Stars twinkle: at night the bright points of the dark sky breathe, the moon stays steady.
- Distant lightning in a storm: under a heavy overcast by day the sky and the far land flash softly a couple of times a minute.
- The golden hour paints the haze too: at sunrise and sunset the sunlit side of the fog turns gold with the rays.
- The vignette sits a touch deeper at night: the frame gathers to the centre in the dark, the day keeps your value.
- The photo cinema bars have a soft inner edge, no hard cut.
- Sunrise and sunset are golden: around 6:30 and 19:30 by the game clock the sun rays and their glow take a deep gold, back to warm white by noon.
- Fires warm the night mist around them: near a flame the cold moonlit veil becomes a warm pocket of light, a camp at night looks lived-in.
- A fog motion slider on the «Profiles and photo» page: the ground mist slowly flows and breathes, walking through it feels alive. The motion stands in the world, not on the screen. 0 turns it off.
- The mod toggle key is set in the game Key Bindings, GU-WOW section, next to photo mode and the screenshot.
- /gu check shows the depth check right from the chat, no ReShade window: near is bright, the sky is black, a red border means no depth. /gu help lists the commands, /gu news shows the version news again.
- Risky sliders warn: from high values of mist thickness, ray definition, heat haze, sharpness and grain a note under the slider says artifacts are possible.

**Fixed**
- Characters, mobs and gear do not glow at night by themselves. A bright spot on geometry nearer than 12 yards is the game lighting a model, not a light source; a flame core and a hand-held torch are brighter than the bar and glow as before.
- The ground mist does not jerk on camera turns: the camera tilt feeds the ground estimate straight from the frame tracking, and the smoothing keeps only the noise.
- The menu warns when anti-aliasing (MSAA) is on: without depth the fog, the rays and the night cannot work, and the settings page now says so.
- Broken saved values heal on login: a number out of its range returns to the default, sliders cannot get stuck.

## 1.6.7-release «Живой огонь» / "Living Flame"

### Русский

**Исправлено**
- Выход из помещения плавный. Игра сообщает «в доме или на улице» одним переключателем, и ночь, низовой туман и вечерний свет прыгали на пороге за один кадр. Теперь признак помещения размазан во времени: выход набирает силу эффектов за пару секунд, как глаза привыкают на пороге, вход гасит их быстрее. Вид на улицу из окна и двери не тронут.

### English

**Fixed**
- Leaving a building is smooth. The game reports «indoors or outside» as a single switch, and the night, the ground mist and the evening light jumped at the doorstep within one frame. The indoor flag is now eased in time: walking out gains the effects over a couple of seconds, the way eyes settle at a doorway, walking in dims them faster. The view of the street through a window or a door is untouched.

## 1.6.6-release «Живой огонь» / "Living Flame"

### Русский

**Улучшено**
- Огонь по-настоящему светит. Свет костра на земле и на персонаже усилен вдвое, ореол в воздухе поднят, лужа света достигает полной силы уже у среднего огня, дальние факелы видны с большего расстояния. Двери фильтра огней открыты шире: ядро пламени и тёплый свет проходят без прежних порогов, а белые крылья и бледную шерсть держит отдельная отсечка.
- Лучи солнца в полтора раза тоньше: буфер света вырос со 180 до 270 строк, снопы чётче и меньше дрожат на краях.
- Свет огней точнее: поле света выросло в полтора раза, ореолы и лужи света сидят плотнее на своих лампах, мелкие огни находятся с большего расстояния.
- Тени в щелях глубже и чище: 24 пробы вместо 16 и шире радиус у близких углов.
- Ночные и туманные переходы без полос: готовый кадр сглажен на один уровень серого (дизеринг), плавные градиенты ночи не распадаются на ступени.
- Слежение за кадром точнее: карта движения выросла в полтора раза, поиск сдвига шире.
- Цена всего набора: около миллисекунды на кадр на средней карте. Слабым машинам по-прежнему помогают пресет More FPS и «Автокачество».

### English

**Improved**
- Fire truly shines. The firelight on the ground and the character is doubled, the halo in the air is up, the pool of light reaches full strength at a modest fire, far torches show from farther away. The fire filter doors are open wider: a flame core and warm light pass without the old gates, while white wings and pale fur are held by their own cut.
- The sun shafts are half again finer: the light buffer grew from 180 to 270 rows, the shafts are crisper and their edges calmer.
- The firelight is more precise: the light field grew half again, the halos and the pools sit tighter on their lamps, small fires are found from farther away.
- The contact shadows are deeper and cleaner: 24 samples instead of 16 and a wider radius for near corners.
- The night and fog gradients show no bands: the finished frame is dithered by one grey level, so the smooth gradients do not break into steps.
- The frame tracking is more precise: the motion map grew half again, the shift search is wider.
- The whole set costs about a millisecond a frame on a mid-range card. The More FPS preset and Auto quality still help weaker machines.

## 1.6.5-release «Лунная тропа» / "Moonlit Path"

### Русский

**Исправлено**
- Костры, факелы и лампы светят снова, тусклые лампы в помещениях тоже. Фильтр 1.6.3 против ложных огней задел настоящие: усреднение делает пламя не совсем белым и не совсем цветным, и оно резалось вместе с крыльями. Теперь у тёплого света (огонь, лава, окна) своя дверь в фильтре, а планка яркости опущена до тусклых ламп.
- Красные имена врагов над головами не считаются огнями. Чистый красный без зелени это текст; пламя оранжевое. Красные надписи не светят и не пересвечиваются.
- Подложка под чатом держится: настройки чата подгружаются после входа в мир и затирали её, теперь она подтверждается ещё раз через мгновение.

### English

**Fixed**
- Bonfires, torches and lamps glow again, dim indoor lamps too. The 1.6.3 filter against false lights caught the real ones: the block average makes a flame neither clipped white nor strongly coloured, and it was cut with the wings. Warm light (fire, lava, windows) has its own door in the filter now, and the brightness bar is down to the dim lamps.
- Red enemy names over heads do not count as fires. Pure red with no green is text; a flame is orange. Red names no longer glow.
- The chat shade holds: the chat settings load after entering the world and overwrote it; it is reasserted a moment later.

## 1.6.4-release «Лунная тропа» / "Moonlit Path"

### Русский

**Новое**
- Под чатом лёгкая подложка: текст не тонет в текстурах мира, поверх которых лежат туман и ночь. Это штатное затемнение окна чата, знакомое по табличке «Непрозрачность»; галочка «Подложка под чатом» на странице «Профили и фото» её включает и выключает, своя настройка непрозрачности у игрока остаётся главной.

### English

**New**
- A light shade sits behind the chat: the text does not sink into the world textures under the fog and the night. It is the game's own chat window shade, the one from the «Opacity» setting; the «Shade behind the chat» box on the «Profiles and photo» page turns it on and off, and the player's own opacity choice stays in charge.

## 1.6.3-release «Лунная тропа» / "Moonlit Path"

### Русский

**Исправлено**
- Рамки напарников читаются ночью. Игра делает рамки дальних членов группы полупрозрачными, и над затемнённой ночью они пропадали целиком; порог, отделяющий интерфейс от мира, опущен, и тусклые рамки с именами остаются видны.
- Ночью светятся только настоящие огни. Белое и бледное ночью сияло, как фонарь: крылья летучих мышей, светлая шерсть, серые доспехи получали ореол и подсвечивали воздух. Теперь свечение оставлено огню, лампам и ярко окрашенному свету, а бесцветное должно быть почти белым по яркости, как сам огонь, чтобы считаться источником. Это же убирает лишние пересветы ночью.

### English

**Fixed**
- Party frames stay readable at night. The game fades the frames of far party members to half transparency, and over the darkened night they vanished; the gate that tells the interface from the world is lowered, and the dim frames with names stay visible.
- At night only real fires glow. White and pale things shone like lamps: bat wings, pale fur and grey armour got a halo and lit the air. The glow now belongs to fire, lamps and strongly coloured light, and a colourless patch must be nearly clipped bright, like a flame itself, to count as a source. This also removes the stray overexposure at night.

## 1.6.2-release «Лунная тропа» / "Moonlit Path"

### Русский

**Изменено**
- Окно ReShade открывается клавишей F5. Старое сочетание Ctrl и Scroll Lock на ноутбуках требовало ещё и Fn, и до окна было не добраться. Установщик переводит на F5 и старые сборки; клавиша, выбранная игроком вручную, не трогается.

### English

**Changed**
- The ReShade window opens with F5. The old Ctrl and Scroll Lock combination needed Fn as well on laptops, and the window was out of reach. The installer moves older builds to F5 too; a key the player chose by hand stays.

## 1.6.1-release «Лунная тропа» / "Moonlit Path"

### Русский

**Исправлено**
- Ползунок «Свет огней» управляет яркостью огней ночью по-настоящему. Ореол в воздухе упирался в фиксированный потолок, а свет костра на земле и на персонаже был константой: у ярких огней ползунок почти ничего не менял. Теперь и ореол, и свет на земле отвечают на него всей шкалой.
- Карта в окне не выключает эффекты. Выключение нужно только полноэкранной карте, где ночь затемняла недорисованную карту; оконная карта закрывает часть экрана, и мир вокруг неё держит эффекты.

### English

**Fixed**
- The light glow slider truly drives the fires at night. The halo in the air ran into a fixed cap and the firelight on the ground and the character was a constant: for bright fires the slider changed almost nothing. Now the halo and the light on the ground answer it over the whole range.
- The windowed map does not switch the effects off. The switch is only needed for the fullscreen map, where the night darkened the half-drawn map; the windowed map covers part of the screen, and the world around it keeps the effects.

## 1.6.0-release «Лунная тропа» / "Moonlit Path"

### Русский

**Новое**
- Эффекты следят за движением кадра. Каждый кадр сравнивается с прошлым, и найденный сдвиг говорит солнцу, туману и огням, куда уехала картинка. Найденное солнце не теряется при повороте камеры, цвет тумана не плывёт через промежуточные цвета, свет и ореолы огней не отстают от своих фонарей. При телепорте и на экранах загрузки слежение само отключается.
- Ползунок «Туман с высоты». Стелющийся туман виден с горы, с обрыва и в полёте: внизу лежат одеяла тумана. 0 даёт прежний вид, сверху воздух чистый. По умолчанию 50.
- Ползунок «Чёткость лучей». 0 — мягкое свечение в дымке, 100 — отдельные широкие снопы с тенью между ними. По умолчанию 25, прежний вид.
- Марево стоит в мире, а не на экране. Рябь привязана к направлению взгляда и к расстоянию: при повороте камеры она едет вместе с землёй.

**Исправлено**
- Низовой туман на холмистой местности держится ровно. На неровной земле оценка «где земля» сбивалась на каждом шаге, и туман мигал; теперь он плавно тает при плохой оценке и возвращается.
- В пасмурную погоду и в дождь лучи солнца приглушены до пятой части. Сплошная серая облачность видна по небу, и яркое облако не сходит за солнце со снопами сквозь дождь.

**Изменено**
- Окно настроек игры шире и выше, пока открыта страница GU-WOW: подписи ползунков помещаются целиком. При выходе со страницы окно возвращается к прежнему размеру.
- «Атмосфера по зонам» на странице «Профили и фото», рядом с автокачеством: это поведение, а не картинка. Место на главной странице заняли новые ползунки.
- Пресеты Starry Night, Peaceful Morning и Grim Storm задают свой туман с высоты; More FPS выключает его.

### English

**New**
- The effects follow the motion of the frame. Every frame is matched against the last one, and the found shift tells the sun, the fog and the lights where the picture went. A found sun is not lost in a camera turn, the fog colour does not swim through in-between colours, the light and the halos of the lamps do not trail behind them. On a teleport and on loading screens the tracking turns itself off.
- A slider, mist from a height. The ground mist shows from a hill, a cliff and in flight: blankets of mist lie below. 0 gives the old look, clear air from above. 50 by default.
- A slider, ray definition. 0 is a soft glow in the haze, 100 separate wide shafts with shade between them. 25 by default, the old look.
- The heat haze stands in the world, not on the screen. The ripples are tied to the view direction and the distance: as the camera turns they ride with the land.

**Fixed**
- The ground mist holds steady on hilly land. On uneven ground the guess of where the ground stands broke with every stride and the mist blinked; now it fades softly while the guess is poor and comes back.
- In overcast weather and in rain the sun rays are cut to a fifth. A solid grey sky is read from the sky itself, so a bright cloud does not pass for a sun with shafts through the rain.

**Changed**
- The game's options window is wider and taller while a GU-WOW page is open: the slider labels fit whole. It returns to its old size when you leave the page.
- Atmosphere by zone lives on the "Profiles and photo" page, next to auto quality: it is behaviour, not the picture. The new sliders took its place on the main page.
- The presets Starry Night, Peaceful Morning and Grim Storm set their own mist from a height; More FPS turns it off.

## 1.5.8-release «Лунная тропа» / "Moonlit Path"

### Русский

**Новое**
- Готовые пресеты на главной странице меню: Default, Starry Night, Peaceful Morning, Cinema, Clear Day, Golden Sunset, Fairy Forest, Grim Storm, Noir и More FPS. Default повторяет настройки автора, остальные собраны от него. Стрелки сразу показывают пресет на экране, кнопка «Применить» оставляет его.
- Пока идёт предпросмотр, ползунки подстраивают показанный пресет. «Применить» сохраняет его с правками, «Отменить» возвращает прежние настройки.
- Рядом со стрелками видно имя пресета, который сейчас на экране. После любой правки там написано «Свои настройки».
- Кнопка «+» рядом со стрелками сохраняет настройки с экрана как пресет «Пользовательские #1» и дальше по номерам, до 10. Кнопка «-» удаляет показанный пользовательский пресет после вопроса. Стрелки листают готовые и пользовательские вместе.

**Изменено**
- Настройки автора обновлены до вида, собранного в игре 25.09. Кнопка «Настройки автора» возвращает пресет Default.
- Марево, кино-HDR и плёночное зерно находятся на главной странице меню рядом с остальными эффектами игры. Они работают всё время, поэтому им место среди настроек игры.
- У марева и кино-HDR есть ползунок силы от 0 до 100. Ноль выключает эффект, 50 даёт вид версии 1.5.4, 100 усиливает вдвое. Кто включал их в 1.5.4, получит 50.
- Страница «Профили и фото» собирает то, что нужно только для снимков и подбора вида: стили, коды, свои пресеты, фоторежим, боке и размытие фона.
- Коды настройки из прошлых версий читаются.

### English

**New**
- Ready presets on the main menu page: Default, Starry Night, Peaceful Morning, Cinema, Clear Day, Golden Sunset, Fairy Forest, Grim Storm, Noir and More FPS. Default is the author's settings, the others are built from it. The arrows show a preset on screen at once, the «Apply» button keeps it.
- While a preview is on, the sliders tune the preset on screen. «Apply» saves it with your changes, «Cancel» brings back your settings.
- Next to the arrows you see the name of the preset on screen. After any change it says «Custom».
- The «+» button next to the arrows saves the on-screen settings as the preset «Custom #1» and up by number, 10 at most. The «-» button deletes the shown user preset after a question. The arrows walk through the ready and the user presets together.

**Changed**
- The author's settings are updated to the look tuned in game on 25.09. The «Author's settings» button brings back the Default preset.
- Heat haze, cinema HDR and film grain sit on the main menu page with the other in-game effects. They work all the time, so they belong with the game settings.
- Heat haze and cinema HDR have a strength slider from 0 to 100. Zero turns the effect off, 50 gives the look of 1.5.4, 100 doubles it. If you had them on in 1.5.4, you get 50.
- The "Profiles and photo" page holds what is needed only for shots and choosing a look: styles, codes, your presets, photo mode, bokeh and background blur.
- Settings codes from earlier versions still load.

## 1.5.6-release «Лунная тропа» / "Moonlit Path"

### Русский

**Исправлено**
- После фоторежима игра могла перестать слушаться клавиатуры, Esc и другие клавиши. Фоторежим прятал интерфейс так, что игра закрывала окна от имени аддона и затем отказывала клавишам. Теперь интерфейс становится прозрачным, окна настроек закрываются заранее, клавиатура отпускается при входе и выходе.
- Esc, Enter в чат и Alt+Z выходят из фоторежима.
- Предупреждение «Binding header GUWOW is defined more than once» в журнале игры.

### English

**Fixed**
- After photo mode the game could stop listening to the keyboard, Esc and other keys. Photo mode hid the interface in a way that made the game close windows as addon code and then refuse keys. Now the interface goes transparent, the options window closes first, the keyboard is let go on entering and leaving.
- Esc, Enter to chat and Alt+Z leave photo mode.
- The warning «Binding header GUWOW is defined more than once» in the game log.

## 1.5.5-release «Лунная тропа» / "Moonlit Path"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский

**Исправлено**
- После работы с пресетами игра могла перестать слушаться клавиатуры, даже Esc. Поле названия пресета держало ввод и после закрытия меню. Теперь оно отпускает клавиатуру при закрытии меню и при нажатии кнопок пресетов. Поле кода настройки тоже.

### English

**Fixed**
- After working with presets the game could stop listening to the keyboard, even Esc. The preset name box kept the input after the menu closed. Now it lets the keyboard go when the menu closes and when a preset button is pressed. The settings code box too.

## 1.5.4-release «Лунная тропа» / "Moonlit Path"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский

Всё новое выключено, чтобы привычная картинка не менялась. Включается на странице «Профили и фото».

**Новое**
- Марево: в пустынях и огненных землях дальняя земля дрожит от жара. Персонажи и небо не искажаются.
- Три цветовых стиля: «Закат», «Сказка» и «Нуар».
- Кино-HDR: тени глубже, яркое не выгорает в белое, цвет чуть плотнее.
- Плёночное зерно с ползунком.
- Фоторежим: ползунок силы размытия и боке, огни на размытом фоне становятся мягкими кружками.
- Кнопка «Настройки автора» в основном разделе меню. Она спрашивает подтверждение и не трогает пресеты.
- После обновления игра один раз показывает, что нового.

**Исправлено**
- Размытие в фоторежиме по умолчанию втрое мягче.
- Окно ReShade открывается сочетанием Ctrl и Scroll Lock. Случайное нажатие Scroll Lock больше не открывает нечитаемое окно, которое держит мышь.
- Установщик в конце называет только те клавиши, которые у вас действительно работают.

### English

All new things are off, so the familiar picture does not change. Turn them on on the "Profiles and photo" page.

**New**
- Heat haze: in deserts and fire lands the far ground wavers in the heat. Characters and the sky stay still.
- Three colour styles: Sunset, Fairy tale and Noir.
- Cinema HDR: deeper shadows, bright areas no longer burn to white, a little denser colour.
- Film grain with a slider.
- Photo mode: a blur strength slider and bokeh, lights in the blur become soft discs.
- An "Author's settings" button in the main menu page. It asks first and leaves the presets alone.
- After an update the game shows once what is new.

**Fixed**
- The photo mode blur is three times softer by default.
- The ReShade window opens with Ctrl and Scroll Lock. A stray Scroll Lock no longer opens an unreadable window that holds the mouse.
- At the end the installer names only the keys that really work for you.

## 1.5.3-release «Лунная тропа» / "Moonlit Path"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский

**Исправлено**
- Надпись ReShade при запуске игры сжата до тонкой полосы, текста на ней не видно. Она примерно в два с половиной раза ниже, чем до 1.5.2.
- Счётчик кадров ReShade, если он включён, остаётся обычного размера.

### English

**Fixed**
- The ReShade banner at the game start is squeezed into a thin strip with no visible text. It is about two and a half times lower than before 1.5.2.
- The ReShade frame counter, if you turned it on, keeps its usual size.

## 1.5.2-release «Лунная тропа» / "Moonlit Path"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский

**Исправлено**
- Надпись ReShade при запуске игры вдвое меньше. Раньше на мониторах от 1440 пикселей в высоту ReShade сам увеличивал её в полтора раза, а на 4K в два.
- Надпись видна около 5 секунд. Собранные эффекты теперь хранятся в папке игры, и очистка диска их больше не стирает. Раньше после неё эффекты собирались заново от 10 до 20 секунд.

### English

**Fixed**
- The ReShade banner at the game start is half as big. Before, ReShade itself made it 1.5 times bigger on screens of 1440 lines and more, and twice as big on 4K.
- The banner shows for about 5 seconds. The compiled effects are now kept in the game folder, so a disk cleanup no longer makes them compile again for 10 to 20 seconds.

## 1.5.1-release «Лунная тропа» / "Moonlit Path"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский

**Исправлено**
- Пробы на странице «Профили и фото» больше не затирают ваши настройки. Стиль, готовый профиль или чужой код сначала включают предпросмотр.
- Настройки меняются, только если нажать «Применить» на полоске вверху экрана. «Отменить» или перезаход в игру возвращают ваши настройки.

**Новое**
- Мои пресеты в основном разделе меню: до 10 своих настроек с названиями. Их можно сохранить, загрузить и удалить.
- Перед загрузкой, удалением и перезаписью пресета меню спрашивает подтверждение.
- Три слота из 1.5.0 сами перенесены в пресеты, сохранённое в них не потеряется.

### English

**Fixed**
- Trying things on the "Profiles and photo" page no longer overwrites your settings. A style, a ready profile or a friend's code starts a preview first.
- Your settings change only when you press "Apply" on the bar at the top of the screen. "Cancel" or logging in again brings your settings back.

**New**
- My presets in the main menu page: up to 10 named sets of your own settings. You can save, load and delete them.
- Before loading, deleting or overwriting a preset, the menu asks you to confirm.
- The three slots of 1.5.0 moved into the presets by themselves, nothing saved in them is lost.

## 1.5.0-release «Лунная тропа» / "Moonlit Path"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский

**Картинка**
- Цветовые стили: «Тёплый», «Холодный», «Плёнка» и «Сочный». Меняют общий характер цвета, как фильтр фотоаппарата.
- Лунный свет: ночью луна даёт мягкие холодные лучи сквозь кроны.
- Атмосфера по зонам: в болотах и лесах гуще низовой туман, в пустынях воздух прозрачнее, в снегах чуть больше дымки. В выжженных землях и в городах низового тумана меньше. Ваши ползунки остаются главными.

**Фото и видео**
- Фоторежим: медленный облёт камеры вокруг персонажа, скрытие имён над головами, кинорамка.
- Чистый снимок: одна кнопка или клавиша, и интерфейс на мгновение прячется, игра делает снимок, всё возвращается.

**Удобство**
- Кнопка у миникарты: левая кнопка открывает меню, правая включает и выключает мод, Shift + левая включает фоторежим. Кнопку можно перетащить по кругу.
- Новая страница меню «Профили и фото»: готовые профили, цветовые стили, три своих слота и коды настройки.
- Коды настройки: нажмите «Мой код», скопируйте строку и отправьте другу. Он вставит её и нажмёт «Применить код».
- Автокачество: если кадров меньше заданного, тени в щелях, низовой туман, резкость, мокрая земля и привыкание глаз на время отключаются. Возвращаются сами, когда нагрузка спадёт.
- Меню на английском для игроков с не-русским клиентом.
- Установщик сам сообщает о новой версии и открывает страницу загрузки.

**Исправлено**
- В меню больше не наезжают друг на друга «Привыкание глаз», «Мокрая земля» и кнопки профилей.

### English

**Picture**
- Colour styles: Warm, Cold, Film and Vivid. They change the overall mood of the colours, like a camera filter.
- Moonlight: at night the moon casts soft cold rays through the trees.
- Atmosphere by zone: thicker ground mist in swamps and forests, clearer air in deserts, a little more haze in the snow. Less ground mist in scorched lands and cities. Your sliders stay in charge.

**Photos and videos**
- Photo mode: a slow camera orbit around your character, names above heads hidden, cinema bars.
- Clean screenshot: one button or key hides the interface for a moment, the game takes the shot, everything comes back.

**Convenience**
- Minimap button: left click opens the menu, right click turns the mod on or off, Shift + left click starts photo mode. Drag it around the minimap.
- A new menu page "Profiles and photo": ready profiles, colour styles, three slots of your own and settings codes.
- Settings codes: press "My code", copy the line and send it to a friend. They paste it and press "Apply code".
- Auto quality: when the frame rate drops below your target, contact shadows, ground mist, sharpening, wet ground and eye adaptation pause. They come back on their own.
- An English menu for players with a non-Russian client.
- The installer tells you when a new version is out and opens its download page.

**Fixed**
- In the menu, "Eye adaptation", "Wet ground" and the profile buttons no longer overlap.

## 1.4 «Фотограф» / "Photographer"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский
- Тени в щелях: предметы садятся на землю, мягкие тени под камнями, травой и у стен.
- Мокрая земля в дождь и пасмурную погоду.
- Фоторежим: интерфейс прячется, персонаж в фокусе, фон размыт.
- Готовые профили: «Кино», «Ясный день», «Мрачно», «Больше FPS».
- Из таверны и домов видна ночь на улице за дверью и окнами.

### English
- Contact shadows: objects sit on the ground, with soft shadows under stones, grass and near walls.
- Wet ground in rain and overcast weather.
- Photo mode: the interface hides, your character stays in focus, the background is blurred.
- Ready profiles: Cinema, Clear day, Gloomy, More FPS.
- From a tavern or a house you see the night outside, through doors and windows.

## 1.3 «Ночь» / "Night"

> Модификация создана в честь неоспоримого наследия Turtle WoW, а также для жизни и процветания коммьюнити Brothers of Turtle. Лок'Тар!
>
> This mod is made in honour of the undeniable legacy of Turtle WoW, and for the life and prosperity of the Brothers of Turtle community. Lok'tar!

### Русский
- Меню настроек прямо в игре: Интерфейс > Модификации > GU-WOW.
- Установщик в одну кнопку.
- Настоящая ночь по игровым часам, с ползунками «Темнота ночи» и «Глубина ночи». Огонь, окна и лава светят.
- Низовой туман с двумя ползунками, погодное настроение, резкость, цвет по времени суток, привыкание глаз, виньетка.
- Эффекты не трогают интерфейс, стартовый экран, экраны загрузки и открытую карту мира.

### English
- A settings menu right in the game: Interface > AddOns > GU-WOW.
- A one-click installer.
- A real night by the game clock, with the Night darkness and Night depth sliders. Fire, windows and lava keep glowing.
- Ground mist with two sliders, weather mood, sharpening, time of day colour, eye adaptation, vignette.
- The effects leave the interface, the login screen, loading screens and the open world map alone.
