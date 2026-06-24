.PHONY: test sim images docs all wave list svf-demo

ID ?=

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

list:
	python3 tools/run_tests.py --list

svf-demo:
	python3 tools/gen_svf_demo_wav.py
