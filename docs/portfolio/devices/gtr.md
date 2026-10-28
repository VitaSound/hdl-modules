# gtr — гитарный процессор

```text
virtual: not_started
hardware: not_started
id: not_started
sale: not_started
```

## Контракт (черновик)

Класс: процессор эффектов. Низколатентная DSP-цепочка, инструментальный вход.

- Виртуальная база: `synths/mini_fx` + цепочка.
- Главный пробел: delay/drive/cab, латентность.

## Модули

- Есть: SVF, AudioPush, mini_fx.
- Нужно: delay, drive, cabinet (хотя бы простой IR или фильтр), цепочка insert.

## DoD виртуала

Как в [DEVICES.md](../DEVICES.md). Эталон: сухой трек гитары → слышна цепочка в REAPER.

## На железе проверить

Инструментальный вход, латентность, шум preamp, клиппинг.
