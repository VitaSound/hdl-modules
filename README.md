# hdl-modules

Репозиторий, в котором будут собраны все модули

Наработки постепенно переосмысливаются и переносятся из [git@github.com:UA3MQJ/fpga-synth.git](https://github.com/UA3MQJ/fpga-synth)

# назначение модулей

| N | Module | Description | Img |
| - | ------ | --- | --- |
| 1 | [powerup_reset](/powerup_reset/README.md) | Генератор автоматического сигнала сброса и сброса по кнопке | ![dds](https://github.com/VitaSound/hdl-modules/blob/main/powerup_reset/test.png?raw=true) |
| 2 | [dds](/dds/README.md) | Генератор базовой цифровой пилы | ![dds](https://github.com/VitaSound/hdl-modules/blob/main/dds/test.png?raw=true) |
| 3 | [dds_transform](/dds_transform/README.md) | Преобразователи формы базовой цифровой пилы <br><br> [dds2saw.v](https://github.com/VitaSound/hdl-modules/blob/main/dds_transform/dds2saw.v) - пила <br> [dds2revsaw.v](https://github.com/VitaSound/hdl-modules/blob/main/dds_transform/dds2revsaw.v) - обратная пила <br> [dds2tria.v](https://github.com/VitaSound/hdl-modules/blob/main/dds_transform/dds2tria.v) - треугольник <br> [dds2meandr.v](https://github.com/VitaSound/hdl-modules/blob/main/dds_transform/dds2meandr.v) - меандр <br> [dds2pwm.v](https://github.com/VitaSound/hdl-modules/blob/main/dds_transform/dds2pwm.v) - PWM c 7-битной регулировкой % | ![dds](https://github.com/VitaSound/hdl-modules/blob/main/dds_transform/test.png?raw=true) |
| 4 | [vca](/vca/README.md) | VCA <br><br> [svca.v](https://github.com/VitaSound/hdl-modules/blob/main/vca/svca.v) - vca 8bit cv, in, out <br> [svca_wide.v](https://github.com/VitaSound/hdl-modules/blob/main/vca/svca_wide.v) - vca 8bit cv, in, 16bit out <br> [svca32.v](https://github.com/VitaSound/hdl-modules/blob/main/vca/svca32.v) - vca 32 bit cv, in, out | ![vca](https://github.com/VitaSound/hdl-modules/blob/main/vca/test.png?raw=true) |

# окружение

Все модули разработаны и протестированы в icarus verilog

https://iverilog.fandom.com/wiki/Installation_Guide#Ubuntu_Linux

для просмотра gtkwave

# sandbox

песочница со всем подряд

самый первый сайт 

https://sites.google.com/site/analogsynthdiy/sobstvennye-razrabotki/sintezator-na-baze-plis/z---ssylki


# заметки

06.07.2024 - test git
07.07.2024 год

07.07.2024 - Windows 10 version
