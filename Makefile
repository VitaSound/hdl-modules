.PHONY: test sim images docs all wave list peek svf-demo

ID ?=
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

# WavePeek query against {test_dir}/out.vcd.
# Preferred: make peek ID=adsr ARGS='info'
# Also:     make peek ID=adsr -- info
#           make peek ID=adsr -- value --at 1us --signals testbench.gate
ifeq ($(filter peek,$(MAKECMDGOALS)),peek)
PEEK_EXTRA := $(filter-out peek,$(MAKECMDGOALS))
ifneq ($(PEEK_EXTRA),)
.PHONY: $(PEEK_EXTRA)
$(PEEK_EXTRA):
	@:
endif
endif

peek:
ifndef ID
	$(error peek requires ID=<module_id>, run "make list" to see ids)
endif
ifeq ($(strip $(ARGS)$(PEEK_EXTRA)),)
	$(error peek requires ARGS='…' or trailing wavepeek args, e.g. ARGS='info' or: make peek ID=adsr -- info)
endif
	python3 tools/peek_wave.py --id $(ID) -- $(ARGS) $(PEEK_EXTRA)

list:
	python3 tools/run_tests.py --list

svf-demo:
	python3 tools/gen_svf_demo_wav.py
