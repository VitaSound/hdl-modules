# TODO

Открытые задачи и известные проблемы репозитория (не путать с чеклистом фаз в [LEGACY_MIGRATION_PLAN.md](LEGACY_MIGRATION_PLAN.md)).

---

## Common / simulation

- [ ] **`frqdivmod` — нечётный `DIV` даёт `X` в Icarus**
  - **Симптом:** при нечётном `DIV` (например 21) `signal_out` периодически `X`; цепочка `strobe_gen` → ADSR не получает стабильных стробов, огибающая остаётся на нуле.
  - **Причина:** для нечётного `DIV` выход собирается комбинационно из двух счётчиков (`posedge` + `negedge`) в `always @(clk, pos_cnt, neg_cnt)` ([`common/frqdivmod.v`](../common/frqdivmod.v)).
  - **Где проявилось:** `mono_voice` при `CLK_HZ=1_000_000` и `SAMPLE_CLK_FREQ=48000` → `ADSR_DIV=21`.
  - **Временный обход:** в [`mono_voice/test/testbench.v`](../mono_voice/test/testbench.v) — `CLK_HZ=960_000` (→ `ADSR_DIV=20`) и такт `#(500_000_000/CLK_HZ)`; RTL `mono_voice` по умолчанию остаётся 1 MHz.
  - **Исправление:** переписать ветку нечётного деления (registered output / один счётчик); добавить регрессионный тест `frqdivmod` с `DIV=21`; после фикса вернуть в `mono_voice/test` `CLK_HZ=1_000_000` при желании.
