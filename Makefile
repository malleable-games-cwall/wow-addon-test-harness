LUA ?= lua
BUSTED ?= busted
LUACHECK ?= luacheck

.PHONY: help deps test lint check binary bundle smoke clean

help:
	@echo "make deps     install busted/luacheck/luafilesystem via luarocks"
	@echo "make test     run the unit test suite"
	@echo "make lint     run luacheck"
	@echo "make check    lint + test"
	@echo "make binary   build a self contained ./dist/wowtest"
	@echo "make bundle   build a portable ./dist/wowtest.lua"
	@echo "make smoke    run the harness against the bundled fixture addons"

deps:
	luarocks install --deps-only wow-addon-test-harness-scm-1.rockspec
	luarocks install busted
	luarocks install luacheck

test:
	$(BUSTED)

lint:
	$(LUACHECK) .

check: lint test

binary:
	scripts/build-binary.sh

bundle:
	mkdir -p dist
	$(LUA) scripts/build-bundle.lua

smoke:
	$(LUA) bin/wowtest.lua --verbose spec/fixtures/SampleAddon

clean:
	rm -rf build dist
