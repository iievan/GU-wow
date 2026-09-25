# GU-WOW: история версий / Version history

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
