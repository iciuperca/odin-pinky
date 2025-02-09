ODIN_EXE=/opt/odin/odin
BIN_DIR=./bin
SHADERS_DIR=shaders
DEBUG_EXE=$(BIN_DIR)/pinky
RELEASE_EXE=$(BIN_DIR)/pinky_release
TEST_EXE=$(BIN_DIR)/pinky_test
ODIN_FILES=$(wildcard *.odin)
VET_FLAGS=-vet -strict-style -vet-cast -vet-using-param -vet-using-stmt -vet-tabs -terse-errors -vet-packages:pinky -vet-unused-procedures
# -vet-packages:pinky -vet-unused-procedures
VET_FLAGS_RELEASE=$(VET_FLAGS)

.PHONY: clean all debug release test run run_release

all: debug release test

debug: $(DEBUG_EXE)

release: $(RELEASE_EXE)

test: $(TEST_EXE)

$(DEBUG_EXE): $(ODIN_FILES) | $(BIN_DIR)
	$(ODIN_EXE) build . -debug -o:none -out:$@ -microarch:native $(VET_FLAGS)

$(RELEASE_EXE): $(ODIN_FILES) | $(BIN_DIR)
	$(ODIN_EXE) build . -o:speed -out:$@ $(VET_FLAGS_RELEASE)

$(TEST_EXE): $(ODIN_FILES) | $(BIN_DIR)
	$(ODIN_EXE) test . -o:speed -microarch:native -out:$@ $(VET_FLAGS)

$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

clean:
	@rm -rf $(BIN_DIR)/*

run: debug
	$(DEBUG_EXE) scripts/myscript.pinky

run_release: release
	$(RELEASE_EXE) scripts/myscript.pinky
