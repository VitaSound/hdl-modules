# Имя исполняемого файла
TARGET = obj_dir/Vgenerator

# Verilator и PortAudio
VERILATOR_FLAGS = --cc --exe --build
PORTAUDIO_LIBS = -lportaudio

# Исходные файлы
SRCS = generator.sv main.cpp

# Правила сборки
all: $(TARGET)

$(TARGET): $(SRCS)
	verilator $(VERILATOR_FLAGS) $(SRCS) --Mdir obj_dir
	cd obj_dir && make -j -f Vgenerator.mk
	g++ -o $(TARGET) obj_dir/main.o obj_dir/verilated.o obj_dir/verilated_threads.o obj_dir/Vgenerator__ALL.a $(PORTAUDIO_LIBS) -lpthread

clean:
	rm -rf obj_dir