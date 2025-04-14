# hdl-modules

Репозиторий, в котором будут собраны все модули

Наработки постепенно переосмысливаются и переносятся из [git@github.com:UA3MQJ/fpga-synth.git](https://github.com/UA3MQJ/fpga-synth)

# назначение модулей

## Common

[Модули общего назначения и вспомогательные](/common/README.md)

| N | Module | Description | Img |
| - | ------ | --- | --- |
| 1 | powerup_reset | Генератор автоматического сигнала сброса и сброса по кнопке | ![dds](https://github.com/VitaSound/hdl-modules/blob/master/common/powerup_reset_test/test.png?raw=true) |
| 2 | frqdivmod | Целочисленный делитель частоты на 2, 3, 4 итд | ![frqdivmod](https://github.com/VitaSound/hdl-modules/blob/master/common/frqdivmod_test/test.png?raw=true) |
| 3 | strobe_gen | Формирователь строба широной 1 clk от нч сигнала (например, от целочисленного делителя) | ![strobe_gen](https://github.com/VitaSound/hdl-modules/blob/master/common/strobe_gen_test/test.png?raw=true) |

Генерация

| N | Module | Description | Img |
| - | ------ | --- | --- |
| 1 | [dds](/dds/README.md) | Генератор базовой цифровой пилы | ![dds](https://github.com/VitaSound/hdl-modules/blob/master/dds/test.png?raw=true) |
| 2 | [dds_transform](/dds_transform/README.md) | Преобразователи формы базовой цифровой пилы <br><br> [dds2saw.v](https://github.com/VitaSound/hdl-modules/blob/master/dds_transform/dds2saw.v) - пила <br> [dds2revsaw.v](https://github.com/VitaSound/hdl-modules/blob/master/dds_transform/dds2revsaw.v) - обратная пила <br> [dds2tria.v](https://github.com/VitaSound/hdl-modules/blob/master/dds_transform/dds2tria.v) - треугольник <br> [dds2meandr.v](https://github.com/VitaSound/hdl-modules/blob/master/dds_transform/dds2meandr.v) - меандр <br> [dds2pwm.v](https://github.com/VitaSound/hdl-modules/blob/master/dds_transform/dds2pwm.v) - PWM c 7-битной регулировкой % | ![dds](https://github.com/VitaSound/hdl-modules/blob/master/dds_transform/test.png?raw=true) |
| 3 | [vca](/vca/README.md) | VCA <br><br> [svca.v](https://github.com/VitaSound/hdl-modules/blob/master/vca/svca.v) - vca 8bit cv, in, out <br> [svca_wide.v](https://github.com/VitaSound/hdl-modules/blob/master/vca/svca_wide.v) - vca 8bit cv, in, 16bit out <br> [svca32.v](https://github.com/VitaSound/hdl-modules/blob/master/vca/svca32.v) - vca 32 bit cv, in, out | ![vca](https://github.com/VitaSound/hdl-modules/blob/master/vca/test.png?raw=true) |
| 4 | [rnd](/rnd/README.md) | RND <br><br> [rnd1.v](https://github.com/VitaSound/hdl-modules/blob/master/rnd/rnd1.v) - rnd 1bit <br> [rnd8.v](https://github.com/VitaSound/hdl-modules/blob/master/rnd/rnd8.v) - rnd 8 bit <br> [rndx.v](https://github.com/VitaSound/hdl-modules/blob/master/rnd/rndx.v) - rnd x bit (1..32) | ![rnd](https://github.com/VitaSound/hdl-modules/blob/master/rnd/test.png?raw=true) |

# окружение

Все модули разработаны и протестированы в icarus verilog

https://iverilog.fandom.com/wiki/Installation_Guide#Ubuntu_Linux

для просмотра gtkwave

# sandbox

песочница со всем подряд

самый первый сайт 

https://sites.google.com/site/analogsynthdiy/sobstvennye-razrabotki/sintezator-na-baze-plis/z---ssylki


# заметки


