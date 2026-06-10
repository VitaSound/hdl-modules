# Как добавить новый модуль

Пошаговая инструкция: создать модуль, отладить testbench, добавить в `modules.yaml`, сгенерировать картинку и README.

## 1. Создать RTL

Пример структуры:

```
mymodule/
  mymodule.v
  test/
    testbench.v
    test.sh
```

`test.sh` — тонкая обёртка (после добавления в yaml):

```bash
#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$ROOT/tools/run_tests.py" --id mymodule
```

## 2. Написать testbench

Минимальный шаблон:

```verilog
`timescale 1us / 1ns

module testbench();
  reg clk;
  initial clk <= 0;
  always #10 clk <= ~clk;

  // DUT instantiation

  initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);
    #1000000;
    $display("mymodule test completed.");
    $finish;
  end
endmodule
```

Важно: `$dumpfile("out.vcd")` создаёт файл в каталоге `test/`.

## 3. Отладить симуляцию

```bash
make sim ID=mymodule
```

Или вручную из каталога `test/`:

```bash
iverilog -o testbench testbench.v ../mymodule.v
vvp testbench
```

Если симуляция падает — исправьте testbench или RTL до перехода к следующему шагу.

## 4. Настроить вид волн (test.gtkw)

```bash
make wave ID=mymodule
```

В GTKWave:
1. Выберите нужные сигналы
2. Настройте **масштаб времени** (Zoom) — чтобы форма волны была видна, а не «сплошной блок»
3. Для шин задайте формат отображения: `Data Format → Analog → Interpolated` (или Step), если нужна цифро-аналоговая форма
4. Расположите строки сигналов с удобной высотой
5. `File → Write Save File` → сохраните как `test/test.gtkw`

Файл `test.gtkw` задаёт сигналы, масштаб, формат (digital/analog) и раскладку для PNG в README. При `make images` эти настройки **сохраняются** — скрипт не делает `Zoom Full`.

## 5. Добавить запись в modules.yaml

Пример для модуля в категории `common`:

```yaml
      - id: mymodule
        description_ru: Краткое описание модуля
        source: mymodule/mymodule.v
        test_dir: mymodule/test
        sources:
          - mymodule/mymodule.v
        gtkw: mymodule/test/test.gtkw
        image: mymodule/test/test.png
```

Пример для пакета в категории `generation`:

```yaml
      - id: mymodule
        title: MyModule
        description_ru: Описание пакета
        readme: mymodule/README.md
        source: mymodule/mymodule.v
        test_dir: mymodule/test
        sources:
          - mymodule/mymodule.v
        gtkw: mymodule/test/test.gtkw
        image: mymodule/test/test.png
        variants:   # опционально
          - file: mymodule/mymodule.v
            label: краткое описание варианта
```

### Чеклист полей

| Поле | Обязательно | Описание |
|------|-------------|----------|
| `id` | да | Уникальный идентификатор для `make sim ID=...` |
| `description_ru` | да | Текст для таблицы README |
| `test_dir` | да | Каталог с `testbench.v` |
| `sources` | да | Список `.v` файлов для `iverilog` |
| `image` | да | Путь к PNG, всегда `{test_dir}/test.png` |
| `gtkw` | рекомендуется | Сохранённый вид GTKWave |
| `readme` | для generation | Путь к README пакета |
| `variants` | опционально | Подмодули со ссылками на `.v` |

## 6. Сгенерировать артефакты

```bash
make all
```

Или по шагам:

```bash
make test ID=mymodule    # симуляция
make images ID=mymodule  # PNG из GTKWave
make docs                # обновить README
```

## 7. Проверить результат

1. Откройте `mymodule/test/test.png` — waveform читаемый?
2. Откройте сгенерированный README — описание и картинка на месте?
3. `make list` — ваш `id` в списке?

## 8. Закоммитить

Добавьте в git:

- `mymodule/mymodule.v`
- `mymodule/test/testbench.v`
- `mymodule/test/test.gtkw`
- `mymodule/test/test.sh`
- `mymodule/test/test.png`
- `modules.yaml`
- сгенерированные `README.md`

Не коммитьте: `out.vcd`, `testbench` (бинарник), `wave.ps`.

## FAQ

### `make test` падает с `iverilog: command not found`

Установите зависимости: [DEPENDENCIES.md](DEPENDENCIES.md)

### `make images` падает — нет X / gtkwave

Нужны `xvfb`, `gtkwave`. Рендер идёт через `xvfb-run` и цветной PNG grab из окна GTKWave.

### Картинка пустая или без сигналов

Сохраните `test.gtkw` с нужными сигналами и перезапустите `make images ID=...`.

### CI ругается на `git diff`

Локально выполните `make all` и закоммитьте обновлённые README и PNG.
