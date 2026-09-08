$(info APOLLO_LSP_CC=$(CC))
$(info APOLLO_LSP_CXX=$(CXX))
$(info APOLLO_LSP_CFLAGS=$(CFLAGS))
$(info APOLLO_LSP_CXXFLAGS=$(CXXFLAGS))
$(info APOLLO_LSP_SOURCES=$(SOURCES) $(STATIC_SOURCES) $(APOLLO_CMD_SOURCES))
$(foreach s,$(SOURCES) $(STATIC_SOURCES),$(info APOLLO_LSP_OVERRIDE=$(s)|$(CXXFLAGS-$(basename $(notdir $(s))).o)))
.PHONY: apollo_lsp_export
apollo_lsp_export:
	@:
