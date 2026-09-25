# GU-WOW: история версий / Version history

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
