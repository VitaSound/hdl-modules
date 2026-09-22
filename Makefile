.PHONY: test sim images docs all wave list peek svf-demo

ID ?=
WAVES ?=
ARGS ?=

test:
ifdef ID
	python3 tools/run_tests.py --id $(ID)
else
	python3 tools/run_tests.py
endif

sim: test

images:
ifdef ID
	python3 tools/render_images.py --id $(ID)
else
	python3 tools/render_images.py
endif

docs:
	python3 tools/gen_readme.py

all: test images docs

wave:
ifndef ID
	$(error wave requires ID=<module_id>, run "make list" to see ids)
endif
	python3 tools/open_wave.py --id $(ID)

# WavePeek query against module/synth VCD.
# Preferred: make peek ID=adsr ARGS='info'
# Synths:    make peek ID=mono_synth|mini_fx|noise_box ARGS='info'
# Explicit:  make peek WAVES=synths/mini_fx/out.vcd ARGS='info'
# Also:      make peek ID=adsr -- info
ifeq ($(filter peek,$(MAKECMDGOALS)),peek)
PEEK_EXTRA := $(filter-out peek,$(MAKECMDGOALS))
ifneq ($(PEEK_EXTRA),)
.PHONY: $(PEEK_EXTRA)
$(PEEK_EXTRA):
	@:
endif
endif

peek:
ifeq ($(strip $(ID)$(WAVES)),)
	$(error peek requires ID=<module_or_synth_id> and/or WAVES=<path>)
endif
ifeq ($(strip $(ARGS)$(PEEK_EXTRA)),)
	$(error peek requires ARGS='…' or trailing wavepeek args, e.g. ARGS='info' or: make peek ID=adsr -- info)
endif
	python3 tools/peek_wave.py $(if $(ID),--id $(ID),) $(if $(WAVES),--waves $(WAVES),) -- $(ARGS) $(PEEK_EXTRA)

list:
	python3 tools/run_tests.py --list

svf-demo:
	python3 tools/gen_svf_demo_wav.py
