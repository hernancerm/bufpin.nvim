HELP_FILE := ./doc/pin.txt
CMD_NVIM := nvim --headless --noplugin
ECHASNOVSKI_GH_BASE_URL := https://raw.githubusercontent.com/echasnovski
CMD_MINI_DOC_GENERATE := @$(CMD_NVIM) -u ./scripts/testdocs_init.lua && echo ''
MINI_DOC_GIT_HASH := 28d1d8172a463460131c3ae929498abe78937382
STYLUA_VERSION := $(shell grep stylua .tool-versions | awk '{ print $$2 }')
STYLUA := $(HOME)/.asdf/installs/stylua/$(STYLUA_VERSION)/bin/stylua

# Check formatting.
.PHONY: testmft
testfmt: $(STYLUA)
	stylua --check lua/ scripts/ tests/

# Check docs are up to date.
.PHONY: testdocs
testdocs: deps/lua/doc.lua
	git checkout $(HELP_FILE)
	@$(CMD_MINI_DOC_GENERATE)
	git diff --exit-code $(HELP_FILE)

# Run CI tests.
.PHONY: testci
testci: testfmt testdocs

# Format.
.PHONY: fmt
fmt: $(STYLUA)
	stylua lua/ scripts/ tests/

# Update docs.
.PHONY: docs
docs: deps/lua/doc.lua
	$(CMD_MINI_DOC_GENERATE)

deps/lua/doc.lua:
	@mkdir -p deps/lua
	curl $(ECHASNOVSKI_GH_BASE_URL)/mini.doc/$(MINI_DOC_GIT_HASH)/lua/mini/doc.lua -o $@

$(STYLUA):
	asdf plugin add stylua
	asdf install stylua
